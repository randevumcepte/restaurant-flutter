import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Çağrılar / KDS ekranı açıkken o ekran zaten uyarır → canlı uyarı susar (çift ses olmasın).
final ValueNotifier<int> cagriEkraniAcik = ValueNotifier<int>(0);
final ValueNotifier<int> canliUyariAyar = ValueNotifier<int>(0); // tercih değişince dinleyici yeniden kurulur

/// Bu cihazda canlı uyarı tercihi: 'acik' | 'kapali' | null (varsayılan: personelde açık, patronda kapalı)
Future<void> canliUyariTercihKaydet(String? deger) async {
  final sp = await SharedPreferences.getInstance();
  if (deger == null) { await sp.remove(CanliUyariDinleyici.tercihAnahtar); } else { await sp.setString(CanliUyariDinleyici.tercihAnahtar, deger); }
  canliUyariAyar.value++;
}

final ValueNotifier<bool> mutfakSekmesinde = ValueNotifier<bool>(false); // HomeScreen: seçili alt sekme KDS mi

/// CANLI UYARI — garson/mutfak döngüsü hangi ekranda olursan ol önüne düşer (uygulama içi, push olmasa da).
///  • Servis ekibi: yeni çağrı, servise hazır, hesap/ödeme, taşıma, QR sipariş → üstten kart + ses + titreşim,
///    tek dokunuşla "Servis edildi" / "Gidiyorum". Bekleyen çağrı 2. ve 5. dakikada yeniden hatırlatılır.
///  • Kasa: hesap / ödeme / taşıma.  • Mutfak & bar: yeni sipariş (KDS ekranı kapalıyken).
///  • Patron/müdür: isteğe bağlı (varsayılan kapalı; Menü > Bu cihaz > Canlı uyarılar).
class CanliUyariDinleyici extends StatefulWidget {
  final void Function(String ekran) onAc; // 'cagrilar' | 'mutfak'
  const CanliUyariDinleyici({super.key, required this.onAc});

  static const tercihAnahtar = 'canli_uyari_v1'; // 'acik' | 'kapali' | yok = varsayılan

  @override
  State<CanliUyariDinleyici> createState() => _CanliUyariDinleyiciState();
}

class _Uyari {
  final String tip; // garson|acil|hesap|odeme|servise_hazir|tasima|siparis|mutfak|ozet
  final String baslik;
  final String govde;
  final int? cagriId;
  final bool tekrar;
  _Uyari(this.tip, this.baslik, this.govde, {this.cagriId, this.tekrar = false});
}

class _CanliUyariDinleyiciState extends State<CanliUyariDinleyici> {
  Timer? _cagriTimer, _mutfakTimer;
  final Map<int, int> _cagriHatirlatma = {}; // çağrı id → kaç kez uyarıldı (0: ilk, 1: 2 dk, 2: 5 dk)
  final Set<int> _gorulenKalem = {};
  bool _ilkCagri = true, _ilkMutfak = true;
  final List<_Uyari> _kuyruk = [];
  OverlayEntry? _giris;
  _Uyari? _gosterilen;
  final AudioPlayer _ses = AudioPlayer();
  DateTime _sonSes = DateTime(2000);
  String? _tercih;

  @override
  void initState() {
    super.initState();
    _tercihYukle();
    canliUyariAyar.addListener(_tercihYukle);
  }

  void _tercihYukle() {
    SharedPreferences.getInstance().then((sp) {
      _tercih = sp.getString(CanliUyariDinleyici.tercihAnahtar);
      if (mounted) _baslat();
    });
  }

  @override
  void dispose() {
    canliUyariAyar.removeListener(_tercihYukle);
    _cagriTimer?.cancel();
    _mutfakTimer?.cancel();
    _giris?.remove();
    _ses.dispose();
    super.dispose();
  }

  bool get _servisModu {
    final a = context.read<AuthProvider>();
    final servis = a.departmanKod == 'servis' || const ['garson', 'komi', 'sef_garson'].contains(a.rol);
    final patron = a.rol == 'sahip' || a.rol == 'mudur';
    if (_tercih == 'kapali') return false;
    if (patron) return _tercih == 'acik';
    return servis || _kasaModu || (_tercih == 'acik' && a.yetkiVar('gor_garson_cagri'));
  }

  bool get _kasaModu {
    final a = context.read<AuthProvider>();
    return a.kasiyer || a.departmanKod == 'kasa' || a.rol == 'kasa';
  }

  bool get _mutfakModu {
    final a = context.read<AuthProvider>();
    if (_tercih == 'kapali') return false;
    return const ['mutfak', 'soguk_mutfak', 'pastane', 'kasap', 'bar'].contains(a.departmanKod) || const ['mutfak', 'bar', 'barmen'].contains(a.rol);
  }

  void _baslat() {
    _cagriTimer?.cancel();
    _mutfakTimer?.cancel();
    if (_servisModu) {
      _cagriCek();
      _cagriTimer = Timer.periodic(const Duration(seconds: 5), (_) => _cagriCek());
    }
    if (_mutfakModu) {
      _mutfakCek();
      _mutfakTimer = Timer.periodic(const Duration(seconds: 8), (_) => _mutfakCek());
    }
  }

  static int _i(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  Future<void> _cagriCek() async {
    if (!mounted) return;
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    try {
      final r = await Api.garsonCagrilari(tok);
      if (!mounted || r['ok'] != 1) return;
      final liste = [for (final c in (r['cagrilar'] as List? ?? const [])) if (c is Map) Map<String, dynamic>.from(c)];
      final kasaYalniz = _kasaModu && !(context.read<AuthProvider>().departmanKod == 'servis' || const ['garson', 'komi', 'sef_garson'].contains(context.read<AuthProvider>().rol));
      final ilgili = liste.where((c) => !kasaYalniz || const ['hesap', 'odeme', 'tasima'].contains('${c['tip']}')).toList();
      final aktifIdler = ilgili.map((c) => _i(c['id'])).toSet();
      _cagriHatirlatma.removeWhere((id, _) => !aktifIdler.contains(id));
      // Kapanan çağrının kartı ekrandaysa kaldır
      if (_gosterilen?.cagriId != null && !aktifIdler.contains(_gosterilen!.cagriId)) _kapat();
      _kuyruk.removeWhere((u) => u.cagriId != null && !aktifIdler.contains(u.cagriId));

      if (_ilkCagri) {
        _ilkCagri = false;
        for (final c in ilgili) { _cagriHatirlatma[_i(c['id'])] = _i(c['saniye']) >= 300 ? 2 : (_i(c['saniye']) >= 120 ? 1 : 0); }
        if (ilgili.isNotEmpty) _ekle(_Uyari('ozet', '🔔 ${ilgili.length} bekleyen çağrı var', ilgili.take(3).map((c) => '${c['masa']} · ${_tipAd('${c['tip']}')}').join('\n')));
        return;
      }
      if (cagriEkraniAcik.value > 0) {
        for (final c in ilgili) { _cagriHatirlatma.putIfAbsent(_i(c['id']), () => 0); }
        return;
      }
      for (final c in ilgili) {
        final id = _i(c['id']);
        final tip = '${c['tip']}';
        final sn = _i(c['saniye']);
        if (!_cagriHatirlatma.containsKey(id)) {
          _cagriHatirlatma[id] = 0;
          _ekle(_cagridanUyari(c));
        } else if (tip != 'siparis' && tip != 'tasima') {
          final n = _cagriHatirlatma[id]!;
          if ((n == 0 && sn >= 120) || (n == 1 && sn >= 300)) {
            _cagriHatirlatma[id] = n + 1;
            _ekle(_cagridanUyari(c, tekrar: true));
          }
        }
      }
    } on ApiYetkiHatasi {
      _cagriTimer?.cancel();
    } catch (_) {}
  }

  String _tipAd(String t) => const {
        'servise_hazir': 'servise hazır', 'garson': 'garson çağırıyor', 'acil': 'ACİL çağrı', 'hesap': 'hesap istiyor',
        'odeme': 'ödeme yapmak istiyor', 'tasima': 'taşıma talebi', 'siparis': 'sipariş verdi',
      }[t] ?? 'çağrı';

  _Uyari _cagridanUyari(Map<String, dynamic> c, {bool tekrar = false}) {
    final tip = '${c['tip']}';
    final masa = '${c['masa'] ?? ''}';
    final dk = (_i(c['saniye']) / 60).floor();
    final ikon = const {'servise_hazir': '🛎️', 'garson': '🙋', 'acil': '🔴', 'hesap': '💳', 'odeme': '💳', 'tasima': '↔️', 'siparis': '🍽️'}[tip] ?? '🔔';
    var govde = '${c['detay'] ?? ''}'.trim();
    if (tip == 'odeme' && c['tutar'] != null) govde = '${(c['tutar'] as num).toStringAsFixed(2).replaceAll('.', ',')} ₺ · nakit ya da kartla tahsil edin';
    if (tip == 'tasima' && c['hedef'] != null) govde = '$masa → ${c['hedef']}';
    if (govde.isEmpty) govde = const {'garson': 'Masaya gidin', 'acil': 'Hemen masaya gidin', 'hesap': 'Hesabı götürün', 'servise_hazir': 'Mutfaktan alıp masaya götürün'}[tip] ?? '';
    final baslik = tekrar ? '⏰ $masa · $dk dk\'dır bekliyor' : '$ikon $masa · ${_tipAd(tip)}';
    return _Uyari(tip, baslik, tekrar ? '${_tipAd(tip)[0].toUpperCase()}${_tipAd(tip).substring(1)}${govde.isEmpty ? '' : ' · $govde'}' : govde, cagriId: _i(c['id']), tekrar: tekrar);
  }

  Future<void> _mutfakCek() async {
    if (!mounted) return;
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    try {
      final r = await Api.mutfak(tok);
      if (!mounted || r['ok'] != 1) return;
      final yeniler = <String, List<String>>{};
      for (final s in (r['siparisler'] as List? ?? const [])) {
        if (s is! Map) continue;
        for (final k in (s['kalemler'] as List? ?? const [])) {
          if (k is! Map) continue;
          final id = _i(k['id']);
          if (_gorulenKalem.add(id) && !_ilkMutfak && '${k['durum']}' == 'gonderildi') {
            final adet = (k['adet'] is num && (k['adet'] as num) > 1) ? '${(k['adet'] as num).toString().replaceAll('.0', '')}× ' : '';
            yeniler.putIfAbsent('${s['masa'] ?? 'Paket'}', () => []).add('$adet${k['ad']}');
          }
        }
      }
      _ilkMutfak = false;
      if (yeniler.isEmpty || mutfakSekmesinde.value) return;
      for (final e in yeniler.entries) {
        _ekle(_Uyari('mutfak', '🍽️ Yeni sipariş · ${e.key}', e.value.take(5).join(', ') + (e.value.length > 5 ? ' +${e.value.length - 5}' : '')));
      }
    } on ApiYetkiHatasi {
      _mutfakTimer?.cancel();
    } catch (_) {}
  }

  void _ekle(_Uyari u) {
    _kuyruk.removeWhere((x) => x.cagriId != null && x.cagriId == u.cagriId);
    _kuyruk.add(u);
    if (_giris == null) _siradaki();
  }

  void _siradaki() {
    if (!mounted || _kuyruk.isEmpty) return;
    final u = _kuyruk.removeAt(0);
    _gosterilen = u;
    _sesCal(u);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _giris = OverlayEntry(builder: (_) => _UyariKart(
          uyari: u,
          onKapat: _kapat,
          onIslem: (islem) => _islem(u, islem),
        ));
    overlay.insert(_giris!);
  }

  void _kapat() {
    _giris?.remove();
    _giris = null;
    _gosterilen = null;
    if (_kuyruk.isNotEmpty) Future.delayed(const Duration(milliseconds: 350), _siradaki);
  }

  Future<void> _islem(_Uyari u, String islem) async {
    _kapat();
    if (islem == 'ac') {
      widget.onAc(u.tip == 'mutfak' ? 'mutfak' : 'cagrilar');
      return;
    }
    if (islem == 'karsila' && u.cagriId != null) {
      final tok = context.read<AuthProvider>().token;
      if (tok == null) return;
      try {
        final r = await Api.garsonCagriKapat(tok, u.cagriId!);
        _cagriHatirlatma.remove(u.cagriId);
        if (!mounted) return;
        final m = ScaffoldMessenger.maybeOf(context);
        m?.showSnackBar(SnackBar(
          content: Text(r['ok'] == 1 ? '${r['mesaj'] ?? 'Tamam'}' : '${r['mesaj'] ?? r['hata'] ?? 'İşlenemedi'}'),
          backgroundColor: r['ok'] == 1 ? const Color(0xFF059669) : const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
        ));
      } catch (_) {}
    }
  }

  Future<void> _sesCal(_Uyari u) async {
    final simdi = DateTime.now();
    if (simdi.difference(_sonSes).inMilliseconds < 1500) return;
    _sonSes = simdi;
    try {
      await _ses.stop();
      await _ses.play(AssetSource(u.tip == 'mutfak' ? 'ses/siparis.wav' : 'ses/cagri.wav'), volume: u.tekrar ? .7 : 1);
    } catch (_) {
      try { SystemSound.play(SystemSoundType.alert); } catch (_) {}
    }
    try {
      if (await Vibration.hasVibrator() == true) {
        Vibration.vibrate(pattern: u.tip == 'acil' ? [0, 500, 150, 500, 150, 500] : [0, 350, 120, 350]);
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Üstten kayan uyarı kartı (masaüstünde sağ üstte, telefonda üstte tam genişlik)
class _UyariKart extends StatefulWidget {
  final _Uyari uyari;
  final VoidCallback onKapat;
  final void Function(String islem) onIslem;
  const _UyariKart({required this.uyari, required this.onKapat, required this.onIslem});

  @override
  State<_UyariKart> createState() => _UyariKartState();
}

class _UyariKartState extends State<_UyariKart> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 260))..forward();
  Timer? _oto;

  @override
  void initState() {
    super.initState();
    final t = widget.uyari.tip;
    // Acil ve servise hazır daha uzun kalır; dokunulmazsa kendiliğinden kapanır (çağrı listede bekler, hatırlatma sürer)
    _oto = Timer(Duration(seconds: t == 'acil' ? 40 : (t == 'servise_hazir' || t == 'odeme' ? 25 : 14)), () => _kapan(widget.onKapat));
  }

  @override
  void dispose() {
    _oto?.cancel();
    _a.dispose();
    super.dispose();
  }

  Future<void> _kapan(VoidCallback sonra) async {
    _oto?.cancel();
    if (!mounted) return;
    await _a.reverse();
    sonra();
  }

  Color get _renk => const {
        'servise_hazir': Color(0xFF059669), 'acil': Color(0xFFDC2626), 'hesap': Color(0xFF2563EB), 'odeme': Color(0xFF2563EB),
        'tasima': Color(0xFF7C3AED), 'siparis': Color(0xFFEA580C), 'mutfak': Color(0xFFEA580C), 'garson': Color(0xFFF59E0B), 'ozet': Color(0xFF4F46E5),
      }[widget.uyari.tip] ?? const Color(0xFF4F46E5);

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final u = widget.uyari;
    final genis = MediaQuery.sizeOf(context).width >= 1000;
    final birincil = switch (u.tip) {
      'servise_hazir' => ('Servis edildi', Icons.room_service_outlined, 'karsila'),
      'garson' || 'acil' => ('Gidiyorum', Icons.directions_walk, 'karsila'),
      'mutfak' => ('KDS\'yi aç', Icons.soup_kitchen_outlined, 'ac'),
      _ => ('Aç', Icons.open_in_new, 'ac'),
    };
    final kart = Material(
      color: t.card,
      elevation: 14,
      shadowColor: Colors.black45,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: _renk, width: 6))),
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.baslik, style: TextStyle(color: t.ink, fontSize: 16.5, fontWeight: FontWeight.w800)),
                if (u.govde.isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 4), child: Text(u.govde, maxLines: 4, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 14, height: 1.35))),
              ]),
            ),
            IconButton(onPressed: () => _kapan(widget.onKapat), icon: Icon(Icons.close, color: t.sub), tooltip: 'Kapat', visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            if (birincil.$3 == 'karsila') ...[
              TextButton.icon(
                onPressed: () => _kapan(() => widget.onIslem('ac')),
                icon: Icon(Icons.list_alt, color: t.sub2, size: 18),
                label: Text('Tümü', style: TextStyle(color: t.sub2, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
            ] else
              const Spacer(),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _renk, minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => _kapan(() => widget.onIslem(birincil.$3)),
              icon: Icon(birincil.$2, size: 19),
              label: Text(birincil.$1, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            ),
            const SizedBox(width: 6),
          ]),
        ]),
      ),
    );
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: genis ? null : 10,
      right: 10,
      width: genis ? 440 : null,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -1.3), end: Offset.zero).animate(CurvedAnimation(parent: _a, curve: Curves.easeOutBack)),
        child: Dismissible(
          key: ValueKey(u),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onKapat(),
          child: kart,
        ),
      ),
    );
  }
}

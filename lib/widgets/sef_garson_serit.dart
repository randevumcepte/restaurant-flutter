import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// SEF GARSON AI — Masalar ekranina GOMULU satis uyari seridi + AKILLI POPUP/ESKALASYON.
/// - Uyari kartlari varsayilan TURUNCU + dikkat ikonu (gorulmedi).
/// - "Ne satayim?" -> AI oneri -> "Anladim" deyince kart YESIL + onay ikonu (ustte kalir).
/// - Yeni/tekrar uyari gelince: telefon titrer + otomatik POPUP (musaitse hemen bakar).
/// - Garson bakmazsa sunucu belli araliklarla tekrar bildirir; esik asilinca YONETICIYE
///   "garson uyarilari dikkate almiyor" bildirimi gider (yonetici bu seritte kirmizi kart gorur).
class SefGarsonSerit extends StatefulWidget {
  const SefGarsonSerit({super.key});
  @override
  State<SefGarsonSerit> createState() => _SefGarsonSeritState();
}

class _SefGarsonSeritState extends State<SefGarsonSerit> {
  static const _mor = Color(0xFF7C3AED);
  static const _turuncu = Color(0xFFF59E0B);
  static const _yesil = Color(0xFF16A34A);
  static const _kirmizi = Color(0xFFDC2626);

  TemaProvider get _t => context.watch<TemaProvider>();
  Color get _sub => _t.sub;

  List<Map<String, dynamic>> uyarilar = [];
  List<Map<String, dynamic>> yoneticiUyarilar = [];
  final Set<String> _gorulen = {};          // lokal: "Anladim" denen -> aninda yesil
  final Map<String, DateTime> _ertelenen = {}; // "Sonra" denen -> gecici sustur (5 dk)
  final Set<int> _bilinenYonetici = {};
  bool _popupAcik = false, _patron = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cek();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _cek());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _anahtar(Map<String, dynamic> u) => '${u['adisyon_id']}.${u['tip']}';
  bool _goruldu(Map<String, dynamic> u) => u['durum'] == 'goruldu' || _gorulen.contains(_anahtar(u));

  Future<void> _cek() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;
    _patron = auth.rol == 'sahip' || auth.rol == 'mudur';
    try {
      final res = await Api.sefGarsonUyarilar(auth.token!);
      if (!mounted) return;
      List<Map<String, dynamic>> liste = [];
      if (res['ok'] == 1) {
        liste = ((res['uyarilar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      // Yonetici (patron) icin eskale uyarilar
      List<Map<String, dynamic>> yon = [];
      if (_patron) {
        try {
          final yr = await Api.sefGarsonYoneticiUyarilar(auth.token!);
          if (yr['ok'] == 1) yon = ((yr['uyarilar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
      if (!mounted) return;
      // Sunucu bir uyariyi tekrar aktive ettiyse (bos soz: "Anladim" deyip satmadi) lokal yesili kaldir
      for (final u in liste) { if (u['durum'] != 'goruldu') _gorulen.remove(_anahtar(u)); }
      setState(() { uyarilar = liste; yoneticiUyarilar = yon; });

      // POPUP: sunucu "bildir=true" dediyse (yeni ya da tekrar hatirlatma) -> titre + popup
      // POPUP: sadece bu ekran (Masalar) ÖNDEyken çık — satış/ödeme ekranındayken
      // (üstte başka route varsa) sipariş bölünmesin. "Sonra" denenler 5 dk ertelenir.
      final ekranOnde = ModalRoute.of(context)?.isCurrent ?? false;
      if (!_popupAcik && ekranOnde) {
        final simdi = DateTime.now();
        final tetik = liste.where((u) {
          final ert = _ertelenen[_anahtar(u)];
          return u['bildir'] == true && !_goruldu(u) && (ert == null || simdi.isAfter(ert));
        }).toList();
        if (tetik.isNotEmpty) {
          HapticFeedback.vibrate();
          _popupGoster(tetik.first);
        }
      }
      // Yeni eskalasyon geldiyse yoneticiyi titret
      if (_patron) {
        final yeniEsk = yon.where((y) => !_bilinenYonetici.contains(y['id'] as int)).toList();
        if (yeniEsk.isNotEmpty && _bilinenYonetici.isNotEmpty) HapticFeedback.vibrate();
        _bilinenYonetici
          ..clear()
          ..addAll(yon.map((y) => y['id'] as int));
      }
    } catch (_) {/* sessiz: Masalar ekranini bozma */}
  }

  // Yeni firsat popup'i: "Ne satayim?" -> oneri akisi; "Sonra" -> kapat (sunucu tekrar hatirlatir)
  Future<void> _popupGoster(Map<String, dynamic> u) async {
    _popupAcik = true;
    final t = context.read<TemaProvider>();
    final ikon = u['ikon']?.toString() ?? '💡';
    // Sunucu bos baslik/mesaj gonderirse popup bombos gorunmesin -> anlamli varsayilan
    final bt = u['baslik']?.toString().trim() ?? '';
    final baslik = bt.isNotEmpty ? bt : 'Satış fırsatı';
    final mt = u['mesaj']?.toString().trim() ?? '';
    final masaAd = u['masa_adi']?.toString().trim() ?? '';
    final mesaj = mt.isNotEmpty
        ? mt
        : (masaAd.isNotEmpty ? '$masaAd masasında satışı artırabileceğiniz bir fırsat var. Öneri için "Ne satayım?" deyin. 😊'
                             : 'Satışı artırabileceğiniz bir fırsat var. Öneri için "Ne satayım?" deyin. 😊');
    await showDialog(useRootNavigator: true, 
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        surfaceTintColor: t.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        title: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(ikon, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(baslik, style: TextStyle(color: t.ink, fontSize: 16.5, fontWeight: FontWeight.w900))),
        ]),
        content: Text(mesaj, style: TextStyle(color: t.ink, fontSize: 14.5, height: 1.4)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(onPressed: () { _ertelenen[_anahtar(u)] = DateTime.now().add(const Duration(minutes: 5)); Navigator.pop(ctx); }, child: Text('Sonra', style: TextStyle(color: t.sub, fontWeight: FontWeight.w600))),
          FilledButton.icon(
            onPressed: () { Navigator.pop(ctx); _oneriGoster(u); },
            style: FilledButton.styleFrom(backgroundColor: _mor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
            icon: const Icon(Icons.emoji_objects, color: Colors.white, size: 18),
            label: const Text('Ne satayım?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    _popupAcik = false;
  }

  // AI oneri sheet'i. Alttaki "Anladim" -> uyari GORULDU (yesil) + popup/hatirlatma durur.
  Future<void> _oneriGoster(Map<String, dynamic> u) async {
    final auth = context.read<AuthProvider>();
    final t = context.read<TemaProvider>();
    await showModalBottomSheet(useRootNavigator: true, 
      context: context,
      backgroundColor: t.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => FutureBuilder<Map<String, dynamic>>(
        future: Api.sefGarsonOneri(auth.token!, u['adisyon_id'] as int, derin: true),
        builder: (ctx, snap) {
          final yuk = snap.connectionState != ConnectionState.done;
          final data = snap.data;
          final mesaj = (data?['ok'] == 1) ? (data?['mesaj']?.toString() ?? '') : 'Öneri alınamadı.';
          final urunler = ((data?['urunler'] as List?) ?? []).map((e) => e.toString()).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor, Color(0xFF4F46E5)]), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.emoji_objects, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('${u['masa_adi']} — ne satayım?', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 16),
              if (yuk)
                Row(children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: _mor)),
                  const SizedBox(width: 12),
                  Text('Şef düşünüyor…', style: TextStyle(color: t.sub, fontSize: 14)),
                ])
              else ...[
                Text(mesaj, style: TextStyle(color: t.ink, fontSize: 15.5, height: 1.35, fontWeight: FontWeight.w600)),
                if (urunler.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: urunler.map((ad) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: _mor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: _mor.withValues(alpha: 0.35))),
                    child: Text(ad, style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  )).toList()),
                ],
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    try { await Api.sefGarsonUyariGordum(auth.token!, u['adisyon_id'] as int, u['tip']?.toString() ?? ''); } catch (_) {}
                    if (mounted) setState(() { _gorulen.add(_anahtar(u)); u['durum'] = 'goruldu'; });
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                  style: FilledButton.styleFrom(backgroundColor: _yesil, padding: const EdgeInsets.symmetric(vertical: 13)),
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  label: const Text('Anladım, satmaya gidiyorum', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _yoneticiOku(Map<String, dynamic> y) async {
    final auth = context.read<AuthProvider>();
    setState(() => yoneticiUyarilar.removeWhere((x) => x['id'] == y['id']));
    try { await Api.sefGarsonYoneticiUyariOku(auth.token!, y['id'] as int); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final toplam = uyarilar.length + yoneticiUyarilar.length;
    if (toplam == 0) return const SizedBox.shrink();
    final t = _t;
    return Container(
      color: t.card,
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 5),
          child: Row(children: [
            const Text('🎯 ', style: TextStyle(fontSize: 12)),
            Text('Şef Garson', style: TextStyle(color: t.ink, fontSize: 12, fontWeight: FontWeight.w900)),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(color: _mor, borderRadius: BorderRadius.circular(9)),
              child: Text('${uyarilar.where((u) => !_goruldu(u)).length} fırsat', style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        SizedBox(
          height: 116,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            children: [
              // Yonetici (kirmizi) kartlar once
              for (final y in yoneticiUyarilar) ...[_yoneticiKart(y), const SizedBox(width: 8)],
              // Uyari kartlari
              for (int i = 0; i < uyarilar.length; i++) ...[
                _kart(uyarilar[i]),
                if (i < uyarilar.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _kart(Map<String, dynamic> u) {
    final t = _t;
    final goruldu = _goruldu(u);
    final eskale = !goruldu && u['durum'] == 'eskale';   // yoneticiye bildirildi -> kirmizi (garsonda da)
    final vurgu = goruldu ? _yesil : (eskale ? _kirmizi : _turuncu);
    final bg = t.koyu
        ? vurgu.withValues(alpha: 0.14)
        : (goruldu ? const Color(0xFFECFDF5) : (eskale ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED)));
    final kenar = t.koyu
        ? vurgu.withValues(alpha: 0.45)
        : (goruldu ? const Color(0xFFA7F3D0) : (eskale ? const Color(0xFFFECACA) : const Color(0xFFFDBA74)));
    final ikon = u['ikon']?.toString() ?? '💡';
    return GestureDetector(
      onTap: () => _popupGoster(u),
      child: Container(
      width: 196,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: kenar, width: eskale ? 1.6 : 1.2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: vurgu.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
            child: Icon(goruldu ? Icons.check_circle : (eskale ? Icons.report_gmailerrorred : Icons.warning_amber_rounded), color: vurgu, size: 16),
          ),
          const SizedBox(width: 7),
          Expanded(child: Row(children: [
            Text(ikon, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 3),
            Expanded(child: Text(u['baslik']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.ink, fontSize: 11.5, fontWeight: FontWeight.w900))),
          ])),
        ]),
        const SizedBox(height: 5),
        Expanded(child: Text(
          goruldu
              ? 'Anlaşıldı — satışa gidiliyor 👍'
              : (eskale ? '⚠️ Yöneticiye bildirildi — hâlâ satış yok.' : (u['mesaj']?.toString() ?? '')),
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: goruldu ? _yesil : (eskale ? _kirmizi : _sub), fontSize: 11, height: 1.25,
              fontWeight: (goruldu || eskale) ? FontWeight.w700 : FontWeight.normal),
        )),
        const SizedBox(height: 5),
        if (goruldu)
          const SizedBox(
            height: 26,
            child: Center(child: Text('✓ görüldü', style: TextStyle(color: _yesil, fontSize: 11, fontWeight: FontWeight.bold))),
          )
        else
          SizedBox(
            width: double.infinity, height: 26,
            child: FilledButton.icon(
              onPressed: () => _oneriGoster(u),
              style: FilledButton.styleFrom(backgroundColor: eskale ? _kirmizi : _mor, padding: EdgeInsets.zero),
              icon: const Icon(Icons.emoji_objects, size: 13, color: Colors.white),
              label: const Text('Ne satayım?', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
      ),
    );
  }

  Widget _yoneticiKart(Map<String, dynamic> y) {
    final t = _t;
    return GestureDetector(
      onTap: () => _yoneticiDetay(y),
      child: Container(
      width: 200,
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: t.koyu ? _kirmizi.withValues(alpha: 0.14) : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: t.koyu ? _kirmizi.withValues(alpha: 0.45) : const Color(0xFFFECACA), width: 1.4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: _kirmizi.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.report_gmailerrorred, color: _kirmizi, size: 17),
          ),
          const SizedBox(width: 7),
          const Expanded(child: Text('Dikkat edilmiyor', style: TextStyle(color: _kirmizi, fontSize: 11.5, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 5),
        Expanded(child: Text(y['mesaj']?.toString() ?? 'Garson uyarıları dikkate almıyor.',
            maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 11, height: 1.25))),
        const SizedBox(height: 5),
        SizedBox(
          width: double.infinity, height: 26,
          child: OutlinedButton(
            onPressed: () => _yoneticiOku(y),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: _kirmizi), padding: EdgeInsets.zero),
            child: const Text('Tamam', style: TextStyle(color: _kirmizi, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
      ),
    );
  }

  // Yönetici (kırmızı) kartı → tam metinli, GENİŞ popup (küçük kartta okunmuyordu).
  Future<void> _yoneticiDetay(Map<String, dynamic> y) async {
    final t = _t;
    final masa = y['masa_adi']?.toString().trim() ?? '';
    final garson = y['garson_adi']?.toString().trim() ?? '';
    await showDialog(useRootNavigator: true, context: context, builder: (ctx) => Dialog(
      backgroundColor: t.card,
      insetPadding: const EdgeInsets.all(28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Kırmızı başlık şeridi
          Container(
            width: double.infinity, padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            color: _kirmizi.withValues(alpha: t.koyu ? 0.20 : 0.10),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: _kirmizi.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(11)),
                child: const Icon(Icons.report_gmailerrorred, color: _kirmizi, size: 22)),
              const SizedBox(width: 12),
              const Expanded(child: Text('Dikkat Edilmiyor', style: TextStyle(color: _kirmizi, fontSize: 18, fontWeight: FontWeight.w900))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (masa.isNotEmpty || garson.isNotEmpty) ...[
                Wrap(spacing: 8, runSpacing: 8, children: [
                  if (masa.isNotEmpty) _detayCip(t, Icons.table_restaurant, masa),
                  if (garson.isNotEmpty) _detayCip(t, Icons.person, garson),
                ]),
                const SizedBox(height: 12),
              ],
              Text(y['mesaj']?.toString() ?? 'Garson, satış uyarılarını dikkate almıyor.',
                  style: TextStyle(color: t.ink, fontSize: 15.5, height: 1.5)),
              const SizedBox(height: 18),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: BorderSide(color: t.line), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text('Kapat', style: TextStyle(color: t.sub2, fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: FilledButton.icon(
                  onPressed: () { Navigator.pop(ctx); _yoneticiOku(y); },
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Anladım, ilgileniyorum', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(backgroundColor: _kirmizi, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    ));
  }

  Widget _detayCip(TemaProvider t, IconData ikon, String metin) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(9), border: Border.all(color: t.line)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ikon, size: 14, color: t.sub2), const SizedBox(width: 5),
          Text(metin, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );
}

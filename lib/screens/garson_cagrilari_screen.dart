import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Canli Garson Cagrilari — QR menuden "Garson Cagir/Hesap iste" gelince buraya aninda duser.
/// 4 sn'de bir yenilenir; yeni cagrida titresim + sesli anons; "Karsilandi" ile kapatilir.
class GarsonCagrilariScreen extends StatefulWidget {
  const GarsonCagrilariScreen({super.key});
  @override
  State<GarsonCagrilariScreen> createState() => _GarsonCagrilariScreenState();
}

class _GarsonCagrilariScreenState extends State<GarsonCagrilariScreen> {
  TemaProvider get _t => context.watch<TemaProvider>();

  List<Map<String, dynamic>> cagrilar = [];
  final Set<int> _biliniyor = {};
  bool _ilk = true, sesli = true, _mesgul = false;
  bool? _titresebilir;   // cihaz titresim destekliyor mu (bir kez sorulur)
  int _anonsSayac = 0;   // sesli hatirlatma sayaci
  String? hata;
  Timer? _timer;
  final FlutterTts _tts = FlutterTts();

  // GÜÇLÜ desenli titreşim — yoğun restoranda hissedilsin (karşılanana kadar her poll tekrar).
  Future<void> _titret() async {
    try {
      _titresebilir ??= (await Vibration.hasVibrator()) == true;
      if (_titresebilir == true) {
        // bekle-BRR-dur-BRR-dur-BRRRR : belirgin, alarm hissi (~2.1 sn)
        Vibration.vibrate(
          pattern: [0, 500, 200, 500, 200, 750],
          intensities: [0, 255, 0, 255, 0, 255],
        );
      } else {
        HapticFeedback.heavyImpact();
      }
    } catch (_) {
      try { HapticFeedback.heavyImpact(); } catch (_) {}
    }
  }

  @override
  void initState() {
    super.initState();
    _tts.setLanguage('tr-TR');
    _tts.setSpeechRate(0.48);
    _cek();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _cek());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tts.stop();
    try { Vibration.cancel(); } catch (_) {}
    super.dispose();
  }

  String _tipYazi(String t) => t == 'hesap' ? 'Hesap istiyor' : (t == 'siparis' ? 'Sipariş verdi' : 'Garson çağırıyor');
  IconData _tipIkon(String t) => t == 'hesap' ? Icons.credit_card : (t == 'siparis' ? Icons.receipt_long : Icons.notifications_active);
  String _sure(int sn) { sn = sn < 0 ? 0 : sn; if (sn < 60) return '$sn sn'; return '${(sn / 60).floor()} dk'; }

  Future<void> _cek() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;
    try {
      final res = await Api.garsonCagrilari(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        final liste = ((res['cagrilar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        // yeni cagri var mi?
        final yeniler = liste.where((c) => !_biliniyor.contains(c['id'])).toList();
        if (!_ilk) {
          // KARŞILANANA KADAR TEKRAR: açık çağrı oldukça her yenilemede (≈4 sn) güçlü titret.
          if (liste.isNotEmpty) {
            _titret();
            if (sesli) {
              if (yeniler.isNotEmpty) {
                _anonsSayac = 0;
                final ilkYeni = yeniler.first;
                _tts.speak('${ilkYeni['masa']}, ${_tipYazi(ilkYeni['tip']?.toString() ?? '')}');
              } else if ((++_anonsSayac) % 3 == 0) {
                // ≈12 sn'de bir sesli hatırlatma (TTS sürekli konuşmasın)
                _tts.speak('${liste.length} bekleyen çağrı var');
              }
            }
          } else {
            _anonsSayac = 0;
          }
        }
        _biliniyor
          ..clear()
          ..addAll(liste.map((c) => c['id'] as int));
        _ilk = false;
        setState(() { cagrilar = liste; hata = null; });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => hata = 'Bağlantı bekleniyor…');
    }
  }

  Future<void> _hepsiniKapat() async {
    if (_mesgul || cagrilar.isEmpty) return;
    _mesgul = true;
    try { Vibration.cancel(); } catch (_) {}
    setState(() => cagrilar = []);
    final auth = context.read<AuthProvider>();
    try { await Api.garsonCagriHepsiniKapat(auth.token!); } catch (_) {}
    _biliniyor.clear();
    _anonsSayac = 0;
    _mesgul = false;
    _cek();
  }

  Future<void> _kapat(int id) async {
    if (_mesgul) return;
    _mesgul = true;
    setState(() => cagrilar.removeWhere((c) => c['id'] == id));
    final auth = context.read<AuthProvider>();
    try { await Api.garsonCagriKapat(auth.token!, id); } catch (_) {}
    _biliniyor.remove(id);
    _mesgul = false;
    _cek();
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        iconTheme: IconThemeData(color: t.ink),
        title: Row(children: [
          const Text('🔔 ', style: TextStyle(fontSize: 18)),
          Text('Garson Çağrıları', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
          if (cagrilar.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: t.kirmizi, borderRadius: BorderRadius.circular(12)),
              child: Text('${cagrilar.length}', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ],
        ]),
        actions: [
          if (cagrilar.isNotEmpty)
            TextButton.icon(
              onPressed: _hepsiniKapat,
              icon: Icon(Icons.done_all, color: t.gold, size: 19),
              label: Text('Tümünü karşıla', style: TextStyle(color: t.gold, fontWeight: FontWeight.bold)),
            ),
          IconButton(
            tooltip: sesli ? 'Sesli anons açık' : 'Sesli anons kapalı',
            onPressed: () => setState(() => sesli = !sesli),
            icon: Icon(sesli ? Icons.volume_up : Icons.volume_off, color: sesli ? t.gold : t.sub),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cek,
        color: t.mor1,
        backgroundColor: t.card,
        child: cagrilar.isEmpty
            ? ListView(children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.28),
                Icon(Icons.notifications_none, size: 60, color: t.sub),
                const SizedBox(height: 14),
                Center(child: Text(hata ?? 'Bekleyen çağrı yok', style: TextStyle(color: t.sub, fontSize: 16, fontWeight: FontWeight.w600))),
                const SizedBox(height: 6),
                Center(child: Text('QR menüden gelen çağrılar buraya anında düşer.', style: TextStyle(color: t.sub, fontSize: 12.5))),
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(14),
                itemCount: cagrilar.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _kart(cagrilar[i], t),
              ),
      ),
    );
  }

  Widget _kart(Map<String, dynamic> c, TemaProvider t) {
    final tip = c['tip']?.toString() ?? 'garson';
    final hesap = tip == 'hesap';
    final sn = (c['saniye'] is num) ? (c['saniye'] as num).toInt() : 0;
    final geciken = sn >= 60;
    final vurgu = hesap ? t.amber : t.kirmizi;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: geciken ? t.kirmizi : t.line, width: geciken ? 1.6 : 1),
        boxShadow: t.golge,
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: vurgu.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
          child: Icon(_tipIkon(tip), color: vurgu, size: 26),
        ),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(c['masa']?.toString() ?? '', style: TextStyle(color: t.ink, fontSize: 19, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(_tipYazi(tip), style: TextStyle(color: vurgu, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(_sure(sn), style: TextStyle(color: geciken ? t.kirmizi : t.gold, fontSize: 16, fontWeight: FontWeight.w800)),
          Text(c['saat']?.toString() ?? '', style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
        const SizedBox(width: 10),
        FilledButton(
          onPressed: () => _kapat(c['id'] as int),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
          child: const Text('✓', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

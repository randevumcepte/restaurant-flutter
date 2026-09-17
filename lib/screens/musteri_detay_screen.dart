import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import 'menu_hamburger.dart';

/// Gelen Müşteri Detayı — dönemsel trafik: özet + zaman serisi + yoğun saat/gün
/// + kanal + bölge + sadakat + AI koçluk. Dashboard'daki "Gelen Müşteri" kartından açılır.
class MusteriDetayScreen extends StatefulWidget {
  final String period;
  const MusteriDetayScreen({super.key, this.period = 'gunluk'});
  @override
  State<MusteriDetayScreen> createState() => _MusteriDetayScreenState();
}

class _MusteriDetayScreenState extends State<MusteriDetayScreen> {
  late String period;
  Map? d;
  bool loading = true;
  final _f = NumberFormat.decimalPattern('tr');
  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  static const _mor1 = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);

  @override
  void initState() { super.initState(); period = widget.period; _yukle(); }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.musteriDetay(auth.token!, period: period);
      if (!mounted) return;
      setState(() { d = res['ok'] == 1 ? res : null; loading = false; });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _donem(String p) { if (p == period) return; setState(() => period = p); _yukle(); }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
        title: Text('Gelen Müşteri', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: const [MenuHamburger()],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : d == null
              ? Center(child: Text('Veri alınamadı', style: TextStyle(color: t.sub)))
              : ListView(padding: const EdgeInsets.all(14), children: [
                  _donemSecici(t),
                  const SizedBox(height: 14),
                  _ozet(t),
                  const SizedBox(height: 14),
                  _trafik(t),
                  const SizedBox(height: 14),
                  _yogunSaat(t),
                  const SizedBox(height: 14),
                  _gunler(t),
                  const SizedBox(height: 14),
                  _kanal(t),
                  const SizedBox(height: 14),
                  _bolge(t),
                  const SizedBox(height: 14),
                  _sadakat(t),
                  const SizedBox(height: 14),
                  _aiKart(t),
                  const SizedBox(height: 30),
                ]),
    );
  }

  Widget _donemSecici(TemaProvider t) {
    Widget btn(String key, String label) {
      final sec = period == key;
      return Expanded(child: GestureDetector(
        onTap: () => _donem(key),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(color: sec ? _mor1 : t.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: sec ? _mor1 : t.line)),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: sec ? Colors.white : t.sub2, fontWeight: FontWeight.w600, fontSize: 12.5)),
        ),
      ));
    }
    return Row(children: [btn('gunluk', 'Günlük'), btn('haftalik', 'Haftalık'), btn('aylik', 'Aylık'), btn('yillik', 'Yıllık')]);
  }

  String get _donemAd => const {'gunluk': 'bugün', 'haftalik': 'bu hafta', 'aylik': 'bu ay', 'yillik': 'bu yıl'}[period] ?? 'bu dönem';

  Widget _ozet(TemaProvider t) {
    final o = (d!['ozet'] as Map?) ?? {};
    final simdi = _n(o['misafir']).toInt();
    final onceki = _n(o['onceki_misafir']).toInt();
    final oncekiVar = onceki > 0;
    final fark = oncekiVar ? (simdi - onceki) / onceki * 100 : 0.0;
    final up = fark >= 0;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.groups, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text('Gelen Müşteri · $_donemAd', style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const Spacer(),
          if (oncekiVar)
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                child: Text('${up ? "▲" : "▼"} %${fark.abs().toStringAsFixed(0)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))),
        ]),
        const SizedBox(height: 6),
        Text('${_f.format(simdi)} kişi', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
        Text(oncekiVar ? 'önceki dönem: $onceki kişi' : 'karşılaştırılacak önceki dönem verisi yok', style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _mini('Folyo', '${_n(o['folyo']).toInt()}'),
            _mini('Ort. Grup', '${_n(o['ort_grup'])}'),
            _mini('Kişi Başı', '${_f.format(_n(o['kisi_basi']).round())}TL', son: true),
          ]),
        ),
      ]),
    );
  }

  Widget _mini(String etiket, String deger, {bool son = false}) => Expanded(
        child: Container(
          decoration: son ? null : const BoxDecoration(border: Border(right: BorderSide(color: Colors.white24))),
          child: Column(children: [
            Text(etiket, style: const TextStyle(color: Colors.white60, fontSize: 10)),
            const SizedBox(height: 3),
            FittedBox(child: Text(deger, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
          ]),
        ),
      );

  Widget _kutu(TemaProvider t, String baslik, Widget cocuk, {String? alt}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(18), boxShadow: t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(baslik, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
        if (alt != null) ...[const SizedBox(height: 2), Text(alt, style: TextStyle(color: t.sub, fontSize: 12))],
        const SizedBox(height: 12),
        cocuk,
      ]),
    );
  }

  // Yatay bar satırı
  Widget _bar(TemaProvider t, String etiket, num deger, num maxV, {String? sag, Color? renk}) {
    final oran = maxV > 0 ? (deger / maxV) : 0.0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 66, child: Text(etiket, style: TextStyle(color: t.sub2, fontSize: 12), overflow: TextOverflow.ellipsis)),
        Expanded(child: Stack(children: [
          Container(height: 18, decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(6))),
          FractionallySizedBox(widthFactor: oran.toDouble().clamp(0.02, 1.0), child: Container(height: 18, decoration: BoxDecoration(color: renk ?? _mor1, borderRadius: BorderRadius.circular(6)))),
        ])),
        const SizedBox(width: 8),
        SizedBox(width: 58, child: Text(sag ?? '${deger.toInt()}', textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _trafik(TemaProvider t) {
    final seri = (d!['seri'] as List?) ?? [];
    if (seri.isEmpty) return const SizedBox.shrink();
    num maxV = 1;
    for (final e in seri) { final v = _n((e as Map)['misafir']); if (v > maxV) maxV = v; }
    return _kutu(t, '📈 Trafik ($_donemAd)', SizedBox(
      height: 150,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final e in seri)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${_n((e as Map)['misafir']).toInt()}', style: TextStyle(color: t.sub, fontSize: 9)),
                const SizedBox(height: 2),
                Container(width: 15, height: (110 * _n(e['misafir']) / maxV).toDouble().clamp(2, 110), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi], begin: Alignment.topCenter, end: Alignment.bottomCenter), borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 4),
                Text(e['etiket'].toString(), style: TextStyle(color: t.sub, fontSize: 8.5)),
              ]),
            ),
        ]),
      ),
    ), alt: 'Ne zaman yoğunsun — tek bakışta.');
  }

  Widget _yogunSaat(TemaProvider t) {
    final saatler = (d!['saatler'] as List?) ?? [];
    if (saatler.isEmpty) return const SizedBox.shrink();
    num maxV = 1;
    for (final e in saatler) { final v = _n((e as Map)['misafir']); if (v > maxV) maxV = v; }
    final enYogun = saatler.reduce((a, b) => _n((a as Map)['misafir']) >= _n((b as Map)['misafir']) ? a : b) as Map;
    return _kutu(t, '🕐 Yoğun Saatler', Column(children: [
      for (final e in saatler)
        _bar(t, (e as Map)['saat'].toString(), _n(e['misafir']), maxV, renk: e == enYogun ? _kirmizi : _mor1),
    ]), alt: 'En yoğun saat: ${enYogun['saat']} — personel/hazırlığı buna göre planla.');
  }

  Widget _gunler(TemaProvider t) {
    final gunler = (d!['gunler'] as List?) ?? [];
    if (gunler.isEmpty) return const SizedBox.shrink();
    num toplam = 0, maxV = 1;
    for (final e in gunler) { final v = _n((e as Map)['misafir']); toplam += v; if (v > maxV) maxV = v; }
    if (toplam <= 0) return const SizedBox.shrink();
    final enYogun = gunler.reduce((a, b) => _n((a as Map)['misafir']) >= _n((b as Map)['misafir']) ? a : b) as Map;
    return _kutu(t, '📅 Haftanın Günleri', Column(children: [
      for (final e in gunler)
        _bar(t, (e as Map)['gun'].toString(), _n(e['misafir']), maxV, renk: e == enYogun ? _yesil : _mavi),
    ]), alt: 'Dönemdeki günlere göre toplam misafir.');
  }

  Widget _kanal(TemaProvider t) {
    final kanallar = (d!['kanallar'] as List?) ?? [];
    if (kanallar.isEmpty) return const SizedBox.shrink();
    num maxV = 1;
    for (final e in kanallar) { final v = _n((e as Map)['misafir']); if (v > maxV) maxV = v; }
    return _kutu(t, '📲 Nereden Geldi (Kanal)', Column(children: [
      for (final e in kanallar)
        _bar(t, (e as Map)['kanal'].toString(), _n(e['misafir']), maxV, sag: '${_n(e['misafir']).toInt()} · %${_n(e['yuzde']).toInt()}'),
    ]));
  }

  Widget _bolge(TemaProvider t) {
    final bolgeler = (d!['bolgeler'] as List?) ?? [];
    if (bolgeler.isEmpty) return const SizedBox.shrink();
    num maxV = 1;
    for (final e in bolgeler) { final v = _n((e as Map)['misafir']); if (v > maxV) maxV = v; }
    return _kutu(t, '🍽️ Bölge Dağılımı', Column(children: [
      for (final e in bolgeler)
        _bar(t, (e as Map)['ad'].toString(), _n(e['misafir']), maxV, sag: '${_n(e['misafir']).toInt()} · %${_n(e['yuzde']).toInt()}', renk: _mavi),
    ]));
  }

  Widget _sadakat(TemaProvider t) {
    final s = (d!['sadakat'] as Map?) ?? {};
    final kayitli = _n(s['kayitli']).toInt();
    final anonim = _n(s['anonim']).toInt();
    final toplam = kayitli + anonim;
    if (toplam <= 0) return const SizedBox.shrink();
    final oran = (kayitli / toplam * 100).round();
    return _kutu(t, '⭐ Sadakat (Kayıtlı Müşteri)', Column(children: [
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$oran%', style: TextStyle(color: _mor1, fontSize: 30, fontWeight: FontWeight.bold)),
          Text('kayıtlı müşteri (tekrar gelen)', style: TextStyle(color: t.sub, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('Kayıtlı: $kayitli', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Anonim: $anonim', style: TextStyle(color: t.sub, fontSize: 13)),
        ]),
      ]),
      const SizedBox(height: 10),
      ClipRRect(borderRadius: BorderRadius.circular(6), child: Row(children: [
        Expanded(flex: kayitli == 0 ? 0 : kayitli, child: Container(height: 12, color: _mor1)),
        Expanded(flex: anonim == 0 ? 0 : anonim, child: Container(height: 12, color: t.card2)),
      ])),
    ]));
  }

  Widget _aiKart(TemaProvider t) {
    final ai = (d!['ai'] as List?) ?? [];
    if (ai.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: t.koyu ? const [Color(0xFF241B4D), Color(0xFF1E2647)] : const [Color(0xFFEDE9FE), Color(0xFFEEF2FF)]),
        borderRadius: BorderRadius.circular(18), border: Border.all(color: _mor1.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [const Text('✨', style: TextStyle(fontSize: 15)), const SizedBox(width: 6), Text('AI Koçluk', style: TextStyle(color: t.koyu ? const Color(0xFFC4B5FD) : _mor1, fontSize: 13, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 10),
        for (final a in ai)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(margin: const EdgeInsets.only(top: 5, right: 8), width: 7, height: 7, decoration: BoxDecoration(color: _renk((a as Map)['seviye']?.toString()), shape: BoxShape.circle)),
              Expanded(child: Text(a['mesaj'].toString(), style: TextStyle(color: t.ink, fontSize: 13, height: 1.35))),
            ]),
          ),
      ]),
    );
  }

  Color _renk(String? s) => s == 'riskli' ? _kirmizi : (s == 'iyi' ? _yesil : _mavi);
}

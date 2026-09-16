import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// GARSON PERFORMANS + ISI HARITASI (patron).
/// - Karne: her garson adisyon/ciro/kalem/ort.servis/adim + saat grafigi.
/// - Isi haritasi: salon planinda (masa x,y) garsonun en cok nerede calistigi (is agirligi).
class GarsonPerformansScreen extends StatefulWidget {
  const GarsonPerformansScreen({super.key});
  @override
  State<GarsonPerformansScreen> createState() => _GarsonPerformansScreenState();
}

class _GarsonPerformansScreenState extends State<GarsonPerformansScreen> {
  TemaProvider get _t => context.watch<TemaProvider>();
  final _f = NumberFormat.decimalPattern('tr');

  String period = 'gunluk';
  int? isiGarson; // null = tüm salon
  bool loading = true;
  List<Map<String, dynamic>> garsonlar = [];
  Map<String, dynamic> isi = {};

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.garsonPerformans(auth.token!, period: period, garsonId: isiGarson);
      if (!mounted) return;
      if (res['ok'] == 1) {
        garsonlar = ((res['garsonlar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        isi = (res['isi'] is Map) ? Map<String, dynamic>.from(res['isi']) : {};
      }
      setState(() => loading = false);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  String _tl(num v) => '${_f.format(v.round())} TL';

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        iconTheme: IconThemeData(color: t.ink),
        title: Text('Garson Performansı', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        // Period seçici
        Container(
          color: t.card,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            for (final p in const [['gunluk', 'Günlük'], ['haftalik', 'Haftalık'], ['aylik', 'Aylık'], ['yillik', 'Yıllık']])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () { setState(() => period = p[0]); _yukle(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: period == p[0] ? t.mor1 : t.card2,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: period == p[0] ? t.mor1 : t.line),
                    ),
                    child: Text(p[1], style: TextStyle(color: period == p[0] ? Colors.white : t.sub2, fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                ),
              ),
          ]),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _yukle,
                  color: t.mor1,
                  child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 28), children: [
                    _isiBolumu(t),
                    const SizedBox(height: 20),
                    Text('Garson Karnesi', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Ciroya göre sıralı', style: TextStyle(color: t.sub, fontSize: 12)),
                    const SizedBox(height: 10),
                    if (garsonlar.isEmpty)
                      Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Bu dönemde veri yok.', style: TextStyle(color: t.sub))))
                    else
                      for (final g in garsonlar) _karneKart(t, g),
                  ]),
                ),
        ),
      ]),
    );
  }

  // ---------------- ISI HARITASI ----------------
  Widget _isiBolumu(TemaProvider t) {
    final masalar = ((isi['masalar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    final maxA = _n(isi['max_agirlik']).toInt();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(18), boxShadow: t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🔥 ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text('Isı Haritası — en çok nerede çalıştı', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 4),
        Text('Salon planında iş yoğunluğu (sipariş/servis). Koyu kırmızı = en yoğun.', style: TextStyle(color: t.sub, fontSize: 11.5)),
        const SizedBox(height: 10),
        // Garson seçici (Tümü + garsonlar)
        SizedBox(
          height: 34,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            _isiChip(t, null, 'Tüm salon'),
            for (final g in garsonlar) _isiChip(t, g['id'] as int, g['ad']?.toString() ?? ''),
          ]),
        ),
        const SizedBox(height: 12),
        if (masalar.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Center(child: Text('Masa/aktivite verisi yok.', style: TextStyle(color: t.sub))))
        else
          _harita(t, masalar, maxA),
        const SizedBox(height: 8),
        _lejant(t),
      ]),
    );
  }

  Widget _isiChip(TemaProvider t, int? id, String ad) {
    final sec = isiGarson == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () { setState(() => isiGarson = id); _yukle(); },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sec ? t.mor1 : t.card2, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: sec ? t.mor1 : t.line),
          ),
          child: Text(ad, style: TextStyle(color: sec ? Colors.white : t.sub2, fontWeight: FontWeight.bold, fontSize: 12)),
        ),
      ),
    );
  }

  // Sicaklik rengi: 0 -> soguk (mavi/gri), 1 -> sicak (kirmizi)
  Color _sicaklik(double o) {
    if (o <= 0) return const Color(0xFF334155).withValues(alpha: 0.25);
    if (o < 0.5) return Color.lerp(const Color(0xFF3B82F6), const Color(0xFFF59E0B), o / 0.5)!;
    return Color.lerp(const Color(0xFFF59E0B), const Color(0xFFEF4444), (o - 0.5) / 0.5)!;
  }

  Widget _harita(TemaProvider t, List<Map<String, dynamic>> masalar, int maxA) {
    // Koordinat aralığı
    int minX = 1 << 30, maxX = -(1 << 30), minY = 1 << 30, maxY = -(1 << 30);
    for (final m in masalar) {
      final x = _n(m['x']).toInt(), y = _n(m['y']).toInt();
      if (x < minX) minX = x; if (x > maxX) maxX = x;
      if (y < minY) minY = y; if (y > maxY) maxY = y;
    }
    final yayilimVar = (maxX - minX) >= 5 && (maxY - minY) >= 5;

    if (!yayilimVar) {
      // Konum verisi yok/degenere -> bölge bölge ızgara (renk = yoğunluk)
      return Wrap(spacing: 8, runSpacing: 8, children: masalar.map((m) {
        final a = _n(m['agirlik']).toInt();
        final o = maxA > 0 ? a / maxA : 0.0;
        return Container(
          width: 58, height: 46,
          decoration: BoxDecoration(color: _sicaklik(o.toDouble()), borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(m['ad']?.toString() ?? '', textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold))),
        );
      }).toList());
    }

    // POS x,y -> kutuya ölçekle
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      const h = 300.0;
      const pad = 22.0;
      double sx(int x) => pad + (w - 2 * pad) * (x - minX) / (maxX - minX);
      double sy(int y) => pad + (h - 2 * pad) * (y - minY) / (maxY - minY);
      return Container(
        height: h,
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Stack(children: masalar.map((m) {
          final a = _n(m['agirlik']).toInt();
          final o = maxA > 0 ? (a / maxA) : 0.0;
          final boyut = 30.0 + 26.0 * o;
          return Positioned(
            left: sx(_n(m['x']).toInt()) - boyut / 2,
            top: sy(_n(m['y']).toInt()) - boyut / 2,
            child: Container(
              width: boyut, height: boyut,
              decoration: BoxDecoration(
                color: _sicaklik(o.toDouble()), shape: BoxShape.circle,
                boxShadow: o > 0.4 ? [BoxShadow(color: _sicaklik(o.toDouble()).withValues(alpha: 0.6), blurRadius: 12)] : null,
              ),
              child: Center(child: Text(m['ad']?.toString() ?? '', textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold))),
            ),
          );
        }).toList()),
      );
    });
  }

  Widget _lejant(TemaProvider t) => Row(children: [
        Text('Az', style: TextStyle(color: t.sub, fontSize: 11)),
        const SizedBox(width: 6),
        Expanded(child: Container(height: 8, decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFFF59E0B), Color(0xFFEF4444)]),
        ))),
        const SizedBox(width: 6),
        Text('Çok', style: TextStyle(color: t.sub, fontSize: 11)),
      ]);

  // ---------------- KARNE KARTI ----------------
  Widget _karneKart(TemaProvider t, Map<String, dynamic> g) {
    final saat = ((g['saat_dagilim'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    final maxSaat = saat.fold<int>(1, (p, s) => (_n(s['adisyon']).toInt() > p) ? _n(s['adisyon']).toInt() : p);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), boxShadow: t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 16, backgroundColor: t.mor1.withValues(alpha: 0.15),
              child: Text((g['ad']?.toString() ?? '?').characters.first, style: TextStyle(color: t.mor1, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Text(g['ad']?.toString() ?? '', style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.w900))),
          Text(_tl(_n(g['ciro'])), style: TextStyle(color: t.yesil, fontSize: 15, fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _metrik(t, '${_n(g['adisyon']).toInt()}', 'Masa/Adisyon'),
          _metrik(t, '${_n(g['kalem']).toInt()}', 'Ürün kalemi'),
          _metrik(t, '${_n(g['ort_servis_dk']).toInt()} dk', 'Ort. servis'),
          _metrik(t, _f.format(_n(g['adim']).toInt()), 'Adım'),
        ]),
        const SizedBox(height: 12),
        // Saat grafiği (mini bar)
        Text('Saatlik yoğunluk', style: TextStyle(color: t.sub, fontSize: 11)),
        const SizedBox(height: 6),
        SizedBox(
          height: 40,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: saat.map((s) {
            final v = _n(s['adisyon']).toInt();
            final hh = maxSaat > 0 ? (34.0 * v / maxSaat) : 0.0;
            return Expanded(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(height: hh < 3 && v > 0 ? 3 : hh, decoration: BoxDecoration(
                    color: v > 0 ? t.mor1 : t.line, borderRadius: BorderRadius.circular(2))),
              ]),
            ));
          }).toList()),
        ),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('08', style: TextStyle(color: t.sub, fontSize: 9)),
          Text('23', style: TextStyle(color: t.sub, fontSize: 9)),
        ]),
      ]),
    );
  }

  Widget _metrik(TemaProvider t, String deger, String etiket) => Expanded(
        child: Column(children: [
          Text(deger, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w900)),
          const SizedBox(height: 2),
          Text(etiket, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 10.5)),
        ]),
      );
}

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
  Map<String, dynamic> sema = {}; // salon_sema veri (parsel/bolge/nokta/masa konum) — ısı zemini
  bool _semaAlindi = false;

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
      // Salon şemasını bir kez çek (ısı zemini)
      if (!_semaAlindi) {
        _semaAlindi = true;
        try {
          final sres = await Api.salonSema(auth.token!);
          if (sres['ok'] == 1 && sres['veri'] is Map) sema = Map<String, dynamic>.from(sres['veri']);
        } catch (_) {}
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

  // ---------------- ISI HARITASI (salon şeması üzerinde) ----------------
  Widget _isiBolumu(TemaProvider t) {
    final masalar = ((isi['masalar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    final bolgeler = ((isi['bolgeler'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
    final maxA = _n(isi['max_agirlik']).toInt();

    Map<String, dynamic>? enMasa;
    final Map<int, int> bolgeTop = {};
    final Map<String, int> agir = {}; final Map<String, String> adMap = {};
    for (final m in masalar) {
      if (enMasa == null || _n(m['agirlik']) > _n(enMasa['agirlik'])) enMasa = m;
      bolgeTop[_n(m['bolge_id']).toInt()] = (bolgeTop[_n(m['bolge_id']).toInt()] ?? 0) + _n(m['agirlik']).toInt();
      agir['${m['id']}'] = _n(m['agirlik']).toInt();
      adMap['${m['id']}'] = m['ad']?.toString() ?? '';
    }
    int enBolge = -1, enBolgeVal = -1;
    bolgeTop.forEach((k, v) { if (v > enBolgeVal) { enBolgeVal = v; enBolge = k; } });
    String bolgeAd(int id) => (bolgeler.firstWhere((b) => _n(b['id']).toInt() == id, orElse: () => {'ad': ''})['ad'] ?? '').toString();
    final veriVar = masalar.isNotEmpty && maxA > 0;
    final semaVar = ((sema['masalar'] as Map?)?.isNotEmpty ?? false);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(18), boxShadow: t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('🔥 ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text('Garsonun Isı Haritası', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 4),
        Text('Salon planında en çok nerede çalıştığı — kırmızı = en yoğun.', style: TextStyle(color: t.sub, fontSize: 11.5)),
        const SizedBox(height: 10),
        SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: [
          _isiChip(t, null, 'Tüm salon'),
          for (final g in garsonlar) _isiChip(t, g['id'] as int, g['ad']?.toString() ?? ''),
        ])),
        const SizedBox(height: 12),
        // Özet / bilgi kutusu
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(veriVar ? Icons.local_fire_department : Icons.info_outline, color: veriVar ? _sicaklik(1) : t.sub, size: 24),
            const SizedBox(width: 10),
            Expanded(child: veriVar
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('En yoğun masa: ${enMasa?['ad'] ?? '-'}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w900)),
                    Text('${bolgeAd(enBolge)} · ${_n(enMasa?['agirlik']).toInt()} işlem', style: TextStyle(color: t.sub, fontSize: 12)),
                  ])
                : Text('Bu dönemde sipariş yok — masalara sipariş girilince ısı burada belirir.', style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.3))),
            if (veriVar) _mesafeRozet(t),
          ]),
        ),
        const SizedBox(height: 14),
        // Harita: şema varsa HER ZAMAN kroki (aktivite yoksa masalar soğuk); şema yoksa ızgara ya da uyarı
        if (semaVar)
          _semaHarita(t, agir, adMap, maxA)
        else if (veriVar)
          ...[for (final b in bolgeler) ..._bolgeBlok(t, b, masalar, maxA, bolgeTop[_n(b['id']).toInt()] ?? 0)]
        else
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text(
            'Salon şemasını "Salon Şeması" ekranından çizip kaydedersen, ısı haritası buraya salon planının üzerinde gelir.',
            textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4)))),
        const SizedBox(height: 8),
        if (semaVar || veriVar) _lejant(t),
        if (veriVar) ...[
          const SizedBox(height: 12),
          ..._gozlemler(t, bolgeler, bolgeTop, enBolge, bolgeAd, enMasa),
        ],
      ]),
    );
  }

  // Toplam yürüyüş mesafesi (adım sayacından): seçili garson ya da tüm salon
  int _adimToplam() {
    if (isiGarson != null) {
      final g = garsonlar.firstWhere((x) => x['id'] == isiGarson, orElse: () => {});
      return _n(g['adim']).toInt();
    }
    return garsonlar.fold<int>(0, (p, g) => p + _n(g['adim']).toInt());
  }

  Widget _mesafeRozet(TemaProvider t) {
    final adim = _adimToplam();
    final km = adim * 0.75 / 1000; // ~0.75 m/adım
    final metin = km >= 1 ? '${km.toStringAsFixed(1)} km' : '${(adim * 0.75).round()} m';
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(children: [Icon(Icons.directions_walk, size: 15, color: t.mor1), const SizedBox(width: 3),
        Text(metin, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w900))]),
      Text('yürüyüş', style: TextStyle(color: t.sub, fontSize: 10)),
    ]);
  }

  // Otomatik gözlemler (veriden)
  List<Widget> _gozlemler(TemaProvider t, List<Map<String, dynamic>> bolgeler, Map<int, int> bolgeTop, int enBolge, String Function(int) bolgeAd, Map<String, dynamic>? enMasa) {
    final g = <String>[];
    if (enBolge >= 0 && (bolgeTop[enBolge] ?? 0) > 0) g.add('En çok ${bolgeAd(enBolge)} bölgesinde çalışıldı.');
    // en sakin bölge (0 olmayan en düşük ya da hiç)
    final sakin = bolgeler.where((b) => (bolgeTop[_n(b['id']).toInt()] ?? 0) == 0).map((b) => b['ad']?.toString() ?? '').where((x) => x.isNotEmpty).toList();
    if (sakin.isNotEmpty) g.add('${sakin.take(2).join(', ')} bölgesi(ler)i sakin — az uğranmış.');
    if (enMasa != null) g.add('En yoğun masa: ${enMasa['ad']} (${_n(enMasa['agirlik']).toInt()} işlem).');
    if (g.isEmpty) return [];
    return [
      Text('Gözlemler', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w900)),
      const SizedBox(height: 6),
      for (final s in g) Padding(padding: const EdgeInsets.only(bottom: 5), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.circle, size: 6, color: t.mor1), const SizedBox(width: 8),
        Expanded(child: Text(s, style: TextStyle(color: t.sub2, fontSize: 12.5, height: 1.3))),
      ])),
    ];
  }

  // Bir bölgenin başlığı + o bölgenin masaları (yoğunluğa göre sıralı, renkli kutular)
  List<Widget> _bolgeBlok(TemaProvider t, Map<String, dynamic> b, List<Map<String, dynamic>> masalar, int maxA, int bolgeTop) {
    final bid = _n(b['id']).toInt();
    final list = masalar.where((m) => _n(m['bolge_id']).toInt() == bid).toList();
    if (list.isEmpty) return [];
    list.sort((x, y) => _n(y['agirlik']).toInt() - _n(x['agirlik']).toInt());
    return [
      Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Row(children: [
          Text(b['ad']?.toString() ?? '', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w900)),
          const SizedBox(width: 8),
          if (bolgeTop > 0) Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(color: t.mor1.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
            child: Text('$bolgeTop işlem', style: TextStyle(color: t.mor1, fontSize: 10.5, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
      Wrap(spacing: 8, runSpacing: 8, children: list.map((m) => _masaTile(t, m, maxA)).toList()),
      const SizedBox(height: 12),
    ];
  }

  Widget _masaTile(TemaProvider t, Map<String, dynamic> m, int maxA) {
    final a = _n(m['agirlik']).toInt();
    final o = maxA > 0 ? a / maxA : 0.0;
    final renk = a > 0 ? _sicaklik(o.toDouble()) : t.card2;
    final yazi = a > 0 ? Colors.white : t.sub;
    return Container(
      width: 78, height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: renk, borderRadius: BorderRadius.circular(12),
        border: a > 0 ? null : Border.all(color: t.line),
        boxShadow: o > 0.55 ? [BoxShadow(color: renk.withValues(alpha: 0.5), blurRadius: 10)] : null,
      ),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 68, child: FittedBox(fit: BoxFit.scaleDown, child: Text(
          m['ad']?.toString() ?? '', maxLines: 1, style: TextStyle(color: yazi, fontSize: 13, fontWeight: FontWeight.w900)))),
        if (a > 0) ...[
          const SizedBox(height: 2),
          Text('$a işlem', style: TextStyle(color: yazi.withValues(alpha: 0.9), fontSize: 9.5, fontWeight: FontWeight.w600)),
        ],
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

  // ---------------- SALON ŞEMASI ÜZERİNDE ISI ----------------
  static const Map<String, List<dynamic>> _tip = {
    'giris':   [Icons.login, Color(0xFF14B8A6), 'Giriş'],
    'mutfak':  [Icons.restaurant, Color(0xFFF97316), 'Mutfak'],
    'bar':     [Icons.local_bar, Color(0xFF7C3AED), 'Bar'],
    'wc':      [Icons.wc, Color(0xFF3B82F6), 'WC'],
    'otopark': [Icons.local_parking, Color(0xFF6366F1), 'Otopark'],
    'kasa':    [Icons.point_of_sale, Color(0xFF10B981), 'Kasa'],
    'depo':    [Icons.inventory_2, Color(0xFF92694A), 'Depo'],
    'diger':   [Icons.place, Color(0xFF64748B), 'Diğer'],
  };

  Widget _semaHarita(TemaProvider t, Map<String, int> agir, Map<String, String> adMap, int maxA) {
    const kat = 0;
    List<List<double>> pts = [];
    for (final pr in ((sema['parsel'] as List?) ?? [])) {
      if (_n(pr['kat']).toInt() == kat) pts = ((pr['pts'] as List?) ?? []).map<List<double>>((e) => [_n(e[0]).toDouble(), _n(e[1]).toDouble()]).toList();
    }
    final zones = ((sema['bolgeler'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).where((b) => _n(b['kat']).toInt() == kat).toList();
    final noktalar = ((sema['noktalar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).where((n) => _n(n['kat']).toInt() == kat).toList();
    final masaYer = <String, Map<String, dynamic>>{};
    ((sema['masalar'] as Map?) ?? {}).forEach((k, v) { final mm = Map<String, dynamic>.from(v); if (_n(mm['kat']).toInt() == kat) masaYer[k.toString()] = mm; });

    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth;
      final h = w * 1.35;
      double sx(num v) => v / 1000 * w;
      double sy(num v) => v / 1000 * h;
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: w, height: h, child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _SemaPainter(
            bos: t.koyu ? const Color(0xFF0E1526) : const Color(0xFFEFF3FA),
            cizgi: t.line.withValues(alpha: 0.25),
            parsel: pts.map((p) => Offset(sx(p[0]), sy(p[1]))).toList(),
            zones: zones.map((b) => Rect.fromLTWH(sx(_n(b['x'])), sy(_n(b['y'])), sx(_n(b['w'])), sy(_n(b['h'])))).toList(),
            bloblar: masaYer.entries.map((e) {
              final a = agir[e.key] ?? 0;
              final o = maxA > 0 ? a / maxA : 0.0;
              return _Blob(Offset(sx(_n(e.value['x'])), sy(_n(e.value['y']))), o.toDouble(), _sicaklik(o.toDouble()), w * 0.14 * (0.55 + o));
            }).toList(),
          ))),
          for (final b in zones)
            Positioned(left: sx(_n(b['x'])) + 6, top: sy(_n(b['y'])) + 4,
              child: Text(b['ad']?.toString() ?? '', style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 10.5, fontWeight: FontWeight.bold))),
          for (final nk in noktalar) _semaNokta(t, nk, sx, sy),
          for (final e in masaYer.entries) _semaMasa(t, e.value, agir[e.key] ?? 0, maxA, adMap[e.key] ?? '', sx, sy),
        ])),
      );
    });
  }

  Widget _semaNokta(TemaProvider t, Map<String, dynamic> nk, double Function(num) sx, double Function(num) sy) {
    final def = _tip[nk['tip']?.toString() ?? 'diger'] ?? _tip['diger']!;
    return Positioned(left: sx(_n(nk['x'])) - 20, top: sy(_n(nk['y'])) - 20, child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: def[1] as Color, borderRadius: BorderRadius.circular(9)),
          child: Icon(def[0] as IconData, color: Colors.white, size: 15)),
      Text(nk['ad']?.toString() ?? '', style: TextStyle(color: t.ink, fontSize: 8.5, fontWeight: FontWeight.bold)),
    ]));
  }

  Widget _semaMasa(TemaProvider t, Map<String, dynamic> yer, int a, int maxA, String ad, double Function(num) sx, double Function(num) sy) {
    final o = maxA > 0 ? a / maxA : 0.0;
    final boyV = _n(yer['boy']) <= 0 ? 150.0 : _n(yer['boy']).toDouble();
    final boyut = sx(boyV).clamp(26.0, 90.0);
    final renk = a > 0 ? _sicaklik(o.toDouble()) : t.sub.withValues(alpha: 0.35);
    return Positioned(left: sx(_n(yer['x'])) - boyut / 2, top: sy(_n(yer['y'])) - boyut / 2,
      child: Container(width: boyut, height: boyut,
        decoration: BoxDecoration(color: renk.withValues(alpha: a > 0 ? 0.95 : 0.5), shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1)),
        child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: const EdgeInsets.all(3),
          child: Text(ad, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)))))));
  }

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

class _Blob {
  final Offset c;
  final double o; // 0..1 yoğunluk
  final Color renk;
  final double yaricap;
  _Blob(this.c, this.o, this.renk, this.yaricap);
}

class _SemaPainter extends CustomPainter {
  final Color bos, cizgi;
  final List<Offset> parsel;
  final List<Rect> zones;
  final List<_Blob> bloblar;
  _SemaPainter({required this.bos, required this.cizgi, required this.parsel, required this.zones, required this.bloblar});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.drawRRect(r, Paint()..color = bos);
    canvas.save();
    canvas.clipRRect(r);
    // parsel (salon şekli)
    if (parsel.length >= 3) {
      final path = Path()..moveTo(parsel[0].dx, parsel[0].dy);
      for (var i = 1; i < parsel.length; i++) { path.lineTo(parsel[i].dx, parsel[i].dy); }
      path.close();
      canvas.drawPath(path, Paint()..color = const Color(0xFF0EA5E9).withValues(alpha: 0.06));
      canvas.drawPath(path, Paint()..color = const Color(0xFF0EA5E9).withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
    // ızgara
    final gp = Paint()..color = cizgi..strokeWidth = 0.5;
    for (int i = 1; i < 12; i++) {
      canvas.drawLine(Offset(size.width * i / 12, 0), Offset(size.width * i / 12, size.height), gp);
      canvas.drawLine(Offset(0, size.height * i / 12), Offset(size.width, size.height * i / 12), gp);
    }
    // bölgeler
    for (final z in zones) {
      canvas.drawRRect(RRect.fromRectAndRadius(z, const Radius.circular(8)), Paint()..color = const Color(0xFF0EA5E9).withValues(alpha: 0.06));
      canvas.drawRRect(RRect.fromRectAndRadius(z, const Radius.circular(8)), Paint()..color = const Color(0xFF0EA5E9).withValues(alpha: 0.28)..style = PaintingStyle.stroke..strokeWidth = 1);
    }
    // ISI blobları (radial gradient) — referanstaki sıcak lekeler
    for (final b in bloblar) {
      if (b.o <= 0) continue;
      final rect = Rect.fromCircle(center: b.c, radius: b.yaricap);
      final shader = RadialGradient(colors: [b.renk.withValues(alpha: 0.55), b.renk.withValues(alpha: 0.0)]).createShader(rect);
      canvas.drawCircle(b.c, b.yaricap, Paint()..shader = shader);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SemaPainter old) => true;
}

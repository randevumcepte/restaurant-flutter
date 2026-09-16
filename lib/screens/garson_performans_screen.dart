import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Map<String, String> _sekil = {}; // masa id -> kare|yuvarlak
  final Map<String, int> _kapasite = {}; // masa id -> kişi/sandalye sayısı
  bool _semaAlindi = false;

  // GÖRSEL KÜTÜPHANESİ: assets/sema/<ad>.png -> ui.Image (yoksa vektör fallback)
  final Map<String, ui.Image> _gorsel = {};
  double _masaOlcek = 1.0; // masa görselini büyüt/küçült (kalıcı)

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _olcekYukle();
    _gorselleriYukle();
    _yukle();
  }

  Future<void> _olcekYukle() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getDouble('isi_masa_olcek') ?? 1.0;
      if (mounted) setState(() => _masaOlcek = v.clamp(0.4, 3.0));
    } catch (_) {}
  }

  void _olcekAyarla(double d) {
    setState(() => _masaOlcek = (_masaOlcek + d).clamp(0.4, 3.0));
    SharedPreferences.getInstance().then((p) => p.setDouble('isi_masa_olcek', _masaOlcek)).catchError((_) => false);
  }

  // Kütüphanedeki sabit görselleri bir kez yükle. Dosya yoksa sessizce atla → vektör çizim.
  Future<void> _gorselleriYukle() async {
    const adlar = ['zemin', 'masa_yuvarlak', 'masa_kare', 'sandalye', 'saksi'];
    for (final a in adlar) {
      try {
        final data = await rootBundle.load('assets/sema/$a.png');
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        _gorsel[a] = (await codec.getNextFrame()).image;
      } catch (_) {/* görsel yok → vektör */}
    }
    if (mounted && _gorsel.isNotEmpty) setState(() {});
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
          for (final m in ((sres['masalar'] as List?) ?? [])) {
            _sekil['${m['id']}'] = (m['sekil']?.toString() ?? 'kare');
            final kap = int.tryParse('${m['kapasite'] ?? ''}') ?? 4;
            _kapasite['${m['id']}'] = kap.clamp(1, 12);
          }
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
          // Masa görseli varsa: büyüt/küçült (kalıcı)
          if ((_gorsel['masa_kare'] ?? _gorsel['masa_yuvarlak']) != null) _olcekKontrol(t),
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

  // Masa görselini büyüt/küçült (kalıcı ayar)
  Widget _olcekKontrol(TemaProvider t) {
    Widget btn(IconData ik, VoidCallback on) => InkWell(
          onTap: on,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
            child: Icon(ik, size: 17, color: t.ink),
          ),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.photo_size_select_large_outlined, size: 14, color: t.sub),
      const SizedBox(width: 4),
      btn(Icons.remove, () => _olcekAyarla(-0.1)),
      SizedBox(width: 34, child: Text('${(_masaOlcek * 100).round()}%', textAlign: TextAlign.center,
          style: TextStyle(color: t.sub, fontSize: 11, fontWeight: FontWeight.bold))),
      btn(Icons.add, () => _olcekAyarla(0.1)),
    ]);
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
      final tablolar = <_Masa>[];
      masaYer.forEach((id, yer) {
        final a = agir[id] ?? 0;
        final o = maxA > 0 ? a / maxA : 0.0;
        final boyV = _n(yer['boy']) <= 0 ? 150.0 : _n(yer['boy']).toDouble();
        final size = sx(boyV).clamp(32.0, 88.0);
        tablolar.add(_Masa(Offset(sx(_n(yer['x'])), sy(_n(yer['y'])).toDouble()), size, o.toDouble(),
            _sicaklik(o.toDouble()), (_sekil[id] ?? 'kare') == 'yuvarlak', adMap[id] ?? '', _kapasite[id] ?? 4));
      });
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: w, height: h, child: Stack(children: [
          Positioned.fill(child: CustomPaint(painter: _SemaPainter(
            koyu: t.koyu,
            parsel: pts.map((p) => Offset(sx(p[0]), sy(p[1]))).toList(),
            zones: zones.map((b) => Rect.fromLTWH(sx(_n(b['x'])), sy(_n(b['y'])), sx(_n(b['w'])), sy(_n(b['h'])))).toList(),
            tablolar: tablolar,
            gorsel: _gorsel,
            masaOlcek: _masaOlcek,
          ))),
          for (final b in zones)
            Positioned(left: sx(_n(b['x'])) + 6, top: sy(_n(b['y'])) + 4,
              child: Text(b['ad']?.toString() ?? '', style: const TextStyle(color: Color(0xFF7DD3FC), fontSize: 10.5, fontWeight: FontWeight.bold))),
          for (final nk in noktalar) _semaNokta(t, nk, sx, sy),
          for (final m in tablolar)
            Positioned(left: m.c.dx - m.size / 2, top: m.c.dy - 7, width: m.size,
              child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Text(m.ad,
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 2)]))))),
        ])),
      );
    });
  }

  Widget _semaNokta(TemaProvider t, Map<String, dynamic> nk, double Function(num) sx, double Function(num) sy) {
    final tip = nk['tip']?.toString() ?? 'diger';
    final def = _tip[tip] ?? _tip['diger']!;
    // Kütüphanede assets/sema/<tip>.png varsa gerçek görseli (büyük), yoksa ikon rozeti.
    const kutu = 66.0;
    final gorsel = Image.asset('assets/sema/$tip.png', width: kutu, fit: BoxFit.contain,
        errorBuilder: (_, _, _) => Container(
            padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: def[1] as Color, borderRadius: BorderRadius.circular(9)),
            child: Icon(def[0] as IconData, color: Colors.white, size: 15)));
    return Positioned(left: sx(_n(nk['x'])) - kutu / 2, top: sy(_n(nk['y'])) - kutu / 2,
      child: SizedBox(width: kutu, child: Column(mainAxisSize: MainAxisSize.min, children: [
        gorsel,
        Text(nk['ad']?.toString() ?? '', textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontSize: 8.5, fontWeight: FontWeight.bold)),
      ])));
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

class _Masa {
  final Offset c;
  final double size;
  final double o; // 0..1 yoğunluk
  final Color renk;
  final bool yuvarlak;
  final String ad;
  final int kapasite; // sandalye sayısı
  _Masa(this.c, this.size, this.o, this.renk, this.yuvarlak, this.ad, this.kapasite);
}

/// KUŞBAKIŞI GERÇEKÇİ SALON: ahşap zemin + gerçekçi masa/sandalye/saksı;
/// ÜSTTE ısı yarı saydam cam katman gibi geçer (mobilya altından görünür).
class _SemaPainter extends CustomPainter {
  final bool koyu;
  final List<Offset> parsel;
  final List<Rect> zones;
  final List<_Masa> tablolar;
  final Map<String, ui.Image> gorsel; // görsel kütüphanesi (assets/sema/*)
  final double masaOlcek; // masa görseli ölçek çarpanı
  _SemaPainter({required this.koyu, required this.parsel, required this.zones, required this.tablolar, required this.gorsel, this.masaOlcek = 1.0});

  Color _jet(double o) {
    o = o.clamp(0, 1);
    if (o < 0.5) return Color.lerp(const Color(0xFF22C55E), const Color(0xFFF59E0B), o / 0.5)!;
    return Color.lerp(const Color(0xFFF59E0B), const Color(0xFFEF4444), (o - 0.5) / 0.5)!;
  }

  // Bir görseli hedef dikdörtgene orantılı (contain) çiz.
  void _cizGorsel(Canvas canvas, ui.Image img, Rect dst) {
    final src = Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble());
    canvas.drawImageRect(img, src, dst, Paint()..filterQuality = FilterQuality.medium..isAntiAlias = true);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.clipRRect(rr);

    Path zemin;
    if (parsel.length >= 3) {
      zemin = Path()..moveTo(parsel[0].dx, parsel[0].dy);
      for (var i = 1; i < parsel.length; i++) { zemin.lineTo(parsel[i].dx, parsel[i].dy); }
      zemin.close();
    } else {
      zemin = Path()..addRRect(rr);
    }

    // --- salon dışı (koyu) ---
    canvas.drawRect(Offset.zero & size, Paint()..color = koyu ? const Color(0xFF0B1020) : const Color(0xFFCBD5E1));

    // --- ZEMİN: görsel varsa döşe, yoksa sıcak ahşap parke ---
    canvas.save();
    canvas.clipPath(zemin);
    final zimg = gorsel['zemin'];
    if (zimg != null) {
      final tile = size.width / 4;
      final sc = tile / zimg.width;
      final mtx = Float64List(16)..[0] = sc..[5] = sc..[10] = 1..[15] = 1;
      final sh = ui.ImageShader(zimg, TileMode.repeated, TileMode.repeated, mtx);
      canvas.drawRect(Offset.zero & size, Paint()..shader = sh);
    } else {
      final zg = const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFE4CBA0), Color(0xFFD3B183)]);
      canvas.drawRect(Offset.zero & size, Paint()..shader = zg.createShader(Offset.zero & size));
      final plank = Paint()..color = const Color(0xFF9C7B54).withValues(alpha: 0.22)..strokeWidth = 1.2;
      for (double y = 0; y < size.height; y += size.width / 16) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), plank);
      }
      final segw = size.width / 8;
      for (double y = 0; y < size.height; y += size.width / 16) {
        final off = ((y ~/ (size.width / 16)) % 2) * segw / 2;
        for (double x = off; x < size.width; x += segw) {
          canvas.drawLine(Offset(x, y), Offset(x, y + size.width / 16), plank);
        }
      }
    }
    canvas.restore();

    // --- bölge zeminleri (hafif farklı ton + etiket kutusu üstte widget) ---
    for (final z in zones) {
      final rz = RRect.fromRectAndRadius(z, const Radius.circular(12));
      canvas.drawRRect(rz, Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.06));
      canvas.drawRRect(rz, Paint()..color = const Color(0xFF7C5A3A).withValues(alpha: 0.35)..style = PaintingStyle.stroke..strokeWidth = 1.4);
    }

    // --- kenar yeşillik (saksılar) ---
    if (parsel.length >= 2) {
      final cx = parsel.map((p) => p.dx).reduce((a, b) => a + b) / parsel.length;
      final cy = parsel.map((p) => p.dy).reduce((a, b) => a + b) / parsel.length;
      final merkez = Offset(cx, cy);
      for (var i = 0; i < parsel.length; i++) {
        final a = parsel[i], b = parsel[(i + 1) % parsel.length];
        final adet = ((b - a).distance / 52).floor().clamp(1, 30);
        for (var k = 0; k <= adet; k++) {
          var p = Offset.lerp(a, b, k / (adet == 0 ? 1 : adet))!;
          final ic = merkez - p;
          if (ic.distance > 0) p = p + (ic / ic.distance) * 12;
          _saksi(canvas, p);
        }
      }
    }

    // --- MASALAR + SANDALYELER (doğal, ısıyla boyanmadan) ---
    for (final m in tablolar) { _masaCiz(canvas, m); }

    // --- ISI: EN ÜSTTE yarı saydam cam katman ---
    canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.55));
    canvas.save();
    canvas.clipPath(zemin);
    // soğuk mavi taban wash
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.22));
    // additif sıcak lekeler
    canvas.saveLayer(Offset.zero & size, Paint());
    for (final m in tablolar) {
      if (m.o <= 0.02) continue;
      final rad = m.size * (2.3 + m.o * 1.7);
      final renk = _jet(m.o);
      final sh = RadialGradient(colors: [renk.withValues(alpha: 0.9), renk.withValues(alpha: 0.0)])
          .createShader(Rect.fromCircle(center: m.c, radius: rad));
      canvas.drawCircle(m.c, rad, Paint()..shader = sh..blendMode = BlendMode.plus);
    }
    canvas.restore();
    canvas.restore();
    canvas.restore();

    // --- duvar (en üstte, keskin) ---
    if (parsel.length >= 3) {
      canvas.drawPath(zemin, Paint()..color = const Color(0xFF5B4632)..style = PaintingStyle.stroke..strokeWidth = 5);
      canvas.drawPath(zemin, Paint()..color = const Color(0xFF8A6B49)..style = PaintingStyle.stroke..strokeWidth = 2);
    }
  }

  void _saksi(Canvas canvas, Offset p) {
    final img = gorsel['saksi'];
    if (img != null) {
      _cizGorsel(canvas, img, Rect.fromCenter(center: p, width: 20, height: 20));
      return;
    }
    canvas.drawCircle(p + const Offset(1.5, 2), 7, Paint()..color = Colors.black.withValues(alpha: 0.18)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
    canvas.drawCircle(p, 7, Paint()..color = const Color(0xFF14532D));
    canvas.drawCircle(p + const Offset(-2.6, -1.4), 3.6, Paint()..color = const Color(0xFF2E7D32));
    canvas.drawCircle(p + const Offset(2.6, 1.2), 3.3, Paint()..color = const Color(0xFF43A047));
    canvas.drawCircle(p + const Offset(0.4, -2.8), 2.8, Paint()..color = const Color(0xFF66BB6A));
  }

  // Kapasiteyi 4 kenara dağıt: fazlalık önce üst/alt sonra sağ/sol
  List<int> _dagit(int n) {
    final b = n ~/ 4, r = n % 4;
    final s = [b, b, b, b]; // üst, sağ, alt, sol
    const order = [0, 2, 1, 3];
    for (var i = 0; i < r; i++) { s[order[i]]++; }
    return s;
  }

  // Tek sandalye: merkez + boyut + yön açısı (aci: sandalyenin "sırtı" yukarı=0).
  // Görsel varsa PNG'yi döndürerek çiz, yoksa vektör (simetrik olduğundan açı görünmez).
  void _chair(Canvas canvas, Offset c, double cw, double ch, double aci) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(aci);
    final r = Rect.fromCenter(center: Offset.zero, width: cw, height: ch);
    final img = gorsel['sandalye'];
    if (img != null) {
      _cizGorsel(canvas, img, r);
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(r.shift(const Offset(0, 2)), const Radius.circular(4)),
          Paint()..color = Colors.black.withValues(alpha: 0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()..shader = const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [Color(0xFF6B4A30), Color(0xFF4A3220)]).createShader(r));
      final hl = Rect.fromLTWH(r.left + 1.5, r.top + 1.5, r.width - 3, r.height * 0.34);
      canvas.drawRRect(RRect.fromRectAndRadius(hl, const Radius.circular(2)),
          Paint()..color = Colors.white.withValues(alpha: 0.10));
    }
    canvas.restore();
  }

  void _masaCiz(Canvas canvas, _Masa m) {
    final s = m.size;
    // COMBO GÖRSEL: masa+sandalye tek PNG → onu bas (ayrı sandalye çizme), boyut ayarıyla ölçekli
    final combo = m.yuvarlak ? gorsel['masa_yuvarlak'] : gorsel['masa_kare'];
    if (combo != null) {
      final w = s * 1.85 * masaOlcek;
      final h = w * combo.height / combo.width; // en-boy oranını koru
      final rect = Rect.fromCenter(center: m.c, width: w, height: h);
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect.deflate(w * 0.14).shift(const Offset(0, 3)), Radius.circular(w * 0.1)),
          Paint()..color = Colors.black.withValues(alpha: 0.22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      _cizGorsel(canvas, combo, rect);
      return;
    }
    final g = s * 0.13;                     // masa-sandalye boşluğu
    final ch = (s * 0.26).clamp(6.0, 24.0); // sandalye derinliği
    final n = m.kapasite < 1 ? 4 : (m.kapasite > 12 ? 12 : m.kapasite);

    if (m.yuvarlak) {
      // yuvarlak masa: sandalyeleri çevreye eşit dağıt (sırt dışa dönük)
      final rr = s / 2 + g + ch / 2;
      final cw = (2 * math.pi * rr / n * 0.7).clamp(8.0, s * 0.6);
      for (var i = 0; i < n; i++) {
        final ang = (2 * math.pi * i / n) - math.pi / 2;
        _chair(canvas, Offset(m.c.dx + math.cos(ang) * rr, m.c.dy + math.sin(ang) * rr), cw, ch, ang + math.pi / 2);
      }
    } else {
      // kare/dikdörtgen masa: 4 kenara dağıt (sırt dışa dönük)
      final d = _dagit(n); // üst, sağ, alt, sol
      for (final side in [0, 2]) { // üst / alt
        final cnt = d[side];
        if (cnt == 0) continue;
        final cw = (s / cnt * 0.82).clamp(7.0, s * 0.6);
        final y = side == 0 ? m.c.dy - s / 2 - g - ch / 2 : m.c.dy + s / 2 + g + ch / 2;
        for (var k = 0; k < cnt; k++) {
          _chair(canvas, Offset(m.c.dx - s / 2 + s / cnt * (k + 0.5), y), cw, ch, side == 0 ? 0 : math.pi);
        }
      }
      for (final side in [1, 3]) { // sağ / sol
        final cnt = d[side];
        if (cnt == 0) continue;
        final cw = (s / cnt * 0.82).clamp(7.0, s * 0.6);
        final x = side == 1 ? m.c.dx + s / 2 + g + ch / 2 : m.c.dx - s / 2 - g - ch / 2;
        for (var k = 0; k < cnt; k++) {
          _chair(canvas, Offset(x, m.c.dy - s / 2 + s / cnt * (k + 0.5)), cw, ch, side == 1 ? math.pi / 2 : -math.pi / 2);
        }
      }
    }

    // MASA ÜSTÜ (vektör ahşap — combo görsel yoksa)
    final golge = Paint()..color = Colors.black.withValues(alpha: 0.28)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final rect = Rect.fromCenter(center: m.c, width: s, height: s);
    final woodSh = RadialGradient(colors: const [Color(0xFFC08A54), Color(0xFF7A5230), Color(0xFF5B3D26)], stops: const [0.0, 0.7, 1.0])
        .createShader(Rect.fromCircle(center: m.c, radius: s / 2));
    if (m.yuvarlak) {
      canvas.drawCircle(m.c + const Offset(0, 3), s / 2, golge);
      canvas.drawCircle(m.c, s / 2, Paint()..shader = woodSh);
      canvas.drawCircle(m.c, s / 2, Paint()..color = const Color(0xFF3D2817)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      canvas.drawCircle(m.c, s * 0.20, Paint()..color = Colors.white.withValues(alpha: 0.10)); // tabak iması
    } else {
      canvas.drawRRect(RRect.fromRectAndRadius(rect.shift(const Offset(0, 3)), const Radius.circular(8)), golge);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..shader = woodSh);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), Paint()..color = const Color(0xFF3D2817)..style = PaintingStyle.stroke..strokeWidth = 1.5);
      canvas.drawCircle(m.c, s * 0.18, Paint()..color = Colors.white.withValues(alpha: 0.10));
    }
  }

  @override
  bool shouldRepaint(covariant _SemaPainter old) => true;
}

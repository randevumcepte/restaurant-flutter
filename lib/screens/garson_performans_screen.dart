import 'package:flutter/material.dart';
import 'menu_hamburger.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../responsive.dart';
import '../services/api.dart';
import '../widgets/salon_isi_haritasi.dart';

/// GARSON PERFORMANS (patron).
/// - Isı haritası + alan uyumu: İşletme Düzeni planında garson kendi alanında mı çalışıyor (web ile aynı).
/// - Karne: her garson adisyon/ciro/kalem/ort.servis/adim + saat grafigi.
class GarsonPerformansScreen extends StatefulWidget {
  const GarsonPerformansScreen({super.key});
  @override
  State<GarsonPerformansScreen> createState() => _GarsonPerformansScreenState();
}

class _GarsonPerformansScreenState extends State<GarsonPerformansScreen> {
  TemaProvider get _t => context.watch<TemaProvider>();
  final _f = NumberFormat.decimalPattern('tr');
  final _isiAnahtar = GlobalKey<SalonIsiHaritasiState>();

  String period = 'aylik';
  bool loading = true;
  List<Map<String, dynamic>> garsonlar = [];

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
      final res = await Api.garsonPerformans(auth.token!, period: period);
      if (!mounted) return;
      if (res['ok'] == 1) {
        garsonlar = ((res['garsonlar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      setState(() => loading = false);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _yenile() async {
    await Future.wait([_yukle(), if (_isiAnahtar.currentState != null) _isiAnahtar.currentState!.yukle()]);
  }

  String _tl(num v) => '${_f.format(v.round())} TL';

  int _adimToplam() => garsonlar.fold<int>(0, (p, g) => p + _n(g['adim']).toInt());

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        iconTheme: IconThemeData(color: t.ink),
        title: Text('Garson Performansı', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
        actions: const [MenuHamburger()],
      ),
      body: RefreshIndicator(
        onRefresh: _yenile,
        color: t.mor1,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 28), children: [
              SalonIsiHaritasi(key: _isiAnahtar),
              const SizedBox(height: 20),
              Text('Garson Karnesi', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('Ciroya göre sıralı', style: TextStyle(color: t.sub, fontSize: 12)),
              const SizedBox(height: 10),
              _donemSecici(t),
              const SizedBox(height: 12),
              if (loading)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else ...[
                _adimMesafeKart(t),
                const SizedBox(height: 14),
                if (garsonlar.isEmpty)
                  Padding(padding: const EdgeInsets.all(24), child: Center(child: Text('Bu dönemde veri yok.', style: TextStyle(color: t.sub))))
                else if (genisMi(context))
                  LayoutBuilder(builder: (ctx, c) {
                    final w = (c.maxWidth - 14) / 2; // tam ikili (sag bosluk kalmasin)
                    return Wrap(spacing: 14, runSpacing: 14, children: [
                      for (final g in garsonlar) SizedBox(width: w, child: _karneKart(t, g)),
                    ]);
                  })
                else
                  for (final g in garsonlar) _karneKart(t, g),
              ],
            ]),
          ),
        ),
      ),
    );
  }

  Widget _donemSecici(TemaProvider t) {
    return SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: [
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
    ]));
  }

  // ADIM + TOPLAM YÜRÜYÜŞ — kompakt çift istatistik (adım sayacından)
  Widget _adimMesafeKart(TemaProvider t) {
    final adim = _adimToplam();
    final km = adim * 0.75 / 1000;
    final kmStr = km >= 1 ? km.toStringAsFixed(1) : km.toStringAsFixed(2);

    Widget stat(IconData ic, Color c, String buyuk, String birim) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.30))),
            child: Row(children: [
              Container(width: 34, height: 34, decoration: BoxDecoration(color: c.withValues(alpha: 0.14), shape: BoxShape.circle),
                  child: Icon(ic, color: c, size: 18)),
              const SizedBox(width: 10),
              Expanded(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: RichText(text: TextSpan(children: [
                TextSpan(text: buyuk, style: TextStyle(color: t.ink, fontSize: 21, fontWeight: FontWeight.w900)),
                TextSpan(text: ' $birim', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.bold)),
              ])))),
            ]),
          ),
        );
    return Row(children: [
      stat(Icons.directions_walk, t.mor1, _f.format(adim), 'adım'),
      const SizedBox(width: 10),
      stat(Icons.route, const Color(0xFF16A34A), kmStr, 'km'),
    ]);
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

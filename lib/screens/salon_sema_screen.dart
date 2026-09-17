import 'dart:convert';
import 'package:flutter/material.dart';
import 'menu_hamburger.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// SALON ŞEMA (dijital ikiz) — patron restoranı çizer: kat(lar), PARSEL (dörtgen başlar,
/// köşeleri sürükle + köşe ekle/çıkar → serbest şekil), bölgeler, sabit noktalar ve masalar.
/// Kaydedilen kroki ısı haritasına ZEMİN olur + POS masa konumunu günceller. Sanal uzay 0..1000.
class SalonSemaScreen extends StatefulWidget {
  const SalonSemaScreen({super.key});
  @override
  State<SalonSemaScreen> createState() => _SalonSemaScreenState();
}

class _SalonSemaScreenState extends State<SalonSemaScreen> {
  TemaProvider get _t => context.watch<TemaProvider>();

  bool loading = true, mesgul = false;
  List<String> katlar = ['Zemin Kat'];
  int aktifKat = 0;

  List<Map<String, dynamic>> bolgeler = [];        // {kat,ad,x,y,w,h}
  List<Map<String, dynamic>> noktalar = [];         // {kat,tip,ad,x,y}
  Map<String, Map<String, dynamic>> masaYer = {};   // masaId -> {kat,x,y}
  Map<int, List<List<double>>> parsel = {};         // kat -> [[x,y],...]
  List<Map<String, dynamic>> masalar = [];          // sunucu: {id,ad,kapasite,sekil}

  Map<String, dynamic>? secili; // {tur: masa|bolge|nokta|kose, anahtar}
  final TransformationController _tc = TransformationController();
  final List<String> _gecmis = []; // geri al yığını (JSON anlık görüntüler)

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _zoom(double f) {
    final m = _tc.value.clone()..scaleByDouble(f, f, 1, 1);
    // aşırıya kaçmasın
    final o = m.getMaxScaleOnAxis();
    if (o < 0.9 || o > 5) return;
    _tc.value = m;
  }

  // ---- GERİ AL ----
  String _anlik() => jsonEncode({
        'katlar': katlar, 'bolgeler': bolgeler, 'noktalar': noktalar, 'masalar': masaYer,
        'parsel': parsel.entries.map((e) => {'kat': e.key, 'pts': e.value}).toList(),
      });

  // Değiştirmeden ÖNCE çağrılır (mevcut durumu yığına at).
  void _gecmisKaydet() {
    _gecmis.add(_anlik());
    if (_gecmis.length > 50) _gecmis.removeAt(0);
  }

  void _geriAl() {
    if (_gecmis.isEmpty) return;
    final v = jsonDecode(_gecmis.removeLast()) as Map<String, dynamic>;
    setState(() {
      katlar = (v['katlar'] as List).map((e) => e.toString()).toList();
      if (katlar.isEmpty) katlar = ['Zemin Kat'];
      bolgeler = (v['bolgeler'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      noktalar = (v['noktalar'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
      masaYer = {};
      (v['masalar'] as Map).forEach((k, val) => masaYer[k.toString()] = Map<String, dynamic>.from(val));
      parsel = {};
      for (final pr in (v['parsel'] as List)) {
        parsel[_n(pr['kat']).toInt()] = ((pr['pts'] as List).map<List<double>>((e) => [_n(e[0]).toDouble(), _n(e[1]).toDouble()]).toList());
      }
      aktifKat = aktifKat.clamp(0, katlar.length - 1);
      secili = null;
    });
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.salonSema(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        masalar = ((res['masalar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        final v = res['veri'];
        if (v is Map) {
          katlar = ((v['katlar'] as List?) ?? ['Zemin Kat']).map((e) => e.toString()).toList();
          if (katlar.isEmpty) katlar = ['Zemin Kat'];
          bolgeler = ((v['bolgeler'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
          noktalar = ((v['noktalar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
          final mm = (v['masalar'] as Map?) ?? {};
          masaYer = {};
          mm.forEach((k, val) => masaYer[k.toString()] = Map<String, dynamic>.from(val));
          parsel = {};
          for (final pr in ((v['parsel'] as List?) ?? [])) {
            final kat = _n(pr['kat']).toInt();
            final pts = ((pr['pts'] as List?) ?? []).map<List<double>>((e) => [_n(e[0]).toDouble(), _n(e[1]).toDouble()]).toList();
            if (pts.isNotEmpty) parsel[kat] = pts;
          }
        }
      }
      setState(() => loading = false);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _kaydet() async {
    if (mesgul) return;
    setState(() => mesgul = true);
    final auth = context.read<AuthProvider>();
    final parselList = parsel.entries.map((e) => {'kat': e.key, 'pts': e.value}).toList();
    final veri = {'katlar': katlar, 'parsel': parselList, 'bolgeler': bolgeler, 'noktalar': noktalar, 'masalar': masaYer};
    try {
      final res = await Api.salonSemaKaydet(auth.token!, jsonEncode(veri));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['ok'] == 1 ? 'Şema kaydedildi ✓' : (res['hata']?.toString() ?? 'Kaydedilemedi')),
        backgroundColor: res['ok'] == 1 ? const Color(0xFF16A34A) : const Color(0xFFDC2626)));
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı hatası')));
    }
    if (mounted) setState(() => mesgul = false);
  }

  static const Map<String, List<dynamic>> _tipler = {
    'giris':   [Icons.login, Color(0xFF14B8A6), 'Giriş'],
    'mutfak':  [Icons.restaurant, Color(0xFFF97316), 'Mutfak'],
    'bar':     [Icons.local_bar, Color(0xFF7C3AED), 'Bar'],
    'wc':      [Icons.wc, Color(0xFF3B82F6), 'WC'],
    'otopark': [Icons.local_parking, Color(0xFF6366F1), 'Otopark'],
    'kasa':    [Icons.point_of_sale, Color(0xFF10B981), 'Kasa'],
    'depo':    [Icons.inventory_2, Color(0xFF92694A), 'Depo'],
    'diger':   [Icons.place, Color(0xFF64748B), 'Diğer'],
  };

  List<List<double>> _dikdortgen() => [[140, 200], [860, 200], [860, 860], [140, 860]];

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final parselVar = parsel[aktifKat]?.isNotEmpty ?? false;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        iconTheme: IconThemeData(color: t.ink),
        title: Text('Salon Şeması', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        actions: [
          const MenuHamburger(),
          IconButton(tooltip: 'Geri al', onPressed: _gecmis.isEmpty ? null : _geriAl,
              icon: Icon(Icons.undo, color: _gecmis.isEmpty ? t.sub.withValues(alpha: 0.4) : t.mor1)),
          IconButton(tooltip: 'Uzaklaş', onPressed: () => _zoom(0.8), icon: Icon(Icons.zoom_out, color: t.sub)),
          IconButton(tooltip: 'Yakınlaş', onPressed: () => _zoom(1.25), icon: Icon(Icons.zoom_in, color: t.sub)),
          IconButton(tooltip: 'Bu katı temizle', onPressed: _katiTemizle, icon: Icon(Icons.layers_clear_outlined, color: t.sub)),
          TextButton.icon(onPressed: mesgul ? null : _kaydet, icon: Icon(Icons.save_outlined, color: t.mor1, size: 20),
              label: Text('Kaydet', style: TextStyle(color: t.mor1, fontWeight: FontWeight.bold))),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _katSekmeleri(t),
              if (parselVar) _parselCubugu(t),
              Expanded(child: _kanvas(t)),
              if (secili != null) _seciliCubuk(t),
              _altAracCubugu(t),
            ]),
    );
  }

  Widget _katSekmeleri(TemaProvider t) => Container(
        color: t.card,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(children: [
          Expanded(child: SizedBox(height: 34, child: ListView(scrollDirection: Axis.horizontal, children: [
            for (int i = 0; i < katlar.length; i++)
              Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                onTap: () => setState(() { aktifKat = i; secili = null; }),
                onLongPress: () => _katMenu(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: aktifKat == i ? t.mor1 : t.card2, borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: aktifKat == i ? t.mor1 : t.line)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(katlar[i], style: TextStyle(color: aktifKat == i ? Colors.white : t.sub2, fontWeight: FontWeight.bold, fontSize: 12.5)),
                    if (aktifKat == i) ...[const SizedBox(width: 4), const Icon(Icons.more_vert, size: 14, color: Colors.white70)],
                  ]),
                ),
              )),
          ]))),
          IconButton(tooltip: 'Kat ekle', onPressed: _katEkle, icon: Icon(Icons.add_circle_outline, color: t.mor1)),
        ]),
      );

  Widget _parselCubugu(TemaProvider t) => Container(
        width: double.infinity, color: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(children: [
          const Icon(Icons.open_with, color: Color(0xFF0EA5E9), size: 16),
          const SizedBox(width: 6),
          Expanded(child: Text('Salon sınırı: köşeleri sürükle', style: TextStyle(color: t.ink, fontSize: 11.5))),
          TextButton(onPressed: _koseEkle, child: const Text('+ Köşe', style: TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold, fontSize: 12))),
          TextButton(onPressed: () { _gecmisKaydet(); setState(() => parsel[aktifKat] = _dikdortgen()); }, child: const Text('Sıfırla', style: TextStyle(color: Color(0xFFF97316), fontSize: 12))),
          TextButton(onPressed: () { _gecmisKaydet(); setState(() { parsel.remove(aktifKat); if (secili?['tur'] == 'kose') secili = null; }); }, child: const Text('Sil', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12))),
        ]),
      );

  Widget _kanvas(TemaProvider t) {
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth - 24;
      final h = (c.maxHeight - 24).clamp(240.0, 100000.0); // mevcut yüksekliği DOLDUR (alt boşluk kalmasın)
      double sx(num v) => v / 1000 * w;
      double sy(num v) => v / 1000 * h;
      return Padding(
        padding: const EdgeInsets.all(12),
        child: ClipRect(
          child: InteractiveViewer(
            transformationController: _tc,
            panEnabled: false,          // tek parmak = öğe/köşe TAŞI (kanvas kaymasın)
            scaleEnabled: true,         // iki parmak = yakınlaştır + kaydır (parsel detay)
            minScale: 0.9, maxScale: 5,
            boundaryMargin: const EdgeInsets.all(120),
            child: SizedBox(
              width: w, height: h,
              child: Stack(clipBehavior: Clip.none, children: [
              // Zemin (dokununca seçim bırak)
              Positioned.fill(child: GestureDetector(
                onTap: () => setState(() => secili = null),
                child: CustomPaint(painter: _ZeminPainter(
                  cizgi: t.line.withValues(alpha: 0.35),
                  parselDolgu: const Color(0xFF0EA5E9).withValues(alpha: 0.10),
                  parselCizgi: const Color(0xFF0EA5E9),
                  bos: t.koyu ? const Color(0xFF0E1526) : const Color(0xFFF1F5F9),
                  pts: (parsel[aktifKat] ?? const []).map((p) => Offset(sx(p[0]).toDouble(), sy(p[1]).toDouble())).toList(),
                )),
              )),
              for (int i = 0; i < bolgeler.length; i++)
                if (_n(bolgeler[i]['kat']).toInt() == aktifKat) _bolgeWidget(t, i, sx, sy, w, h),
              for (int i = 0; i < noktalar.length; i++)
                if (_n(noktalar[i]['kat']).toInt() == aktifKat) _noktaWidget(t, i, sx, sy, w, h),
              for (final e in masaYer.entries)
                if (_n(e.value['kat']).toInt() == aktifKat) _masaWidget(t, e.key, sx, sy, w, h),
              for (int i = 0; i < (parsel[aktifKat]?.length ?? 0); i++) _koseTutamak(t, i, sx, sy, w, h),
              ]),
            ),
          ),
        ),
      );
    });
  }

  bool _sec(String tur, dynamic k) => secili != null && secili!['tur'] == tur && secili!['anahtar'] == k;

  Widget _koseTutamak(TemaProvider t, int i, double Function(num) sx, double Function(num) sy, double cw, double ch) {
    final pt = parsel[aktifKat]![i];
    final sc = _sec('kose', i);
    return Positioned(
      left: sx(pt[0]) - 13, top: sy(pt[1]) - 13,
      child: GestureDetector(
        onTap: () => setState(() => secili = {'tur': 'kose', 'anahtar': i}),
        onPanStart: (_) => _gecmisKaydet(),
        onPanUpdate: (d) => setState(() {
          pt[0] = (pt[0] + d.delta.dx / cw * 1000).clamp(0, 1000);
          pt[1] = (pt[1] + d.delta.dy / ch * 1000).clamp(0, 1000);
        }),
        child: Container(width: 26, height: 26, decoration: BoxDecoration(
          color: const Color(0xFF0EA5E9), shape: BoxShape.circle,
          border: Border.all(color: sc ? Colors.white : Colors.white70, width: sc ? 3 : 1.5))),
      ),
    );
  }

  Widget _bolgeWidget(TemaProvider t, int i, double Function(num) sx, double Function(num) sy, double cw, double ch) {
    final b = bolgeler[i];
    final sc = _sec('bolge', i);
    const renk = Color(0xFF0EA5E9);
    return Positioned(
      left: sx(_n(b['x'])), top: sy(_n(b['y'])),
      child: GestureDetector(
        // Gövde SADECE seçer/siler — sürüklemez (üstüne nokta/masa konabilsin, kazara oynamasın)
        onTap: () => setState(() => secili = {'tur': 'bolge', 'anahtar': i}),
        onLongPress: () => _sil('bolge', i),
        child: Container(
          width: sx(_n(b['w'])), height: sy(_n(b['h'])),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sc ? renk : renk.withValues(alpha: 0.5), width: sc ? 2 : 1.2)),
          child: Stack(clipBehavior: Clip.none, children: [
            Padding(padding: const EdgeInsets.all(6), child: Text(b['ad']?.toString() ?? '', style: const TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold))),
            if (sc) Positioned(right: 0, top: 0, child: GestureDetector(     // TAŞI
              onPanStart: (_) => _gecmisKaydet(),
              onPanUpdate: (d) => setState(() {
                b['x'] = (_n(b['x']) + d.delta.dx / cw * 1000).clamp(0, 1000);
                b['y'] = (_n(b['y']) + d.delta.dy / ch * 1000).clamp(0, 1000);
              }),
              child: Container(width: 28, height: 28, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.open_with, size: 16, color: Colors.white)))),
            if (sc) Positioned(right: 0, bottom: 0, child: GestureDetector(  // BOYUT
              onPanStart: (_) => _gecmisKaydet(),
              onPanUpdate: (d) => setState(() {
                b['w'] = (_n(b['w']) + d.delta.dx / cw * 1000).clamp(90, 1000);
                b['h'] = (_n(b['h']) + d.delta.dy / ch * 1000).clamp(70, 1000);
              }),
              child: Container(width: 26, height: 26, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.open_in_full, size: 15, color: Colors.white)))),
          ]),
        ),
      ),
    );
  }

  Widget _noktaWidget(TemaProvider t, int i, double Function(num) sx, double Function(num) sy, double cw, double ch) {
    final nk = noktalar[i];
    final def = _tipler[nk['tip']?.toString() ?? 'diger'] ?? _tipler['diger']!;
    final sc = _sec('nokta', i);
    final nbo = _n(nk['boy']) <= 0 ? 58.0 : _n(nk['boy']).toDouble();
    return Positioned(
      left: sx(_n(nk['x'])) - nbo / 2, top: sy(_n(nk['y'])) - nbo / 2,
      child: GestureDetector(
        onTap: () => setState(() => secili = {'tur': 'nokta', 'anahtar': i}),
        onLongPress: () => _sil('nokta', i),
        onPanStart: (_) => _gecmisKaydet(),
        onPanUpdate: (d) => setState(() {
          nk['x'] = (_n(nk['x']) + d.delta.dx / cw * 1000).clamp(0, 1000);
          nk['y'] = (_n(nk['y']) + d.delta.dy / ch * 1000).clamp(0, 1000);
        }),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Görsel kütüphanesi: assets/sema/<tip>.png varsa gerçek görsel (boyutlanabilir), yoksa ikon rozeti
          Container(
            decoration: sc ? BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white, width: 2.5)) : null,
            child: Image.asset('assets/sema/${nk['tip'] ?? 'diger'}.png', width: nbo, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: def[1] as Color, borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: (def[1] as Color).withValues(alpha: 0.4), blurRadius: 6)]),
                child: Icon(def[0] as IconData, color: Colors.white, size: 20))),
          ),
          const SizedBox(height: 2),
          Text(nk['ad']?.toString() ?? (def[2] as String), style: TextStyle(color: t.ink, fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _masaWidget(TemaProvider t, String mid, double Function(num) sx, double Function(num) sy, double cw, double ch) {
    final yer = masaYer[mid]!;
    final masa = masalar.firstWhere((m) => '${m['id']}' == mid, orElse: () => <String, dynamic>{'ad': mid, 'sekil': 'kare'});
    final yuvarlak = (masa['sekil']?.toString() ?? 'kare') == 'yuvarlak';
    final kap = _n(masa['kapasite']).toInt();
    final masaGorsel = yuvarlak
        ? (kap > 0 && kap <= 2 ? 'assets/sema/masa_yuvarlak_2.png' : 'assets/sema/masa_yuvarlak.png')
        : (kap > 0 && kap <= 2 ? 'assets/sema/masa_kare_2.png' : 'assets/sema/masa_kare.png');
    final sc = _sec('masa', mid);
    final boyV = _n(yer['boy']) <= 0 ? 170.0 : _n(yer['boy']).toDouble();
    final boyut = sx(boyV).clamp(28.0, cw);
    return Positioned(
      left: sx(_n(yer['x'])) - boyut / 2, top: sy(_n(yer['y'])) - boyut / 2,
      child: GestureDetector(
        onTap: () => setState(() => secili = {'tur': 'masa', 'anahtar': mid}),
        onLongPress: () => _sil('masa', mid),
        onPanStart: (_) => _gecmisKaydet(),
        onPanUpdate: (d) => setState(() {
          yer['x'] = (_n(yer['x']) + d.delta.dx / cw * 1000).clamp(0, 1000);
          yer['y'] = (_n(yer['y']) + d.delta.dy / ch * 1000).clamp(0, 1000);
        }),
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          // Görsel kütüphanesi: masa_kare/masa_yuvarlak.png varsa gerçek görsel, yoksa mor kutu
          Container(
            width: boyut, height: boyut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(yuvarlak ? boyut / 2 : 12),
              border: sc ? Border.all(color: Colors.white, width: 2.5) : null),
            child: Image.asset(
              masaGorsel,
              width: boyut, height: boyut, fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Container(
                decoration: BoxDecoration(color: t.mor1,
                  borderRadius: BorderRadius.circular(yuvarlak ? boyut / 2 : 12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1),
                  boxShadow: [BoxShadow(color: t.mor1.withValues(alpha: 0.35), blurRadius: 6)])),
            ),
          ),
          // Masa adı/no rozeti (görsel üstünde okunur)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(7)),
            child: Text(masa['ad']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
          ),
          if (sc) Positioned(right: -6, bottom: -6, child: GestureDetector(
            onPanStart: (_) => _gecmisKaydet(),
            onPanUpdate: (d) => setState(() => yer['boy'] = (boyV + d.delta.dx / cw * 1000 * 1.4).clamp(90, 700)),
            child: Container(width: 22, height: 22, decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle,
                border: Border.all(color: t.mor1, width: 2)),
                child: Icon(Icons.open_in_full, size: 12, color: t.mor1)),
          )),
        ]),
      ),
    );
  }

  Widget _seciliCubuk(TemaProvider t) {
    final tur = secili!['tur'];
    String ad = 'Öğe';
    bool adDegisir = false;
    if (tur == 'masa') {
      ad = (masalar.firstWhere((m) => '${m['id']}' == secili!['anahtar'], orElse: () => <String, dynamic>{'ad': 'Masa'})['ad']).toString();
    } else if (tur == 'bolge') {
      ad = bolgeler[secili!['anahtar'] as int]['ad']?.toString() ?? 'Bölge'; adDegisir = true;
    } else if (tur == 'nokta') {
      ad = noktalar[secili!['anahtar'] as int]['ad']?.toString() ?? 'Nokta'; adDegisir = true;
    } else if (tur == 'kose') {
      ad = 'Köşe';
    }
    return Container(
      color: t.card2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(children: [
        Icon(Icons.adjust, size: 16, color: t.sub),
        const SizedBox(width: 8),
        Expanded(child: Text('Seçili: $ad', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        if (tur == 'masa') ...[
          Text('Boyut', style: TextStyle(color: t.sub, fontSize: 12)),
          IconButton(tooltip: 'Küçült', visualDensity: VisualDensity.compact, onPressed: () => _masaBoy(secili!['anahtar'] as String, 0.82),
              icon: Icon(Icons.remove_circle_outline, color: t.mor1)),
          IconButton(tooltip: 'Büyült', visualDensity: VisualDensity.compact, onPressed: () => _masaBoy(secili!['anahtar'] as String, 1.22),
              icon: Icon(Icons.add_circle_outline, color: t.mor1)),
        ],
        if (tur == 'nokta') ...[
          Text('Boyut', style: TextStyle(color: t.sub, fontSize: 12)),
          IconButton(tooltip: 'Küçült', visualDensity: VisualDensity.compact, onPressed: () => _noktaBoy(secili!['anahtar'] as int, 0.85),
              icon: Icon(Icons.remove_circle_outline, color: t.mor1)),
          IconButton(tooltip: 'Büyült', visualDensity: VisualDensity.compact, onPressed: () => _noktaBoy(secili!['anahtar'] as int, 1.18),
              icon: Icon(Icons.add_circle_outline, color: t.mor1)),
        ],
        if (adDegisir)
          TextButton.icon(onPressed: _seciliAdDegistir, icon: Icon(Icons.edit, size: 16, color: t.mor1),
              label: Text('Adı Değiştir', style: TextStyle(color: t.mor1, fontWeight: FontWeight.bold))),
        TextButton.icon(onPressed: () => _sil(tur, secili!['anahtar']), icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
            label: const Text('Sil', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _altAracCubugu(TemaProvider t) {
    Widget btn(IconData ik, String lbl, VoidCallback onTap, Color c) => Expanded(
          child: InkWell(onTap: onTap, child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(ik, color: c, size: 22), const SizedBox(height: 3),
              Text(lbl, style: TextStyle(color: t.sub2, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          )),
        );
    return Container(
      decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
      child: SafeArea(top: false, child: Row(children: [
        btn(Icons.table_bar, 'Masa Ekle', _masaEkleSheet, t.mor1),
        btn(Icons.crop_square, 'Bölge', _bolgeEkle, const Color(0xFF0EA5E9)),
        btn(Icons.add_location_alt, 'Nokta', _noktaEkleSheet, const Color(0xFFF97316)),
        btn(Icons.pentagon_outlined, 'Salon Sınırı', () { _gecmisKaydet(); setState(() { parsel[aktifKat] ??= _dikdortgen(); }); }, const Color(0xFF14B8A6)),
      ])),
    );
  }

  // ---------------- işlemler ----------------
  void _sil(String tur, dynamic anahtar) {
    _gecmisKaydet();
    setState(() {
      if (tur == 'masa') {
        masaYer.remove(anahtar);
      } else if (tur == 'bolge') {
        bolgeler.removeAt(anahtar as int);
      } else if (tur == 'nokta') {
        noktalar.removeAt(anahtar as int);
      } else if (tur == 'kose') {
        parsel[aktifKat]?.removeAt(anahtar as int);
      }
      secili = null;
    });
  }

  void _seciliAdDegistir() {
    if (secili == null) return;
    final tur = secili!['tur'];
    final idx = secili!['anahtar'];
    String mevcut = '';
    if (tur == 'bolge') {
      mevcut = bolgeler[idx as int]['ad']?.toString() ?? '';
    } else if (tur == 'nokta') {
      mevcut = noktalar[idx as int]['ad']?.toString() ?? '';
    }
    _adGir('Ad', mevcut, (v) { _gecmisKaydet(); setState(() {
      if (tur == 'bolge') {
        bolgeler[idx as int]['ad'] = v;
      } else if (tur == 'nokta') {
        noktalar[idx as int]['ad'] = v;
      }
    }); });
  }

  void _bolgeEkle() {
    _adGir('Bölge adı', '', (v) { _gecmisKaydet(); setState(() {
      bolgeler.add({'kat': aktifKat, 'ad': v, 'x': 300.0, 'y': 300.0, 'w': 320.0, 'h': 240.0});
      secili = {'tur': 'bolge', 'anahtar': bolgeler.length - 1};
    }); });
  }

  void _noktaEkleSheet() {
    final t = _t;
    showModalBottomSheet(useRootNavigator: true, context: context, backgroundColor: t.card, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sabit nokta ekle', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: _tipler.entries.map((e) => InkWell(
          onTap: () { Navigator.pop(ctx); _noktaEkle(e.key); },
          child: Container(width: 92, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: (e.value[1] as Color).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: (e.value[1] as Color).withValues(alpha: 0.4))),
            child: Column(children: [Icon(e.value[0] as IconData, color: e.value[1] as Color), const SizedBox(height: 6),
                Text(e.value[2] as String, style: TextStyle(color: t.ink, fontSize: 12, fontWeight: FontWeight.w600))]),
          ))).toList()),
      ])),
    );
  }

  void _noktaEkle(String tip) { _gecmisKaydet(); setState(() {
        noktalar.add({'kat': aktifKat, 'tip': tip, 'ad': (_tipler[tip]![2] as String), 'x': 500.0, 'y': 500.0});
        secili = {'tur': 'nokta', 'anahtar': noktalar.length - 1};
      }); }

  void _masaEkleSheet() {
    final t = _t;
    final yerlesmis = masaYer.keys.toSet();
    final bekleyen = masalar.where((m) => !yerlesmis.contains('${m['id']}')).toList();
    showModalBottomSheet(useRootNavigator: true, context: context, backgroundColor: t.card, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text('Masa ekle', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold))),
          if (yerlesmis.isNotEmpty) TextButton(onPressed: () { Navigator.pop(ctx); _tumMasalariKaldir(); },
              child: const Text('Yerleşenleri kaldır', style: TextStyle(color: Color(0xFFDC2626), fontSize: 12))),
        ]),
        Text('Masaya dokun → şemaya düşer, sonra sürükle.', style: TextStyle(color: t.sub, fontSize: 12)),
        const SizedBox(height: 12),
        if (bekleyen.isEmpty)
          Text('Tüm masalar yerleştirildi 👍 (yeniden dizmek için "Yerleşenleri kaldır")', style: TextStyle(color: t.sub))
        else
          ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.45),
            child: SingleChildScrollView(child: Wrap(spacing: 8, runSpacing: 8, children: bekleyen.map((m) => InkWell(
              onTap: () { Navigator.pop(ctx); _masaEkle('${m['id']}'); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: t.mor1.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: t.mor1.withValues(alpha: 0.4))),
                child: Text(m['ad']?.toString() ?? '', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold))),
            )).toList()))),
      ])),
    );
  }

  void _masaEkle(String mid) { _gecmisKaydet(); setState(() {
        masaYer[mid] = {'kat': aktifKat, 'x': 500.0, 'y': 450.0, 'boy': 170.0};
        secili = {'tur': 'masa', 'anahtar': mid};
      }); }

  void _masaBoy(String mid, double f) {
    final yer = masaYer[mid];
    if (yer == null) return;
    _gecmisKaydet();
    final cur = _n(yer['boy']) <= 0 ? 170.0 : _n(yer['boy']).toDouble();
    setState(() => yer['boy'] = (cur * f).clamp(90, 700));
  }

  void _noktaBoy(int i, double f) {
    _gecmisKaydet();
    final nk = noktalar[i];
    final cur = _n(nk['boy']) <= 0 ? 58.0 : _n(nk['boy']).toDouble();
    setState(() => nk['boy'] = (cur * f).clamp(28, 220));
  }

  void _tumMasalariKaldir() { _gecmisKaydet(); setState(() { masaYer.clear(); secili = null; }); }

  void _katiTemizle() {
    showDialog(useRootNavigator: true, context: context, builder: (ctx) => AlertDialog(
      backgroundColor: _t.card, surfaceTintColor: _t.card,
      title: Text('Bu katı temizle?', style: TextStyle(color: _t.ink, fontSize: 16)),
      content: Text('Bu kattaki masalar, bölgeler, noktalar ve salon sınırı kaldırılır (kaydedene kadar geri alınabilir).', style: TextStyle(color: _t.sub)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)), onPressed: () {
          _gecmisKaydet();
          setState(() {
            bolgeler.removeWhere((b) => _n(b['kat']).toInt() == aktifKat);
            noktalar.removeWhere((nk) => _n(nk['kat']).toInt() == aktifKat);
            masaYer.removeWhere((k, v) => _n(v['kat']).toInt() == aktifKat);
            parsel.remove(aktifKat);
            secili = null;
          });
          Navigator.pop(ctx);
        }, child: const Text('Temizle')),
      ],
    ));
  }

  void _koseEkle() {
    final pts = parsel[aktifKat];
    if (pts == null || pts.length < 2) return;
    // En uzun kenarın ortasına köşe ekle
    int en = 0; double enU = -1;
    for (int i = 0; i < pts.length; i++) {
      final a = pts[i], b = pts[(i + 1) % pts.length];
      final u = (a[0] - b[0]) * (a[0] - b[0]) + (a[1] - b[1]) * (a[1] - b[1]);
      if (u > enU) { enU = u; en = i; }
    }
    final a = pts[en], b = pts[(en + 1) % pts.length];
    _gecmisKaydet();
    setState(() => pts.insert(en + 1, [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2]));
  }

  void _katEkle() { _gecmisKaydet(); setState(() { katlar.add('Kat ${katlar.length}'); aktifKat = katlar.length - 1; }); _adGir('Kat adı', katlar.last, (v) => setState(() => katlar[aktifKat] = v)); }

  void _katMenu(int i) {
    final t = _t;
    showModalBottomSheet(useRootNavigator: true, context: context, backgroundColor: t.card, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: Icon(Icons.edit, color: t.mor1), title: Text('Adı Değiştir', style: TextStyle(color: t.ink)),
            onTap: () { Navigator.pop(ctx); _adGir('Kat adı', katlar[i], (v) => setState(() => katlar[i] = v)); }),
        if (katlar.length > 1)
          ListTile(leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)), title: const Text('Katı Sil', style: TextStyle(color: Color(0xFFDC2626))),
              onTap: () { Navigator.pop(ctx); _katSil(i); }),
      ])),
    );
  }

  void _katSil(int i) {
    _gecmisKaydet();
    setState(() {
      bolgeler.removeWhere((b) => _n(b['kat']).toInt() == i);
      noktalar.removeWhere((nk) => _n(nk['kat']).toInt() == i);
      masaYer.removeWhere((k, v) => _n(v['kat']).toInt() == i);
      parsel.remove(i);
      // i'den büyük katları bir azalt (indeksler kaysın)
      for (final b in bolgeler) { if (_n(b['kat']).toInt() > i) b['kat'] = _n(b['kat']).toInt() - 1; }
      for (final nk in noktalar) { if (_n(nk['kat']).toInt() > i) nk['kat'] = _n(nk['kat']).toInt() - 1; }
      for (final v in masaYer.values) { if (_n(v['kat']).toInt() > i) v['kat'] = _n(v['kat']).toInt() - 1; }
      final yeniParsel = <int, List<List<double>>>{};
      parsel.forEach((k, val) => yeniParsel[k > i ? k - 1 : k] = val);
      parsel = yeniParsel;
      katlar.removeAt(i);
      aktifKat = aktifKat.clamp(0, katlar.length - 1);
      secili = null;
    });
  }

  // Klavye açılan güvenilir isim girişi (dialog yerine bottom sheet)
  void _adGir(String baslik, String mevcut, ValueChanged<String> onOk) {
    final t = _t;
    final c = TextEditingController(text: mevcut);
    showModalBottomSheet(useRootNavigator: true, context: context, backgroundColor: t.card, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(controller: c, autofocus: true, textInputAction: TextInputAction.done,
            style: TextStyle(color: t.ink, fontSize: 16),
            onSubmitted: (_) { final v = c.text.trim(); if (v.isNotEmpty) onOk(v); Navigator.pop(ctx); },
            decoration: InputDecoration(hintText: baslik, hintStyle: TextStyle(color: t.sub),
              filled: true, fillColor: t.card2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 12),
          SizedBox(width: double.infinity, child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.mor1),
            onPressed: () { final v = c.text.trim(); if (v.isNotEmpty) onOk(v); Navigator.pop(ctx); },
            child: const Text('Tamam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
        ]),
      ),
    );
  }
}

class _ZeminPainter extends CustomPainter {
  final Color cizgi, parselDolgu, parselCizgi, bos;
  final List<Offset> pts;
  _ZeminPainter({required this.cizgi, required this.parselDolgu, required this.parselCizgi, required this.bos, required this.pts});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    if (pts.length < 3) {
      canvas.drawRRect(r, Paint()..color = bos);
    } else {
      canvas.drawRRect(r, Paint()..color = bos);
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }
      path.close();
      canvas.drawPath(path, Paint()..color = parselDolgu..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()..color = parselCizgi..style = PaintingStyle.stroke..strokeWidth = 2.5);
    }
    final gp = Paint()..color = cizgi..strokeWidth = 0.6;
    for (int i = 1; i < 10; i++) {
      final dx = size.width * i / 10, dy = size.height * i / 10;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gp);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gp);
    }
  }

  @override
  bool shouldRepaint(covariant _ZeminPainter old) => true;
}

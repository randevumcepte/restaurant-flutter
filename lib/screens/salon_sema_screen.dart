import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// SALON ŞEMA (dijital ikiz) — patron restoranı çizer: kat(lar), PARSEL (serbest şekil,
/// köşe köşe), bölge alanları, sabit noktalar (giriş/mutfak/bar/wc/otopark/kasa/depo) ve
/// masalar. Kaydedilen kroki ısı haritasına ZEMİN olur + POS masa konumunu günceller.
/// Koordinatlar 0..1000 sanal uzayda.
class SalonSemaScreen extends StatefulWidget {
  const SalonSemaScreen({super.key});
  @override
  State<SalonSemaScreen> createState() => _SalonSemaScreenState();
}

class _SalonSemaScreenState extends State<SalonSemaScreen> {
  TemaProvider get _t => context.watch<TemaProvider>();

  bool loading = true, mesgul = false;
  String arac = 'sec'; // sec | alan
  List<String> katlar = ['Zemin Kat'];
  int aktifKat = 0;

  List<Map<String, dynamic>> bolgeler = [];   // {kat,ad,x,y,w,h,renk}
  List<Map<String, dynamic>> noktalar = [];    // {kat,tip,ad,x,y}
  Map<String, Map<String, dynamic>> masaYer = {}; // masaId -> {kat,x,y}
  Map<int, List<List<double>>> parsel = {};    // kat -> [[x,y],...] (poligon köşeleri)
  List<Map<String, dynamic>> masalar = [];     // sunucu: {id,ad,kapasite,sekil,bolge_id}

  Map<String, dynamic>? secili; // {tur: masa|bolge|nokta|kose, anahtar}

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

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        iconTheme: IconThemeData(color: t.ink),
        title: Text('Salon Şeması', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
        actions: [
          TextButton.icon(
            onPressed: mesgul ? null : _kaydet,
            icon: Icon(Icons.save_outlined, color: t.mor1, size: 20),
            label: Text('Kaydet', style: TextStyle(color: t.mor1, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _katSekmeleri(t),
              if (arac == 'alan') _alanIpucu(t),
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
                onLongPress: () => _katDuzenle(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: aktifKat == i ? t.mor1 : t.card2, borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: aktifKat == i ? t.mor1 : t.line)),
                  child: Text(katlar[i], style: TextStyle(color: aktifKat == i ? Colors.white : t.sub2, fontWeight: FontWeight.bold, fontSize: 12.5)),
                ),
              )),
          ]))),
          IconButton(tooltip: 'Kat ekle', onPressed: _katEkle, icon: Icon(Icons.add_circle_outline, color: t.mor1)),
        ]),
      );

  Widget _alanIpucu(TemaProvider t) => Container(
        width: double.infinity, color: const Color(0xFF0EA5E9).withValues(alpha: 0.14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          const Icon(Icons.touch_app, color: Color(0xFF0EA5E9), size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('Salonun köşelerine sırayla dokun (üçgen, L, kare… serbest). Bitince "Bitir".',
              style: TextStyle(color: t.ink, fontSize: 12))),
          if ((parsel[aktifKat]?.isNotEmpty ?? false)) ...[
            TextButton(onPressed: () => setState(() { if (parsel[aktifKat]!.isNotEmpty) parsel[aktifKat]!.removeLast(); }),
                child: const Text('Geri al', style: TextStyle(color: Color(0xFFF97316), fontSize: 12))),
            TextButton(onPressed: () => setState(() => arac = 'sec'), child: const Text('Bitir', style: TextStyle(color: Color(0xFF0EA5E9), fontWeight: FontWeight.bold))),
          ],
        ]),
      );

  Widget _kanvas(TemaProvider t) {
    return LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth - 24;
      double s(num v) => v / 1000 * w;
      double sanal(double px) => px / w * 1000;
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              if (arac == 'alan') {
                setState(() => (parsel[aktifKat] ??= []).add([sanal(d.localPosition.dx).clamp(0, 1000), sanal(d.localPosition.dy).clamp(0, 1000)]));
              } else {
                setState(() => secili = null);
              }
            },
            child: SizedBox(
              width: w, height: w,
              child: Stack(clipBehavior: Clip.none, children: [
                // zemin + ızgara + parsel
                Positioned.fill(child: CustomPaint(painter: _ZeminPainter(
                  cizgi: t.line.withValues(alpha: 0.35),
                  parselDolgu: const Color(0xFF0EA5E9).withValues(alpha: 0.10),
                  parselCizgi: const Color(0xFF0EA5E9),
                  bos: t.koyu ? const Color(0xFF0E1526) : const Color(0xFFF1F5F9),
                  pts: (parsel[aktifKat] ?? const []).map((p) => Offset(s(p[0]).toDouble(), s(p[1]).toDouble())).toList(),
                ))),
                // Bölgeler
                for (int i = 0; i < bolgeler.length; i++)
                  if (_n(bolgeler[i]['kat']).toInt() == aktifKat) _bolgeWidget(t, i, s, w),
                // Noktalar
                for (int i = 0; i < noktalar.length; i++)
                  if (_n(noktalar[i]['kat']).toInt() == aktifKat) _noktaWidget(t, i, s, w),
                // Masalar
                for (final e in masaYer.entries)
                  if (_n(e.value['kat']).toInt() == aktifKat) _masaWidget(t, e.key, s, w),
                // Parsel köşe tutamakları (sec modunda)
                if (arac == 'sec')
                  for (int i = 0; i < (parsel[aktifKat]?.length ?? 0); i++) _koseTutamak(t, i, s, w),
              ]),
            ),
          ),
        ),
      );
    });
  }

  bool _sec(String tur, dynamic k) => secili != null && secili!['tur'] == tur && secili!['anahtar'] == k;

  Widget _koseTutamak(TemaProvider t, int i, double Function(num) s, double cw) {
    final pt = parsel[aktifKat]![i];
    final sc = _sec('kose', i);
    return Positioned(
      left: s(pt[0]) - 11, top: s(pt[1]) - 11,
      child: GestureDetector(
        onTap: () => setState(() => secili = {'tur': 'kose', 'anahtar': i}),
        onPanUpdate: (d) => setState(() {
          pt[0] = (pt[0] + d.delta.dx / cw * 1000).clamp(0, 1000);
          pt[1] = (pt[1] + d.delta.dy / cw * 1000).clamp(0, 1000);
        }),
        child: Container(width: 22, height: 22, decoration: BoxDecoration(
          color: const Color(0xFF0EA5E9), shape: BoxShape.circle,
          border: Border.all(color: sc ? Colors.white : Colors.white70, width: sc ? 2.5 : 1.5))),
      ),
    );
  }

  Widget _bolgeWidget(TemaProvider t, int i, double Function(num) s, double cw) {
    final b = bolgeler[i];
    final sc = _sec('bolge', i);
    const renk = Color(0xFF0EA5E9);
    return Positioned(
      left: s(_n(b['x'])), top: s(_n(b['y'])),
      child: GestureDetector(
        onTap: () => setState(() => secili = {'tur': 'bolge', 'anahtar': i}),
        onPanUpdate: (d) => setState(() {
          b['x'] = (_n(b['x']) + d.delta.dx / cw * 1000).clamp(0, 1000);
          b['y'] = (_n(b['y']) + d.delta.dy / cw * 1000).clamp(0, 1000);
        }),
        child: Container(
          width: s(_n(b['w'])), height: s(_n(b['h'])),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: sc ? renk : renk.withValues(alpha: 0.5), width: sc ? 2 : 1.2)),
          child: Stack(children: [
            Padding(padding: const EdgeInsets.all(6), child: Text(b['ad']?.toString() ?? '', style: const TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold))),
            if (sc) Positioned(right: 0, bottom: 0, child: GestureDetector(
              onPanUpdate: (d) => setState(() {
                b['w'] = (_n(b['w']) + d.delta.dx / cw * 1000).clamp(90, 1000);
                b['h'] = (_n(b['h']) + d.delta.dy / cw * 1000).clamp(70, 1000);
              }),
              child: Container(width: 24, height: 24, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.open_in_full, size: 14, color: Colors.white)))),
          ]),
        ),
      ),
    );
  }

  Widget _noktaWidget(TemaProvider t, int i, double Function(num) s, double cw) {
    final nk = noktalar[i];
    final def = _tipler[nk['tip']?.toString() ?? 'diger'] ?? _tipler['diger']!;
    final sc = _sec('nokta', i);
    return Positioned(
      left: s(_n(nk['x'])) - 30, top: s(_n(nk['y'])) - 28,
      child: GestureDetector(
        onTap: () => setState(() => secili = {'tur': 'nokta', 'anahtar': i}),
        onPanUpdate: (d) => setState(() {
          nk['x'] = (_n(nk['x']) + d.delta.dx / cw * 1000).clamp(0, 1000);
          nk['y'] = (_n(nk['y']) + d.delta.dy / cw * 1000).clamp(0, 1000);
        }),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: def[1] as Color, borderRadius: BorderRadius.circular(12),
                border: sc ? Border.all(color: Colors.white, width: 2.5) : null,
                boxShadow: [BoxShadow(color: (def[1] as Color).withValues(alpha: 0.4), blurRadius: 6)]),
            child: Icon(def[0] as IconData, color: Colors.white, size: 20)),
          const SizedBox(height: 2),
          Text(nk['ad']?.toString() ?? (def[2] as String), style: TextStyle(color: t.ink, fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _masaWidget(TemaProvider t, String mid, double Function(num) s, double cw) {
    final yer = masaYer[mid]!;
    final masa = masalar.firstWhere((m) => '${m['id']}' == mid, orElse: () => {'ad': mid, 'sekil': 'kare'});
    final yuvarlak = (masa['sekil']?.toString() ?? 'kare') == 'yuvarlak';
    final sc = _sec('masa', mid);
    const boyut = 60.0;
    return Positioned(
      left: s(_n(yer['x'])) - boyut / 2, top: s(_n(yer['y'])) - boyut / 2,
      child: GestureDetector(
        onTap: () => setState(() => secili = {'tur': 'masa', 'anahtar': mid}),
        onPanUpdate: (d) => setState(() {
          yer['x'] = (_n(yer['x']) + d.delta.dx / cw * 1000).clamp(0, 1000);
          yer['y'] = (_n(yer['y']) + d.delta.dy / cw * 1000).clamp(0, 1000);
        }),
        child: Container(
          width: boyut, height: boyut,
          decoration: BoxDecoration(color: t.mor1,
            borderRadius: BorderRadius.circular(yuvarlak ? boyut / 2 : 12),
            border: Border.all(color: sc ? Colors.white : Colors.white.withValues(alpha: 0.4), width: sc ? 2.5 : 1),
            boxShadow: [BoxShadow(color: t.mor1.withValues(alpha: 0.35), blurRadius: 6)]),
          child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text(masa['ad']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900))))),
        ),
      ),
    );
  }

  // Seçili öğe için işlem çubuğu (adı değiştir / sil)
  Widget _seciliCubuk(TemaProvider t) {
    final tur = secili!['tur'];
    String ad = 'Öğe';
    bool adDegisir = false;
    if (tur == 'masa') { ad = (masalar.firstWhere((m) => '${m['id']}' == secili!['anahtar'], orElse: () => {'ad': 'Masa'})['ad']).toString(); }
    else if (tur == 'bolge') { ad = bolgeler[secili!['anahtar'] as int]['ad']?.toString() ?? 'Bölge'; adDegisir = true; }
    else if (tur == 'nokta') { ad = noktalar[secili!['anahtar'] as int]['ad']?.toString() ?? 'Nokta'; adDegisir = true; }
    else if (tur == 'kose') { ad = 'Köşe'; }
    return Container(
      color: t.card2,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(children: [
        Icon(Icons.adjust, size: 16, color: t.sub),
        const SizedBox(width: 8),
        Expanded(child: Text('Seçili: $ad', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
        if (adDegisir)
          TextButton.icon(onPressed: _seciliAdDegistir, icon: Icon(Icons.edit, size: 16, color: t.mor1),
              label: Text('Adı', style: TextStyle(color: t.mor1, fontWeight: FontWeight.bold))),
        TextButton.icon(onPressed: _seciliSil, icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFDC2626)),
            label: const Text('Sil', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _altAracCubugu(TemaProvider t) {
    Widget btn(IconData ik, String lbl, VoidCallback onTap, Color c, {bool aktifMi = false}) => Expanded(
          child: InkWell(onTap: onTap, child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            color: aktifMi ? c.withValues(alpha: 0.14) : Colors.transparent,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(ik, color: c, size: 21), const SizedBox(height: 3),
              Text(lbl, style: TextStyle(color: aktifMi ? c : t.sub2, fontSize: 10.5, fontWeight: FontWeight.w700)),
            ]),
          )),
        );
    return Container(
      decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
      child: SafeArea(top: false, child: Row(children: [
        btn(Icons.pan_tool_alt, 'Seç/Taşı', () => setState(() => arac = 'sec'), t.mor1, aktifMi: arac == 'sec'),
        btn(Icons.gesture, 'Alan Çiz', () => setState(() { arac = 'alan'; secili = null; }), const Color(0xFF0EA5E9), aktifMi: arac == 'alan'),
        btn(Icons.table_bar, 'Masa', _masaEkleSheet, t.mor1),
        btn(Icons.crop_square, 'Bölge', _bolgeEkle, const Color(0xFF0EA5E9)),
        btn(Icons.add_location_alt, 'Nokta', _noktaEkleSheet, const Color(0xFFF97316)),
      ])),
    );
  }

  // ---- işlemler ----
  void _seciliSil() {
    if (secili == null) return;
    setState(() {
      final tur = secili!['tur'];
      if (tur == 'masa') {
        masaYer.remove(secili!['anahtar']);
      } else if (tur == 'bolge') {
        bolgeler.removeAt(secili!['anahtar'] as int);
      } else if (tur == 'nokta') {
        noktalar.removeAt(secili!['anahtar'] as int);
      } else if (tur == 'kose') {
        parsel[aktifKat]?.removeAt(secili!['anahtar'] as int);
      }
      secili = null;
    });
  }

  void _seciliAdDegistir() {
    if (secili == null) return;
    final tur = secili!['tur'];
    String mevcut = '';
    if (tur == 'bolge') {
      mevcut = bolgeler[secili!['anahtar'] as int]['ad']?.toString() ?? '';
    } else if (tur == 'nokta') {
      mevcut = noktalar[secili!['anahtar'] as int]['ad']?.toString() ?? '';
    }
    _adDuzenle('Ad', (v) => setState(() {
      if (tur == 'bolge') {
        bolgeler[secili!['anahtar'] as int]['ad'] = v;
      } else if (tur == 'nokta') {
        noktalar[secili!['anahtar'] as int]['ad'] = v;
      }
    }), mevcut: mevcut);
  }

  void _bolgeEkle() {
    setState(() {
      bolgeler.add({'kat': aktifKat, 'ad': 'Bölge', 'x': 320.0, 'y': 320.0, 'w': 320.0, 'h': 240.0, 'renk': 0xFF0EA5E9});
      secili = {'tur': 'bolge', 'anahtar': bolgeler.length - 1};
      arac = 'sec';
    });
    _adDuzenle('Bölge adı', (v) => setState(() => bolgeler.last['ad'] = v), mevcut: 'Bölge');
  }

  void _noktaEkleSheet() {
    final t = _t;
    showModalBottomSheet(context: context, backgroundColor: t.card, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sabit nokta ekle', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: _tipler.entries.map((e) => GestureDetector(
          onTap: () { Navigator.pop(ctx); _noktaEkle(e.key); },
          child: Container(width: 92, padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: (e.value[1] as Color).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: (e.value[1] as Color).withValues(alpha: 0.4))),
            child: Column(children: [Icon(e.value[0] as IconData, color: e.value[1] as Color), const SizedBox(height: 6),
                Text(e.value[2] as String, style: TextStyle(color: t.ink, fontSize: 12, fontWeight: FontWeight.w600))]),
          ))).toList()),
      ])),
    );
  }

  void _noktaEkle(String tip) => setState(() {
        noktalar.add({'kat': aktifKat, 'tip': tip, 'ad': (_tipler[tip]![2] as String), 'x': 500.0, 'y': 500.0});
        secili = {'tur': 'nokta', 'anahtar': noktalar.length - 1};
        arac = 'sec';
      });

  void _masaEkleSheet() {
    final t = _t;
    final yerlesmis = masaYer.keys.toSet();
    final bekleyen = masalar.where((m) => !yerlesmis.contains('${m['id']}')).toList();
    showModalBottomSheet(context: context, backgroundColor: t.card, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Masa ekle', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Yerleştirilmemiş masalar — dokun, şemaya düşsün (sonra sürükle).', style: TextStyle(color: t.sub, fontSize: 12)),
        const SizedBox(height: 12),
        if (bekleyen.isEmpty)
          Text('Tüm masalar yerleştirildi 👍', style: TextStyle(color: t.sub))
        else
          ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.5),
            child: SingleChildScrollView(child: Wrap(spacing: 8, runSpacing: 8, children: bekleyen.map((m) => GestureDetector(
              onTap: () { Navigator.pop(ctx); _masaEkle('${m['id']}'); },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: t.mor1.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: t.mor1.withValues(alpha: 0.4))),
                child: Text(m['ad']?.toString() ?? '', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold))),
            )).toList()))),
      ])),
    );
  }

  void _masaEkle(String mid) => setState(() {
        masaYer[mid] = {'kat': aktifKat, 'x': 500.0, 'y': 450.0};
        secili = {'tur': 'masa', 'anahtar': mid};
        arac = 'sec';
      });

  void _katEkle() { setState(() { katlar.add('Kat ${katlar.length}'); aktifKat = katlar.length - 1; }); _katDuzenle(katlar.length - 1); }
  void _katDuzenle(int i) => _adDuzenle('Kat adı', (v) => setState(() => katlar[i] = v), mevcut: katlar[i]);

  void _adDuzenle(String baslik, ValueChanged<String> onOk, {String mevcut = ''}) {
    final t = _t;
    final c = TextEditingController(text: mevcut);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: t.card, surfaceTintColor: t.card,
      title: Text(baslik, style: TextStyle(color: t.ink, fontSize: 16)),
      content: TextField(controller: c, autofocus: true, style: TextStyle(color: t.ink),
          decoration: InputDecoration(hintText: baslik, hintStyle: TextStyle(color: t.sub))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
        FilledButton(onPressed: () { final v = c.text.trim(); if (v.isNotEmpty) onOk(v); Navigator.pop(ctx); }, child: const Text('Tamam')),
      ],
    ));
  }
}

class _ZeminPainter extends CustomPainter {
  final Color cizgi, parselDolgu, parselCizgi, bos;
  final List<Offset> pts;
  _ZeminPainter({required this.cizgi, required this.parselDolgu, required this.parselCizgi, required this.bos, required this.pts});

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    // Parsel çizilmediyse tüm alan zemin; çizildiyse sadece poligon zemin
    if (pts.length < 3) {
      canvas.drawRRect(r, Paint()..color = bos);
    } else {
      canvas.save();
      canvas.clipRRect(r);
      final path = Path()..moveTo(pts[0].dx, pts[0].dy);
      for (var i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }
      path.close();
      canvas.drawPath(path, Paint()..color = parselDolgu..style = PaintingStyle.fill);
      canvas.drawPath(path, Paint()..color = parselCizgi..style = PaintingStyle.stroke..strokeWidth = 2.5);
      canvas.restore();
    }
    // ızgara
    final gp = Paint()..color = cizgi..strokeWidth = 0.6;
    for (int i = 1; i < 10; i++) {
      final dx = size.width * i / 10, dy = size.height * i / 10;
      canvas.drawLine(Offset(dx, 0), Offset(dx, size.height), gp);
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gp);
    }
    // parsel çiziliyorken köşeleri + kenarları göster (3'ten az)
    if (pts.isNotEmpty && pts.length < 3) {
      final lp = Paint()..color = parselCizgi..strokeWidth = 2.5;
      for (var i = 1; i < pts.length; i++) { canvas.drawLine(pts[i - 1], pts[i], lp); }
      for (final p in pts) { canvas.drawCircle(p, 5, Paint()..color = parselCizgi); }
    }
  }

  @override
  bool shouldRepaint(covariant _ZeminPainter old) => true;
}

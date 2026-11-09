import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../screens/masa_atama_screen.dart';
import '../services/api.dart';

/// GARSON ISI HARİTASI + ALAN UYUMU — web Garson Yönetimi > Isı Haritası ile aynı.
/// İşletme Düzeni masa planı üzerinde: bölgeler kart olarak (Tüm Salon) ya da tek bölge büyük.
/// Sayılar sipariş + servis + hesap işlemleridir; garsonun yürüdüğü yeri değil, işlem yaptığı masayı gösterir.
class SalonIsiHaritasi extends StatefulWidget {
  const SalonIsiHaritasi({super.key});
  @override
  State<SalonIsiHaritasi> createState() => SalonIsiHaritasiState();
}

class _Yuzde {
  final int n, p;
  const _Yuzde(this.n, this.p);
}

class _Uyum {
  int ic = 0, dis = 0;
  int? oran;
  final Map<int, int> bolge = {};
  final List<MapEntry<Map<String, dynamic>, int>> liste = [];
  int get top => ic + dis;
}

class _Yerlesim {
  final Map<int, Offset> poz;
  final int c, r;
  const _Yerlesim(this.poz, this.c, this.r);
}

class SalonIsiHaritasiState extends State<SalonIsiHaritasi> {
  bool _yukleniyor = true;
  String? _hata;
  List<Map<String, dynamic>> _alanlar = [], _masalar = [], _garsonlar = [];
  Map<String, dynamic> _plan = {}, _isi = {};
  String _pencere = 'saat';
  int _garson = 0;
  int _alan = -1; // -1 = Tüm Salon
  Timer? _zaman;

  static const _pencereler = [['saat', 'Son 1 Saat'], ['bugun', 'Bugün'], ['hafta', 'Bu Hafta']];
  static const _kirmizi = Color(0xFFEF4444);
  // Planda gösterilen salon noktaları (bitki/ışık/duvar süs, gösterilmez)
  static const Map<String, List<Object>> _noktalar = {
    'kasa': [Icons.point_of_sale, 'Kasa'], 'bar': [Icons.local_bar, 'Bar'], 'giris': [Icons.login, 'Giriş'],
    'mutfak': [Icons.restaurant, 'Mutfak'], 'wc': [Icons.wc, 'WC'], 'otopark': [Icons.local_parking, 'Otopark'],
    'depo': [Icons.inventory_2_outlined, 'Depo'], 'diger': [Icons.place_outlined, 'Etiket'],
  };

  int _i(dynamic v) => v is num ? v.toInt() : (int.tryParse('${v ?? ''}') ?? 0);

  @override
  void initState() {
    super.initState();
    yukle();
    _zaman = Timer.periodic(const Duration(seconds: 30), (_) { if (mounted) yukle(sessiz: true); });
  }

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  Future<void> yukle({bool sessiz = false}) async {
    final auth = context.read<AuthProvider>();
    if (!sessiz) setState(() { _yukleniyor = true; _hata = null; });
    try {
      final r = await Api.isiHaritasi(auth.token!);
      if (!mounted) return;
      if (r['ok'] == 1) {
        List<Map<String, dynamic>> liste(String k) => ((r[k] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _alanlar = liste('alanlar');
        _masalar = liste('masalar');
        _garsonlar = liste('garsonlar');
        _plan = r['plan'] is Map ? Map<String, dynamic>.from(r['plan']) : {};
        _isi = r['isi'] is Map ? Map<String, dynamic>.from(r['isi']) : {};
        final ilk = _alanlar.isEmpty ? 0 : _i(_alanlar.first['id']);
        if (_alanlar.length < 2) {
          _alan = ilk;
        } else if (_alan != -1 && !_alanlar.any((a) => _i(a['id']) == _alan)) {
          _alan = -1;
        }
        if (_garson != 0 && !_garsonlar.any((g) => _i(g['id']) == _garson)) _garson = 0;
        _hata = null;
      } else if (!sessiz) {
        _hata = r['hata']?.toString() ?? 'Isı haritası alınamadı.';
      }
      setState(() => _yukleniyor = false);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() { _yukleniyor = false; if (!sessiz) _hata = 'Sunucuya ulaşılamadı.'; });
    }
  }

  // ---------------- veri ----------------
  // masa_id => {personel_id: işlem}. PHP yalnız 0..n anahtarlı diziyi JSON listesi yapar: indeks = personel id.
  int _sayi(int masaId, int gid) {
    final p = _isi[_pencere];
    final s = p is Map ? p['$masaId'] : null;
    if (s is Map) return gid != 0 ? _i(s['$gid']) : s.values.fold<int>(0, (a, v) => a + _i(v));
    if (s is List) return gid != 0 ? (gid < s.length ? _i(s[gid]) : 0) : s.fold<int>(0, (a, v) => a + _i(v));
    return 0;
  }

  Map<int, _Yuzde> _yuzdeler(int gid) {
    var mx = 0;
    final n = <int, int>{};
    for (final m in _masalar) { final id = _i(m['id']); n[id] = _sayi(id, gid); mx = math.max(mx, n[id]!); }
    return n.map((id, v) => MapEntry(id, _Yuzde(v, mx > 0 ? (v * 100 / mx).round() : 0)));
  }

  // Garsonun sorumlu masaları. Atama yoksa null: tüm masalara bakar, alan dışı hesaplanmaz.
  Set<int>? _kendi(int gid) {
    final g = _garsonlar.firstWhere((x) => _i(x['id']) == gid, orElse: () => <String, dynamic>{});
    final b = ((g['b'] as List?) ?? []).map(_i).toSet(), m = ((g['m'] as List?) ?? []).map(_i).toSet();
    if (b.isEmpty && m.isEmpty) return null;
    return _masalar.where((x) => b.contains(_i(x['b'])) || m.contains(_i(x['id']))).map((x) => _i(x['id'])).toSet();
  }

  _Uyum? _uyum(int gid) {
    final k = _kendi(gid);
    if (k == null) return null;
    final u = _Uyum();
    for (final m in _masalar) {
      final n = _sayi(_i(m['id']), gid);
      if (n == 0) continue;
      if (k.contains(_i(m['id']))) {
        u.ic += n;
      } else {
        u.dis += n;
        u.bolge[_i(m['b'])] = (u.bolge[_i(m['b'])] ?? 0) + n;
        u.liste.add(MapEntry(m, n));
      }
    }
    // Alan dışı işlem varsa %100 görünmesin
    if (u.top > 0) u.oran = u.dis > 0 ? math.min(99, (u.ic * 100 / u.top).round()) : 100;
    u.liste.sort((a, b) => b.value - a.value);
    return u;
  }

  String _alanAd(int id) => (_alanlar.firstWhere((a) => _i(a['id']) == id, orElse: () => {'ad': 'Bölgesiz'})['ad'] ?? '').toString();
  String _masaAd(Map<String, dynamic> m) { final a = m['ad']?.toString() ?? ''; return RegExp(r'^\d+$').hasMatch(a) ? 'Masa $a' : a; }
  // Harita etiketi: "Bahçe 3" gibi adlarda numara (bölge zaten belli, tam ad dokununca)
  String _masaEt(Map<String, dynamic> m) { final a = m['ad']?.toString() ?? ''; return RegExp(r'^\D*\s(\d+)$').firstMatch(a)?.group(1) ?? a; }
  Color _isiRenk(int p) => p >= 90 ? const Color(0xFFC026D3) : p >= 70 ? const Color(0xFFF97316) : p >= 40 ? const Color(0xFF6C8CF5) : const Color(0xFFC7D2FE);
  Color _uyumRenk(int p) => p >= 80 ? const Color(0xFF10B981) : p >= 50 ? const Color(0xFFF59E0B) : _kirmizi;

  // ---------------- plan (İşletme Düzeni ile aynı yerleşim) ----------------
  // Kayıtlı konumu olmayan masalar sıraya dizilir; alt ortadaki resepsiyon alanı boş bırakılır
  _Yerlesim _yerlesim(List<Map<String, dynamic>> list) {
    final n = list.length, c = math.max(2, math.sqrt(n * 1.8).ceil());
    final ayrilan = c.isOdd ? 1 : 2, r = math.max(1, ((n + ayrilan) / c).ceil());
    final ust = c * (r - 1), kalan = math.max(0, n - ust), solS = (kalan / 2).ceil(), sagS = kalan - solS;
    final xs = <double>[for (var i = 0; i < solS; i++) 60 + (i + .5) * 320 / solS, for (var i = 0; i < sagS; i++) 620 + (i + .5) * 320 / sagS];
    final rowH = 920 / r, colW = 880 / c, poz = <int, Offset>{};
    for (var k = 0; k < n; k++) {
      poz[_i(list[k]['id'])] = k < ust ? Offset(60 + ((k % c) + .5) * colW, 40 + ((k ~/ c) + .5) * rowH) : Offset(xs[k - ust], 40 + (r - .5) * rowH);
    }
    return _Yerlesim(poz, c, r);
  }

  Map<String, dynamic>? _planSatir(Map<String, dynamic> m) {
    final p = _plan['${m['id']}'];
    return p is Map && _i(p['b']) == _i(m['b']) ? Map<String, dynamic>.from(p) : null;
  }

  Map<String, dynamic> _alanMeta(int alan) {
    final a = _plan['_alan'];
    final v = a is Map ? a['$alan'] : null;
    return v is Map ? Map<String, dynamic>.from(v) : {};
  }

  void _bilgi(String s) {
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(s), duration: const Duration(seconds: 2)));
  }

  Widget _planCiz(int alan, int gid, {required bool mini}) {
    final list = _masalar.where((m) => _i(m['b']) == alan).toList();
    final yer = _yerlesim(list), y = _yuzdeler(gid), kendi = gid != 0 ? _kendi(gid) : null, meta = _alanMeta(alan);
    final oran = (meta['oran'] is num && (meta['oran'] as num) > 0) ? (meta['oran'] as num).toDouble() : 2.35;
    final kenar = mini ? 5.0 : 8.0;
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF6F0E7), border: Border.all(color: const Color(0xFFEADCC8), width: kenar), borderRadius: BorderRadius.circular(mini ? 12 : 16)),
      child: LayoutBuilder(builder: (ctx, c) {
        final w = c.maxWidth, h = math.max(w / oran, yer.r * (mini ? 78.0 : 110.0));
        final ts = [w * .12, w * .88 / yer.c * .66, h * .92 / yer.r * .9].reduce(math.min);
        final cocuk = <Widget>[Positioned.fill(child: CustomPaint(painter: _Izgara()))];
        for (final o in ((meta['dekor'] as List?) ?? [])) {
          if (o is! Map || !_noktalar.containsKey(o['t'])) continue;
          final d = _noktalar[o['t']]!, ad = (o['ad']?.toString() ?? '').isNotEmpty ? o['ad'].toString() : d[1] as String;
          cocuk.add(Positioned(left: _i(o['x']) / 1000 * w, top: _i(o['y']) / 1000 * h, child: FractionalTranslation(
            translation: const Offset(-.5, -.5),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: mini ? 5 : 8, vertical: mini ? 2 : 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFD7C3A8))),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(d[0] as IconData, size: mini ? 11 : 15, color: const Color(0xFF7C5536)),
                const SizedBox(width: 3),
                Text(ad, style: TextStyle(fontSize: mini ? 9.5 : 12, fontWeight: FontWeight.w700, color: const Color(0xFF4A3220))),
              ]),
            ),
          )));
        }
        for (final m in list) {
          final p = _planSatir(m), kay = p != null ? Offset(_i(p['x']).toDouble(), _i(p['y']).toDouble()) : yer.poz[_i(m['id'])]!;
          final alanDisi = kendi != null && !kendi.contains(_i(m['id']));
          final boy = (p?['boy'] is num) ? (p!['boy'] as num).toDouble() : 1.0;
          final kap = _i(m['kapasite']);
          final sekil = p?['sekil']?.toString() ?? (m['sekil'] == 'yuvarlak' || kap <= 2 ? 'yuvarlak' : (kap >= 5 ? 'uzun' : 'kare'));
          final mw = ts * (sekil == 'uzun' ? 1.5 : 1) * boy, mh = ts * boy;
          cocuk.add(Positioned(
            left: kay.dx / 1000 * w - mw / 2, top: kay.dy / 1000 * h - mh / 2, width: mw, height: mh,
            child: _masa(m, sekil, (p?['rot'] is num) ? (p!['rot'] as num).toDouble() : 0, kap, y[_i(m['id'])]!, alanDisi, ts * boy),
          ));
        }
        if (list.isEmpty) {
          cocuk.add(Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .92), borderRadius: BorderRadius.circular(10)),
            child: const Text('Bu alanda masa yok', style: TextStyle(color: Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600)),
          )));
        }
        return ClipRRect(borderRadius: BorderRadius.circular(mini ? 7 : 8), child: SizedBox(height: h, child: Stack(children: cocuk)));
      }),
    );
  }

  Widget _masa(Map<String, dynamic> m, String sekil, double rot, int kap, _Yuzde d, bool alanDisi, double ts) {
    final isik = alanDisi && d.n > 0 ? _kirmizi : _isiRenk(d.p);
    final sandalye = d.p >= 90 && !alanDisi ? const Color(0xFF6D28D9) : const Color(0xFF8A5429);
    final govde = LayoutBuilder(builder: (ctx, c) {
      final w = c.maxWidth, h = c.maxHeight, cw = ts * .2, chh = ts * .16;
      Widget san(double x, double y, double aci) => Positioned(left: x * w - cw / 2, top: y * h - chh / 2, width: cw, height: chh,
          child: Transform.rotate(angle: aci, child: DecoratedBox(decoration: BoxDecoration(color: sandalye, borderRadius: BorderRadius.circular(chh * .35)))));
      final s = <Widget>[];
      Rect tabla;
      if (sekil == 'yuvarlak') {
        final n = kap.clamp(2, 8), ofs = n == 2 ? 0.0 : 45.0;
        for (var i = 0; i < n; i++) {
          final a = (ofs + i * 360 / n) * math.pi / 180;
          s.add(san(.5 + math.sin(a) * .37, .5 - math.cos(a) * .37, a));
        }
        tabla = Rect.fromLTRB(.2, .2, .8, .8);
      } else if (sekil == 'uzun') {
        final yan = ((kap - 2) ~/ 2).clamp(1, 4);
        for (var i = 0; i < yan; i++) {
          final x = (58 + (i + .5) * 184 / yan) / 300;
          s..add(san(x, .15, 0))..add(san(x, .85, math.pi));
        }
        s..add(san(.1, .5, -math.pi / 2))..add(san(.9, .5, math.pi / 2));
        tabla = Rect.fromLTRB(.153, .24, .847, .76);
      } else {
        s..add(san(.15, .5, -math.pi / 2))..add(san(.85, .5, math.pi / 2));
        if (kap > 2) s..add(san(.5, .15, 0))..add(san(.5, .85, math.pi));
        tabla = Rect.fromLTRB(.23, .23, .77, .77);
      }
      final yuv = sekil == 'yuvarlak';
      s.add(Positioned(
        left: tabla.left * w, top: tabla.top * h, width: tabla.width * w, height: tabla.height * h,
        child: DecoratedBox(decoration: BoxDecoration(
          color: const Color(0xFFFFF9F0),
          shape: yuv ? BoxShape.circle : BoxShape.rectangle,
          borderRadius: yuv ? null : BorderRadius.circular(ts * .06),
          border: Border.all(color: const Color(0xFFD7A77B), width: math.max(1.5, ts * .03)),
          boxShadow: [BoxShadow(color: isik.withValues(alpha: d.n > 0 ? .85 : .45), blurRadius: ts * .3, spreadRadius: ts * (alanDisi && d.n > 0 ? .07 : .03))],
        )),
      ));
      return Stack(clipBehavior: Clip.none, children: s);
    });
    final et = Column(mainAxisSize: MainAxisSize.min, children: [
      Text(_masaEt(m), maxLines: 1, style: TextStyle(fontSize: math.max(10, ts * .2), height: 1.05, fontWeight: FontWeight.w800, color: const Color(0xFF1E1633))),
      Text('%${d.p}', style: TextStyle(fontSize: math.max(8, ts * .115), height: 1.1, fontWeight: FontWeight.w800, color: const Color(0xFF1E1633))),
    ]);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _bilgi('${_masaAd(m)}: ${d.n} işlem, %${d.p} yoğunluk${alanDisi ? ' · alan dışı' : ''}'),
      child: Opacity(
        opacity: alanDisi && d.n == 0 ? .32 : 1,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          Positioned.fill(child: Transform.rotate(angle: rot * math.pi / 180, child: govde)),
          et,
          if (alanDisi && d.n > 0)
            Positioned(top: -2, right: -2, child: Container(
              constraints: const BoxConstraints(minWidth: 19), height: 19, padding: const EdgeInsets.symmetric(horizontal: 4), alignment: Alignment.center,
              decoration: BoxDecoration(color: _kirmizi, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white, width: 2)),
              child: Text('${d.n}', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
            )),
        ]),
      ),
    );
  }

  // ---------------- arayüz ----------------
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final Widget icerik;
    if (_yukleniyor) {
      icerik = const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()));
    } else if (_hata != null) {
      icerik = Padding(padding: const EdgeInsets.all(20), child: Center(child: Column(children: [
        Text(_hata!, style: TextStyle(color: t.sub)),
        TextButton(onPressed: yukle, child: const Text('Tekrar dene')),
      ])));
    } else {
      icerik = _govde(t);
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(18), boxShadow: t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.local_fire_department_outlined, color: t.mor1, size: 22),
            const SizedBox(width: 6),
            Text('Isı Haritası', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w900)),
          ]),
          _secim(t, Icons.schedule, _pencere, {for (final p in _pencereler) p[0]: p[1]}, (v) => setState(() => _pencere = v)),
          _secim(t, Icons.person_outline, '$_garson', {'0': 'Tüm garsonlar', for (final g in _garsonlar) '${g['id']}': g['ad']?.toString() ?? ''},
              (v) => setState(() => _garson = int.parse(v))),
        ]),
        const SizedBox(height: 6),
        Text('Sipariş, servis ve hesap işlemlerinden hesaplanır; garsonun yürüdüğü yeri değil, işlem yaptığı masayı gösterir. Yüzde, seçilen aralıktaki en yoğun masaya göredir.',
            style: TextStyle(color: t.sub, fontSize: 11.5, height: 1.35)),
        const SizedBox(height: 10),
        icerik,
      ]),
    );
  }

  Widget _secim(TemaProvider t, IconData ikon, String deger, Map<String, String> secenek, ValueChanged<String> degisti) {
    return Container(
      height: 38,
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: t.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ikon, size: 18, color: t.sub2),
        const SizedBox(width: 4),
        DropdownButtonHideUnderline(child: DropdownButton<String>(
          value: secenek.containsKey(deger) ? deger : secenek.keys.first,
          dropdownColor: t.card, borderRadius: BorderRadius.circular(12),
          style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600),
          items: [for (final e in secenek.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) { if (v != null) degisti(v); },
        )),
      ]),
    );
  }

  Widget _govde(TemaProvider t) {
    final harita = _alan == -1 ? _salon(t) : _planCiz(_alan, _garson, mini: false);
    return LayoutBuilder(builder: (ctx, c) {
      final genis = c.maxWidth >= 900;
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (_alanlar.length >= 2) ...[_serit(t), const SizedBox(height: 10)],
        _uyumKart(t),
        if (genis)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: harita),
            const SizedBox(width: 16),
            SizedBox(width: 280, child: _yan(t)),
          ])
        else ...[harita, const SizedBox(height: 16), _yan(t)],
      ]);
    });
  }

  Widget _serit(TemaProvider t) {
    Widget cip(int id, String ad) {
      final secili = id == _alan;
      return Padding(padding: const EdgeInsets.only(right: 8), child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => setState(() => _alan = id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: secili ? t.mor1.withValues(alpha: .13) : t.card, borderRadius: BorderRadius.circular(999),
            border: Border.all(color: secili ? t.mor1 : t.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (id == -1) ...[Icon(Icons.dashboard_outlined, size: 16, color: t.mor1), const SizedBox(width: 5)],
            Text(ad, style: TextStyle(color: secili ? t.mor1 : t.ink, fontSize: 13, fontWeight: secili ? FontWeight.w700 : FontWeight.w600)),
          ]),
        ),
      ));
    }
    return SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: [
      cip(-1, 'Tüm Salon'),
      for (final a in _alanlar) cip(_i(a['id']), a['ad']?.toString() ?? ''),
    ]));
  }

  Widget _salon(TemaProvider t) {
    final kendi = _garson != 0 ? _kendi(_garson) : null, y = _yuzdeler(_garson);
    return LayoutBuilder(builder: (ctx, c) {
      final sutun = c.maxWidth >= 640 ? 2 : 1, kw = (c.maxWidth - 12 * (sutun - 1)) / sutun;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        for (final a in _alanlar) SizedBox(width: kw, child: _bolgeKart(t, _i(a['id']), a['ad']?.toString() ?? '', kendi, y)),
      ]);
    });
  }

  Widget _bolgeKart(TemaProvider t, int id, String ad, Set<int>? kendi, Map<int, _Yuzde> y) {
    final l = _masalar.where((m) => _i(m['b']) == id).toList();
    var top = 0, dis = 0, ks = 0;
    for (final m in l) {
      final n = y[_i(m['id'])]!.n;
      top += n;
      if (kendi != null) { if (kendi.contains(_i(m['id']))) { ks++; } else { dis += n; } }
    }
    Widget rozet(String s, Color r) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: r.withValues(alpha: .13), borderRadius: BorderRadius.circular(999)),
          child: Text(s, style: TextStyle(color: r, fontSize: 11, fontWeight: FontWeight.w700)),
        );
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.card, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ks > 0 ? t.mor1 : t.line, width: ks > 0 ? 2 : 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        InkWell(
          onTap: () => setState(() => _alan = id),
          child: Padding(padding: const EdgeInsets.fromLTRB(2, 2, 2, 8), child: Row(children: [
            Expanded(child: Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(ad, style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
              if (ks > 0) rozet(ks == l.length ? 'Kendi alanı' : 'Kendi alanı · $ks masa', t.mor1),
              if (dis > 0) rozet('$dis alan dışı', const Color(0xFFDC2626)),
            ])),
            Text('$top işlem', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            Icon(Icons.open_in_full, size: 15, color: t.mor1),
          ])),
        ),
        GestureDetector(onTap: () => setState(() => _alan = id), child: _planCiz(id, _garson, mini: true)),
      ]),
    );
  }

  Widget _uyumKart(TemaProvider t) {
    if (_garson == 0) return const SizedBox.shrink();
    final g = _garsonlar.firstWhere((x) => _i(x['id']) == _garson, orElse: () => <String, dynamic>{});
    final ad = g['ad']?.toString() ?? 'Bu garson', u = _uyum(_garson);
    Widget kutu(List<Widget> c) => Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
          child: Row(children: c),
        );
    if (u == null) {
      return kutu([
        Icon(Icons.info_outline, color: t.mor1),
        const SizedBox(width: 10),
        Expanded(child: Text('$ad için alan atanmamış. Alan atanınca kendi alanı ve alan dışı işlemleri burada görünür.',
            style: TextStyle(color: t.ink, fontSize: 13, height: 1.35))),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: t.mor1, visualDensity: VisualDensity.compact),
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MasaAtamaScreen()));
            if (mounted) yukle(sessiz: true);
          },
          child: const Text('Alan Ata'),
        ),
      ]);
    }
    if (u.top == 0) {
      return kutu([
        Icon(Icons.info_outline, color: t.mor1),
        const SizedBox(width: 10),
        Expanded(child: Text('$ad seçilen aralıkta işlem yapmamış.', style: TextStyle(color: t.ink, fontSize: 13))),
      ]);
    }
    final oran = u.oran!, renk = _uyumRenk(oran);
    final bolge = (u.bolge.keys.toList()..sort((a, b) => u.bolge[b]! - u.bolge[a]!)).map((b) => '${_alanAd(b)}: ${u.bolge[b]}').join(', ');
    Widget ef(Color c, String s) => Padding(padding: const EdgeInsets.only(top: 4), child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 11, height: 11, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(s, style: TextStyle(color: t.sub, fontSize: 11.5, fontWeight: FontWeight.w600)),
        ]));
    return kutu([
      Text('%$oran', style: TextStyle(color: renk, fontSize: 30, fontWeight: FontWeight.w800, height: 1)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text("$ad işlemlerinin %$oran'i kendi alanında", style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text('${u.ic} işlem kendi alanında, ${u.dis} işlem alan dışında${bolge.isNotEmpty ? ' ($bolge)' : ''}',
            style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 6),
        ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(
          value: oran / 100, minHeight: 8, color: renk, backgroundColor: t.mor1.withValues(alpha: .12))),
        Wrap(spacing: 14, children: [ef(_kirmizi, 'Alan dışı işlem'), ef(t.sub2.withValues(alpha: .45), 'Alan dışı, işlem yok')]),
      ])),
    ]);
  }

  Widget _cubukSatir(TemaProvider t, String ad, double oran, Color renk, String sag, {VoidCallback? onTap, String? ipucu}) {
    final satir = Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2), child: Row(children: [
      SizedBox(width: 92, child: Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w700))),
      const SizedBox(width: 8),
      Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(
          value: oran.clamp(0, 1).toDouble(), minHeight: 9, color: renk, backgroundColor: t.mor1.withValues(alpha: .12)))),
      SizedBox(width: 42, child: Text(sag, textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w700))),
    ]));
    final w = onTap == null ? satir : InkWell(borderRadius: BorderRadius.circular(8), onTap: onTap, child: satir);
    return ipucu == null ? w : Tooltip(message: ipucu, child: w);
  }

  Widget _yan(TemaProvider t) {
    Widget bas(IconData ik, String s) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Row(children: [
          Icon(ik, size: 18, color: t.mor1),
          const SizedBox(width: 5),
          Text(s, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ]));
    final c = <Widget>[];
    if (_garson == 0) {
      final sat = _garsonlar.map((g) => MapEntry(g, _uyum(_i(g['id']))?.oran)).toList()
        ..sort((a, b) => (a.value ?? 999) - (b.value ?? 999));
      c.add(bas(Icons.verified_outlined, 'Alan Uyumu'));
      if (sat.isEmpty) {
        c.add(Text('Aktif garson yok.', style: TextStyle(color: t.sub, fontSize: 12.5)));
      } else {
        for (final s in sat) {
          final o = s.value;
          c.add(_cubukSatir(t, s.key['ad']?.toString() ?? '', (o ?? 0) / 100, _uyumRenk(o ?? 0), o == null ? '—' : '%$o',
              ipucu: o == null ? 'Alan atanmamış ya da bu aralıkta işlem yok' : "İşlemlerinin %$o'i kendi alanında",
              onTap: () => setState(() => _garson = _i(s.key['id']))));
        }
        c.add(Padding(padding: const EdgeInsets.only(top: 4), child: Text('— : alan atanmamış ya da bu aralıkta işlem yok.', style: TextStyle(color: t.sub, fontSize: 11))));
      }
      c.add(const SizedBox(height: 16));
    } else {
      final u = _uyum(_garson);
      if (u != null && u.liste.isNotEmpty) {
        final mx = u.liste.first.value;
        c.add(bas(Icons.warning_amber_rounded, 'Alan Dışı Masalar'));
        for (final x in u.liste.take(8)) {
          c.add(_cubukSatir(t, _masaAd(x.key), x.value / mx, _kirmizi, '${x.value}'));
        }
        c.add(const SizedBox(height: 16));
      }
    }
    final y = _yuzdeler(_garson);
    final l = _masalar.where((m) => y[_i(m['id'])]!.n > 0).toList()..sort((a, b) => y[_i(b['id'])]!.n - y[_i(a['id'])]!.n);
    c.add(bas(Icons.format_list_numbered, 'En Yoğun Masalar'));
    if (l.isEmpty) {
      c.add(Text('Bu aralıkta işlem yok.', style: TextStyle(color: t.sub, fontSize: 12.5)));
    } else {
      for (final m in l.take(8)) {
        final d = y[_i(m['id'])]!;
        c.add(_cubukSatir(t, _masaAd(m), d.p / 100, _isiRenk(d.p), '${d.n}'));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: c);
  }
}

// Plan zemini: İşletme Düzeni'ndeki ızgara (yatay 8, dikey 4 bölme)
class _Izgara extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()..color = const Color(0x29967A5C)..strokeWidth = 1;
    for (var i = 1; i < 8; i++) { final x = s.width * i / 8; canvas.drawLine(Offset(x, 0), Offset(x, s.height), p); }
    for (var i = 1; i < 4; i++) { final y = s.height * i / 4; canvas.drawLine(Offset(0, y), Offset(s.width, y), p); }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

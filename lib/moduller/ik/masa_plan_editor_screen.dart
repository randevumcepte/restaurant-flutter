import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';

/// Web İşletme Düzeni > Masa Planı düzenleyicisi (sürükle-bırak): masaları alanda sürükle, şekil/boy/açı ver, Kaydet.
/// Aynı uca (/isletme-duzeni/plan-kaydet) aynı biçimde yazar → Salon Şeması ve POS masa haritası da güncellenir.
/// Alan koordinatı 0..1000 (yatay ve dikey ayrı ölçek), en/boy oranı alanın `oran`ı (web ile aynı).
class MasaPlanEditorScreen extends StatefulWidget {
  final Map<String, dynamic> veri; // /isletme-duzeni köprü verisi: bolgeler, masalar, plan
  final int ilkAlan;
  const MasaPlanEditorScreen({super.key, required this.veri, this.ilkAlan = 0});
  @override
  State<MasaPlanEditorScreen> createState() => _MasaPlanEditorScreenState();
}

class _MasaPlanEditorScreenState extends State<MasaPlanEditorScreen> {
  late final List<Map<String, dynamic>> _bolgeler = liste(widget.veri['bolgeler']);
  late final List<Map<String, dynamic>> _masalar = liste(widget.veri['masalar']);
  final Map<int, Map<String, dynamic>> _poz = {}; // masaId → {x,y,sekil,boy,rot}
  final Map<int, Map<String, dynamic>> _alanMeta = {}; // bolgeId → {oran, dekor}
  final Set<int> _kirli = {};
  final List<String> _gecmis = [];
  late int _alan;
  int? _secili;
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    final plan = harita(widget.veri['plan']);
    final meta = harita(plan['_alan']);
    for (final b in [0, ..._bolgeler.map((b) => tamOku(b['id']))]) {
      final a = harita(meta['$b']);
      _alanMeta[b] = {'oran': sayiOku(a['oran']) > 0 ? sayiOku(a['oran']).toDouble() : 2.35, 'dekor': dizi(a['dekor'])};
    }
    final alanlar = _alanIdleri();
    _alan = alanlar.contains(widget.ilkAlan) ? widget.ilkAlan : (alanlar.isEmpty ? 0 : alanlar.first);
    for (final b in alanlar) {
      final ms = _alanMasalari(b);
      var bos = 0;
      for (final m in ms) {
        final id = tamOku(m['id']);
        final p = harita(plan['$id']);
        if (p.isNotEmpty && tamOku(p['b']) == b) {
          _poz[id] = {'x': sayiOku(p['x']).toDouble(), 'y': sayiOku(p['y']).toDouble(), if (p['sekil'] != null) 'sekil': p['sekil'], if (p['boy'] != null) 'boy': sayiOku(p['boy']).toDouble(), if (p['rot'] != null) 'rot': tamOku(p['rot'])};
        } else {
          // Planda yeri olmayan masa: web'deki otomatik yerleşim gibi düzgün ızgaraya dizilir (kaydedilince sabitlenir)
          final sutun = (ms.length <= 4 ? ms.length : (ms.length <= 12 ? 4 : 6)).clamp(1, 6);
          final satir = (ms.length / sutun).ceil().clamp(1, 99);
          final i = bos++;
          _poz[id] = {'x': (i % sutun + .5) * 1000 / sutun, 'y': (i ~/ sutun + .5) * 1000 / satir, 'sekil': m['sekil']};
        }
      }
    }
  }

  List<int> _alanIdleri() {
    final ids = _bolgeler.map((b) => tamOku(b['id'])).toList();
    if (_masalar.any((m) => tamOku(m['bolge_id']) == 0)) ids.insert(0, 0);
    return ids;
  }

  List<Map<String, dynamic>> _alanMasalari(int b) => _masalar.where((m) => tamOku(m['bolge_id']) == b && tamOku(m['arsiv']) == 0).toList();

  String _alanAd(int b) => b == 0 ? 'Bölgesiz' : metinOku(_bolgeler.firstWhere((x) => tamOku(x['id']) == b, orElse: () => {})['ad'], 'Alan');

  void _yedek() {
    _gecmis.add(Uri(queryParameters: {for (final e in _poz.entries) '${e.key}': '${e.value['x']},${e.value['y']},${e.value['sekil'] ?? ''},${e.value['boy'] ?? ''},${e.value['rot'] ?? ''}'}).query);
    if (_gecmis.length > 40) _gecmis.removeAt(0);
  }

  void _geriAl() {
    if (_gecmis.isEmpty) return;
    final q = Uri.splitQueryString(_gecmis.removeLast());
    setState(() {
      q.forEach((k, v) {
        final p = v.split(',');
        _poz[int.parse(k)] = {
          'x': double.parse(p[0]),
          'y': double.parse(p[1]),
          if (p[2].isNotEmpty) 'sekil': p[2],
          if (p[3].isNotEmpty) 'boy': double.parse(p[3]),
          if (p[4].isNotEmpty) 'rot': int.parse(p[4]),
        };
      });
    });
  }

  void _degis(int masaId, void Function(Map<String, dynamic> p) f) {
    setState(() {
      f(_poz[masaId]!);
      _kirli.add(_alan);
    });
  }

  Future<void> _kaydet() async {
    if (_kirli.isEmpty) {
      Navigator.pop(context, false);
      return;
    }
    setState(() => _mesgul = true);
    final alanlar = <String, dynamic>{};
    for (final b in _kirli) {
      alanlar['$b'] = {
        'oran': _alanMeta[b]!['oran'],
        'konumlar': {
          for (final m in _alanMasalari(b))
            '${tamOku(m['id'])}': {
              'x': (_poz[tamOku(m['id'])]!['x'] as num).round(),
              'y': (_poz[tamOku(m['id'])]!['y'] as num).round(),
              if (_poz[tamOku(m['id'])]!['sekil'] != null) 'sekil': _poz[tamOku(m['id'])]!['sekil'],
              if (_poz[tamOku(m['id'])]!['boy'] != null) 'boy': _poz[tamOku(m['id'])]!['boy'],
              if (_poz[tamOku(m['id'])]!['rot'] != null) 'rot': _poz[tamOku(m['id'])]!['rot'],
            },
        },
        // Dekor (bar, kapı, WC…) ve Salon Şeması noktaları olduğu gibi geri gider: silinmez
        'objeler': _alanMeta[b]!['dekor'],
      };
    }
    final ok = await kopruGonder(context, '/isletme-duzeni/plan-kaydet', {'alanlar': alanlar}, json: true, basariMesaji: 'Masa planı kaydedildi, Salon Şeması da güncellendi.');
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<bool> _cikisOnay() async {
    if (_kirli.isEmpty) return true;
    return kOnay(context, 'Kaydedilmemiş değişiklikler var. Çıkılsın mı?', tehlikeli: true, evet: 'Kaydetmeden çık');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final alanlar = _alanIdleri();
    final ms = _alanMasalari(_alan);
    final oran = (_alanMeta[_alan]?['oran'] as num? ?? 2.35).toDouble();
    final secili = _secili == null ? null : _masalar.firstWhere((m) => tamOku(m['id']) == _secili, orElse: () => {});

    return PopScope(
      canPop: _kirli.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _cikisOnay() && context.mounted) Navigator.pop(context, false);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          backgroundColor: t.card,
          foregroundColor: t.ink,
          title: const Text('Masa Planını Düzenle'),
          actions: [
            IconButton(tooltip: 'Geri al', onPressed: _gecmis.isEmpty ? null : _geriAl, icon: const Icon(Icons.undo)),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: KButon(_kirli.isEmpty ? 'Kapat' : 'Kaydet', ikon: Icons.save_outlined, yukleniyor: _mesgul, onTap: _kaydet),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            if (alanlar.length > 1)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                child: Row(children: [
                  for (final b in alanlar)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: b == _alan,
                        showCheckmark: false,
                        selectedColor: t.mor1,
                        backgroundColor: t.card,
                        side: BorderSide(color: b == _alan ? t.mor1 : t.line),
                        label: Text('${_alanAd(b)} (${_alanMasalari(b).length})${_kirli.contains(b) ? ' •' : ''}',
                            style: TextStyle(color: b == _alan ? Colors.white : t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
                        onSelected: (_) => setState(() {
                          _alan = b;
                          _secili = null;
                        }),
                      ),
                    ),
                ]),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Text(ms.isEmpty ? 'Bu alanda masa yok.' : 'Masayı sürükleyerek taşıyın; dokunarak seçin ve şeklini, boyunu, açısını değiştirin.',
                  style: TextStyle(color: t.sub, fontSize: 12.5)),
            ),
            Expanded(
              child: LayoutBuilder(builder: (c, k) {
                // Alan web ile aynı en/boy oranında; dar ekranda yatay kaydırılır, yükseklik ekrana sığar
                final yuk = (k.maxHeight - 16).clamp(200.0, 2000.0);
                var gen = yuk * oran;
                if (gen < k.maxWidth - 24) gen = k.maxWidth - 24;
                final h = gen / oran;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: SizedBox(width: gen, height: h, child: _alanCiz(t, ms, gen, h)),
                );
              }),
            ),
            if (secili != null && secili.isNotEmpty) _ozellik(t, secili),
          ]),
        ),
      ),
    );
  }

  Widget _alanCiz(TemaProvider t, List<Map<String, dynamic>> ms, double w, double h) {
    final dekor = dizi(_alanMeta[_alan]?['dekor']).whereType<Map>().toList();
    final taban = (h / 7).clamp(34.0, 84.0); // 1x masanın kenarı
    return GestureDetector(
      onTap: () => setState(() => _secili = null),
      child: Container(
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: t.line, width: 1.5),
        ),
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: CustomPaint(painter: _Izgara(t.line.withValues(alpha: .5)))),
          // Dekor ve şema noktaları: yalnız gösterilir (düzenlemesi webde), kayıtta korunur
          for (final d in dekor)
            Positioned(
              left: sayiOku(d['x']) / 1000 * w - 22,
              top: sayiOku(d['y']) / 1000 * h - 11,
              child: IgnorePointer(
                child: Container(
                  constraints: const BoxConstraints(minWidth: 44),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.line)),
                  child: Text(metinOku(d['ad'], metinOku(d['t'])), textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 10.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          for (final m in ms) _masa(t, m, w, h, taban),
        ]),
      ),
    );
  }

  Widget _masa(TemaProvider t, Map<String, dynamic> m, double w, double h, double taban) {
    final id = tamOku(m['id']);
    final p = _poz[id]!;
    final sekil = metinOku(p['sekil'], metinOku(m['sekil'], 'kare'));
    final boy = (p['boy'] as num? ?? 1).toDouble();
    final rot = (p['rot'] as num? ?? 0).toInt();
    final mw = taban * boy * (sekil == 'uzun' ? 1.8 : 1);
    final mh = taban * boy;
    final sec = _secili == id;
    final dolu = ['dolu', 'birlesik'].contains(metinOku(m['durum']));
    return Positioned(
      left: (p['x'] as num) / 1000 * w - mw / 2,
      top: (p['y'] as num) / 1000 * h - mh / 2,
      child: GestureDetector(
        onTap: () => setState(() => _secili = id),
        onPanStart: (_) {
          _yedek();
          setState(() => _secili = id);
        },
        onPanUpdate: (d) => _degis(id, (p) {
          p['x'] = ((p['x'] as num) + d.delta.dx / w * 1000).clamp(15.0, 985.0);
          p['y'] = ((p['y'] as num) + d.delta.dy / h * 1000).clamp(15.0, 985.0);
        }),
        onPanEnd: (_) => _degis(id, (p) {
          // 5'lik ızgaraya otur (web ile aynı düzgün hizalama)
          p['x'] = ((p['x'] as num) / 5).round() * 5.0;
          p['y'] = ((p['y'] as num) / 5).round() * 5.0;
        }),
        child: Transform.rotate(
          angle: rot * 3.14159265 / 180,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: mw,
            height: mh,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: dolu ? t.amber.withValues(alpha: .16) : t.mor1.withValues(alpha: .10),
              borderRadius: sekil == 'yuvarlak' ? BorderRadius.circular(mh) : BorderRadius.circular(10),
              border: Border.all(color: sec ? t.mor1 : (dolu ? t.amber : t.mor1.withValues(alpha: .45)), width: sec ? 2.5 : 1.5),
              boxShadow: sec ? [BoxShadow(color: t.mor1.withValues(alpha: .3), blurRadius: 14)] : null,
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: FittedBox(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(metinOku(m['ad']), style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
                  Text('${tamOku(m['kapasite'])} kişi', style: TextStyle(color: t.sub, fontSize: 10.5)),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ozellik(TemaProvider t, Map<String, dynamic> m) {
    final id = tamOku(m['id']);
    final p = _poz[id]!;
    final sekil = metinOku(p['sekil'], metinOku(m['sekil'], 'kare'));
    final boy = (p['boy'] as num? ?? 1).toDouble();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(metinOku(m['ad']), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700))),
          IconButton(
            tooltip: '90° döndür',
            onPressed: () {
              _yedek();
              _degis(id, (p) => p['rot'] = (((p['rot'] as num?) ?? 0).toInt() + 90) % 360);
            },
            icon: Icon(Icons.rotate_right, color: t.mor1),
          ),
        ]),
        Wrap(spacing: 8, children: [
          for (final s in const [('kare', 'Kare', Icons.crop_square), ('yuvarlak', 'Yuvarlak', Icons.circle_outlined), ('uzun', 'Uzun', Icons.rectangle_outlined)])
            ChoiceChip(
              selected: sekil == s.$1,
              showCheckmark: false,
              selectedColor: t.mor1,
              backgroundColor: t.card2,
              avatar: Icon(s.$3, size: 18, color: sekil == s.$1 ? Colors.white : t.sub),
              label: Text(s.$2, style: TextStyle(color: sekil == s.$1 ? Colors.white : t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
              onSelected: (_) {
                _yedek();
                _degis(id, (p) => p['sekil'] = s.$1);
              },
            ),
        ]),
        Row(children: [
          Text('Boy', style: TextStyle(color: t.sub, fontSize: 13, fontWeight: FontWeight.w600)),
          Expanded(
            child: Slider(
              value: boy.clamp(.5, 2),
              min: .5,
              max: 2,
              divisions: 15,
              label: '${(boy * 100).round()}%',
              activeColor: t.mor1,
              onChangeStart: (_) => _yedek(),
              onChanged: (d) => _degis(id, (p) => p['boy'] = double.parse(d.toStringAsFixed(1))),
            ),
          ),
          Text('${(boy * 100).round()}%', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }
}

class _Izgara extends CustomPainter {
  final Color renk;
  _Izgara(this.renk);
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = renk
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      c.drawLine(Offset(s.width * i / 10, 0), Offset(s.width * i / 10, s.height), p);
      c.drawLine(Offset(0, s.height * i / 10), Offset(s.width, s.height * i / 10), p);
    }
  }

  @override
  bool shouldRepaint(_Izgara o) => o.renk != renk;
}

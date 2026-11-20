import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import '../ai/ortak.dart';
import '../satinalma/ortak.dart';

/// Web Barkod & Etiket > Ürün Etiketi > "Kendi tasarımım": etiket tasarımı (arka plan resmi) yükle,
/// SKT / parti / barkod… kutularını üstüne sürükle, boyutlandır, yazı boyu/kalın/hiza ver, ürüne bağla.
/// Uçlar web ile aynı: /barkod-etiket/sablon | sablon-ornek | sablon-bagla | sablon-sil. Kutu konumları etiketin %'si.
const kEtiketAlanlar = <String, String>{
  'ad': 'Ürün adı', 'fiyat': 'Fiyat', 'birim_fiyat': 'Birim fiyat', 'net': 'Net miktar', 'uretim': 'Üretim tarihi', 'skt': 'Son tüketim (SKT)',
  'parti': 'Parti no', 'barkod': 'Barkod', 'icindekiler': 'İçindekiler', 'alerjen': 'Alerjen', 'saklama': 'Saklama koşulu', 'uretici': 'Üretici',
  'uretim_yeri': 'Üretim yeri', 'serbest': 'Serbest yazı',
};

List<Map<String, dynamic>> _alanlarOku(dynamic v) {
  dynamic d = v;
  if (v is String) {
    try {
      d = jsonDecode(v);
    } catch (_) {
      d = const [];
    }
  }
  return liste(d).map((a) => Map<String, dynamic>.from(a)).toList();
}

class EtiketSablonScreen extends StatefulWidget {
  const EtiketSablonScreen({super.key});
  @override
  State<EtiketSablonScreen> createState() => _EtiketSablonScreenState();
}

class _EtiketSablonScreenState extends State<EtiketSablonScreen> {
  final _k = GlobalKey<KopruEkranState>();

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/barkod-etiket/urun-etiketi',
      baslik: 'Etiket Tasarımlarım',
      ikon: Icons.design_services_outlined,
      govde: (c, v, yenile) => _govde(c, v, yenile),
    );
  }

  Widget _govde(BuildContext c, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = c.watch<TemaProvider>();
    final sablonlar = liste(v['sablonlar']);
    final duzenler = v['duzenler'] == true;
    final urunler = liste(v['liste']).where((u) => metinOku(u['turler']).split(',').contains('paket')).toList();
    return KGovde(yenile: yenile, children: [
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Kendi etiket tasarımınız', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Grafikerin hazırladığı etiketi resim olarak yükleyin; SKT, parti, barkod gibi değişen bilgilerin kutularını tasarımdaki boş yerlere sürükleyin. '
              'Ürüne bağlayınca her basımda bu kutular o günün bilgisiyle dolar.',
              style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4)),
          if (duzenler) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              KButon('Tasarım yükle', ikon: Icons.upload_outlined, onTap: () => _yeni(c)),
              KButon('Örnek tasarımla dene', ikon: Icons.auto_awesome_outlined, ikincil: true, onTap: () async {
                if (await kopruGonder(c, '/barkod-etiket/sablon-ornek', {})) yenile();
              }),
            ]),
          ],
        ]),
      ),
      if (sablonlar.isEmpty)
        const KBos(ikon: Icons.design_services_outlined, baslik: 'Henüz tasarım yok', aciklama: 'Bir etiket resmi yükleyin ya da örnek tasarımla deneyin.')
      else
        AiIzgara(minGenislik: 300, cocuklar: [
          for (final s in sablonlar)
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(metinOku(s['ad']), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700))),
                  KRozet('${sayiYaz(s['gen_mm'])} × ${sayiYaz(s['yuk_mm'])} mm', renk: t.sub2),
                ]),
                const SizedBox(height: 10),
                _EtiketOnizleme(sablon: s, alanlar: _alanlarOku(s['alanlar'])),
                const SizedBox(height: 6),
                Text('Bağlı ürün: ${urunler.where((u) => tamOku(u['sablon_id']) == tamOku(s['id'])).map((u) => metinOku(u['ad'])).join(', ').ifEmpty('yok')}',
                    style: TextStyle(color: t.sub, fontSize: 12)),
                if (duzenler) ...[
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    KButon('Yerleşimi düzenle', ikon: Icons.open_with, onTap: () async {
                      final k = await Navigator.of(c).push<bool>(MaterialPageRoute(builder: (_) => EtiketSablonEditor(sablon: s)));
                      if (k == true) yenile();
                    }),
                    KButon('Ürüne bağla', ikon: Icons.link, ikincil: true, onTap: () => _bagla(c, s, urunler, yenile)),
                    KButon('Sil', ikon: Icons.delete_outline, renk: t.kirmizi, ikincil: true, onTap: () async {
                      if (!await kOnay(c, '"${metinOku(s['ad'])}" tasarımı silinsin mi? Bağlı ürünler standart etikete döner.', tehlikeli: true, evet: 'Sil')) return;
                      if (c.mounted && await kopruGonder(c, '/barkod-etiket/sablon-sil', {'id': '${s['id']}'})) yenile();
                    }),
                  ]),
                ],
              ]),
            ),
        ]),
      KKart(
        child: Row(children: [
          Icon(Icons.print_outlined, color: t.mavi, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text('Tasarımlı etiket, Etiket Bas sekmesinde "Kendi tasarımım" seçilerek basılır.', style: TextStyle(color: t.sub2, fontSize: 12.5))),
        ]),
      ),
    ]);
  }

  Future<void> _yeni(BuildContext c) async {
    final t = c.read<TemaProvider>();
    final adK = TextEditingController(), genK = TextEditingController(text: '58'), yukK = TextEditingController(text: '40');
    PlatformFile? dosya;
    final tamam = await kAltSayfa<bool>(c, baslik: 'Tasarım yükle', icerik: (s) => StatefulBuilder(builder: (s, ss) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Tasarım adı', adK, ipucu: 'ör. Nar Ekşisi 500 ml'),
            Row(children: [
              Expanded(child: KAlan('Genişlik (mm)', genK, klavye: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: KAlan('Yükseklik (mm)', yukK, klavye: TextInputType.number)),
            ]),
            const SizedBox(height: 6),
            KSatir(
              solIkon: KIkon(Icons.image_outlined, renk: t.mor1),
              baslik: dosya == null ? 'Etiket resmini seç' : dosya!.name,
              alt: 'PNG, JPG ya da WEBP · en çok 4 MB (PDF ise önce resim olarak kaydedin)',
              onTap: () async {
                final r = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'], withData: true);
                if (r?.files.firstOrNull?.bytes != null) ss(() => dosya = r!.files.first);
              },
            ),
            const SizedBox(height: 12),
            KButon('Yükle ve kutuları yerleştir', ikon: Icons.upload, genis: true, onTap: () {
              if (dosya == null) return kToast(s, 'Etiket resmini seçin.', hata: true);
              Navigator.pop(s, true);
            }),
          ]);
        }));
    if (tamam != true || dosya == null || !c.mounted) return;
    final onceki = liste(_k.currentState?.veri?['sablonlar']).map((x) => tamOku(x['id'])).toSet();
    final cvp = await saDosyaYukle(c, '/barkod-etiket/sablon', [('arka', dosya!.name, dosya!.bytes!)],
        alanlar: {'ad': adK.text.trim(), 'gen_mm': genK.text.trim(), 'yuk_mm': yukK.text.trim()});
    if (!c.mounted || cvp == null) return;
    if (!cvp.ok) return kToast(c, metinOku(cvp.j['hata'], 'Yüklenemedi.'), hata: true);
    kToast(c, 'Tasarım yüklendi. Şimdi kutuları tasarımdaki boş yerlere sürükleyin.');
    await _k.currentState?.yukle();
    // Yeni tasarımı doğrudan düzenleyicide aç (köprü yönlendirmesi sorgusuz gelir: listede yeni çıkan kayıt)
    final s = liste(_k.currentState?.veri?['sablonlar']).where((x) => !onceki.contains(tamOku(x['id']))).firstOrNull;
    if (s != null && c.mounted) {
      final k = await Navigator.of(c).push<bool>(MaterialPageRoute(builder: (_) => EtiketSablonEditor(sablon: s)));
      if (k == true) _k.currentState?.yukle();
    }
  }

  Future<void> _bagla(BuildContext c, Map<String, dynamic> s, List<Map<String, dynamic>> urunler, Future<void> Function() yenile) async {
    final t = c.read<TemaProvider>();
    if (urunler.isEmpty) return kToast(c, '"Paketli ürün etiketi" seçili ürün yok. Ürünler sekmesinde ürünün etiket türünü seçin.', hata: true);
    final uid = await kAltSayfa<int>(c, baslik: '"${metinOku(s['ad'])}" hangi ürüne?', icerik: (ss) => Column(children: [
          for (final u in urunler)
            KSatir(
              solIkon: KIkon(Icons.inventory_2_outlined, renk: t.mor1),
              baslik: metinOku(u['ad']),
              alt: tamOku(u['sablon_id']) == tamOku(s['id']) ? 'Bu tasarım bağlı' : (u['sablon_id'] != null ? 'Başka tasarım bağlı (değişir)' : null),
              onTap: () => Navigator.pop(ss, tamOku(u['id'])),
            ),
        ]));
    if (uid == null || !c.mounted) return;
    if (await kopruGonder(c, '/barkod-etiket/sablon-bagla', {'sablon_id': '${s['id']}', 'eu_id': '$uid'})) yenile();
  }
}

extension on String {
  String ifEmpty(String y) => isEmpty ? y : this;
}

/// Etiket önizlemesi: arka plan resmi + kutular (etiketin %'si ile konumlu)
class _EtiketOnizleme extends StatelessWidget {
  final Map<String, dynamic> sablon;
  final List<Map<String, dynamic>> alanlar;
  const _EtiketOnizleme({required this.sablon, required this.alanlar});
  @override
  Widget build(BuildContext context) {
    final gen = sayiOku(sablon['gen_mm']).toDouble().clamp(10, 400);
    final yuk = sayiOku(sablon['yuk_mm']).toDouble().clamp(10, 400);
    return AspectRatio(
      aspectRatio: gen / yuk,
      child: LayoutBuilder(builder: (c, k) => _EtiketZemin(sablon: sablon, w: k.maxWidth, h: k.maxHeight, alanlar: alanlar, mmPx: k.maxWidth / gen)),
    );
  }
}

class _EtiketZemin extends StatelessWidget {
  final Map<String, dynamic> sablon;
  final double w, h, mmPx;
  final List<Map<String, dynamic>> alanlar;
  final int? secili;
  final Widget Function(int i, Widget kutu)? sar;
  const _EtiketZemin({required this.sablon, required this.w, required this.h, required this.alanlar, required this.mmPx, this.secili, this.sar});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final arka = metinOku(sablon['arka']);
    final resim = arka.isNotEmpty && !arka.toLowerCase().endsWith('.svg');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: t.line), boxShadow: t.golge),
      child: Stack(children: [
        if (resim)
          Positioned.fill(child: Image.network(tamAdres(arka), fit: BoxFit.fill, errorBuilder: (_, _, _) => const SizedBox()))
        else
          Positioned.fill(
            child: Container(
              color: const Color(0xFFF8F5EF),
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.only(top: 8),
              child: Text(arka.isEmpty ? '' : 'Örnek tasarım', style: const TextStyle(color: Color(0xFFB45309), fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        for (var i = 0; i < alanlar.length; i++) _kutu(t, i),
      ]),
    );
  }

  Widget _kutu(TemaProvider t, int i) {
    final a = alanlar[i];
    final k = metinOku(a['k']);
    final hz = metinOku(a['hz'], 'l');
    final sec = secili == i;
    final ornek = k == 'serbest' ? metinOku(a['t'], 'Yazı') : (k == 'barkod' ? '▌▌▌▌ ▌▌ ▌▌▌' : (kEtiketAlanlar[k] ?? k));
    final kutu = Container(
      width: sayiOku(a['w']) / 100 * w,
      height: sayiOku(a['h']) / 100 * h,
      alignment: hz == 'c' ? Alignment.center : (hz == 'r' ? Alignment.centerRight : Alignment.centerLeft),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: (sec ? t.mor1 : const Color(0xFF6366F1)).withValues(alpha: sec ? .18 : .08),
        border: Border.all(color: sec ? t.mor1 : const Color(0xFF6366F1).withValues(alpha: .6), width: sec ? 2 : 1),
      ),
      child: Text(ornek,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(color: Colors.black87, fontSize: (sayiOku(a['fs']) * .3528 * mmPx).clamp(5, 60).toDouble(), fontWeight: tamOku(a['b']) == 1 ? FontWeight.w700 : FontWeight.w400)),
    );
    return Positioned(left: sayiOku(a['x']) / 100 * w, top: sayiOku(a['y']) / 100 * h, child: sar == null ? kutu : sar!(i, kutu));
  }
}

/// Yerleşim düzenleyici: kutuyu sürükle (taşı), sağ alt tutamaçla boyutlandır, dokununca özellikleri
class EtiketSablonEditor extends StatefulWidget {
  final Map<String, dynamic> sablon;
  const EtiketSablonEditor({super.key, required this.sablon});
  @override
  State<EtiketSablonEditor> createState() => _EtiketSablonEditorState();
}

class _EtiketSablonEditorState extends State<EtiketSablonEditor> {
  late final List<Map<String, dynamic>> _alanlar = _alanlarOku(widget.sablon['alanlar']);
  late final _adK = TextEditingController(text: metinOku(widget.sablon['ad']));
  late final _tK = TextEditingController();
  int? _sec;
  bool _kirli = false, _mesgul = false;

  double get _gen => sayiOku(widget.sablon['gen_mm']).toDouble().clamp(10, 400);
  double get _yuk => sayiOku(widget.sablon['yuk_mm']).toDouble().clamp(10, 400);

  void _degis(VoidCallback f) => setState(() {
        f();
        _kirli = true;
      });

  Future<void> _kaydet() async {
    setState(() => _mesgul = true);
    final c = await kopruGonderCevap(context, '/barkod-etiket/sablon', {
      'id': '${widget.sablon['id']}',
      'ad': _adK.text.trim(),
      'gen_mm': '${widget.sablon['gen_mm']}',
      'yuk_mm': '${widget.sablon['yuk_mm']}',
      'alanlar': jsonEncode([
        for (final a in _alanlar)
          {
            'k': a['k'],
            'x': sayiOku(a['x']),
            'y': sayiOku(a['y']),
            'w': sayiOku(a['w']),
            'h': sayiOku(a['h']),
            'fs': sayiOku(a['fs']),
            'b': tamOku(a['b']),
            'hz': metinOku(a['hz'], 'l'),
            't': metinOku(a['t']),
          }
      ]),
    });
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (c != null && c.ok) {
      kToast(context, 'Yerleşim kaydedildi.');
      Navigator.pop(context, true);
    } else if (c != null) {
      kToast(context, metinOku(c.j['hata'], 'Kaydedilemedi.'), hata: true);
    }
  }

  void _ekle() async {
    final t = context.read<TemaProvider>();
    final k = await kAltSayfa<String>(context, baslik: 'Kutu ekle', icerik: (s) => Column(children: [
          for (final e in kEtiketAlanlar.entries)
            KSatir(solIkon: KIkon(Icons.add_box_outlined, renk: t.mor1), baslik: e.value, onTap: () => Navigator.pop(s, e.key)),
        ]));
    if (k == null || _alanlar.length >= 30) return;
    _degis(() {
      _alanlar.add({'k': k, 'x': 10.0, 'y': 10.0, 'w': k == 'barkod' ? 44.0 : 40.0, 'h': k == 'barkod' ? 30.0 : 10.0, 'fs': 7.0, 'b': 0, 'hz': k == 'barkod' ? 'c' : 'l', 't': ''});
      _sec = _alanlar.length - 1;
      _tK.text = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final secili = _sec == null || _sec! >= _alanlar.length ? null : _alanlar[_sec!];
    return PopScope(
      canPop: !_kirli,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await kOnay(context, 'Kaydedilmemiş değişiklikler var. Çıkılsın mı?', tehlikeli: true, evet: 'Kaydetmeden çık') && context.mounted) Navigator.pop(context, false);
      },
      child: Scaffold(
        backgroundColor: t.bg,
        appBar: AppBar(
          backgroundColor: t.card,
          foregroundColor: t.ink,
          title: const Text('Etiket Yerleşimi'),
          actions: [
            IconButton(tooltip: 'Kutu ekle', onPressed: _ekle, icon: const Icon(Icons.add_box_outlined)),
            Padding(padding: const EdgeInsets.only(right: 8), child: KButon('Kaydet', ikon: Icons.save_outlined, yukleniyor: _mesgul, onTap: _kaydet)),
          ],
        ),
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: KAlan('Tasarım adı', _adK),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text('Kutuyu sürükleyerek taşıyın, sağ alttaki tutamaçla boyutlandırın, dokunarak yazı boyunu ve hizasını ayarlayın.',
                  style: TextStyle(color: t.sub, fontSize: 12.5)),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AspectRatio(
                    aspectRatio: _gen / _yuk,
                    child: LayoutBuilder(builder: (c, k) {
                      final w = k.maxWidth, h = k.maxHeight;
                      return GestureDetector(
                        onTap: () => setState(() => _sec = null),
                        child: _EtiketZemin(
                          sablon: widget.sablon,
                          w: w,
                          h: h,
                          mmPx: w / _gen,
                          alanlar: _alanlar,
                          secili: _sec,
                          sar: (i, kutu) => GestureDetector(
                            onTap: () => setState(() {
                              _sec = i;
                              _tK.text = metinOku(_alanlar[i]['t']);
                            }),
                            onPanStart: (_) => setState(() => _sec = i),
                            onPanUpdate: (d) => _degis(() {
                              final a = _alanlar[i];
                              a['x'] = (sayiOku(a['x']) + d.delta.dx / w * 100).clamp(0, 100 - sayiOku(a['w'])).toDouble();
                              a['y'] = (sayiOku(a['y']) + d.delta.dy / h * 100).clamp(0, 100 - sayiOku(a['h'])).toDouble();
                            }),
                            child: Stack(clipBehavior: Clip.none, children: [
                              kutu,
                              if (_sec == i)
                                Positioned(
                                  right: -12,
                                  bottom: -12,
                                  child: GestureDetector(
                                    onPanUpdate: (d) => _degis(() {
                                      final a = _alanlar[i];
                                      a['w'] = (sayiOku(a['w']) + d.delta.dx / w * 100).clamp(3, 100 - sayiOku(a['x'])).toDouble();
                                      a['h'] = (sayiOku(a['h']) + d.delta.dy / h * 100).clamp(2, 100 - sayiOku(a['y'])).toDouble();
                                    }),
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(color: t.mor1, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                                      child: const Icon(Icons.open_in_full, size: 13, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ]),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
            if (secili != null) _ozellik(t, secili),
          ]),
        ),
      ),
    );
  }

  Widget _ozellik(TemaProvider t, Map<String, dynamic> a) {
    final k = metinOku(a['k']);
    final fs = sayiOku(a['fs']).toDouble().clamp(4, 40).toDouble();
    final hz = metinOku(a['hz'], 'l');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(kEtiketAlanlar[k] ?? k, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700))),
          IconButton(
            tooltip: 'Kutuyu kaldır',
            onPressed: () => _degis(() {
              _alanlar.removeAt(_sec!);
              _sec = null;
            }),
            icon: Icon(Icons.delete_outline, color: t.kirmizi),
          ),
        ]),
        if (k == 'serbest')
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: TextField(
              controller: _tK,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Yazı', isDense: true, counterText: ''),
              onChanged: (s) => _degis(() => a['t'] = s),
            ),
          ),
        Row(children: [
          Text('Yazı boyu', style: TextStyle(color: t.sub, fontSize: 13, fontWeight: FontWeight.w600)),
          Expanded(
            child: Slider(value: fs, min: 4, max: 40, divisions: 72, label: '${fs.toStringAsFixed(1)} pt', activeColor: t.mor1, onChanged: (d) => _degis(() => a['fs'] = double.parse(d.toStringAsFixed(1)))),
          ),
          Text('${fs.toStringAsFixed(1)} pt', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
        ]),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilterChip(
            selected: tamOku(a['b']) == 1,
            showCheckmark: false,
            selectedColor: t.mor1,
            backgroundColor: t.card2,
            label: Text('Kalın', style: TextStyle(color: tamOku(a['b']) == 1 ? Colors.white : t.ink, fontWeight: FontWeight.w700, fontSize: 13)),
            onSelected: (s) => _degis(() => a['b'] = s ? 1 : 0),
          ),
          for (final h in const [('l', Icons.format_align_left), ('c', Icons.format_align_center), ('r', Icons.format_align_right)])
            ChoiceChip(
              selected: hz == h.$1,
              showCheckmark: false,
              selectedColor: t.mor1,
              backgroundColor: t.card2,
              label: Icon(h.$2, size: 18, color: hz == h.$1 ? Colors.white : t.sub),
              onSelected: (_) => _degis(() => a['hz'] = h.$1),
            ),
        ]),
      ]),
    );
  }
}


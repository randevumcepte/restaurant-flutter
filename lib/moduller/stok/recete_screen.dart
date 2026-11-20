import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../screens/barkod_tarayici.dart';
import '../../ui/kit.dart';
import 'barkod_screen.dart';
import 'ortak.dart';

/// Web /recete — ürün reçeteleri (maliyet + food-cost, reçete editörü) + yarı mamüller (tanımla/düzenle/sil)
/// + YARI MAMÜL ÜRETİM PARTİSİ (üret: hammadde düş + stoğa SKT'li parti + barkod; parti listesi, etiket, geri al).
class ReceteScreen extends StatefulWidget {
  const ReceteScreen({super.key});

  @override
  State<ReceteScreen> createState() => _ReceteScreenState();
}

Color _fcRenk(TemaProvider t, double fc) => fc <= 0 ? t.sub : (fc <= 30 ? t.yesil : (fc <= 40 ? t.amber : t.kirmizi));

/// Birim çevirme katsayısı (temel ölçeğe göre): g/ml = 1, kg/lt = 1000; bilinmeyen null
double? _olcek(String kis) => switch (kis.toLowerCase().trim()) {
      'g' || 'gr' || 'ml' || 'adet' || 'ad' || 'porsiyon' || 'prs' => 1,
      'kg' || 'lt' || 'l' => 1000,
      'cl' => 10,
      'dl' => 100,
      _ => null,
    };

class _ReceteScreenState extends State<ReceteScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _sekme = 'urun';
  String _ara = '';
  String _f = 'tumu';

  Future<void> _yenile() async => _k.currentState?.yukle();

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/recete',
      baslik: 'Reçeteler',
      ikon: Icons.menu_book_outlined,
      fab: (ctx, v, y) => _sekme == 'ym' && stSahip(ctx)
          ? FloatingActionButton.extended(
              heroTag: 'ymFab',
              onPressed: () => _ymAc(ctx, v, null),
              icon: const Icon(Icons.add),
              label: const Text('Yarı Mamül', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : const SizedBox.shrink(),
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Future<void> _ymAc(BuildContext context, Map<String, dynamic> v, Map<String, dynamic>? ym) async {
    final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => YariMamulSayfa(ym: ym, veri: v)));
    if (degisti == true) _yenile();
  }

  Future<void> _urunAc(BuildContext context, Map<String, dynamic> v, Map<String, dynamic> u) async {
    final degisti = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => UrunReceteSayfa(urun: u, veri: v)));
    if (degisti == true) _yenile();
  }

  Future<void> _ymSil(Map<String, dynamic> ym) async {
    if (!await kOnay(context, '"${ym['ad']}" silinsin mi?', aciklama: 'Bir ürün reçetesinde kullanılıyorsa silinmez; önce oradan çıkarın.', evet: 'Sil', tehlikeli: true)) return;
    if (!mounted) return;
    final r = await stGonder(context, '/api/patron/yarimamul-sil', {'id': ym['id']}, basari: 'Yarı mamül silindi.');
    if (r.ok) _yenile();
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final urunler = liste(v['urunler']);
    final ymler = liste(v['yarimamuller']);
    final q = _ara.toLowerCase();
    final receteli = urunler.where((u) => u['receteli'] == true).length;
    final yuksek = urunler.where((u) => sayiOku(u['food_cost']) > 35).length;
    final ortFc = () {
      final l = urunler.where((u) => sayiOku(u['food_cost']) > 0).toList();
      return l.isEmpty ? 0.0 : l.fold<double>(0, (s, u) => s + sayiOku(u['food_cost'])) / l.length;
    }();
    return KGovde(yenile: yenile, children: [
      KCipler(secenekler: [('urun', 'Ürün reçeteleri ${urunler.length}'), ('ym', 'Yarı mamüller ${ymler.length}')], secili: _sekme, onSec: (s) => setState(() => _sekme = s)),
      const SizedBox(height: 8),
      if (_sekme == 'urun') ...[
        KKpiIzgara([
          KKpi(etiket: 'Reçeteli ürün', deger: '$receteli / ${urunler.length}', ikon: Icons.menu_book_outlined, renk: t.mor1, onTap: () => setState(() => _f = 'tumu')),
          KKpi(etiket: 'Ortalama food-cost', deger: yuzde(ortFc), ikon: Icons.percent, renk: _fcRenk(t, ortFc)),
          KKpi(etiket: 'Food-cost > %35', deger: '$yuksek', ikon: Icons.trending_up, renk: yuksek > 0 ? t.kirmizi : t.yesil, onTap: () => setState(() => _f = 'yuksek')),
        ]),
        const SizedBox(height: 8),
        KAra(ipucu: 'Ürün ara', onDegis: (s) => setState(() => _ara = s)),
        const SizedBox(height: 8),
        KCipler(
          secenekler: [('tumu', 'Tümü'), ('recetesiz', 'Reçetesiz ${urunler.length - receteli}'), ('yuksek', 'Yüksek food-cost $yuksek')],
          secili: _f,
          onSec: (s) => setState(() => _f = s),
        ),
        const SizedBox(height: 8),
        if (urunler.isEmpty)
          const KBos(baslik: 'Aktif ürün yok', ikon: Icons.restaurant_menu, aciklama: 'Reçete, menüdeki aktif ürünlere tanımlanır. Önce Menü Yönetimi ekranından ürün ekleyin.')
        else ...[
          () {
            final gorunen = urunler.where((u) {
              if (q.isNotEmpty && !'${u['ad']}'.toLowerCase().contains(q)) return false;
              if (_f == 'recetesiz' && u['receteli'] == true) return false;
              if (_f == 'yuksek' && sayiOku(u['food_cost']) <= 35) return false;
              return true;
            }).toList();
            if (gorunen.isEmpty) return const KBos(baslik: 'Bu filtrede ürün yok', ikon: Icons.filter_alt_off_outlined);
            if (genisMi(context)) {
              return LayoutBuilder(builder: (c, s) {
                final w = (s.maxWidth - 24) / 3;
                return Wrap(spacing: 12, children: [for (final u in gorunen) SizedBox(width: w, child: _urunKart(context, v, u))]);
              });
            }
            return Column(children: [for (final u in gorunen) _urunKart(context, v, u)]);
          }(),
        ],
      ] else ...[
        KKart(
          renk: t.mor1,
          child: Text('Sos, hamur, marine gibi ara ürünleri yarı mamül olarak tanımlayın; ürün reçetelerine ekleyin. '
              'Önceden üretip stoğa almak için "Üret" deyin: hammadde düşer, SKT\'li parti ve barkod oluşur.',
              style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4)),
        ),
        if (ymler.isEmpty)
          KBos(
            baslik: 'Henüz yarı mamül yok',
            ikon: Icons.blender_outlined,
            aciklama: stSahip(context)
                ? 'Sağ alttaki "Yarı Mamül" ile ilk ara ürünü tanımlayın; sonra ürün reçetelerine ekleyin. Satışta hammaddesi otomatik düşer.'
                : 'Yarı mamülü işletme sahibi tanımlar.',
          )
        else
          for (final ym in ymler)
            KKart(
              onTap: () => _ymAc(context, v, ym),
              child: Row(children: [
                KIkon(Icons.blender_outlined, renk: t.mavi),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${ym['ad']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                    Text('Verim ${mik(ym['verim_miktar'])} ${ym['verim_birim']} · ${ym['kalem_sayisi']} bileşen · ${tl(ym['toplam_maliyet'])}',
                        style: TextStyle(color: t.sub, fontSize: 12.5)),
                    Text('Birim maliyet ${tl(ym['birim_maliyet'])}/${ym['verim_birim']}', style: TextStyle(color: t.sub2, fontSize: 12)),
                  ]),
                ),
                if (stSahip(context))
                  IconButton(tooltip: 'Sil', onPressed: () => _ymSil(ym), icon: Icon(Icons.delete_outline, color: t.sub)),
                Icon(Icons.chevron_right, color: t.sub),
              ]),
            ),
      ],
    ]);
  }

  Widget _urunKart(BuildContext context, Map<String, dynamic> v, Map<String, dynamic> u) {
    final t = context.read<TemaProvider>();
    final fc = sayiOku(u['food_cost']);
    final receteli = u['receteli'] == true;
    return KKart(
      renk: receteli ? _fcRenk(t, fc) : t.amber,
      onTap: () => _urunAc(context, v, u),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${u['ad']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(receteli ? 'Satış ${tl(u['fiyat'])} · Maliyet ${tl(u['maliyet'])}' : 'Reçete tanımlı değil — dokunup ekleyin',
                style: TextStyle(color: receteli ? t.sub : t.amber, fontSize: 12.5)),
          ]),
        ),
        if (receteli) KRozet('FC ${yuzde(fc)}', renk: _fcRenk(t, fc)),
        Icon(Icons.chevron_right, color: t.sub),
      ]),
    );
  }
}

// ═════════════════════ ortak kalem düzenleyici ═════════════════════
class _Kaynak {
  final List<Map<String, dynamic>> malzemeler; // id, ad, temel_birim_id, guncel_maliyet, birim
  final List<Map<String, dynamic>> birimler; // id, ad, kisaltma, tip
  final List<Map<String, dynamic>> yarimamuller; // id, ad, verim_birim_id, verim_birim, birim_maliyet
  _Kaynak(Map<String, dynamic> v)
      : malzemeler = liste(v['malzemeler']),
        birimler = liste(v['birimler']),
        yarimamuller = liste(v['yarimamuller']);

  Map<String, dynamic>? birim(int id) => birimler.where((b) => tamOku(b['id']) == id).firstOrNull;
  String kis(int id) => metinOku(birim(id)?['kisaltma']);

  /// Aynı türdeki (ağırlık/hacim/adet) birimler
  List<(int, String)> uyumlu(int temelBirimId) {
    final tip = metinOku(birim(temelBirimId)?['tip']);
    final l = birimler.where((b) => tip.isEmpty || metinOku(b['tip']) == tip).toList();
    return [for (final b in (l.isEmpty ? birimler : l)) (tamOku(b['id']), '${b['kisaltma']}')];
  }

  /// Yaklaşık satır maliyeti (kaydedince sunucu kesin hesaplar)
  double? tahmin(Map<String, dynamic> k) {
    final miktar = sayiOku(k['miktar']);
    if (k['yarimamul'] == true) {
      final ym = yarimamuller.where((y) => tamOku(y['id']) == tamOku(k['alt_recete_id'])).firstOrNull;
      if (ym == null) return null;
      final a = _olcek(kis(tamOku(k['birim_id']))), b = _olcek(metinOku(ym['verim_birim']));
      if (tamOku(k['birim_id']) == tamOku(ym['verim_birim_id'])) return miktar * sayiOku(ym['birim_maliyet']);
      if (a == null || b == null) return null;
      return miktar * a / b * sayiOku(ym['birim_maliyet']);
    }
    final m = malzemeler.where((x) => tamOku(x['id']) == tamOku(k['malzeme_id'])).firstOrNull;
    if (m == null) return null;
    if (tamOku(k['birim_id']) == tamOku(m['temel_birim_id'])) return miktar * sayiOku(m['guncel_maliyet']);
    final a = _olcek(kis(tamOku(k['birim_id']))), b = _olcek(kis(tamOku(m['temel_birim_id'])));
    if (a == null || b == null) return null;
    return miktar * a / b * sayiOku(m['guncel_maliyet']);
  }
}

Future<Map<String, dynamic>?> _kalemSec(BuildContext context, _Kaynak k, {int? haricYm, Map<String, dynamic>? mevcut}) {
  String mod = mevcut?['yarimamul'] == true ? 'ym' : 'malzeme';
  String ara = '';
  Map<String, dynamic>? secili = mevcut == null
      ? null
      : (mod == 'ym'
          ? k.yarimamuller.where((y) => tamOku(y['id']) == tamOku(mevcut['alt_recete_id'])).firstOrNull
          : k.malzemeler.where((m) => tamOku(m['id']) == tamOku(mevcut['malzeme_id'])).firstOrNull);
  int? birim = mevcut == null ? null : tamOku(mevcut['birim_id']);
  final miktar = TextEditingController(text: mevcut == null ? '' : '${sayiOku(mevcut['miktar'])}'.replaceAll(RegExp(r'\.0$'), ''));
  return kAltSayfa<Map<String, dynamic>>(context, baslik: mevcut == null ? 'Kalem Ekle' : 'Kalemi Düzenle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
        final t = c.read<TemaProvider>();
        final kaynak = mod == 'ym' ? k.yarimamuller.where((y) => tamOku(y['id']) != haricYm).toList() : k.malzemeler;
        final gor = kaynak.where((x) => ara.isEmpty || '${x['ad']}'.toLowerCase().contains(ara)).take(60).toList();
        final temel = secili == null ? 0 : (mod == 'ym' ? tamOku(secili!['verim_birim_id']) : tamOku(secili!['temel_birim_id']));
        final birimler = secili == null ? <(int, String)>[] : k.uyumlu(temel);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (mevcut == null)
            KCipler(
              secenekler: const [('malzeme', 'Malzeme'), ('ym', 'Yarı mamül')],
              secili: mod,
              onSec: (s) => ss(() {
                mod = s;
                secili = null;
                birim = null;
              }),
            ),
          if (secili == null) ...[
            const SizedBox(height: 6),
            KAra(ipucu: mod == 'ym' ? 'Yarı mamül ara' : 'Malzeme ara', onDegis: (s) => ss(() => ara = s.toLowerCase())),
            const SizedBox(height: 6),
            if (kaynak.isEmpty)
              KBos(baslik: mod == 'ym' ? 'Yarı mamül yok' : 'Malzeme yok', aciklama: mod == 'ym' ? 'Önce Yarı Mamüller sekmesinden tanımlayın.' : 'Önce Stok / Malzeme ekranından malzeme kartı açın.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView(shrinkWrap: true, children: [
                  for (final x in gor)
                    KSatir(
                      baslik: '${x['ad']}',
                      alt: mod == 'ym' ? 'Verim birimi ${x['verim_birim']} · ${tl(x['birim_maliyet'])}/${x['verim_birim']}' : '${tl(x['guncel_maliyet'])}/${x['birim']}',
                      onTap: () => ss(() {
                        secili = x;
                        birim = mod == 'ym' ? tamOku(x['verim_birim_id']) : tamOku(x['temel_birim_id']);
                      }),
                    ),
                ]),
              ),
          ] else ...[
            KSatir(
              solIkon: Icon(mod == 'ym' ? Icons.blender_outlined : Icons.inventory_2_outlined, color: t.mor1),
              baslik: '${secili!['ad']}',
              alt: mod == 'ym' ? 'Yarı mamül' : 'Malzeme',
              sag: mevcut == null ? TextButton(onPressed: () => ss(() => secili = null), child: const Text('Değiştir')) : null,
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: KAlan('Miktar', miktar, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true)),
              const SizedBox(width: 10),
              Expanded(child: KSecim<int>('Birim', deger: birim, secenekler: birimler, onSec: (b) => ss(() => birim = b))),
            ]),
            KButon(mevcut == null ? 'Ekle' : 'Güncelle', ikon: Icons.check, genis: true, onTap: () {
              final mk = double.tryParse(miktar.text.trim().replaceAll(',', '.')) ?? 0;
              if (mk <= 0 || birim == null) {
                kToast(c, 'Miktar ve birim girin.', hata: true);
                return;
              }
              Navigator.pop(c, {
                if (mod == 'ym') 'alt_recete_id': tamOku(secili!['id']) else 'malzeme_id': tamOku(secili!['id']),
                'malzeme': '${secili!['ad']}',
                'yarimamul': mod == 'ym',
                'miktar': mk,
                'birim_id': birim,
                'birim': k.kis(birim!),
              });
            }),
          ],
        ]);
      }));
}

class _KalemListe extends StatelessWidget {
  final List<Map<String, dynamic>> kalemler;
  final _Kaynak kaynak;
  final bool duzen;
  final int? haricYm;
  final VoidCallback degisti;
  const _KalemListe({required this.kalemler, required this.kaynak, required this.duzen, required this.degisti, this.haricYm});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (kalemler.isEmpty)
        KBos(
          baslik: 'Kalem yok',
          ikon: Icons.list_alt,
          aciklama: duzen ? '"Kalem ekle" ile malzeme ya da yarı mamül ekleyin; miktar porsiyon/verim başınadır.' : 'Bu reçeteye henüz kalem girilmemiş. Reçeteyi işletme sahibi düzenler.',
        )
      else
        for (var i = 0; i < kalemler.length; i++)
          () {
            final k = kalemler[i];
            final mal = k.containsKey('satir_maliyet') ? sayiOku(k['satir_maliyet']) : kaynak.tahmin(k);
            return KSatir(
              solIkon: Icon(k['yarimamul'] == true ? Icons.blender_outlined : Icons.inventory_2_outlined, color: k['yarimamul'] == true ? t.mavi : t.mor1),
              baslik: '${k['malzeme']}',
              alt: '${mik(k['miktar'])} ${k['birim']}${k['yarimamul'] == true ? ' · yarı mamül' : ''}',
              onTap: duzen
                  ? () async {
                      final y = await _kalemSec(context, kaynak, haricYm: haricYm, mevcut: k);
                      if (y != null) {
                        kalemler[i] = y;
                        degisti();
                      }
                    }
                  : null,
              sag: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(mal == null ? '—' : '${k.containsKey('satir_maliyet') ? '' : '≈'}${tl(mal)}', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                if (duzen)
                  IconButton(
                    tooltip: 'Çıkar',
                    onPressed: () {
                      kalemler.removeAt(i);
                      degisti();
                    },
                    icon: Icon(Icons.remove_circle_outline, color: t.kirmizi),
                  ),
              ]),
            );
          }(),
      if (duzen) ...[
        const SizedBox(height: 8),
        KButon('Kalem ekle', ikon: Icons.add, ikincil: true, genis: true, onTap: () async {
          final y = await _kalemSec(context, kaynak, haricYm: haricYm);
          if (y != null) {
            kalemler.add(y);
            degisti();
          }
        }),
      ],
    ]);
  }
}

String _kalemJson(List<Map<String, dynamic>> kalemler) => jsonEncode([
      for (final k in kalemler)
        if (k['yarimamul'] == true)
          {'alt_recete_id': tamOku(k['alt_recete_id']), 'miktar': sayiOku(k['miktar']), 'birim_id': tamOku(k['birim_id'])}
        else
          {'malzeme_id': tamOku(k['malzeme_id']), 'miktar': sayiOku(k['miktar']), 'birim_id': tamOku(k['birim_id'])},
    ]);

// ═════════════════════ ürün reçetesi editörü ═════════════════════
class UrunReceteSayfa extends StatefulWidget {
  final Map<String, dynamic> urun;
  final Map<String, dynamic> veri;
  const UrunReceteSayfa({super.key, required this.urun, required this.veri});

  @override
  State<UrunReceteSayfa> createState() => _UrunReceteSayfaState();
}

class _UrunReceteSayfaState extends State<UrunReceteSayfa> {
  late final _Kaynak _kay = _Kaynak(widget.veri);
  Map<String, dynamic>? _d;
  List<Map<String, dynamic>> _kalemler = [];
  String? _hata;
  bool _kirli = false, _kaydediyor = false, _kaydedildi = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final c = await stAl(context, '/api/patron/urun-recete', q: {'urun_id': '${widget.urun['id']}'});
    if (!mounted) return;
    setState(() {
      if (c.ok) {
        _d = c.veri;
        _kalemler = liste(c.veri['kalemler']);
        _hata = null;
        _kirli = false;
      } else {
        _hata = c.yetkisiz ? 'Reçete detayını işletme sahibi ve müdür görür; düzenlemeyi yalnız sahip yapar.' : (c.hata ?? 'Reçete alınamadı.');
      }
    });
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediyor = true);
    final r = await stGonder(context, '/api/patron/recete-kaydet', {'urun_id': widget.urun['id'], 'kalemler': _kalemJson(_kalemler)}, basari: 'Reçete kaydedildi.');
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    if (r.ok) {
      _kaydedildi = true;
      _yukle();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final d = _d;
    final duzen = d?['duzenleyebilir'] == true;
    final fiyat = sayiOku(d?['fiyat'] ?? widget.urun['fiyat']);
    double maliyet = 0;
    bool eksik = false;
    for (final k in _kalemler) {
      final m = k.containsKey('satir_maliyet') ? sayiOku(k['satir_maliyet']) : _kay.tahmin(k);
      if (m == null) {
        eksik = true;
      } else {
        maliyet += m;
      }
    }
    final fc = fiyat > 0 ? maliyet / fiyat * 100 : 0.0;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (pop, _) async {
        if (pop) return;
        if (_kirli && !await kOnay(context, 'Kaydedilmemiş değişiklik var', aciklama: 'Çıkarsanız reçetedeki değişiklikler kaybolur.', evet: 'Çık', tehlikeli: true)) return;
        if (context.mounted) Navigator.of(context).pop(_kaydedildi);
      },
      child: KSayfa(
        baslik: '${widget.urun['ad']}',
        altBaslik: 'Reçete',
        ikon: Icons.menu_book_outlined,
        govde: _hata != null
            ? KHata(_hata!, tekrar: _yukle, yetkisiz: _hata!.contains('sahip'))
            : d == null
                ? const KYukleniyor()
                : KGovde(yenile: _yukle, children: [
                    KKpiIzgara([
                      KKpi(etiket: 'Satış fiyatı', deger: tl(fiyat), ikon: Icons.sell_outlined, renk: t.mavi),
                      KKpi(etiket: 'Porsiyon maliyeti', deger: '${eksik || _kirli ? '≈' : ''}${tl(maliyet)}', ikon: Icons.payments_outlined, renk: t.mor1),
                      KKpi(etiket: 'Food-cost', deger: yuzde(fc), ikon: Icons.percent, renk: _fcRenk(t, fc), alt: fc > 35 ? 'Yüksek — porsiyon/fiyatı gözden geçirin' : null),
                    ]),
                    if (_kirli)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text('≈ yaklaşık: kaydedince maliyet sunucuda kesin hesaplanır.', style: TextStyle(color: t.sub, fontSize: 12)),
                      ),
                    const SizedBox(height: 8),
                    KBaslik('Kalemler (1 porsiyon)', ikon: Icons.list_alt),
                    _KalemListe(kalemler: _kalemler, kaynak: _kay, duzen: duzen, degisti: () => setState(() => _kirli = true)),
                    if (duzen) ...[
                      const SizedBox(height: 12),
                      KButon('Reçeteyi Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _kaydediyor, onTap: _kirli && !_kaydediyor ? _kaydet : null),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text('Reçeteyi yalnız işletme sahibi düzenleyebilir.', style: TextStyle(color: t.sub, fontSize: 12.5)),
                      ),
                  ]),
      ),
    );
  }
}

// ═════════════════════ yarı mamül editörü + üretim partisi ═════════════════════
class YariMamulSayfa extends StatefulWidget {
  final Map<String, dynamic>? ym;
  final Map<String, dynamic> veri;
  const YariMamulSayfa({super.key, required this.ym, required this.veri});

  @override
  State<YariMamulSayfa> createState() => _YariMamulSayfaState();
}

class _YariMamulSayfaState extends State<YariMamulSayfa> {
  late final _Kaynak _kay = _Kaynak(widget.veri);
  late int? _id = widget.ym == null ? null : tamOku(widget.ym!['id']);
  final _ad = TextEditingController();
  final _verim = TextEditingController(text: '1');
  int? _verimBirim;
  List<Map<String, dynamic>> _kalemler = [];
  bool _duzen = false, _yuklendi = false, _kirli = false, _kaydediyor = false, _degisti = false;
  String? _hata;
  // üretim partileri
  List<Map<String, dynamic>> _partiler = [];
  double _stok = 0;
  bool _partiYuklendi = false;

  bool get _kameraVar => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  void initState() {
    super.initState();
    _duzen = stSahip(context);
    if (_id == null) {
      _yuklendi = true;
      _verimBirim = _kay.birimler.isEmpty ? null : tamOku(_kay.birimler.first['id']);
    } else {
      _yukle();
      _partiYukle();
    }
  }

  @override
  void dispose() {
    _ad.dispose();
    _verim.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    final c = await stAl(context, '/api/patron/yarimamul-detay', q: {'id': '$_id'});
    if (!mounted) return;
    setState(() {
      _yuklendi = true;
      if (c.ok) {
        _ad.text = metinOku(c.veri['ad']);
        _verim.text = mik(c.veri['verim_miktar']).replaceAll('.', '');
        _verimBirim = tamOku(c.veri['verim_birim_id']) > 0 ? tamOku(c.veri['verim_birim_id']) : null;
        _kalemler = liste(c.veri['kalemler']);
        _duzen = c.veri['duzenleyebilir'] == true;
        _hata = null;
        _kirli = false;
      } else {
        _hata = c.yetkisiz ? 'Yarı mamül detayını işletme sahibi ve müdür görür.' : (c.hata ?? 'Yarı mamül alınamadı.');
      }
    });
  }

  Future<void> _partiYukle() async {
    if (_id == null) return;
    final c = await stAl(context, '/api/patron/yarimamul-partileri', q: {'recete_id': '$_id'});
    if (!mounted) return;
    setState(() {
      _partiYuklendi = true;
      if (c.ok) {
        _partiler = liste(c.veri['partiler']).where((p) => sayiOku(p['kalan']) > 0.0001).toList();
        _stok = sayiOku(c.veri['stok']);
      }
    });
  }

  String get _birimTxt => _verimBirim == null ? '' : _kay.kis(_verimBirim!);

  Future<void> _kaydet() async {
    final ad = _ad.text.trim();
    final verim = double.tryParse(_verim.text.trim().replaceAll(',', '.')) ?? 0;
    if (ad.isEmpty) return kToast(context, 'Yarı mamül adı boş olamaz', hata: true);
    if (verim <= 0) return kToast(context, 'Verim (kaç çıkıyor) 0’dan büyük olmalı', hata: true);
    if (_verimBirim == null) return kToast(context, 'Verim birimi seçin (litre/kg/porsiyon…)', hata: true);
    setState(() => _kaydediyor = true);
    final r = await stGonder(context, '/api/patron/yarimamul-kaydet',
        {'id': _id ?? 0, 'ad': ad, 'verim_miktar': verim, 'verim_birim_id': _verimBirim, 'kalemler': _kalemJson(_kalemler)}, basari: 'Yarı mamül kaydedildi.');
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    if (r.ok) {
      _degisti = true;
      _id = tamOku(r.j['id']) > 0 ? tamOku(r.j['id']) : _id;
      await _yukle();
      _partiYukle();
    }
  }

  Future<void> _uret() async {
    final miktar = TextEditingController(text: _verim.text);
    final barkod = TextEditingController();
    String? skt = stBugun(3);
    final sonuc = await kAltSayfa<Map<String, dynamic>>(context, baslik: 'Üret · ${_ad.text}', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.read<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Hammaddeler reçeteye göre stoktan düşer; üretilen miktar SKT\'li parti olarak stoğa girer ve barkod verilir.', style: TextStyle(color: t.sub, fontSize: 13, height: 1.35)),
            const SizedBox(height: 10),
            KAlan('Üretilen miktar ($_birimTxt)', miktar, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
            StTarihAlan('Son tüketim tarihi (SKT)', deger: skt, temizlenir: true, onSec: (s) => ss(() => skt = s)),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: KAlan('Barkod', barkod, ipucu: 'Boş bırakın — otomatik üretilir')),
              if (_kameraVar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 6),
                  child: IconButton.filledTonal(onPressed: () async {
                    final s = await BarkodTarayici.oku(c);
                    if (s != null) ss(() => barkod.text = s);
                  }, icon: const Icon(Icons.qr_code_scanner)),
                ),
            ]),
            KButon('Üret ve Stoğa Al', ikon: Icons.precision_manufacturing_outlined, genis: true, onTap: () async {
              final mk = double.tryParse(miktar.text.trim().replaceAll(',', '.')) ?? 0;
              if (mk <= 0) {
                kToast(c, 'Üretilen miktar 0 olamaz', hata: true);
                return;
              }
              final r = await stGonder(c, '/api/patron/yarimamul-uret', {'recete_id': _id, 'miktar': mk, 'skt': skt ?? '', 'barkod': barkod.text.trim()}, sessiz: true);
              if (r.ok && c.mounted) Navigator.pop(c, r.j);
            }),
          ]);
        }));
    if (sonuc == null || !mounted) return;
    _degisti = true;
    _partiYukle();
    final bk = metinOku(sonuc['barkod']);
    final t = context.read<TemaProvider>();
    await kAltSayfa(context, baslik: 'Üretildi', icerik: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KKart(
            renk: t.yesil,
            child: Text('${mik(sonuc['miktar'])} $_birimTxt üretildi, stoğa eklendi.\nBarkod: $bk · SKT: ${tarihYaz(sonuc['skt'], saat: false)}',
                style: TextStyle(color: t.ink, fontSize: 14, height: 1.45, fontWeight: FontWeight.w600)),
          ),
          KButon('Etiket Yazdır', ikon: Icons.print_outlined, genis: true, onTap: () {
            Navigator.pop(c);
            _etiket(bk, metinOku(sonuc['skt']), sayiOku(sonuc['miktar']), stBugun());
          }),
        ]));
  }

  void _etiket(String barkod, String skt, double miktar, String tarih) {
    stEtiketSorBas(context, [
      StEtiket(
        kod: barkod,
        ust: 'Üretim: ${tarihYaz(tarih, saat: false)} · ${mik(miktar)} $_birimTxt',
        ad: _ad.text.trim().isEmpty ? 'Yarı Mamül' : _ad.text.trim(),
        alt: 'SKT: ${skt.isEmpty ? '—' : tarihYaz(skt, saat: false)}',
      ),
    ], ad: 'Parti-Etiketi');
  }

  Future<void> _geriAl(Map<String, dynamic> p, {String? pin}) async {
    if (pin == null &&
        !await kOnay(context, 'Bu üretim partisi geri alınsın mı?',
            aciklama: '• Düşen malzemeler stoğa geri döner\n• Bu partinin stoğu silinir\n• Yalnızca satılmamış parti geri alınabilir', evet: 'Geri Al', tehlikeli: true)) {
      return;
    }
    if (!mounted) return;
    final r = await stGonder(context, '/api/patron/yarimamul-uretim-sil', {'parti_id': p['id'], 'onay_pin': ?pin}, basari: 'Geri alındı.', hataSessiz: true);
    if (!mounted) return;
    if (r.ok) {
      _degisti = true;
      _partiYukle();
      return;
    }
    if (r.j['onay_gerek'] == true) {
      final k = TextEditingController();
      final girilen = await kAltSayfa<String>(context, baslik: 'Yetki Onayı', icerik: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(r.hata ?? 'Müdür/Sahip onayı gerekli', style: TextStyle(color: c.read<TemaProvider>().sub2, fontSize: 13.5)),
            const SizedBox(height: 10),
            TextField(controller: k, obscureText: true, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(labelText: 'Müdür/Sahip PIN')),
            const SizedBox(height: 12),
            KButon('Onayla', genis: true, onTap: () => Navigator.pop(c, k.text.trim())),
          ]));
      if (girilen != null && girilen.isNotEmpty && mounted) return _geriAl(p, pin: girilen);
      return;
    }
    kToast(context, r.hata ?? 'Geri alınamadı', hata: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final patron = stPatron(context);
    double maliyet = 0;
    bool yaklasik = _kirli;
    for (final k in _kalemler) {
      final m = k.containsKey('satir_maliyet') ? sayiOku(k['satir_maliyet']) : _kay.tahmin(k);
      if (m == null) {
        yaklasik = true;
      } else {
        maliyet += m;
      }
    }
    final verim = double.tryParse(_verim.text.trim().replaceAll(',', '.')) ?? 0;
    final birimler = [for (final b in _kay.birimler) (tamOku(b['id']), '${b['kisaltma']} · ${b['ad']}')];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (pop, _) async {
        if (pop) return;
        if (_kirli && !await kOnay(context, 'Kaydedilmemiş değişiklik var', evet: 'Çık', tehlikeli: true)) return;
        if (context.mounted) Navigator.of(context).pop(_degisti);
      },
      child: KSayfa(
        baslik: _id == null ? 'Yeni Yarı Mamül' : (_ad.text.isEmpty ? 'Yarı Mamül' : _ad.text),
        ikon: Icons.blender_outlined,
        govde: _hata != null
            ? KHata(_hata!, tekrar: _yukle, yetkisiz: true)
            : !_yuklendi
                ? const KYukleniyor()
                : KGovde(children: [
                    if (_duzen) ...[
                      KAlan('Ad', _ad, zorunlu: true, ipucu: 'Örn: Domates sosu'),
                      Row(children: [
                        Expanded(child: KAlan('Verim (kaç çıkıyor)', _verim, klavye: const TextInputType.numberWithOptions(decimal: true))),
                        const SizedBox(width: 10),
                        Expanded(child: KSecim<int>('Verim birimi', deger: _verimBirim, secenekler: birimler, onSec: (b) => setState(() { _verimBirim = b; _kirli = true; }))),
                      ]),
                    ] else
                      KKart(child: Text('${_ad.text} · verim ${_verim.text} $_birimTxt', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))),
                    KKpiIzgara([
                      KKpi(etiket: 'Toplam maliyet', deger: '${yaklasik ? '≈' : ''}${tl(maliyet)}', ikon: Icons.payments_outlined, renk: t.mor1),
                      KKpi(etiket: 'Birim maliyet', deger: verim > 0 ? '${tl(maliyet / verim)}/$_birimTxt' : '—', ikon: Icons.scale_outlined, renk: t.mavi),
                      if (_id != null) KKpi(etiket: 'Stokta', deger: '${mik(_stok)} $_birimTxt', ikon: Icons.inventory_2_outlined, renk: t.yesil),
                    ]),
                    const SizedBox(height: 8),
                    KBaslik('Bileşenler (verim başına)', ikon: Icons.list_alt),
                    _KalemListe(kalemler: _kalemler, kaynak: _kay, duzen: _duzen, haricYm: _id, degisti: () => setState(() => _kirli = true)),
                    if (_duzen) ...[
                      const SizedBox(height: 12),
                      KButon(_id == null ? 'Yarı Mamülü Oluştur' : 'Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _kaydediyor,
                          onTap: _kaydediyor || (_id != null && !_kirli) ? null : _kaydet),
                    ],
                    if (_id != null) ...[
                      const SizedBox(height: 16),
                      KBaslik('Üretim partileri', ikon: Icons.precision_manufacturing_outlined,
                          alt: 'Önceden üretilip stoğa alınan partiler (SKT · kalan). Satıldıkça en yakın SKT\'li partiden düşer.',
                          sag: patron ? FilledButton.icon(onPressed: _kirli ? null : _uret, icon: const Icon(Icons.add, size: 18), label: const Text('Üret')) : null),
                      if (_kirli && patron) Text('Üretmeden önce değişiklikleri kaydedin.', style: TextStyle(color: t.amber, fontSize: 12.5)),
                      if (!_partiYuklendi)
                        const Padding(padding: EdgeInsets.all(16), child: KYukleniyor())
                      else if (_partiler.isEmpty)
                        KBos(
                          baslik: 'Henüz üretim partisi yok',
                          ikon: Icons.inventory_outlined,
                          aciklama: patron ? '"Üret" ile üretim girin: hammadde düşer, SKT\'li parti + barkod oluşur.' : 'Üretimi işletme sahibi ya da müdür girer.',
                        )
                      else
                        for (final p in _partiler)
                          () {
                            final g = p['skt_gun'];
                            final renk = g == null ? t.sub : (tamOku(g) < 0 ? t.kirmizi : (tamOku(g) <= 3 ? t.amber : t.yesil));
                            final uyari = g == null ? 'SKT yok' : (tamOku(g) < 0 ? 'SKT GEÇTİ' : '${tamOku(g)} gün kaldı');
                            return KKart(
                              renk: renk,
                              padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(metinOku(p['lot_no'], '—'), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                                    Text('SKT ${tarihYaz(p['skt'], saat: false)} · $uyari · üretim ${tarihYaz(p['giris_tarihi'], saat: false)}', style: TextStyle(color: renk, fontSize: 12)),
                                  ]),
                                ),
                                Text('${mik(p['kalan'])} / ${mik(p['giris'])}', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                                IconButton(
                                  tooltip: 'Etiketi yeniden yazdır',
                                  onPressed: () => _etiket(metinOku(p['lot_no']), metinOku(p['skt']), sayiOku(p['giris']), metinOku(p['giris_tarihi'])),
                                  icon: Icon(Icons.print_outlined, color: t.mavi),
                                ),
                                IconButton(tooltip: 'Üretimi geri al', onPressed: () => _geriAl(p), icon: Icon(Icons.undo, color: t.kirmizi)),
                              ]),
                            );
                          }(),
                    ],
                  ]),
      ),
    );
  }
}

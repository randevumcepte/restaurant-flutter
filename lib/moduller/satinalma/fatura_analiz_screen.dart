import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

const _sekmeler = [('tasarruf', 'Kaçan Tasarruf'), ('enflasyon', 'Zam ve Enflasyon'), ('iz', 'Ürün Fiyat İzi'), ('odeme', 'Ödeme Takvimi')];

/// Web /fatura-analiz/{tasarruf|enflasyon|iz|odeme} — alış faturası analizleri (dönem, Excel, TÜFE girişi, ürün fiyat izi).
class FaturaAnalizScreen extends StatefulWidget {
  final String url;
  const FaturaAnalizScreen({super.key, this.url = '/fatura-analiz/tasarruf'});
  @override
  State<FaturaAnalizScreen> createState() => _FaturaAnalizScreenState();
}

class _FaturaAnalizScreenState extends State<FaturaAnalizScreen> {
  late String _sekme;
  final Map<String, String> _q = {};

  @override
  void initState() {
    super.initState();
    final u = Uri.parse(widget.url);
    final s = u.pathSegments.length > 1 ? u.pathSegments[1] : 'tasarruf';
    _sekme = _sekmeler.any((x) => x.$1 == s) ? s : 'tasarruf';
    _q.addAll(u.queryParameters);
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: ValueKey('$_sekme|$_q'),
      yol: '/fatura-analiz/$_sekme',
      q: Map.of(_q),
      baslik: 'Fatura Analizleri',
      ikon: Icons.analytics_outlined,
      govde: _govde,
      araclar: (ctx, v, yenile) => [
        IconButton(
          tooltip: 'Excel',
          onPressed: () => saDosyaIndir(context, '/fatura-analiz/$_sekme', 'fatura-analiz-$_sekme.xlsx', q: {..._q, 'format': 'xlsx', if (_sekme != 'odeme') 'bas': metinOku(v['bas']), if (_sekme != 'odeme') 'bit': metinOku(v['bit'])}),
          icon: const Icon(Icons.table_view_outlined),
        ),
        IconButton(tooltip: 'Fatura Denetimi', onPressed: () => saAc(context, '/fatura-denetim', 'Fatura Denetim'), icon: const Icon(Icons.fact_check_outlined)),
      ],
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    return KGovde(yenile: yenile, children: [
      KCipler(secenekler: _sekmeler, secili: _sekme, onSec: (k) => setState(() {
            _sekme = k;
            _q.remove('malzeme');
          })),
      if (_sekme != 'odeme')
        Row(children: [
          Expanded(child: KSatir(baslik: 'Başlangıç', alt: tarihYaz(v['bas'], saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
            final s = await saTarihSec(context, ilk: metinOku(v['bas']));
            if (s != null) setState(() => _q['bas'] = s);
          })),
          const SizedBox(width: 8),
          Expanded(child: KSatir(baslik: 'Bitiş', alt: tarihYaz(v['bit'], saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
            final s = await saTarihSec(context, ilk: metinOku(v['bit']));
            if (s != null) setState(() => _q['bit'] = s);
          })),
        ]),
      const SizedBox(height: 8),
      ...switch (_sekme) {
        'tasarruf' => _tasarruf(liste(v['t']), v, t),
        'enflasyon' => _enflasyon(harita(v['e']), v, t, yenile),
        'iz' => _iz(harita(v['iz']), v, t),
        _ => _odeme(harita(v['o']), t),
      },
    ]);
  }

  List<Widget> _tasarruf(List<Map<String, dynamic>> l, Map<String, dynamic> v, TemaProvider t) {
    if (l.isEmpty) {
      return const [KBos(baslik: 'Bu dönemde alış faturası yok', aciklama: 'Alış faturaları elle girildikçe ya da Gelen e-Faturalar\'dan aktarıldıkça dolar.', ikon: Icons.savings_outlined)];
    }
    final kTed = l.fold<double>(0, (a, x) => a + sayiOku(x['kac_ted']));
    final kFiy = l.fold<double>(0, (a, x) => a + sayiOku(x['kac_fiyat']));
    final top = l.fold<double>(0, (a, x) => a + sayiOku(x['tutar']));
    return [
      KKpiIzgara([
        KKpi(etiket: 'Toplam alış', deger: tl(top, kisa: true), alt: '${l.length} ürün', renk: t.mor1),
        KKpi(etiket: 'Tedarikçi farkı', deger: tl(kTed, kisa: true), alt: 'En ucuz ortalama verenden alınsaydı', renk: t.kirmizi),
        KKpi(etiket: 'Fiyat farkı', deger: tl(kFiy, kisa: true), alt: 'Dönemin en düşük fiyatından alınsaydı', renk: t.amber),
      ]),
      Text('Fiyatlar temel birime çevrildi. Ürüne dokunun → fiyat izi.', style: TextStyle(color: t.sub, fontSize: 12.5)),
      const SizedBox(height: 8),
      SaIzgara([
        for (final x in l)
          KKart(
            onTap: () => setState(() {
              _sekme = 'iz';
              _q['malzeme'] = '${x['mid']}';
            }),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(x['ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5)),
              Text('${x['ted_say']} tedarikçi · ${x['alim']} alım · ${sayiYaz(x['miktar'])} ${metinOku(x['birim'])} · ${tl(x['tutar'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
              const SizedBox(height: 4),
              SaDeger('Ort. fiyat', tl(x['ort'])),
              if (x['en_iyi_ted'] != null) SaDeger('En ucuz tedarikçi', '${x['en_iyi_ted']} · ${tl(x['en_iyi'])}'),
              SaDeger('En düşük ödenen', '${tl(x['min'])} · ${metinOku(x['min_ted'])} · ${tarihYaz(x['min_tarih'], saat: false)}'),
              SaDeger('Tedarikçi farkı', sayiOku(x['kac_ted']) > 0 ? tl(x['kac_ted']) : '—', renk: sayiOku(x['kac_ted']) > 0 ? t.kirmizi : t.sub, kalin: true),
              SaDeger('Fiyat farkı', sayiOku(x['kac_fiyat']) > 0 ? tl(x['kac_fiyat']) : '—', renk: sayiOku(x['kac_fiyat']) > 0 ? t.amber : t.sub),
            ]),
          ),
      ], minGenislik: 420),
    ];
  }

  List<Widget> _enflasyon(Map<String, dynamic> e, Map<String, dynamic> v, TemaProvider t, Future<void> Function() yenile) {
    final tufe = harita(e['tufe']);
    final yonetici = v['yonetici'] == true;
    final aylar = <String>[];
    final bas = DateTime.tryParse(metinOku(v['bas'])), bit = DateTime.tryParse(metinOku(v['bit']));
    if (bas != null && bit != null) {
      var c = DateTime(bas.year, bas.month);
      while (!c.isAfter(bit)) {
        aylar.add('${c.year}-${c.month.toString().padLeft(2, '0')}');
        c = DateTime(c.year, c.month + 1);
      }
    }
    final urun = liste(e['urun']);
    final ted = liste(e['tedarikci']);
    String yz(dynamic x) => x == null ? '—' : yuzde(x);
    return [
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Aylık TÜFE (%)', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
          Text('TÜİK her ayın 3\'ünde açıklar; aylık değişimi girin. Boş ay kıyası engeller.${yonetici ? '' : ' (TÜFE değerlerini işletme sahibi ya da müdür girer.)'}', style: TextStyle(color: t.sub, fontSize: 12.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final ay in aylar) KRozet('$ay: ${tufe[ay] != null ? yuzde(tufe[ay]) : 'boş'}', renk: tufe[ay] != null ? t.mavi : t.sub),
          ]),
          if (yonetici && aylar.isNotEmpty) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerLeft, child: KButon('TÜFE gir / düzenle', ikon: Icons.edit_outlined, ikincil: true, onTap: () => _tufeGir(aylar, tufe, yenile))),
          ],
        ]),
      ),
      if (e['eksik'] == true || tamOku(e['eksik']) > 0) SaBilgi('Bazı ayların TÜFE değeri girilmemiş; o ürünlerde enflasyon kıyası boş kaldı.', renk: t.kirmizi),
      if (dizi(e['suphe']).isNotEmpty)
        SaBilgi('${dizi(e['suphe']).length} ürün kıyasa katılmadı: fiyatı 3 katından fazla değişmiş, büyük ihtimalle farklı ambalaj ya da birim: ${dizi(e['suphe']).take(8).join(' · ')}', renk: t.amber),
      if (urun.isEmpty)
        const KBos(baslik: 'Kıyas için veri yok', aciklama: 'Bir ürünün aynı tedarikçiden en az iki farklı ayda alınmış olması gerekir. Dönemi genişletin ya da alış faturaları biriktikçe tekrar bakın.', ikon: Icons.trending_up)
      else ...[
        KBaslik('Tedarikçiler', ikon: Icons.storefront_outlined),
        KKart(
          child: KTablo(basliklar: const ['Tedarikçi', 'Ürün', 'Tutar', 'Ort. zam', 'TÜFE', 'Fark', 'Enflasyon üstü'], sagaYasla: const {1, 2, 3, 4, 5, 6}, satirlar: [
            for (final x in ted) [metinOku(x['ted']), '${x['urun']}', tl(x['tutar'], kisa: true), yz(x['zam']), yz(x['tufe']), x['fark'] == null ? '—' : '${yz(x['fark'])} puan', '${x['ustu']}'],
          ]),
        ),
        KBaslik('Ürünler (enflasyonun en çok üstünde olan başta)', ikon: Icons.inventory_2_outlined, renk: t.kirmizi),
        if (genisMi(context))
          KKart(
            child: KTablo(basliklar: const ['Ürün', 'Tedarikçi', 'İlk', 'Son', 'Zam', 'TÜFE', 'Fark'], sagaYasla: const {2, 3, 4, 5, 6}, satirlar: [
              for (final x in urun.take(300))
                ['${x['ad']} (${x['birim']})', metinOku(x['ted']), '${tl(x['ilk'])} · ${x['ilk_ay']}', '${tl(x['son'])} · ${x['son_ay']}', yz(x['zam']), yz(x['tufe']), x['fark'] == null ? '—' : '${yz(x['fark'])} puan'],
            ]),
          )
        else
          for (final x in urun.take(300))
            KKart(
              renk: sayiOku(x['fark']) > 0 ? t.kirmizi : t.yesil,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${x['ad']} · ${x['ted']}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                Text('${tl(x['ilk'])} (${x['ilk_ay']}) → ${tl(x['son'])} (${x['son_ay']}) · birim: ${x['birim']}', style: TextStyle(color: t.sub, fontSize: 12.5)),
                Text('Zam ${yz(x['zam'])} · TÜFE ${yz(x['tufe'])} · Fark ${x['fark'] == null ? '—' : '${yz(x['fark'])} puan'}',
                    style: TextStyle(color: sayiOku(x['fark']) > 0 ? t.kirmizi : t.yesil, fontWeight: FontWeight.w700, fontSize: 12.5)),
              ]),
            ),
      ],
    ];
  }

  Future<void> _tufeGir(List<String> aylar, Map<String, dynamic> tufe, Future<void> Function() yenile) async {
    final k = {for (final a in aylar) a: TextEditingController(text: tufe[a] != null ? '${tufe[a]}' : '')};
    final ok = await kAltSayfa<bool>(context, baslik: 'Aylık TÜFE (%)', icerik: (c) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final a in aylar) KAlan(a, k[a]!, klavye: const TextInputType.numberWithOptions(decimal: true, signed: true), ipucu: 'ör. 2,47'),
          KButon('Kaydet', genis: true, onTap: () => Navigator.pop(c, true)),
        ]));
    if (ok != true || !mounted) return;
    await saGonder(context, '/fatura-analiz/tufe', {'tufe': {for (final a in aylar) a: k[a]!.text.trim()}}, json: false);
    yenile();
  }

  List<Widget> _iz(Map<String, dynamic> iz, Map<String, dynamic> v, TemaProvider t) {
    final sec = liste(iz['secenek']);
    final sat = liste(iz['sat']);
    final out = <Widget>[
      if (sec.isNotEmpty)
        KSecim<String>('Ürün', deger: '${iz['mid']}', secenekler: [for (final o in sec) ('${o['id']}', '${o['ad']} — ${tl(o['tutar'], kisa: true)}')], onSec: (x) => setState(() => _q['malzeme'] = x ?? '')),
    ];
    if (sat.isEmpty) {
      out.add(const KBos(baslik: 'Bu dönemde alış yok', aciklama: 'Dönemi genişletin ya da alış faturaları girildikçe tekrar bakın.', ikon: Icons.timeline));
      return out;
    }
    final once = <int, double>{};
    final pts = sat.where((x) => x['bilinen'] == true).map((x) => sayiOku(x['pt'])).toList();
    final maks = pts.isEmpty ? 1.0 : pts.reduce((a, b) => a > b ? a : b);
    out.add(KBaslik(metinOku(iz['ad']), alt: 'Fiyat ${metinOku(iz['temel'])} başına (temel birim)', ikon: Icons.timeline));
    for (final x in sat) {
      final tid = tamOku(x['tid']);
      final o = once[tid];
      final pt = sayiOku(x['pt']);
      if (x['bilinen'] == true) once[tid] = pt;
      final degisim = o != null && o > 0 && x['bilinen'] == true ? (pt - o) / o * 100 : null;
      out.add(KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('${tarihYaz(x['tarih'], saat: false)} · ${metinOku(x['ted'])}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13.5))),
            if (degisim != null)
              Text('${degisim > 0 ? '+' : ''}${yuzde(degisim)}', style: TextStyle(color: degisim > .1 ? t.kirmizi : (degisim < -.1 ? t.yesil : t.sub), fontWeight: FontWeight.w700)),
          ]),
          Text('Fatura ${metinOku(x['fatura'], '—')} · ${sayiYaz(x['miktar'])} ${metinOku(x['birim'])} × ${tl(x['fiyat'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: x['bilinen'] == true ? (pt / maks).clamp(.04, 1.0) : 0, minHeight: 8, backgroundColor: t.card2, color: t.mor1))),
            const SizedBox(width: 8),
            Text(x['bilinen'] == true ? '${tl(pt)}/${metinOku(iz['temel'])}' : 'çevrim yok', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 12.5)),
          ]),
        ]),
      ));
    }
    return out;
  }

  List<Widget> _odeme(Map<String, dynamic> o, TemaProvider t) {
    final hafta = harita(o['hafta']);
    final fat = liste(o['fatura']);
    if (fat.isEmpty) return const [KBos(baslik: 'Açık fatura yok', aciklama: 'Tüm alış faturalarının ödemesi carilerde görünüyor ya da son 400 günde alış faturası yok.', ikon: Icons.event_available_outlined)];
    final top = fat.fold<double>(0, (a, x) => a + sayiOku(x['kalan']));
    final gecikmis = harita(hafta.entries.firstWhere((e) => e.key.startsWith('0|'), orElse: () => const MapEntry('', {})).value);
    return [
      KKpiIzgara([
        KKpi(etiket: 'Açık borç', deger: tl(top, kisa: true), alt: '${fat.length} fatura', renk: t.mor1),
        KKpi(etiket: 'Gecikmiş', deger: tl(gecikmis['tutar'], kisa: true), alt: '${tamOku(gecikmis['adet'])} fatura', renk: t.kirmizi),
        KKpi(etiket: 'Tedarikçi', deger: '${o['ted_say'] ?? '—'}', renk: t.mavi),
      ]),
      if (tamOku(o['cari_yok']) > 0) SaBilgi('Ödemeler tedarikçi carisindeki ödemelerden en eski faturadan başlayarak düşüldü. ${o['cari_yok']} tedarikçinin carisi yok; faturaları açık sayıldı.', renk: t.amber),
      KBaslik('Haftalık', ikon: Icons.calendar_month_outlined),
      for (final e in hafta.entries)
        KKart(
          renk: e.key.startsWith('0|') ? t.kirmizi : t.mavi,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(e.key.split('|').length > 1 ? e.key.split('|')[1] : e.key, style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
              Text('${harita(e.value)['adet']} fatura · ${tl(harita(e.value)['tutar'])}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
            ]),
            Text((harita(harita(e.value)['ted']).entries.toList()..sort((a, b) => sayiOku(b.value).compareTo(sayiOku(a.value)))).map((x) => '${x.key} ${tl(x.value, kisa: true)}').join(' · '),
                style: TextStyle(color: t.sub, fontSize: 12.5)),
          ]),
        ),
      KBaslik('Açık Faturalar', ikon: Icons.receipt_long_outlined),
      KKart(
        child: KTablo(basliklar: const ['Vade', 'Tedarikçi', 'Fatura', 'Tarih', 'Toplam', 'Kalan', 'Cari'], sagaYasla: const {4, 5}, satirlar: [
          for (final x in fat) [tarihYaz(x['vade'], saat: false), metinOku(x['ted']), metinOku(x['fatura'], '—'), tarihYaz(x['tarih'], saat: false), tl(x['toplam']), tl(x['kalan']), x['cari'] == true ? 'var' : 'yok'],
        ]),
      ),
    ];
  }
}

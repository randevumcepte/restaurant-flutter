import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

const _efgDurum = {
  'bekliyor': ('Eşleştirme bekliyor', Color(0xFFF59E0B)),
  'aktarildi': ('Aktarıldı', Color(0xFF10B981)),
  'iade': ('İade', Color(0xFF4F46E5)),
  'yok_sayildi': ('Yok sayıldı', Color(0xFF64748B)),
  'tumu': ('Tümü', Color(0xFF7C3AED)),
};

/// Web /efatura-gelen — gelen e-faturalar: entegratör bağlantısı, şimdi çek, XML/ZIP yükle, durum sekmeleri,
/// arama, toplu kartlama, Excel, kalem eşleştirme (detay).
class EfaturaGelenScreen extends StatefulWidget {
  const EfaturaGelenScreen({super.key});
  @override
  State<EfaturaGelenScreen> createState() => _EfaturaGelenScreenState();
}

class _EfaturaGelenScreenState extends State<EfaturaGelenScreen> {
  final _ekran = GlobalKey<KopruEkranState>();
  final _ara = TextEditingController();
  bool _mesgul = false;

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _ekran,
      yol: '/efatura-gelen',
      baslik: 'Gelen e-Faturalar',
      ikon: Icons.move_to_inbox_outlined,
      govde: _govde,
      araclar: (ctx, v, yenile) => [
        IconButton(tooltip: 'Excel (kalemler, fiyat değişimi, denetim)', onPressed: () => saDosyaIndir(context, '/efatura-gelen/excel', 'gelen-efaturalar.xlsx'), icon: const Icon(Icons.table_view_outlined)),
        IconButton(tooltip: 'Fatura Denetim', onPressed: () => saAc(context, '/fatura-denetim', 'Fatura Denetim'), icon: const Icon(Icons.fact_check_outlined)),
      ],
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final b = harita(v['b']);
    final say = harita(v['say']);
    final durum = metinOku(v['durum'], 'tumu');
    final liste0 = liste(v['liste']);
    final eksik = harita(v['eksik']), birimBek = harita(v['birimBek']), kalemSay = harita(v['kalemSay']);
    final ent = harita(v['entegratorler']);
    final suruHazir = b.isNotEmpty && metinOku(b['entegrator']).isNotEmpty && dizi(ent[b['entegrator']]).length > 1 && dizi(ent[b['entegrator']])[1] == true;
    final toplam = say.values.fold<int>(0, (a, x) => a + tamOku(x));
    if (_ara.text.isEmpty && metinOku(v['ara']).isNotEmpty) _ara.text = metinOku(v['ara']);
    return KGovde(yenile: yenile, children: [
      // Entegratör bağlantısı
      KKart(
        renk: t.mor1,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Entegratör Bağlantısı', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15))),
            b['aktif'] == 1 && suruHazir ? KRozet('Otomatik açık', renk: t.yesil) : KRozet('Kapalı', renk: t.sub),
          ]),
          const SizedBox(height: 4),
          Text('Faturalarınız hangi e-fatura entegratörüne geliyorsa onu seçin. Gelen faturalar 15 dakikada bir otomatik çekilir; rakamlar faturadaki gibi birebir gelir.', style: TextStyle(color: t.sub, fontSize: 12.5)),
          if (metinOku(b['son_hata']).isNotEmpty || metinOku(b['son_sonuc']).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(metinOku(b['son_hata']).isNotEmpty ? metinOku(b['son_hata']) : metinOku(b['son_sonuc']), style: TextStyle(color: metinOku(b['son_hata']).isNotEmpty ? t.kirmizi : t.yesil, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (v['yonetici'] == true) KButon('Bağlantı ayarı', ikon: Icons.link, ikincil: true, onTap: () => _baglanti(v, yenile)),
            if (b['aktif'] == 1 && suruHazir) KButon('Şimdi çek', ikon: Icons.sync, yukleniyor: _mesgul, onTap: () => _islem('/efatura-gelen/cek', yenile)),
          ]),
          if (v['yonetici'] != true) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Bağlantı ayarını işletme sahibi ya da müdür yapar.', style: TextStyle(color: t.sub, fontSize: 12))),
        ]),
      ),
      // Yükleme
      KKart(
        renk: t.mavi,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text('Fatura Yükle', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15))),
            KRozet('Ücretsiz', renk: t.yesil),
          ]),
          const SizedBox(height: 4),
          Text('XML / ZIP dosyası seçin (en doğrusu). Aynı fatura iki kez yüklenirse ETTN\'den tanınır. Satırı ya da toplamı tutmayan faturalar otomatik aktarılmaz, kontrol için bekletilir.',
              style: TextStyle(color: t.sub, fontSize: 12.5)),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: KButon('XML / ZIP seç ve yükle', ikon: Icons.upload_file, renk: t.mavi, yukleniyor: _mesgul, onTap: () => _yukle(yenile))),
        ]),
      ),
      KCipler(secenekler: [
        for (final e in _efgDurum.entries) (e.key, '${e.value.$1} (${e.key == 'tumu' ? toplam : tamOku(say[e.key])})'),
      ], secili: durum, onSec: (k) => _ekran.currentState?.sorgu({'durum': k})),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: _ara,
          textInputAction: TextInputAction.search,
          onSubmitted: (s) => _ekran.currentState?.sorgu({'q': s.trim()}),
          decoration: InputDecoration(
            hintText: 'Fatura no / tedarikçi (Enter ile ara)',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
            suffixIcon: IconButton(icon: const Icon(Icons.close), onPressed: () {
              _ara.clear();
              _ekran.currentState?.sorgu({'q': ''});
            }),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      if (v['kartYetki'] == true && tamOku(say['bekliyor']) >= 3)
        SaBilgi(
          'İlk kurulum mu? Geçmiş faturaları tek tek eşleştirmek yerine, eşleşmeyen tüm ürünleri yeni malzeme kartı olarak açıp hepsini aktarabilirsiniz. Aynı ürün tek kart olur.',
          renk: t.amber,
          ikon: Icons.bolt,
          sag: TextButton(onPressed: () => _topluYeni(tamOku(say['bekliyor']), yenile), child: const Text('Tümünü kartla ve aktar')),
        ),
      if (liste0.isEmpty)
        KBos(
          baslik: toplam > 0 ? 'Bu filtrede fatura yok' : 'Henüz gelen e-fatura yok',
          aciklama: toplam > 0 ? 'Başka bir durum sekmesi seçin ya da aramayı temizleyin.' : 'Entegratörü bağlayın ya da e-fatura XML/ZIP dosyası yükleyin.',
          ikon: Icons.move_to_inbox_outlined,
        )
      else
        SaIzgara([
          for (final f in liste0)
            Builder(builder: (_) {
              final d = _efgDurum[metinOku(f['durum'])];
              final ek = tamOku(eksik['${f['id']}']);
              final bb = tamOku(birimBek['${f['id']}']);
              final bek = f['durum'] == 'bekliyor';
              return KKart(
                renk: d?.$2,
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => EfaturaDetayScreen(id: tamOku(f['id']))));
                  yenile();
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(metinOku(f['satici_ad'], '—'), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5))),
                    KRozet(d?.$1 ?? metinOku(f['durum']), renk: d?.$2 ?? t.sub),
                  ]),
                  Text('${metinOku(f['fatura_no'], '—')} · ${tarihYaz(f['tarih'], saat: false)}${f['profil'] == 'TICARIFATURA' ? ' · Ticari${metinOku(f['cevap']).isNotEmpty ? (f['cevap'] == 'kabul' ? ' · kabul edildi' : ' · reddedildi') : ''}' : ''}',
                      style: TextStyle(color: t.sub, fontSize: 12.5)),
                  if (metinOku(f['not']).isNotEmpty) Text(metinOku(f['not']), style: TextStyle(color: t.sub2, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 4, children: [
                    KRozet('${tamOku(kalemSay['${f['id']}'])} kalem', renk: t.mavi),
                    if (ek > 0 && bek) KRozet('$ek eşleşmedi', renk: t.amber),
                    if (bb > 0 && bek) KRozet('$bb birim çevrimi bekliyor', renk: t.kirmizi),
                    if (f['tutarli'] == 0 || f['tutarli'] == false) KRozet('toplam tutmuyor', renk: t.kirmizi),
                  ]),
                  const SizedBox(height: 6),
                  Row(children: [
                    Expanded(child: Text(tl(f['genel_toplam']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15))),
                    Text(bek ? 'Eşleştir →' : 'Aç →', style: TextStyle(color: bek ? t.amber : t.mor1, fontWeight: FontWeight.w700)),
                  ]),
                ]),
              );
            }),
        ], minGenislik: 420),
      if (liste0.length >= 300) Text('İlk 300 fatura gösteriliyor; aramayı kullanın.', style: TextStyle(color: t.sub, fontSize: 12)),
    ]);
  }

  Future<void> _islem(String yol, Future<void> Function() yenile) async {
    setState(() => _mesgul = true);
    await saGonder(context, yol, {}, json: false);
    if (!mounted) return;
    setState(() => _mesgul = false);
    yenile();
  }

  Future<void> _yukle(Future<void> Function() yenile) async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['xml', 'zip'], withData: true);
    if (r == null || r.files.isEmpty || !mounted) return;
    final dosyalar = <(String, String, List<int>)>[for (final f in r.files) if (f.bytes != null) ('dosyalar[]', f.name, f.bytes!)];
    if (dosyalar.isEmpty) return kToast(context, 'Dosya okunamadı.', hata: true);
    setState(() => _mesgul = true);
    final c = await saDosyaYukle(context, '/efatura-gelen/yukle', dosyalar);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (c != null) {
      final m = metinOku(c.j['mesaj']);
      final h = metinOku(c.j['hata']);
      if (m.isNotEmpty) kToast(context, m);
      if (h.isNotEmpty) {
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) kToast(context, h, hata: true);
      }
    }
    yenile();
  }

  Future<void> _topluYeni(int n, Future<void> Function() yenile) async {
    final ok = await kOnay(context, 'Tümünü kartla ve aktar?', aciklama: '$n bekleyen faturadaki eşleşmeyen ürünler için yeni malzeme kartları açılacak ve faturalar alış faturasına aktarılacak.', evet: 'Devam et');
    if (!ok || !mounted) return;
    await _islem('/efatura-gelen/toplu-yeni', yenile);
  }

  Future<void> _baglanti(Map<String, dynamic> v, Future<void> Function() yenile) async {
    final b = harita(v['b']);
    final ent = harita(v['entegratorler']);
    String? e = metinOku(b['entegrator']).isEmpty ? null : metinOku(b['entegrator']);
    String ortam = metinOku(b['ortam'], 'canli');
    bool aktif = b['aktif'] == 1 || b['aktif'] == true;
    bool sil = false;
    String stok = metinOku(b['stok_modu']);
    String bas = metinOku(b['baslangic']);
    if (bas.isEmpty) {
      final d = DateTime.now().subtract(const Duration(days: 30));
      bas = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    }
    final anahtar = TextEditingController();
    final anahtarVar = v['anahtarVar'] == true;
    final ok = await kAltSayfa<bool>(context, baslik: 'Entegratör Bağlantısı', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.watch<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KSecim<String>('Entegratör', deger: e, secenekler: [
              for (final x in ent.entries) (x.key, '${dizi(x.value).isNotEmpty ? dizi(x.value)[0] : x.key}${dizi(x.value).length > 1 && dizi(x.value)[1] == true ? '' : ' (yakında · XML yükleyin)'}'),
            ], onSec: (x) => ss(() => e = x)),
            KAlan('API anahtarı${anahtarVar ? ' · kayıtlı' : ''}', anahtar, ipucu: anahtarVar ? 'Değiştirmek için yeni anahtarı yazın' : 'Entegratör portalından alınır'),
            KSatir(baslik: 'İlk çekim başlangıcı', alt: tarihYaz(bas, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
              final s = await saTarihSec(c, ilk: bas);
              if (s != null) ss(() => bas = s);
            }),
            const SizedBox(height: 8),
            KSecim<String>('Stok girişi', deger: stok, secenekler: [
              ('', 'Otomatik (${v['stokModu'] == 'mal_kabul' ? 'mal kabulde' : 'faturadan'})'),
              ('mal_kabul', 'Mal kabulde yapılıyor (fatura yalnız finansal)'),
              ('fatura', 'Faturadan stok girişi yap'),
            ], onSec: (x) => ss(() => stok = x ?? '')),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: aktif, onChanged: (x) => ss(() => aktif = x), title: Text('Otomatik çek', style: TextStyle(color: t.ink))),
            KCipler(secenekler: const [('canli', 'Canlı'), ('test', 'Test')], secili: ortam, onSec: (x) => ss(() => ortam = x)),
            if (anahtarVar)
              CheckboxListTile(contentPadding: EdgeInsets.zero, value: sil, onChanged: (x) => ss(() => sil = x == true), title: Text('Anahtarı sil', style: TextStyle(color: t.kirmizi))),
            KButon('Kaydet ve test et', ikon: Icons.link, genis: true, onTap: () => Navigator.pop(c, true)),
          ]);
        }));
    if (ok != true || !mounted) return;
    final c = await saGonder(context, '/efatura-gelen/baglanti', {
      'entegrator': e ?? '', 'api_anahtar': anahtar.text.trim(), 'baslangic': bas, 'stok_modu': stok, 'ortam': ortam,
      if (aktif) 'aktif': '1', if (sil) 'anahtar_sil': '1',
    }, json: false);
    if (c != null) yenile();
  }
}

// ───────────────────────── Detay: kalem eşleştirme ─────────────────────────
class EfaturaDetayScreen extends StatefulWidget {
  final int id;
  const EfaturaDetayScreen({super.key, required this.id});
  @override
  State<EfaturaDetayScreen> createState() => _EfaturaDetayScreenState();
}

class _EfdKalem {
  String malzeme = '';
  int birim = 0;
  final cevrim = TextEditingController();
  final yeniAd = TextEditingController();
}

class _EfaturaDetayScreenState extends State<EfaturaDetayScreen> {
  final _ekran = GlobalKey<KopruEkranState>();
  Map<int, _EfdKalem>? _k;
  bool _mesgul = false;

  @override
  Widget build(BuildContext context) {
    return KopruEkran(key: _ekran, yol: '/efatura-gelen/${widget.id}', baslik: 'Gelen e-Fatura', ikon: Icons.move_to_inbox_outlined, govde: _govde);
  }

  Future<void> _yenile() async {
    _k = null;
    await _ekran.currentState?.yukle();
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final g = harita(v['g']);
    if (g.isEmpty) return const KBos(baslik: 'Fatura bulunamadı', aciklama: 'Fatura silinmiş ya da başka şubeye ait olabilir.');
    final kalemler = liste(v['kalemler']);
    final malz = liste(v['malzemeler']);
    final birimler = liste(v['birimler']);
    final birimAd = {for (final b in birimler) tamOku(b['id']): metinOku(b['kisaltma'], metinOku(b['ad']))};
    final temelMap = {for (final m in malz) '${m['id']}': tamOku(m['temel_birim_id'])};
    final durum = metinOku(g['durum']);
    final acik = durum == 'bekliyor' || durum == 'iade';
    final kartYetki = v['kartYetki'] == true;
    final tutarli = g['tutarli'] == 1 || g['tutarli'] == true;
    _k ??= {
      for (final k in kalemler)
        tamOku(k['id']): _EfdKalem()
          ..malzeme = k['malzeme_id'] != null ? '${k['malzeme_id']}' : (harita(k['oneri'])['id'] != null ? '${harita(k['oneri'])['id']}' : '')
          ..birim = tamOku(k['alis_birim_id'])
          ..cevrim.text = k['cevrim'] != null ? sayiYaz(k['cevrim']) : ''
          ..yeniAd.text = metinOku(k['ad']),
    };
    final eksik = kalemler.where((k) => k['malzeme_id'] == null).length;
    final kalemNet = kalemler.fold<double>(0, (a, k) => a + sayiOku(k['satir_tutar']));
    final ted = harita(v['tedarikci']);
    final d = _efgDurum[durum];
    return KGovde(yenile: _yenile, maxGenislik: 1000, children: [
      Row(children: [
        Expanded(child: Text('${metinOku(g['fatura_no'], 'ETTN')} · ${metinOku(g['satici_ad'], 'Tedarikçi')}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 16))),
        KRozet(durum == 'aktarildi' ? 'Alış faturasına aktarıldı' : (durum == 'iade' ? 'İade faturası' : (d?.$1 ?? durum)), renk: d?.$2 ?? t.sub),
      ]),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (metinOku(g['xml_yol']).isNotEmpty) KButon('XML indir', ikon: Icons.code, ikincil: true, onTap: () => saDosyaIndir(context, '/efatura-gelen/${g['id']}/xml', 'efatura-${metinOku(g['fatura_no'], '${g['id']}')}.xml')),
        if (durum == 'aktarildi') KButon('Fiyat Radarı', ikon: Icons.radar, ikincil: true, onTap: () => saAc(context, '/fiyat-radari', 'Fiyat Radarı')),
      ]),
      const SizedBox(height: 10),
      KKpiIzgara([
        KKpi(etiket: 'Tedarikçi', deger: metinOku(ted['ad'], metinOku(g['satici_ad'], '—')), alt: 'VKN ${metinOku(g['satici_vkn'], '—')}', renk: t.mor1),
        KKpi(etiket: 'Fatura', deger: metinOku(g['fatura_no'], '—'), alt: '${tarihYaz(g['tarih'], saat: false)} · ${g['profil'] == 'TICARIFATURA' ? 'Ticari' : (g['profil'] == 'TEMELFATURA' ? 'Temel' : metinOku(g['profil']))} · ${metinOku(g['tip'])}', renk: t.mavi),
        KKpi(etiket: 'Mal / hizmet (KDV hariç)', deger: tl(g['ara_toplam']), alt: sayiOku(g['iskonto']) > 0 ? 'İskonto ${tl(g['iskonto'])}' : null, renk: t.sub),
        KKpi(etiket: 'KDV', deger: tl(g['kdv_toplam']), renk: t.amber),
        KKpi(etiket: 'Ödenecek', deger: tl(g['genel_toplam']), alt: metinOku(g['para_birimi'], 'TRY') != 'TRY' ? '${g['para_birimi']} · kur ${sayiYaz(g['kur'])}' : null, renk: t.mor1),
      ]),
      if (!tutarli) SaBilgi('Kalemlerin toplamı (${tl(kalemNet)}) faturadaki mal/hizmet toplamını (${tl(g['ara_toplam'])}) tutmuyor. Bu yüzden otomatik aktarılmadı; kalemleri faturayla karşılaştırın.', renk: t.kirmizi, ikon: Icons.error_outline),
      if (metinOku(g['not']).isNotEmpty) SaBilgi(metinOku(g['not']), renk: t.amber),
      KBaslik('Kalemler', ikon: Icons.list_alt, renk: t.amber, sag: acik && eksik > 0 ? KRozet('$eksik kalem eşleşmedi', renk: t.amber) : null),
      for (final k in kalemler) _kalemKart(k, t, acik, kartYetki, malz, birimler, birimAd, temelMap),
      SaDeger('Kalem toplamı (KDV hariç)', tl(kalemNet), kalin: true),
      const SizedBox(height: 10),
      if (acik) ...[
        KButon(durum == 'iade' ? 'Eşleştirmeyi kaydet' : (tutarli ? 'Kaydet ve alış faturasına aktar' : 'Eşleştirmeyi kaydet'), ikon: Icons.done_all, renk: t.yesil, genis: true, yukleniyor: _mesgul, onTap: _kaydet),
        const SizedBox(height: 6),
        Text('Stok: ${v['stokModu'] == 'mal_kabul' ? 'mal kabulde yazılır; bu fatura finansal kayıt olur ve mal kabulle karşılaştırılır.' : 'bu faturadan stok girişi yapılır.'} Alış birimi temel birimden farklıysa çevrimi girin (ör. 1 Koli = 12 Adet).',
            style: TextStyle(color: t.sub, fontSize: 12)),
      ],
      if (acik && !tutarli && eksik == 0 && durum == 'bekliyor')
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: KButon('Kontrol ettim, yine de aktar', ikon: Icons.warning_amber_outlined, renk: t.kirmizi, ikincil: true, onTap: () async {
            if (!await kOnay(context, 'Toplam tutmuyor. Yine de aktarılsın mı?', tehlikeli: true, evet: 'Aktar')) return;
            if (!context.mounted) return;
            await saGonder(context, '/efatura-gelen/${g['id']}/aktar', {}, json: false);
            _yenile();
          }),
        ),
      const SizedBox(height: 14),
      if (v['cevapVerilir'] == true)
        KKart(
          renk: t.mavi,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Ticari fatura yanıtı', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
            Text('Ticari faturada 8 gün içinde kabul ya da red yanıtı verebilirsiniz. Miktar ya da fiyat siparişle uyuşmuyorsa reddedin.', style: TextStyle(color: t.sub, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: KButon('Kabul et', renk: t.yesil, onTap: () => _cevap(g, true))),
              const SizedBox(width: 8),
              Expanded(child: KButon('Reddet', renk: t.kirmizi, onTap: () => _cevap(g, false))),
            ]),
          ]),
        ),
      if (durum == 'bekliyor' || durum == 'iade')
        Align(alignment: Alignment.centerLeft, child: KButon('Yok say', ikon: Icons.visibility_off_outlined, ikincil: true, onTap: () => _yoksay(g, false)))
      else if (durum == 'yok_sayildi')
        Align(alignment: Alignment.centerLeft, child: KButon('Tekrar beklemeye al', ikon: Icons.undo, ikincil: true, onTap: () => _yoksay(g, true))),
    ]);
  }

  Widget _kalemKart(Map<String, dynamic> k, TemaProvider t, bool acik, bool kartYetki, List<Map<String, dynamic>> malz, List<Map<String, dynamic>> birimler, Map<int, String> birimAd, Map<String, int> temelMap) {
    final s = _k![tamOku(k['id'])]!;
    final temel = temelMap[s.malzeme] ?? tamOku(k['temel_birim_id']);
    final farkli = s.malzeme.isNotEmpty && s.malzeme != 'yeni' && temel > 0 && s.birim > 0 && temel != s.birim;
    final es = metinOku(k['eslesme']);
    final oneri = harita(k['oneri']);
    String esMetin;
    Color esRenk;
    switch (es) {
      case 'birim':
        esMetin = 'Bu ürün daha önce başka birimle geldi; "1 ${birimAd[tamOku(k['alis_birim_id'])] ?? 'birim'} = kaç" girip kaydedin';
        esRenk = t.kirmizi;
      case 'hafiza':
        esMetin = 'Hafızadan eşleşti';
        esRenk = t.yesil;
      case 'ad':
        esMetin = 'Aynı adla eşleşti';
        esRenk = t.yesil;
      case 'elle':
        esMetin = 'Elle eşleştirildi';
        esRenk = t.yesil;
      default:
        esMetin = oneri.isNotEmpty ? 'Öneri: ${oneri['ad']} (kaydedince onaylanır)' : 'Listede yoksa "Yeni malzeme oluştur"';
        esRenk = oneri.isNotEmpty ? t.amber : t.sub;
    }
    return KKart(
      renk: k['malzeme_id'] == null ? t.amber : t.yesil,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Text('${k['sira']}. ', style: TextStyle(color: t.sub, fontWeight: FontWeight.w700)),
          Expanded(child: Text(metinOku(k['ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
          Text(tl(k['satir_tutar']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
        ]),
        if (metinOku(k['stok_kodu']).isNotEmpty) Text('Stok kodu: ${k['stok_kodu']}', style: TextStyle(color: t.sub, fontSize: 12)),
        Text('${sayiYaz(k['miktar'])} ${birimAd[tamOku(k['alis_birim_id'])] ?? metinOku(k['birim_kodu'])} × ${tl(k['birim_fiyat'])}${sayiOku(k['iskonto']) > 0 ? ' (liste ${tl(k['liste_fiyat'])})' : ''} · KDV %${sayiYaz(k['kdv_yuzde'])}',
            style: TextStyle(color: t.sub2, fontSize: 12.5)),
        const SizedBox(height: 8),
        if (!acik)
          SaDeger('Bizim malzeme', '${metinOku(k['malzeme_ad'], '—')} · ${birimAd[tamOku(k['alis_birim_id'])] ?? '—'}')
        else ...[
          KSecim<String>('Bizim malzeme', deger: s.malzeme, secenekler: [
            ('', '— Eşleştirilmedi —'),
            if (kartYetki) ('yeni', '+ Yeni malzeme oluştur'),
            for (final m in malz) ('${m['id']}', metinOku(m['ad'])),
          ], onSec: (x) => setState(() => s.malzeme = x ?? '')),
          if (s.malzeme == 'yeni') KAlan('Yeni malzeme adı', s.yeniAd),
          Text(esMetin, style: TextStyle(color: esRenk, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: KSecim<int>('Alış birimi', deger: s.birim == 0 ? null : s.birim, secenekler: [for (final b in birimler) (tamOku(b['id']), metinOku(b['ad']))], onSec: (x) => setState(() => s.birim = x ?? 0)),
            ),
            if (farkli) ...[
              const SizedBox(width: 8),
              Expanded(child: KAlan('1 ${birimAd[s.birim] ?? ''} = ? ${birimAd[temel] ?? ''}', s.cevrim, klavye: const TextInputType.numberWithOptions(decimal: true))),
            ],
          ]),
        ],
      ]),
    );
  }

  Future<void> _kaydet() async {
    final kalem = <String, dynamic>{};
    _k!.forEach((id, s) {
      kalem['$id'] = {'malzeme': s.malzeme, 'birim': s.birim, 'cevrim': s.cevrim.text.trim(), if (s.malzeme == 'yeni') 'yeni_ad': s.yeniAd.text.trim()};
    });
    setState(() => _mesgul = true);
    await saGonder(context, '/efatura-gelen/${widget.id}/eslestir', {'kalem': kalem}, json: false);
    if (!mounted) return;
    setState(() => _mesgul = false);
    _yenile();
  }

  Future<void> _cevap(Map<String, dynamic> g, bool kabul) async {
    String not = '';
    if (!kabul) {
      final s = await saMetinSor(context, 'Fatura reddedilsin mi?', aciklama: 'Fatura reddedilecek ve tedarikçiye bildirilecek.', ipucu: 'Red gerekçesi (zorunlu)', enAz: 3, evet: 'Reddet', tehlikeli: true);
      if (s == null) return;
      not = s;
    } else if (!await kOnay(context, 'Kabul yanıtı gönderilsin mi?', evet: 'Kabul et')) {
      return;
    }
    if (!mounted) return;
    await saGonder(context, '/efatura-gelen/${g['id']}/cevap', {'islem': kabul ? 'kabul' : 'red', 'not': not}, json: false);
    _yenile();
  }

  Future<void> _yoksay(Map<String, dynamic> g, bool geri) async {
    if (!geri && !await kOnay(context, 'Fatura yok sayılsın mı?', aciklama: 'Bu fatura alış faturasına aktarılmayacak.', tehlikeli: true, evet: 'Yok say')) return;
    if (!mounted) return;
    final c = await saGonder(context, '/efatura-gelen/${g['id']}/yoksay', {if (geri) 'geri': '1'}, json: false);
    if (!mounted) return;
    if (c?.ok == true && !geri) {
      Navigator.pop(context);
    } else {
      _yenile();
    }
  }
}

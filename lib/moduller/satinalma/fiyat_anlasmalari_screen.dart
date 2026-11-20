import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

const _faDurum = {
  'aktif': ('Yürürlükte', Color(0xFF10B981)),
  'yakinda': ('Bitiyor', Color(0xFFF59E0B)),
  'baslamadi': ('Başlamadı', Color(0xFF4F46E5)),
  'bitti': ('Süresi bitti', Color(0xFFF43F5E)),
  'durdu': ('Durduruldu', Color(0xFF64748B)),
};
const _fiyatMaddesi = [('sabit', 'Sabit fiyat'), ('tavan', 'Artış tavanlı'), ('endeks', 'Endeksli (TÜFE vb.)'), ('serbest', 'Serbest / bildirimli')];

/// Web /fiyat-anlasmalari — tekli fiyat anlaşmaları + çerçeve sözleşmeler (kalemler, şartlar, belgeler), ihlal (fazla ödenen),
/// piyasa farkı. Düzenleme yalnız `duzenler` bayrağı olanlarda (web ile aynı yetki seviyesi); `salt` görenler belge görmez.
class FiyatAnlasmalariScreen extends StatefulWidget {
  const FiyatAnlasmalariScreen({super.key});
  @override
  State<FiyatAnlasmalariScreen> createState() => _FiyatAnlasmalariScreenState();
}

class _FiyatAnlasmalariScreenState extends State<FiyatAnlasmalariScreen> {
  String _sekme = 'tekli';
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/fiyat-anlasmalari',
      baslik: 'Fiyat Anlaşmaları',
      ikon: Icons.handshake_outlined,
      govde: _govde,
      araclar: (ctx, v, yenile) => [
        if (v['salt'] != true)
          IconButton(tooltip: 'Raporlar', onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FiyatAnlasmaRaporScreen())), icon: const Icon(Icons.insights)),
      ],
      fab: (ctx, v, yenile) => v['duzenler'] == true
          ? FloatingActionButton.extended(
              heroTag: 'fa_yeni',
              onPressed: () => _sekme == 'tekli' ? _anlasmaForm(v, yenile) : _sozlesmeForm(v, yenile),
              icon: const Icon(Icons.add),
              label: Text(_sekme == 'tekli' ? 'Yeni Anlaşma' : 'Yeni Sözleşme', style: const TextStyle(fontWeight: FontWeight.w700)),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final kpi = harita(v['kpi']);
    final kartlar = liste(v['kartlar']).where((k) => saIcerir('${k['ted']} ${k['mal']}', _ara)).toList();
    final soz = liste(v['sozKart']).where((s) => saIcerir('${s['ted']} ${s['sozlesme_no']} ${s['baslik']} ${liste(s['kalemler']).map((x) => x['ad']).join(' ')}', _ara)).toList();
    final duzen = v['duzenler'] == true;
    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Yürürlükte', deger: '${kpi['aktif']}', ikon: Icons.verified_outlined, renk: t.yesil),
        KKpi(etiket: 'Yakında bitiyor', deger: '${kpi['yakinda']}', ikon: Icons.hourglass_bottom, renk: t.amber),
        KKpi(etiket: 'Süresi biten', deger: '${kpi['bitti']}', ikon: Icons.event_busy_outlined, renk: t.sub),
        KKpi(etiket: 'Anlaşma ihlali', deger: '${kpi['ihlal']}', alt: 'Fazla ödenen: ${tl(kpi['fazla'], kisa: true)}', ikon: Icons.warning_amber_outlined, renk: t.kirmizi),
      ]),
      if (!duzen) const SaBilgi('Görüntüleme yetkiniz var; anlaşma eklemek/düzenlemek için "Fiyat Anlaşmaları – düzenle" yetkisi gerekir.', ikon: Icons.lock_outline),
      KCipler(secenekler: [('tekli', 'Tekli anlaşmalar (${liste(v['kartlar']).length})'), ('sozlesme', 'Çerçeve sözleşmeler (${liste(v['sozKart']).length})')], secili: _sekme, onSec: (k) => setState(() => _sekme = k)),
      KAra(ipucu: 'Tedarikçi, malzeme, sözleşme no ara…', onDegis: (s) => setState(() => _ara = s)),
      if (_sekme == 'tekli') ...[
        if (kartlar.isEmpty)
          const KBos(baslik: 'Fiyat anlaşması yok', aciklama: 'Tedarikçiyle anlaştığınız sabit fiyatı ekleyin; siparişte bu fiyat kullanılır, faturada aşılırsa ihlal olarak işaretlenir.', ikon: Icons.handshake_outlined)
        else
          SaIzgara([for (final k in kartlar) _anlasmaKart(k, v, t, yenile)], minGenislik: 420),
      ] else ...[
        if (soz.isEmpty)
          const KBos(baslik: 'Çerçeve sözleşme yok', aciklama: 'Bir tedarikçiyle birden çok malzeme için imzaladığınız sözleşmeyi (şartlar + belgeler) buraya ekleyin.', ikon: Icons.description_outlined)
        else
          SaIzgara([for (final s in soz) _sozlesmeKart(s, v, t, yenile)], minGenislik: 460),
      ],
    ]);
  }

  Widget _belgeler(List<Map<String, dynamic>> b, bool duzen, Future<void> Function() yenile, TemaProvider t) {
    if (b.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (final x in b)
        InputChip(
          avatar: Icon(Icons.attach_file, size: 16, color: t.mor1),
          label: Text(metinOku(x['ad']), style: TextStyle(fontSize: 12.5, color: t.ink)),
          onPressed: () => saDosyaIndir(context, '/fiyat-anlasmalari/belge/${x['id']}', metinOku(x['ad'], 'belge'), q: {'indir': '1'}),
          onDeleted: duzen
              ? () async {
                  if (!await kOnay(context, 'Belge silinsin mi?', aciklama: metinOku(x['ad']), tehlikeli: true, evet: 'Sil')) return;
                  if (!mounted) return;
                  await saGonder(context, '/fiyat-anlasmalari/belge-sil', {'id': x['id']}, json: false);
                  yenile();
                }
              : null,
        ),
    ]);
  }

  Widget _anlasmaKart(Map<String, dynamic> k, Map<String, dynamic> v, TemaProvider t, Future<void> Function() yenile) {
    final d = _faDurum[metinOku(k['durum'])];
    final duzen = v['duzenler'] == true;
    final ihlal = tamOku(k['ihlal_say']) > 0;
    return KKart(
      renk: ihlal ? t.kirmizi : d?.$2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(metinOku(k['mal']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15))),
          KRozet(d?.$1 ?? metinOku(k['durum']), renk: d?.$2 ?? t.sub),
        ]),
        Text('${metinOku(k['ted'])}${metinOku(k['sozlesme_ad']).isNotEmpty ? ' · ${k['sozlesme_ad']}' : ''}', style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 6),
        Text('${tl(k['fiyat'])}${metinOku(k['birim']).isNotEmpty ? ' / ${k['birim']}' : ''}', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w800, fontSize: 18)),
        Text('${metinOku(k['baslangic']).isEmpty ? 'Başlangıç yok' : tarihYaz(k['baslangic'], saat: false)} → ${metinOku(k['bitis']).isEmpty ? 'Süresiz' : tarihYaz(k['bitis'], saat: false)}${k['kalan'] != null ? ' · ${k['kalan']} gün kaldı' : ''}',
            style: TextStyle(color: t.sub2, fontSize: 12.5)),
        if (k['ilerleme'] != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: LinearProgressIndicator(value: (sayiOku(k['ilerleme']) / 100).clamp(0, 1).toDouble(), minHeight: 5, backgroundColor: t.line, color: d?.$2 ?? t.mor1)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          KRozet('${k['fatura_say']} fatura kalemi', renk: t.mavi),
          if (ihlal) KRozet('${k['ihlal_say']} ihlal · fazla ${tl(k['fazla'], kisa: true)}', renk: t.kirmizi),
          if (k['son_fiyat'] != null) KRozet('Son fatura: ${tl(k['son_fiyat'])}', renk: t.sub),
          if (k['piyasa'] != null)
            KRozet('Piyasa: ${tl(k['piyasa'])} (${sayiOku(k['piyasa_fark']) > 0 ? '+' : ''}${k['piyasa_fark']}%)', renk: sayiOku(k['piyasa_fark']) > 0 ? t.amber : t.yesil),
          if (k['taahhut'] != null) KRozet('Taahhüt: ${sayiYaz(k['taahhut'])}/ay', renk: t.mor1),
        ]),
        if (metinOku(k['not']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Not: ${k['not']}', style: TextStyle(color: t.sub2, fontSize: 12.5))),
        if (v['salt'] != true) Padding(padding: const EdgeInsets.only(top: 6), child: _belgeler(liste(k['belgeler']), duzen && k['sozlesme_id'] == null, yenile, t)),
        if (duzen && k['sozlesme_id'] == null) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            KButon('Düzenle', ikon: Icons.edit_outlined, ikincil: true, onTap: () => _anlasmaForm(v, yenile, k: k)),
            KButon(tamOku(k['aktif']) == 1 ? 'Durdur' : 'Yeniden başlat', ikon: tamOku(k['aktif']) == 1 ? Icons.pause_circle_outline : Icons.play_circle_outline, ikincil: true, renk: t.amber, onTap: () async {
              await saGonder(context, '/fiyat-anlasmalari/durum', {'id': k['id']}, json: false);
              yenile();
            }),
            KButon('Sil', ikon: Icons.delete_outline, ikincil: true, renk: t.kirmizi, onTap: () async {
              if (!await kOnay(context, 'Anlaşma silinsin mi?', aciklama: '${k['mal']} · ${k['ted']} (belgeleriyle birlikte)', tehlikeli: true, evet: 'Sil')) return;
              if (!mounted) return;
              await saGonder(context, '/fiyat-anlasmalari/durum', {'id': k['id'], 'sil': 1}, json: false);
              yenile();
            }),
          ]),
        ] else if (duzen && k['sozlesme_id'] != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text('Bu fiyat bir çerçeve sözleşmeye bağlı; sözleşme sekmesinden düzenlenir.', style: TextStyle(color: t.sub, fontSize: 12))),
      ]),
    );
  }

  Widget _sozlesmeKart(Map<String, dynamic> s, Map<String, dynamic> v, TemaProvider t, Future<void> Function() yenile) {
    final d = _faDurum[metinOku(s['durum'])];
    final duzen = v['duzenler'] == true;
    final kal = liste(s['kalemler']);
    final fm = _fiyatMaddesi.firstWhere((x) => x.$1 == s['fiyat_maddesi'], orElse: () => ('', '')).$2;
    return KKart(
      renk: tamOku(s['ihlal']) > 0 ? t.kirmizi : d?.$2,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(metinOku(s['sozlesme_no']).isNotEmpty ? '${s['sozlesme_no']}${metinOku(s['baslik']).isNotEmpty ? ' · ${s['baslik']}' : ''}' : metinOku(s['baslik'], 'Sözleşme #${s['id']}'),
              style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15))),
          KRozet(d?.$1 ?? metinOku(s['durum']), renk: d?.$2 ?? t.sub),
        ]),
        Text(metinOku(s['ted']), style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 4),
        Text('${metinOku(s['baslangic']).isEmpty ? '—' : tarihYaz(s['baslangic'], saat: false)} → ${metinOku(s['bitis']).isEmpty ? 'Süresiz' : tarihYaz(s['bitis'], saat: false)}${s['kalan'] != null ? ' · ${s['kalan']} gün kaldı' : ''}',
            style: TextStyle(color: t.sub2, fontSize: 12.5)),
        if (s['fesih_son'] != null)
          Text('Fesih ihbarı için son gün: ${tarihYaz(s['fesih_son'], saat: false)}${s['fesih_kalan'] != null ? ' (${s['fesih_kalan']} gün)' : ''}',
              style: TextStyle(color: sayiOku(s['fesih_kalan']) <= 30 ? t.kirmizi : t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (fm.isNotEmpty) KRozet('$fm${s['artis_tavan'] != null ? ' %${sayiYaz(s['artis_tavan'])}' : ''}', renk: t.mor1),
          if (s['odeme_vade_gun'] != null) KRozet('Vade ${s['odeme_vade_gun']} gün', renk: t.mavi),
          if (metinOku(s['teslim_suresi']).isNotEmpty) KRozet('Teslim: ${s['teslim_suresi']}', renk: t.mavi),
          if (metinOku(s['imza_tarihi']).isNotEmpty) KRozet('İmza: ${tarihYaz(s['imza_tarihi'], saat: false)}${metinOku(s['imzalayan']).isNotEmpty ? ' · ${s['imzalayan']}' : ''}', renk: t.sub),
          if (tamOku(s['ihlal']) > 0) KRozet('${s['ihlal']} ihlal · fazla ${tl(s['fazla'], kisa: true)}', renk: t.kirmizi),
        ]),
        const Divider(),
        for (final x in kal)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(children: [
              Expanded(child: Text(metinOku(x['ad']), style: TextStyle(color: t.ink, fontSize: 13.5))),
              if (tamOku(x['ihlal']) > 0) Padding(padding: const EdgeInsets.only(right: 6), child: KRozet('${x['ihlal']} ihlal', renk: t.kirmizi)),
              Text('${tl(x['fiyat'])}${metinOku(x['birim']).isNotEmpty ? '/${x['birim']}' : ''}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ]),
          ),
        if (metinOku(s['fiyat_maddesi_not']).isNotEmpty) Text('Fiyat maddesi: ${s['fiyat_maddesi_not']}', style: TextStyle(color: t.sub2, fontSize: 12.5)),
        if (metinOku(s['not']).isNotEmpty) Text('Not: ${s['not']}', style: TextStyle(color: t.sub2, fontSize: 12.5)),
        if (v['salt'] != true) Padding(padding: const EdgeInsets.only(top: 6), child: _belgeler(liste(s['belgeler']), duzen, yenile, t)),
        if (duzen) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            KButon('Düzenle', ikon: Icons.edit_outlined, ikincil: true, onTap: () => _sozlesmeForm(v, yenile, s: s)),
            KButon(tamOku(s['aktif']) == 1 ? 'Durdur' : 'Yeniden yürürlüğe al', ikon: tamOku(s['aktif']) == 1 ? Icons.pause_circle_outline : Icons.play_circle_outline, ikincil: true, renk: t.amber, onTap: () async {
              await saGonder(context, '/fiyat-anlasmalari/sozlesme-durum', {'id': s['id']}, json: false);
              yenile();
            }),
            KButon('Sil', ikon: Icons.delete_outline, ikincil: true, renk: t.kirmizi, onTap: () async {
              if (!await kOnay(context, 'Sözleşme silinsin mi?', aciklama: 'Sözleşme, malzeme fiyatları ve belgeleri silinecek.', tehlikeli: true, evet: 'Sil')) return;
              if (!mounted) return;
              await saGonder(context, '/fiyat-anlasmalari/sozlesme-durum', {'id': s['id'], 'sil': 1}, json: false);
              yenile();
            }),
          ]),
        ],
      ]),
    );
  }

  Future<List<(String, String, List<int>)>> _belgeSec() async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.custom, allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'doc', 'docx', 'xls', 'xlsx'], withData: true);
    return [for (final f in r?.files ?? <PlatformFile>[]) if (f.bytes != null) ('belgeler[]', f.name, f.bytes!)];
  }

  Future<void> _gonderCok(String yol, Map<String, String> alanlar, List<(String, String, List<int>)> dosyalar, Future<void> Function() yenile) async {
    final c = await saDosyaYukle(context, yol, dosyalar, alanlar: alanlar);
    if (c == null || !mounted) return;
    final m = metinOku(c.j['mesaj']), h = metinOku(c.j['hata']);
    if (h.isNotEmpty) {
      kToast(context, h, hata: true);
    } else {
      kToast(context, m.isEmpty ? 'Kaydedildi.' : m);
    }
    yenile();
  }

  Future<void> _anlasmaForm(Map<String, dynamic> v, Future<void> Function() yenile, {Map<String, dynamic>? k}) async {
    int? ted = k == null ? null : tamOku(k['ted_id']);
    int? mal = k == null ? null : tamOku(k['mal_id']);
    final fiyat = TextEditingController(text: k == null ? '' : '${k['fiyat']}');
    final birim = TextEditingController(text: metinOku(k?['birim']));
    final taah = TextEditingController(text: k?['taahhut'] == null ? '' : '${k!['taahhut']}');
    final not = TextEditingController(text: metinOku(k?['not']));
    var bas = metinOku(k?['baslangic']), bit = metinOku(k?['bitis']);
    var dosyalar = <(String, String, List<int>)>[];
    final ipucu = harita(v['ipucu']), malBirim = harita(v['malBirim']);
    final ok = await kAltSayfa<bool>(context, baslik: k == null ? 'Yeni Fiyat Anlaşması' : 'Anlaşmayı Düzenle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.watch<TemaProvider>();
          final ip = harita(ipucu['$ted-$mal']);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KSecim<int>('Tedarikçi', deger: ted, secenekler: [for (final x in liste(v['tedarikciler'])) (tamOku(x['id']), metinOku(x['ad']))], onSec: (x) => ss(() => ted = x)),
            KSecim<int>('Malzeme', deger: mal, secenekler: [for (final x in liste(v['malzemeler'])) (tamOku(x['id']), metinOku(x['ad']))], onSec: (x) => ss(() {
                  mal = x;
                  if (birim.text.isEmpty) birim.text = metinOku(malBirim['$x']);
                })),
            if (ip.isNotEmpty) Text('Son alış: ${tl(ip['f'])}${metinOku(ip['b']).isNotEmpty ? '/${ip['b']}' : ''} · ${tarihYaz(ip['t'], saat: false)}', style: TextStyle(color: t.mavi, fontSize: 12.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: KAlan('Anlaşma fiyatı (₺)', fiyat, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true)),
              const SizedBox(width: 8),
              Expanded(child: KAlan('Birim', birim, ipucu: 'kg / lt / adet')),
            ]),
            Row(children: [
              Expanded(child: KSatir(baslik: 'Başlangıç', alt: bas.isEmpty ? 'Seçilmedi' : tarihYaz(bas, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
                final s = await saTarihSec(c, ilk: bas);
                if (s != null) ss(() => bas = s);
              })),
              const SizedBox(width: 8),
              Expanded(child: KSatir(baslik: 'Bitiş', alt: bit.isEmpty ? 'Süresiz' : tarihYaz(bit, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
                final s = await saTarihSec(c, ilk: bit);
                if (s != null) ss(() => bit = s);
              })),
            ]),
            KAlan('Aylık taahhüt miktarı (ops.)', taah, klavye: const TextInputType.numberWithOptions(decimal: true)),
            KAlan('Not', not, satir: 2),
            KButon('Belge ekle (${dosyalar.length})', ikon: Icons.attach_file, ikincil: true, onTap: () async {
              final d = await _belgeSec();
              ss(() => dosyalar = [...dosyalar, ...d]);
            }),
            if (dosyalar.isNotEmpty) Text(dosyalar.map((d) => d.$2).join(', '), style: TextStyle(color: t.sub, fontSize: 12)),
            const SizedBox(height: 10),
            KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () {
              if (ted == null || mal == null) return kToast(c, 'Tedarikçi ve malzeme seçin.', hata: true);
              if (sayiOku(fiyat.text) <= 0) return kToast(c, 'Anlaşma fiyatı girin.', hata: true);
              if (bas.isNotEmpty && bit.isNotEmpty && bit.compareTo(bas) < 0) return kToast(c, 'Bitiş tarihi başlangıçtan önce olamaz.', hata: true);
              Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok != true || !mounted) return;
    await _gonderCok('/fiyat-anlasmalari/ekle', {
      if (k != null) 'id': '${k['id']}',
      'tedarikci_id': '$ted', 'malzeme_id': '$mal', 'birim_fiyat': fiyat.text.trim(), 'birim': birim.text.trim(), 'baslangic': bas, 'bitis': bit, 'taahhut_miktar': taah.text.trim(), 'not': not.text.trim(),
    }, dosyalar, yenile);
  }

  Future<void> _sozlesmeForm(Map<String, dynamic> v, Future<void> Function() yenile, {Map<String, dynamic>? s}) async {
    int? ted = s == null ? null : tamOku(s['ted_id']);
    TextEditingController k0(String a) => TextEditingController(text: s == null || s[a] == null ? '' : '${s[a]}');
    final no = k0('sozlesme_no'), baslik = k0('baslik'), imzalayan = k0('imzalayan'), vade = k0('odeme_vade_gun'), teslim = k0('teslim_suresi'), tavan = k0('artis_tavan'),
        fmNot = k0('fiyat_maddesi_not'), fesih = k0('fesih_ihbar_gun'), not = k0('not');
    var imza = metinOku(s?['imza_tarihi']), bas = metinOku(s?['baslangic']), bit = metinOku(s?['bitis']);
    var fm = metinOku(s?['fiyat_maddesi'], 'sabit');
    final kalem = <(int, int?, TextEditingController, TextEditingController, TextEditingController)>[
      for (final x in liste(s?['kalemler']))
        (tamOku(x['id']), tamOku(x['malzeme_id']), TextEditingController(text: '${x['fiyat']}'), TextEditingController(text: metinOku(x['birim'])), TextEditingController(text: x['taahhut'] == null ? '' : '${x['taahhut']}')),
    ];
    if (kalem.isEmpty) kalem.add((0, null, TextEditingController(), TextEditingController(), TextEditingController()));
    final belgeSil = <int>{};
    var dosyalar = <(String, String, List<int>)>[];
    final malBirim = harita(v['malBirim']);
    final ok = await kAltSayfa<bool>(context, baslik: s == null ? 'Yeni Çerçeve Sözleşme' : 'Sözleşmeyi Düzenle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.watch<TemaProvider>();
          Widget tarih(String et, String deger, void Function(String) f) => KSatir(baslik: et, alt: deger.isEmpty ? 'Seçilmedi' : tarihYaz(deger, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
                final x = await saTarihSec(c, ilk: deger);
                if (x != null) ss(() => f(x));
              });
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KSecim<int>('Tedarikçi', deger: ted, secenekler: [for (final x in liste(v['tedarikciler'])) (tamOku(x['id']), metinOku(x['ad']))], onSec: (x) => ss(() => ted = x)),
            Row(children: [Expanded(child: KAlan('Sözleşme no', no)), const SizedBox(width: 8), Expanded(child: KAlan('Başlık', baslik))]),
            Row(children: [Expanded(child: tarih('İmza tarihi', imza, (x) => imza = x)), const SizedBox(width: 8), Expanded(child: KAlan('İmzalayan', imzalayan))]),
            Row(children: [Expanded(child: tarih('Başlangıç', bas, (x) => bas = x)), const SizedBox(width: 8), Expanded(child: tarih('Bitiş', bit, (x) => bit = x))]),
            Row(children: [
              Expanded(child: KAlan('Ödeme vadesi (gün)', vade, klavye: TextInputType.number)),
              const SizedBox(width: 8),
              Expanded(child: KAlan('Teslim süresi', teslim, ipucu: 'ör. 24 saat')),
            ]),
            KSecim<String>('Fiyat maddesi', deger: fm, secenekler: _fiyatMaddesi, onSec: (x) => ss(() => fm = x ?? 'sabit')),
            if (fm == 'tavan') KAlan('Artış tavanı (%)', tavan, klavye: const TextInputType.numberWithOptions(decimal: true)),
            KAlan('Fiyat maddesi notu', fmNot),
            KAlan('Fesih ihbar süresi (gün)', fesih, klavye: TextInputType.number),
            KAlan('Not', not, satir: 2),
            Text('Malzemeler ve fiyatlar', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            for (var i = 0; i < kalem.length; i++)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 10, 4, 0),
                decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: KSecim<int>('Malzeme', deger: kalem[i].$2, secenekler: [for (final x in liste(v['malzemeler'])) (tamOku(x['id']), metinOku(x['ad']))], onSec: (x) => ss(() {
                            final e = kalem[i];
                            if (e.$4.text.isEmpty) e.$4.text = metinOku(malBirim['$x']);
                            kalem[i] = (e.$1, x, e.$3, e.$4, e.$5);
                          })),
                    ),
                    IconButton(onPressed: kalem.length == 1 ? null : () => ss(() => kalem.removeAt(i)), icon: Icon(Icons.close, color: t.sub)),
                  ]),
                  Row(children: [
                    Expanded(child: KAlan('Fiyat', kalem[i].$3, klavye: const TextInputType.numberWithOptions(decimal: true))),
                    const SizedBox(width: 8),
                    Expanded(child: KAlan('Birim', kalem[i].$4)),
                    const SizedBox(width: 8),
                    Expanded(child: KAlan('Taahhüt/ay', kalem[i].$5, klavye: const TextInputType.numberWithOptions(decimal: true))),
                  ]),
                ]),
              ),
            KButon('Malzeme ekle', ikon: Icons.add, ikincil: true, onTap: () => ss(() => kalem.add((0, null, TextEditingController(), TextEditingController(), TextEditingController())))),
            const SizedBox(height: 10),
            if (s != null && liste(s['belgeler']).isNotEmpty) ...[
              Text('Mevcut belgeler (silinecekleri işaretleyin)', style: TextStyle(color: t.sub2, fontWeight: FontWeight.w700, fontSize: 13)),
              for (final b in liste(s['belgeler']))
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: belgeSil.contains(tamOku(b['id'])),
                  onChanged: (x) => ss(() => x == true ? belgeSil.add(tamOku(b['id'])) : belgeSil.remove(tamOku(b['id']))),
                  title: Text(metinOku(b['ad']), style: TextStyle(color: t.ink, fontSize: 13)),
                ),
            ],
            KButon('Belge ekle (${dosyalar.length})', ikon: Icons.attach_file, ikincil: true, onTap: () async {
              final d = await _belgeSec();
              ss(() => dosyalar = [...dosyalar, ...d]);
            }),
            if (dosyalar.isNotEmpty) Text(dosyalar.map((d) => d.$2).join(', '), style: TextStyle(color: t.sub, fontSize: 12)),
            const SizedBox(height: 10),
            KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () {
              if (ted == null) return kToast(c, 'Tedarikçi seçin.', hata: true);
              if (!kalem.any((e) => e.$2 != null && sayiOku(e.$3.text) > 0)) return kToast(c, 'En az bir malzeme ve fiyatı girin.', hata: true);
              if (bas.isNotEmpty && bit.isNotEmpty && bit.compareTo(bas) < 0) return kToast(c, 'Bitiş tarihi başlangıçtan önce olamaz.', hata: true);
              Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok != true || !mounted) return;
    final alan = <String, String>{
      if (s != null) 'id': '${s['id']}',
      'tedarikci_id': '$ted', 'sozlesme_no': no.text.trim(), 'baslik': baslik.text.trim(), 'imza_tarihi': imza, 'imzalayan': imzalayan.text.trim(),
      'baslangic': bas, 'bitis': bit, 'odeme_vade_gun': vade.text.trim(), 'teslim_suresi': teslim.text.trim(), 'fiyat_maddesi': fm, 'artis_tavan': tavan.text.trim(),
      'fiyat_maddesi_not': fmNot.text.trim(), 'fesih_ihbar_gun': fesih.text.trim(), 'not': not.text.trim(),
    };
    var i = 0;
    for (final e in kalem) {
      if (e.$2 == null) continue;
      alan['kalem_id[$i]'] = '${e.$1}';
      alan['kalem_malzeme[$i]'] = '${e.$2}';
      alan['kalem_fiyat[$i]'] = e.$3.text.trim();
      alan['kalem_birim[$i]'] = e.$4.text.trim();
      alan['kalem_taahhut[$i]'] = e.$5.text.trim();
      i++;
    }
    var j = 0;
    for (final b in belgeSil) {
      alan['belge_sil[${j++}]'] = '$b';
    }
    await _gonderCok('/fiyat-anlasmalari/sozlesme', alan, dosyalar, yenile);
  }
}

// ───────────────────────── Raporlar (/fiyat-anlasmalari/rapor) ─────────────────────────
const _raporlar = [
  ('tasarruf', 'Tasarruf'), ('fazla', 'Fazla ödenen'), ('taahhut', 'Taahhüt'), ('kapsama', 'Kapsama'),
  ('zarar', 'Zarar eden anlaşmalar'), ('yenileme', 'Yenileme / artış'), ('tedarikci', 'Tedarikçi'), ('takvim', 'Bitiş takvimi'),
];

class FiyatAnlasmaRaporScreen extends StatefulWidget {
  const FiyatAnlasmaRaporScreen({super.key});
  @override
  State<FiyatAnlasmaRaporScreen> createState() => _FiyatAnlasmaRaporScreenState();
}

class _FiyatAnlasmaRaporScreenState extends State<FiyatAnlasmaRaporScreen> {
  final _ekran = GlobalKey<KopruEkranState>();
  String _r = 'tasarruf';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _ekran,
      yol: '/fiyat-anlasmalari/rapor',
      baslik: 'Fiyat Anlaşması Raporları',
      ikon: Icons.insights,
      govde: _govde,
      araclar: (ctx, v, yenile) => [
        IconButton(
          tooltip: 'Excel (CSV)',
          onPressed: () => saDosyaIndir(context, '/fiyat-anlasmalari/rapor-indir', 'fiyat-anlasma-$_r.csv', q: {
            'r': _r, 'bas': metinOku(v['bas']), 'bit': metinOku(v['bit']), if (tamOku(v['ted']) > 0) 'ted': '${v['ted']}',
          }),
          icon: const Icon(Icons.download_outlined),
        ),
      ],
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final r = harita(v['rapor']);
    return KGovde(yenile: yenile, children: [
      Row(children: [
        Expanded(child: KSatir(baslik: 'Başlangıç', alt: tarihYaz(v['bas'], saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
          final s = await saTarihSec(context, ilk: metinOku(v['bas']));
          if (s != null) _ekran.currentState?.sorgu({'bas': s});
        })),
        const SizedBox(width: 8),
        Expanded(child: KSatir(baslik: 'Bitiş', alt: tarihYaz(v['bit'], saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
          final s = await saTarihSec(context, ilk: metinOku(v['bit']));
          if (s != null) _ekran.currentState?.sorgu({'bit': s});
        })),
      ]),
      KSecim<int>('Tedarikçi', deger: tamOku(v['ted']), secenekler: [(0, 'Tümü'), for (final x in liste(v['tedarikciler'])) (tamOku(x['id']), metinOku(x['ad']))],
          onSec: (x) => _ekran.currentState?.sorgu({'ted': '${x ?? 0}'})),
      KCipler(secenekler: _raporlar, secili: _r, onSec: (k) => setState(() => _r = k)),
      ..._rapor(r, t),
    ]);
  }

  Widget _tablo(List<String> b, List<List<String>> s, Set<int> sag, String bos) =>
      s.isEmpty ? KBos(baslik: 'Kayıt yok', aciklama: bos, ikon: Icons.inbox_outlined) : KKart(child: KTablo(basliklar: b, satirlar: s, sagaYasla: sag));

  List<Widget> _rapor(Map<String, dynamic> r, TemaProvider t) {
    String y(dynamic x) => x == null ? '—' : '${sayiOku(x) > 0 ? '+' : ''}${sayiYaz(x)}%';
    switch (_r) {
      case 'fazla':
        final f = harita(r['fazla']);
        return [
          KKpiIzgara([KKpi(etiket: 'Fazla ödenen', deger: tl(f['toplam']), alt: '${f['adet']} fatura kalemi', renk: t.kirmizi)]),
          for (final x in liste(f['ted']))
            KKart(
              renk: t.kirmizi,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text(metinOku(x['ted']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
                  Text(tl(x['toplam']), style: TextStyle(color: t.kirmizi, fontWeight: FontWeight.w700)),
                ]),
                KTablo(basliklar: const ['Tarih', 'Fatura', 'Malzeme', 'Anlaşma', 'Fatura fiyatı', 'Miktar', 'Fazla'], sagaYasla: const {3, 4, 5, 6}, satirlar: [
                  for (final s in liste(x['satir']))
                    [tarihYaz(s['tarih'], saat: false), metinOku(s['fatura_no'], '—'), '${s['mal']} ${metinOku(s['birim'])}', tl(s['anlasma']), tl(s['fatura']), sayiYaz(s['miktar']), tl(s['fazla'])],
                ]),
              ]),
            ),
          if (liste(f['ted']).isEmpty) const KBos(baslik: 'Anlaşma ihlali yok', aciklama: 'Bu dönemde faturalardaki fiyatlar anlaşma fiyatını aşmamış.', ikon: Icons.verified_outlined),
        ];
      case 'taahhut':
        return [
          _tablo(const ['Malzeme', 'Tedarikçi', 'Aylık taahhüt', 'Aylar (gerçekleşen / oran)'], [
            for (final x in liste(r['taahhut']))
              ['${x['mal']}', '${x['ted']}', '${sayiYaz(x['taahhut'])} ${metinOku(x['birim'])}', harita(x['aylar']).entries.map((e) => '${e.key}: ${sayiYaz(harita(e.value)['miktar'])} (%${harita(e.value)['oran']})').join(' · ')],
          ], const {2}, 'Taahhüt miktarı girilmiş anlaşma yok ya da bu dönemde alış olmamış.'),
        ];
      case 'kapsama':
        final k = harita(r['kapsama']);
        return [
          KKpiIzgara([
            KKpi(etiket: 'Toplam alış', deger: tl(k['toplam'], kisa: true), renk: t.mor1),
            KKpi(etiket: 'Anlaşmalı alış', deger: tl(k['anlasmali'], kisa: true), renk: t.yesil),
            KKpi(etiket: 'Kapsama oranı', deger: '%${k['oran']}', renk: t.mavi),
          ]),
          KBaslik('Anlaşma yapılması önerilen malzemeler', ikon: Icons.lightbulb_outline),
          _tablo(const ['Malzeme', 'Harcama', 'Alış', 'Tedarikçi', 'En düşük', 'En yüksek', 'Oynaklık'], [
            for (final x in liste(k['oneri'])) ['${x['mal']}', tl(x['harcama'], kisa: true), '${x['alis']}', '${x['ted_say']}', tl(x['min']), tl(x['max']), '%${x['oynaklik']}'],
          ], const {1, 2, 3, 4, 5, 6}, 'Anlaşmasız önemli malzeme yok.'),
        ];
      case 'zarar':
        return [
          if (metinOku(r['hal_tarih']).isNotEmpty) SaBilgi('Hal referansı: ${tarihYaz(r['hal_tarih'], saat: false)} bülteni.'),
          _tablo(const ['Malzeme', 'Tedarikçi', 'Anlaşma', 'Piyasa (30 gün)', 'Piyasa farkı', 'Hal', 'Hal farkı', 'Bitiş', 'Durum'], [
            for (final x in liste(r['zarar']))
              ['${x['mal']}', '${x['ted']}', tl(x['anlasma']), x['piyasa'] != null ? '${tl(x['piyasa'])} ${metinOku(x['piyasa_ted'])}' : '—', y(x['piyasa_fark']), x['hal'] != null ? tl(x['hal']) : '—', y(x['hal_fark']),
                metinOku(x['bitis']).isEmpty ? 'Süresiz' : tarihYaz(x['bitis'], saat: false), x['zarar'] == true ? 'Zarar ediyor' : 'Uygun'],
          ], const {2, 4, 6}, 'Yürürlükte anlaşma yok.'),
        ];
      case 'yenileme':
        final yy = harita(r['yenileme']);
        return [
          KBaslik('Tedarikçi ortalama artışı', ikon: Icons.trending_up),
          _tablo(const ['Tedarikçi', 'Ort. artış', 'Yenileme sayısı'], [for (final x in liste(yy['ted'])) ['${x['ted']}', y(x['ort']), '${x['say']}']], const {1, 2}, 'Yenilenen anlaşma yok.'),
          KBaslik('Malzeme bazında fiyat adımları', ikon: Icons.timeline),
          _tablo(const ['Malzeme', 'Tedarikçi', 'Adımlar', 'Toplam'], [
            for (final x in liste(yy['satir']))
              ['${x['mal']}', '${x['ted']}', liste(x['adimlar']).map((a) => '${tarihYaz(a['baslangic'], saat: false)}: ${tl(a['fiyat'])}${a['degisim'] != null ? ' (${y(a['degisim'])})' : ''}').join(' → '), y(x['toplam'])],
          ], const {3}, 'Birden fazla dönemi olan anlaşma yok.'),
        ];
      case 'tedarikci':
        return [
          _tablo(const ['Tedarikçi', 'Yürürlükteki anlaşma', 'Anlaşmalı fatura kalemi', 'Fatura uyumu', 'Tasarruf', 'Fazla ödenen', 'Zamanında teslim'], [
            for (final x in liste(r['tedarikci']))
              ['${x['ted']}', '${x['anlasma']}', '${x['fatura']}', x['uyum'] == null ? '—' : '%${x['uyum']}', tl(x['tasarruf'], kisa: true), tl(x['fazla'], kisa: true), x['teslim'] == null ? '—' : '%${x['teslim']}'],
          ], const {1, 2, 3, 4, 5, 6}, 'Anlaşmalı tedarikçi yok.'),
        ];
      case 'takvim':
        return [
          _tablo(const ['Tür', 'Ad', 'Tedarikçi', 'Malzeme', 'Fesih için son gün', 'Bitiş'], [
            for (final x in liste(r['takvim']))
              [x['tur'] == 'sozlesme' ? 'Sözleşme' : 'Anlaşma', '${x['ad']}', '${x['ted']}', '${x['kalem']}', metinOku(x['fesih']).isEmpty ? '—' : tarihYaz(x['fesih'], saat: false), tarihYaz(x['bitis'], saat: false)],
          ], const {3}, 'Bitiş tarihi olan anlaşma/sözleşme yok.'),
        ];
      default:
        final ts = harita(r['tasarruf']);
        return [
          KKpiIzgara([
            KKpi(etiket: 'Toplam tasarruf', deger: tl(ts['toplam']), renk: t.yesil),
            KKpi(etiket: 'Anlaşma yüzünden kayıp', deger: tl(ts['kayip']), alt: 'Piyasa anlaşmadan ucuzken', renk: t.kirmizi),
          ]),
          if (harita(ts['aylik']).isNotEmpty)
            KKart(child: KTablo(basliklar: const ['Ay', 'Tasarruf'], sagaYasla: const {1}, satirlar: [for (final e in harita(ts['aylik']).entries) [e.key, tl(e.value)]])),
          _tablo(const ['Malzeme', 'Tedarikçi', 'Anlaşma', 'Referans', 'Kaynak', 'Miktar', 'Tasarruf'], [
            for (final x in liste(ts['satir']))
              ['${x['mal']}', '${x['ted']}', '${tl(x['anlasma'])}${metinOku(x['birim']).isNotEmpty ? '/${x['birim']}' : ''}', x['ref'] == null ? '—' : tl(x['ref']), metinOku(x['kaynak'], '—'), sayiYaz(x['miktar']), tl(x['tasarruf'])],
          ], const {2, 3, 5, 6}, 'Bu dönemde anlaşmalı alış yok. Anlaşma ekleyip alış faturaları girildikçe dolar.'),
        ];
    }
  }
}

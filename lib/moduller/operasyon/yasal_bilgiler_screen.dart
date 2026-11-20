import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// Web /yasal-bilgiler — şirket/yasal bilgiler formu (YasalMetin 14 alan) + üretilen belgelerin önizlemesi.
/// Kaydet → POST /yasal-bilgiler/kaydet ; belge → GET /yasal-onizle/{tip} (kopyala / PDF yazdır-paylaş).
class OpYasalBilgilerScreen extends StatelessWidget {
  const OpYasalBilgilerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/yasal-bilgiler',
      baslik: 'Yasal Bilgiler & Sözleşmeler',
      ikon: Icons.gavel,
      altBaslik: 'Bilgileri bir kez doldurun — belgeler otomatik üretilsin',
      govde: (ctx, veri, yenile) => _YasalForm(veri: veri, yenile: yenile),
    );
  }
}

const _gruplar = {
  'Şirket Bilgileri': ['unvan', 'marka_adi', 'adres'],
  'Vergi / Resmi': ['vergi_dairesi', 'vergi_no', 'mersis_no'],
  'İletişim & KVKK': ['telefon', 'eposta', 'website', 'kep_adresi', 'veri_sorumlusu', 'kvkk_irtibat'],
  'Satış / Teslimat': ['iade_suresi', 'teslimat_bilgi'],
};

class _YasalForm extends StatefulWidget {
  final Map<String, dynamic> veri;
  final Future<void> Function() yenile;
  const _YasalForm({required this.veri, required this.yenile});
  @override
  State<_YasalForm> createState() => _YasalFormState();
}

class _YasalFormState extends State<_YasalForm> {
  final Map<String, TextEditingController> _c = {};
  bool _kaydediliyor = false;

  Map<String, dynamic> get _alanlar => harita(widget.veri['alanlar']);

  @override
  void initState() {
    super.initState();
    _doldur();
  }

  @override
  void didUpdateWidget(covariant _YasalForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.veri != widget.veri) _doldur();
  }

  void _doldur() {
    final row = harita(widget.veri['row']);
    for (final k in _alanlar.keys) {
      final c = _c.putIfAbsent(k, () => TextEditingController());
      c.text = metinOku(row[k]);
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediliyor = true);
    final ok = await kopruGonder(context, '/yasal-bilgiler/kaydet', {for (final e in _c.entries) e.key: e.value.text.trim()});
    if (!mounted) return;
    setState(() => _kaydediliyor = false);
    if (ok) await widget.yenile();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final eksikler = dizi(widget.veri['eksikler']).map((e) => metinOku(e)).where((e) => e.isNotEmpty).toList();
    final tipler = harita(widget.veri['tipler']);
    final tam = eksikler.isEmpty;
    final genis = genisMi(context);
    // Grupta olmayan (sunucuya sonradan eklenmiş) alanlar da kaybolmasın
    final gruplu = _gruplar.values.expand((x) => x).toSet();
    final digerleri = _alanlar.keys.where((k) => !gruplu.contains(k)).toList();
    final gruplar = {..._gruplar, if (digerleri.isNotEmpty) 'Diğer': digerleri};

    final form = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final g in gruplar.entries) ...[
        KBaslik(g.key, ikon: _grupIkon(g.key), renk: t.mor1),
        KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (final k in g.value)
              if (_alanlar.containsKey(k)) _alan(k),
          ]),
        ),
      ],
      KButon('Kaydet & Sözleşmeleri Üret', ikon: Icons.save_outlined, genis: true, yukleniyor: _kaydediliyor, onTap: _kaydet),
      const SizedBox(height: 16),
    ]);

    final belgeler = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KBaslik('Üretilen Belgeler', ikon: Icons.description_outlined, renk: t.mavi, alt: 'Dokunun, önizleyin; kopyalayın ya da PDF olarak yazdırın/paylaşın.'),
      KKart(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        child: Column(children: [
          for (final e in tipler.entries)
            KSatir(
              solIkon: KIkon(Icons.description_outlined, renk: t.mor1),
              baslik: metinOku(e.value),
              alt: tam ? 'Hazır' : 'Eksik alanlar [köşeli parantez] ile görünür',
              sag: Icon(Icons.chevron_right, color: t.sub),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OpYasalOnizleScreen(tip: e.key, baslik: metinOku(e.value)))),
            ),
        ]),
      ),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, size: 18, color: t.sub),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Belgeler standart şablonlardan üretilir ve müşteri uygulamasında (Ayarlar → Yasal) otomatik görünür. Yürürlüğe almadan önce bir hukuk danışmanına kontrol ettirmeniz önerilir.',
              style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4),
            ),
          ),
        ]),
      ),
    ]);

    return KGovde(
      yenile: widget.yenile,
      children: [
        KKart(
          renk: tam ? const Color(0xFF16A34A) : t.amber,
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(tam ? Icons.verified_outlined : Icons.error_outline, size: 30, color: tam ? const Color(0xFF16A34A) : t.amber),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(tam ? 'Bilgiler tam — sözleşmeler hazır' : 'Eksik bilgi var', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(
                  tam
                      ? 'Tüm yasal belgeler şirket bilgilerinizle otomatik oluşturuluyor. Aşağıdan önizleyebilirsiniz.'
                      : 'Şu zorunlu alanlar boş: ${eksikler.join(', ')}. Doldurmadan belgelerde köşeli parantezli uyarı görünür.',
                  style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4),
                ),
              ]),
            ),
          ]),
        ),
        if (genis)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(flex: 3, child: form),
            const SizedBox(width: 16),
            Expanded(flex: 2, child: belgeler),
          ])
        else ...[form, belgeler],
      ],
    );
  }

  IconData _grupIkon(String g) => switch (g) {
        'Şirket Bilgileri' => Icons.apartment,
        'Vergi / Resmi' => Icons.account_balance_outlined,
        'İletişim & KVKK' => Icons.contact_phone_outlined,
        'Satış / Teslimat' => Icons.local_shipping_outlined,
        _ => Icons.more_horiz,
      };

  Widget _alan(String k) {
    final a = dizi(_alanlar[k]);
    final etiket = a.isNotEmpty ? metinOku(a[0], k) : k;
    final zorunlu = a.length > 1 && (a[1] == true || a[1] == 1);
    final ipucu = a.length > 2 ? metinOku(a[2]) : null;
    final cok = k == 'adres' || k == 'teslimat_bilgi';
    final klavye = switch (k) {
      'iade_suresi' => TextInputType.number,
      'telefon' => TextInputType.phone,
      'eposta' || 'kep_adresi' => TextInputType.emailAddress,
      'website' => TextInputType.url,
      _ => cok ? TextInputType.multiline : TextInputType.text,
    };
    return KAlan(etiket, _c[k]!, ipucu: ipucu, zorunlu: zorunlu, satir: cok ? 2 : 1, klavye: klavye);
  }
}

/// Web /yasal-onizle/{tip} — üretilen belgenin metni (müşteri uygulamasında böyle görünür)
class OpYasalOnizleScreen extends StatelessWidget {
  final String tip;
  final String baslik;
  const OpYasalOnizleScreen({super.key, required this.tip, required this.baslik});

  Future<void> _pdf(BuildContext context, Map<String, dynamic> b) async {
    try {
      final f = await PdfGoogleFonts.notoSansRegular();
      final fb = await PdfGoogleFonts.notoSansBold();
      final doc = pw.Document();
      final metin = metinOku(b['metin']);
      doc.addPage(pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: f, bold: fb),
        build: (c) => [
          pw.Text(metinOku(b['baslik'], baslik), style: pw.TextStyle(font: fb, fontSize: 16)),
          pw.SizedBox(height: 4),
          pw.Text('Son güncelleme: ${metinOku(b['guncelleme'])}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
          pw.SizedBox(height: 12),
          for (final p in metin.split('\n')) pw.Text(p, style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 2)),
        ],
      ));
      await Printing.layoutPdf(onLayout: (_) async => doc.save(), name: '${metinOku(b['baslik'], baslik)}.pdf');
    } catch (e) {
      if (context.mounted) kToast(context, 'PDF hazırlanamadı (yazı tipi için internet gerekir).', hata: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/yasal-onizle/$tip',
      baslik: baslik,
      ikon: Icons.description_outlined,
      altBaslik: 'Önizleme — müşteri uygulamasında böyle görünür',
      araclar: (ctx, veri, yenile) {
        final b = harita(veri['belge']);
        return [
          IconButton(
            tooltip: 'Metni kopyala',
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: metinOku(b['metin'])));
              if (ctx.mounted) kToast(ctx, 'Metin kopyalandı.');
            },
          ),
          IconButton(tooltip: 'PDF yazdır / paylaş', icon: const Icon(Icons.print_outlined), onPressed: () => _pdf(ctx, b)),
        ];
      },
      govde: (ctx, veri, yenile) {
        final t = ctx.watch<TemaProvider>();
        final b = harita(veri['belge']);
        final tam = b['tam'] == true || b['tam'] == 1;
        return KGovde(
          yenile: yenile,
          maxGenislik: 820,
          children: [
            if (!tam)
              KKart(
                renk: t.kirmizi,
                child: Text('Bazı zorunlu alanlar boş — metinde [köşeli parantezli] uyarılar görünüyor. Yasal Bilgiler ekranından tamamlayın.',
                    style: TextStyle(color: t.ink, fontSize: 13, height: 1.4)),
              ),
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Son güncelleme: ${metinOku(b['guncelleme'], '—')}', style: TextStyle(color: t.sub, fontSize: 12)),
                const SizedBox(height: 10),
                if (metinOku(b['metin']).isEmpty)
                  const KBos(baslik: 'Belge metni boş', aciklama: 'Bu belge için şablon bulunamadı. Yasal Bilgiler ekranından bilgileri kaydedip tekrar deneyin.', ikon: Icons.description_outlined)
                else
                  SelectableText(metinOku(b['metin']), style: TextStyle(color: t.ink, fontSize: 14, height: 1.6)),
              ]),
            ),
          ],
        );
      },
    );
  }
}

import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_api.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// STOK modülü ortak yardımcıları (yalnız bu modül kullanır).
///
/// Not: web'in /api/patron/* uçları yetkisiz kişiye 401 döner. Ortak köprü 401'i "oturum bitti" sayıp
/// çıkış yaptırır; bu yüzden bu modül o uçları [stAl] / [stGonder] ile çağırır (401 = yalnız "yetkiniz yok").

KopruCevap _yetkisizCevap() => KopruCevap(403, {'ok': 0, 'hata': 'Bu işlem için yetkiniz yok.', 'yetkisiz': 1});

/// GET (JSON ya da sayfa verisi). Oturumu kapatmaz.
Future<KopruCevap> stAl(BuildContext context, String yol, {Map<String, String>? q}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return _yetkisizCevap();
  try {
    return await KopruApi.al(tok, yol, q: q);
  } on ApiYetkiHatasi {
    return _yetkisizCevap();
  }
}

/// POST (form ya da JSON). Hata olursa kırmızı bildirim gösterir; başarıda [basari] (ya da sunucu mesajı).
Future<KopruCevap> stGonder(BuildContext context, String yol, Map<String, dynamic> veri,
    {bool json = false, String? basari, bool sessiz = false, bool hataSessiz = false}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return _yetkisizCevap();
  KopruCevap c;
  try {
    c = json ? await KopruApi.gonderJson(tok, yol, veri) : await KopruApi.gonder(tok, yol, veri);
  } on ApiYetkiHatasi {
    c = _yetkisizCevap();
  }
  if (!context.mounted) return c;
  if (c.ok) {
    if (!sessiz) kToast(context, c.mesaj ?? basari ?? 'Kaydedildi.');
  } else if (!hataSessiz) {
    kToast(context, c.hata ?? 'İşlem yapılamadı.', hata: true);
  }
  return c;
}

// ───────── yetki (web'deki bayrakların uygulama karşılığı; sunucu ayrıca süzer) ─────────
String stRol(BuildContext c) => c.read<AuthProvider>().rol ?? '';
bool stSahip(BuildContext c) => stRol(c) == 'sahip';
bool stPatron(BuildContext c) => const ['sahip', 'mudur'].contains(stRol(c));
/// Malzeme kartı ekle/düzenle: sahip her zaman, diğerleri 'gor_malzeme_kart' yetkisiyle (web _malzemeKartYetki)
bool stKartYetki(BuildContext c) {
  final a = c.read<AuthProvider>();
  return a.rol == 'sahip' || a.yetkiler.contains('gor_malzeme_kart');
}

/// Başka bir web sayfasının uygulama ekranını aç
void stAc(BuildContext context, String url, String ad) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret(url, ad)));
}

/// Miktar yazımı (tam sayıysa ondalıksız)
String mik(dynamic v) => sayiYaz(v);

/// Bugün yyyy-MM-dd
String stBugun([int ekGun = 0]) {
  final d = DateTime.now().add(Duration(days: ekGun));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Tarih seç → yyyy-MM-dd (vazgeçilirse null)
Future<String?> stTarihSec(BuildContext context, {String? ilk, bool gecmis = true}) async {
  final simdi = DateTime.now();
  final d0 = DateTime.tryParse(ilk ?? '') ?? simdi;
  final d = await showDatePicker(
    context: context,
    initialDate: d0,
    firstDate: gecmis ? DateTime(simdi.year - 2) : DateTime(simdi.year, simdi.month, simdi.day),
    lastDate: DateTime(simdi.year + 3),
  );
  if (d == null) return null;
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Tarih seçme kutusu (etiketli, dokununca takvim)
class StTarihAlan extends StatelessWidget {
  final String etiket;
  final String? deger;
  final ValueChanged<String?> onSec;
  final bool temizlenir;
  const StTarihAlan(this.etiket, {super.key, required this.deger, required this.onSec, this.temizlenir = false});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () async {
            final s = await stTarihSec(context, ilk: deger);
            if (s != null) onSec(s);
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
            child: Row(children: [
              Icon(Icons.event_outlined, size: 18, color: t.sub),
              const SizedBox(width: 8),
              Expanded(child: Text(deger == null || deger!.isEmpty ? 'Seçilmedi' : tarihYaz(deger, saat: false), style: TextStyle(color: t.ink, fontSize: 15))),
              if (temizlenir && deger != null && deger!.isNotEmpty)
                IconButton(onPressed: () => onSec(null), icon: Icon(Icons.close, size: 18, color: t.sub), tooltip: 'Temizle'),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Excel / PDF indir ve kaydet (web'deki indirme bağlantıları)
Future<void> stDosyaIndir(BuildContext context, String yol, String dosyaAdi, {Map<String, String>? q}) async {
  final tok = context.read<AuthProvider>().token;
  if (tok == null) return;
  kToast(context, 'Dosya hazırlanıyor…');
  Uint8List? b;
  try {
    b = await KopruApi.dosya(tok, yol, q: q);
  } on ApiYetkiHatasi {
    b = null;
  }
  if (!context.mounted) return;
  if (b == null || b.isEmpty) {
    kToast(context, 'Dosya alınamadı (veri yok ya da yetkiniz yok).', hata: true);
    return;
  }
  try {
    final yolu = await FilePicker.platform.saveFile(dialogTitle: 'Kaydet', fileName: dosyaAdi, bytes: b);
    if (yolu != null && !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      final f = File(yolu);
      if (!f.existsSync() || f.lengthSync() == 0) await f.writeAsBytes(b);
    }
    if (yolu != null && context.mounted) kToast(context, 'Kaydedildi: $dosyaAdi');
  } catch (e) {
    if (context.mounted) kToast(context, 'Kaydedilemedi: $e', hata: true);
  }
}

/// Excel + PDF indirme düğmeleri (başlık araçları için)
List<Widget> stIndirAraclari(BuildContext context, String yol, String dosyaKok, {Map<String, String>? q}) => [
      IconButton(
        tooltip: 'Excel indir',
        icon: const Icon(Icons.table_view_outlined),
        onPressed: () => stDosyaIndir(context, yol, '$dosyaKok.xlsx', q: {...?q, 'format': 'xlsx'}),
      ),
      IconButton(
        tooltip: 'PDF indir',
        icon: const Icon(Icons.picture_as_pdf_outlined),
        onPressed: () => stDosyaIndir(context, yol, '$dosyaKok.pdf', q: {...?q, 'format': 'pdf'}),
      ),
    ];

// ───────────────────────── ETİKET (PDF ile yazdır) ─────────────────────────
/// Web'de tarayıcıdan/Zebra'dan basılan etiketlerin uygulama karşılığı: PDF üretir, yazdırma/önizleme penceresini açar.
class StEtiket {
  final String kod;
  final String ust;
  final String ad;
  final String alt;
  final int adet;
  const StEtiket({required this.kod, this.ust = '', this.ad = '', this.alt = '', this.adet = 1});
}

const List<(String, String, double, double)> kStEtiketBoyutlar = [
  ('40x30', '40 × 30 mm', 40, 30),
  ('50x25', '50 × 25 mm', 50, 25),
  ('50x30', '50 × 30 mm', 50, 30),
  ('58x40', '58 × 40 mm', 58, 40),
  ('60x40', '60 × 40 mm', 60, 40),
  ('70x40', '70 × 40 mm', 70, 40),
  ('70x50', '70 × 50 mm', 70, 50),
  ('100x50', '100 × 50 mm', 100, 50),
  ('100x70', '100 × 70 mm', 100, 70),
];

pw.Font? _fR, _fB;

/// tip: c128 | ean13 | qr
Future<void> stEtiketYazdir(BuildContext context, List<StEtiket> etiketler, {String tip = 'c128', String boyut = '50x30', String ad = 'Etiket'}) async {
  if (etiketler.isEmpty) {
    kToast(context, 'Basılacak etiket yok.', hata: true);
    return;
  }
  final b = kStEtiketBoyutlar.firstWhere((x) => x.$1 == boyut, orElse: () => kStEtiketBoyutlar[2]);
  try {
    _fR ??= await PdfGoogleFonts.notoSansRegular();
    _fB ??= await PdfGoogleFonts.notoSansBold();
  } catch (_) {
    // çevrimdışı: varsayılan yazı tipi (Türkçe harflerde eksik olabilir)
  }
  final doc = pw.Document(theme: _fR == null ? null : pw.ThemeData.withFont(base: _fR, bold: _fB));
  final fmt = PdfPageFormat(b.$3 * PdfPageFormat.mm, b.$4 * PdfPageFormat.mm, marginAll: 2 * PdfPageFormat.mm);
  final barkod = tip == 'qr' ? pw.Barcode.qrCode() : (tip == 'ean13' ? pw.Barcode.ean13() : pw.Barcode.code128());
  for (final e in etiketler) {
    for (var i = 0; i < e.adet.clamp(1, 500); i++) {
      doc.addPage(pw.Page(
        pageFormat: fmt,
        build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          if (e.ust.isNotEmpty) pw.Text(e.ust, style: const pw.TextStyle(fontSize: 6), maxLines: 1),
          if (e.ad.isNotEmpty) pw.Text(e.ad, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), maxLines: 2, textAlign: pw.TextAlign.center),
          pw.SizedBox(height: 1.5),
          pw.Expanded(
            child: pw.Center(
              child: tip == 'qr'
                  ? pw.BarcodeWidget(barcode: barkod, data: e.kod, drawText: false)
                  : pw.BarcodeWidget(barcode: barkod, data: e.kod, textStyle: const pw.TextStyle(fontSize: 6.5)),
            ),
          ),
          if (tip == 'qr') pw.Text(e.kod, style: const pw.TextStyle(fontSize: 6), maxLines: 1),
          if (e.alt.isNotEmpty) pw.Text(e.alt, style: const pw.TextStyle(fontSize: 6.5), maxLines: 1),
        ]),
      ));
    }
  }
  try {
    final bayt = await doc.save();
    await Printing.layoutPdf(name: '$ad.pdf', onLayout: (_) async => bayt);
  } catch (e) {
    if (context.mounted) kToast(context, 'Etiket hazırlanamadı: $e', hata: true);
  }
}

/// Basit sayı sorma penceresi (adet / miktar)
Future<double?> stSayiSor(BuildContext context, String baslik, {String etiket = 'Miktar', String baslangic = '', String? aciklama}) {
  final k = TextEditingController(text: baslangic);
  return kAltSayfa<double>(context, baslik: baslik, icerik: (c) {
    final t = c.read<TemaProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (aciklama != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(aciklama, style: TextStyle(color: t.sub2, fontSize: 13.5, height: 1.4))),
      KAlan(etiket, k, klavye: const TextInputType.numberWithOptions(decimal: true, signed: true)),
      KButon('Tamam', genis: true, onTap: () {
        final v = double.tryParse(k.text.trim().replaceAll(',', '.'));
        if (v == null) {
          kToast(c, 'Geçerli bir sayı girin.', hata: true);
          return;
        }
        Navigator.pop(c, v);
      }),
    ]);
  });
}

/// Durum rengi yardımcıları
Color stDurumRenk(TemaProvider t, String d) => switch (d) {
      'negatif' => const Color(0xFF991B1B),
      'kirmizi' || 'gecmis' || 'uygunsuz' => t.kirmizi,
      'turuncu' || 'yaklasan' => t.amber,
      'yesil' || 'uygun' || 'yapildi' => t.yesil,
      _ => t.sub,
    };

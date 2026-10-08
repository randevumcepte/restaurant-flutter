import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// PDF'i UYGULAMA İÇİNDE önizler — kendi AppBar'ı + geri oku var, yazdır/paylaş
/// butonları içinde. Böylece kullanıcı asla OS'in tam ekran yazdırma ekranında
/// (geri dönemediği yerde) sıkışmaz.
class PdfOnizlemeScreen extends StatelessWidget {
  final String baslik;
  final Uint8List Function() bytes;
  const PdfOnizlemeScreen({super.key, required this.baslik, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF1F6),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(baslik, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: PdfPreview(
        build: (format) => bytes(),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: false, // kendi belirgin butonumuzu kullanıyoruz
        allowSharing: false, // paylaş kaldırıldı
        useActions: false, // üstteki küçük aksiyon çubuğu gizli
        pdfFileName: '$baslik.pdf',
        maxPageWidth: 360, // 80mm fiş gerçek genişliğinde kalsın (ekranı kaplamasın)
        dpi: 260, // net/keskin önizleme (düşük DPI bulanık gösteriyordu)
        scrollViewDecoration: const BoxDecoration(color: Color(0xFFEEF1F6)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      ),
      // Tek, büyük ve belirgin YAZDIR butonu — paylaş yok
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: SizedBox(
          height: 58,
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
            onPressed: () => Printing.layoutPdf(onLayout: (format) async => bytes(), name: baslik),
            icon: const Icon(Icons.print, size: 26),
            label: const Text('YAZDIR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ),
        ),
      ),
    );
  }
}

// Fontlar BİR KEZ yüklenir, sonra her fişte ANINDA kullanılır. Eskiden her açılışta
// PdfGoogleFonts ~1-2sn yüklüyordu (fiş geç açılıyordu). Açılışta fisFontlariIsit() ön-ısıtır.
pw.Font? _fontR;
pw.Font? _fontB;
Future<void> _fontlariYukle() async {
  _fontR ??= await PdfGoogleFonts.notoSansRegular();
  _fontB ??= await PdfGoogleFonts.notoSansBold();
}

/// Uygulama açılışında çağır: fişler anında açılsın diye fontları önceden yükler.
Future<void> fisFontlariIsit() async {
  try { await _fontlariYukle(); } catch (_) {}
}

Future<Uint8List> _fisDoc(Map d) async {
  final f = NumberFormat.decimalPattern('tr');
  String tl(dynamic v) => '${f.format((v is num ? v : 0).round())} TL';
  num n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  await _fontlariYukle();
  final font = _fontR!;
  final fontB = _fontB!;
  final doc = pw.Document();
  final kalemler = (d['kalemler'] as List?) ?? [];

  pw.Widget satir(String s, String v, {double fs = 9, bool bold = false}) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(s, style: pw.TextStyle(fontSize: fs, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(v, style: pw.TextStyle(fontSize: fs, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.roll80,
    theme: pw.ThemeData.withFont(base: font, bold: fontB),
    build: (ctx) {
      final matrah = (n(d['toplam']) / 1.10);
      final kdv = n(d['toplam']) - matrah;
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text(d['isletme']?.toString() ?? 'ResteOS', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold))),
        if ((d['adres']?.toString() ?? '').isNotEmpty) pw.Center(child: pw.Text(d['adres'].toString(), style: const pw.TextStyle(fontSize: 8))),
        if ((d['telefon']?.toString() ?? '').isNotEmpty) pw.Center(child: pw.Text(d['telefon'].toString(), style: const pw.TextStyle(fontSize: 8))),
        pw.SizedBox(height: 4),
        pw.Center(child: pw.Text('HESAP FİŞİ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, letterSpacing: 2))),
        pw.Divider(),
        satir('Masa: ${d['masa']}', 'Adisyon: #${d['adisyon_no']}', fs: 9),
        satir('Garson: ${d['garson']}', d['tarih']?.toString() ?? '', fs: 9),
        pw.Divider(),
        for (final k in kalemler)
          pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 1.5),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Expanded(child: pw.Text('${n((k as Map)['adet']).toInt()}x ${k['ad']}', style: const pw.TextStyle(fontSize: 9.5))),
              pw.Text(tl(k['tutar']), style: const pw.TextStyle(fontSize: 9.5)),
            ]),
          ),
        pw.Divider(),
        satir('Ara Toplam', tl(d['ara_toplam'])),
        if (n(d['indirim']) > 0) satir('İskonto', '-${tl(d['indirim'])}'),
        if (n(d['ikram']) > 0) satir('İkram', '-${tl(d['ikram'])}'),
        satir('KDV %10 (dahil)', tl(kdv), fs: 8),
        pw.SizedBox(height: 6),
        // Vurgulu toplam kutusu
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          decoration: const pw.BoxDecoration(color: PdfColors.black),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('TOPLAM', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
            pw.Text(tl(d['toplam']), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ]),
        ),
        pw.SizedBox(height: 10),
        pw.Center(child: pw.Text('Afiyet olsun · Teşekkür ederiz', style: const pw.TextStyle(fontSize: 9))),
        pw.SizedBox(height: 2),
        pw.Center(child: pw.Text('Bu bir bilgi fişidir, mali değeri yoktur.', style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600))),
        pw.SizedBox(height: 6),
      ]);
    },
  ));

  return doc.save();
}

Future<Uint8List> _zRaporuDoc(Map d) async {
  final f = NumberFormat.decimalPattern('tr');
  String tl(dynamic v) => '${f.format((v is num ? v : 0).round())} TL';
  num n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  await _fontlariYukle();
  final font = _fontR!;
  final fontB = _fontB!;
  final doc = pw.Document();

  pw.Widget satir(String s, String v, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text(s, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          pw.Text(v, style: pw.TextStyle(fontSize: 11, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ]),
      );
  pw.Widget baslik(String t) => pw.Padding(padding: const pw.EdgeInsets.only(top: 10, bottom: 4), child: pw.Text(t, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)));

  final odeme = (d['odeme'] as List?) ?? [];
  final servis = (d['servis'] as List?) ?? [];
  final top = (d['top'] as List?) ?? [];

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    theme: pw.ThemeData.withFont(base: font, bold: fontB),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Center(child: pw.Text(d['isletme']?.toString() ?? 'ResteOS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold))),
      pw.Center(child: pw.Text('GÜN SONU / Z RAPORU · ${d['tarih']}', style: const pw.TextStyle(fontSize: 12))),
      pw.Divider(thickness: 1.5),
      satir('Toplam Ciro', tl(d['ciro']), bold: true),
      satir('Kapanan Adisyon', '${n(d['kapanan']).toInt()}'),
      satir('Misafir', '${n(d['misafir']).toInt()}'),
      satir('Adisyon Ortalaması', tl(d['ortalama'])),
      satir('Kişi Başı', tl(d['kisi_basi'])),
      satir('Açık Kalan Adisyon', '${n(d['acik_kalan']).toInt()}'),
      baslik('Ödeme Dağılımı'),
      for (final o in odeme) satir((o as Map)['tip'].toString().toUpperCase(), '${n(o['adet']).toInt()} · ${tl(o['tutar'])}'),
      baslik('Servis Tipi'),
      for (final s in servis) satir((s as Map)['ad'].toString(), '${n(s['adet']).toInt()} · ${tl(s['tutar'])}'),
      baslik('Kayıp / Sızıntı'),
      satir('İskonto', tl(d['iskonto'])),
      satir('İkram', tl(d['ikram'])),
      satir('Silinen Ürün (void)', tl(d['void'])),
      satir('İptal Adisyon', '${n(d['iptal_adet']).toInt()} · ${tl(d['iptal_tutar'])}'),
      satir('Fire', tl(d['fire'])),
      baslik('Maliyet / Kâr'),
      satir('Food-Cost', '${tl(d['maliyet'])} (%${n(d['maliyet_yuzde']).toInt()})'),
      satir('Brüt Kâr', tl(d['brut_kar']), bold: true),
      baslik('En Çok Satan'),
      for (final t in top) satir((t as Map)['urun_adi'].toString(), '${n(t['adet']).toInt()} adet'),
      pw.SizedBox(height: 16),
      pw.Center(child: pw.Text('ResteOS · ${d['tarih']}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey))),
    ]),
  ));
  return doc.save();
}

/// Adisyon fişi -> uygulama içi önizleme (geri butonlu) -> oradan yazdır/paylaş.
Future<void> fisYazdir(BuildContext context, Map d) async {
  final data = await _fisDoc(d);
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PdfOnizlemeScreen(baslik: 'Fiş', bytes: () => data),
  ));
}

/// Gün Sonu (Z Raporu) -> uygulama içi önizleme (geri butonlu) -> oradan yazdır/paylaş.
Future<void> zRaporuYazdir(BuildContext context, Map d) async {
  final data = await _zRaporuDoc(d);
  if (!context.mounted) return;
  await Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => PdfOnizlemeScreen(baslik: 'Z Raporu', bytes: () => data),
  ));
}

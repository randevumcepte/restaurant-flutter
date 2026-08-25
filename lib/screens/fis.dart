import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';

/// Adisyon fişi -> 80mm termal PDF -> sistem yazdır/paylaş (herhangi bir yazıcı / PDF kaydet).
Future<void> fisYazdir(Map d) async {
  final f = NumberFormat.decimalPattern('tr');
  String tl(dynamic v) => '${f.format((v is num ? v : 0).round())} TL';
  num n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  final font = await PdfGoogleFonts.notoSansRegular();
  final fontB = await PdfGoogleFonts.notoSansBold();
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
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      pw.Center(child: pw.Text(d['isletme']?.toString() ?? 'RestoOS', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
      if ((d['adres']?.toString() ?? '').isNotEmpty) pw.Center(child: pw.Text(d['adres'].toString(), style: const pw.TextStyle(fontSize: 8))),
      if ((d['telefon']?.toString() ?? '').isNotEmpty) pw.Center(child: pw.Text(d['telefon'].toString(), style: const pw.TextStyle(fontSize: 8))),
      pw.Divider(),
      satir('Masa: ${d['masa']}', 'No: ${d['adisyon_no']}', fs: 9),
      satir('Garson: ${d['garson']}', d['tarih']?.toString() ?? '', fs: 9),
      pw.Divider(),
      for (final k in kalemler)
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 1),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Expanded(child: pw.Text('${n((k as Map)['adet']).toInt()}x ${k['ad']}', style: const pw.TextStyle(fontSize: 9))),
            pw.Text(tl(k['tutar']), style: const pw.TextStyle(fontSize: 9)),
          ]),
        ),
      pw.Divider(),
      satir('Ara Toplam', tl(d['ara_toplam'])),
      if (n(d['indirim']) > 0) satir('İskonto', '-${tl(d['indirim'])}'),
      if (n(d['ikram']) > 0) satir('İkram', '-${tl(d['ikram'])}'),
      pw.SizedBox(height: 4),
      satir('TOPLAM', tl(d['toplam']), fs: 13, bold: true),
      pw.SizedBox(height: 10),
      pw.Center(child: pw.Text('Afiyet olsun · Teşekkürler', style: const pw.TextStyle(fontSize: 9))),
      pw.SizedBox(height: 6),
    ]),
  ));

  await Printing.layoutPdf(onLayout: (format) => doc.save());
}

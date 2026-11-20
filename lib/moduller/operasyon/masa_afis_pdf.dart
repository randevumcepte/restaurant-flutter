import 'dart:io';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../ui/kit.dart';

/// Masa QR afişi üretimi (web /masa-afisler + /masa-yonetim yazdır/indir karşılığı).
///  - A6: her masa bir sayfa (web masa yönetimi "Yazdır")
///  - A4: sayfada 4 afiş, 2 sütun (web /masa-afisler "Yazdır / PDF İndir")
enum OpMasaAfisDuzen { a6, a4 }

pw.Font? _fR, _fB;

Future<pw.ThemeData> _tema() async {
  _fR ??= await PdfGoogleFonts.nunitoRegular();
  _fB ??= await PdfGoogleFonts.nunitoExtraBold();
  return pw.ThemeData.withFont(base: _fR!, bold: _fB!);
}

String opMasaAfisDosyaAdi(String s) {
  final t = s.replaceAll(RegExp(r'[\\/:*?"<>|]+'), '-').trim();
  return t.isEmpty ? 'Masa' : t;
}

const _mor = PdfColor.fromInt(0xFF7C3AED);
const _gri = PdfColor.fromInt(0xFF6B7280);

pw.Widget _afis(String sube, Map<String, dynamic> m, {required bool buyuk}) {
  final url = metinOku(m['qr_url']);
  final ad = metinOku(m['ad'], '-');
  final qr = buyuk ? 170.0 : 150.0;
  return pw.Container(
    padding: const pw.EdgeInsets.all(14),
    decoration: buyuk
        ? null
        : pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400, style: pw.BorderStyle.dashed), borderRadius: pw.BorderRadius.circular(10)),
    child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
      pw.Container(height: 5, width: double.infinity, color: _mor),
      pw.SizedBox(height: 10),
      pw.Text(sube, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 4),
      pw.Text('Karekodu telefonunuzla okutun', style: const pw.TextStyle(fontSize: 10, color: _gri)),
      pw.Text('Menü · Sipariş · Garson Çağır · Öde', style: const pw.TextStyle(fontSize: 9, color: _gri)),
      pw.SizedBox(height: 10),
      pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: url, width: qr, height: qr),
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: pw.BoxDecoration(color: _mor, borderRadius: pw.BorderRadius.circular(20)),
        child: pw.Text('MASA $ad', style: pw.TextStyle(fontSize: 18, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
      ),
    ]),
  );
}

/// QR'ı olan masalardan afiş PDF'i üretir.
Future<Uint8List> opMasaAfisPdf(String sube, List<Map<String, dynamic>> masalar, OpMasaAfisDuzen duzen) async {
  final doc = pw.Document(theme: await _tema(), title: 'Masa QR Afişleri');
  final liste = masalar.where((m) => metinOku(m['qr_url']).isNotEmpty).toList();
  if (duzen == OpMasaAfisDuzen.a6) {
    for (final m in liste) {
      doc.addPage(pw.Page(pageFormat: PdfPageFormat.a6, margin: const pw.EdgeInsets.all(14), build: (_) => pw.Center(child: _afis(sube, m, buyuk: true))));
    }
  } else {
    for (var i = 0; i < liste.length; i += 4) {
      final parca = liste.sublist(i, (i + 4).clamp(0, liste.length));
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(18),
        build: (_) => pw.GridView(
          crossAxisCount: 2,
          childAspectRatio: 1.25,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: [for (final m in parca) _afis(sube, m, buyuk: false)],
        ),
      ));
    }
  }
  return doc.save();
}

/// Yazdır (sistem yazdırma penceresi — Windows'ta "PDF olarak kaydet" de buradan).
Future<void> opMasaAfisYazdir(BuildContext context, String sube, List<Map<String, dynamic>> masalar, OpMasaAfisDuzen duzen) async {
  if (!masalar.any((m) => metinOku(m['qr_url']).isNotEmpty)) {
    kToast(context, 'Yazdırılacak QR kodu bulunamadı.', hata: true);
    return;
  }
  try {
    await Printing.layoutPdf(name: 'Masa QR Afişleri', onLayout: (_) => opMasaAfisPdf(sube, masalar, duzen));
  } catch (e) {
    if (context.mounted) kToast(context, 'Yazdırılamadı: $e', hata: true);
  }
}

/// PDF olarak paylaş / kaydet (WhatsApp, e-posta, dosyalar).
Future<void> opMasaAfisPaylas(BuildContext context, String sube, List<Map<String, dynamic>> masalar, OpMasaAfisDuzen duzen, {String? dosya}) async {
  if (!masalar.any((m) => metinOku(m['qr_url']).isNotEmpty)) {
    kToast(context, 'Paylaşılacak QR kodu bulunamadı.', hata: true);
    return;
  }
  try {
    final b = await opMasaAfisPdf(sube, masalar, duzen);
    await Printing.sharePdf(bytes: b, filename: '${opMasaAfisDosyaAdi(dosya ?? 'QR-Afisleri-$sube')}.pdf');
  } catch (e) {
    if (context.mounted) kToast(context, 'PDF hazırlanamadı: $e', hata: true);
  }
}

/// Tek masanın QR'ını baskıya uygun 1000px PNG olarak kaydet (web "QR kodunu indir").
Future<void> opMasaQrPngKaydet(BuildContext context, Map<String, dynamic> m) async {
  final url = metinOku(m['qr_url']);
  if (url.isEmpty) {
    kToast(context, 'Bu masanın QR kodu henüz oluşmamış.', hata: true);
    return;
  }
  try {
    final painter = QrPainter(
      data: url,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF14121A)),
      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF14121A)),
    );
    // Beyaz kenarlı görüntü: QR 920px + 40px kenar boşluğu
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(const Rect.fromLTWH(0, 0, 1000, 1000), Paint()..color = Colors.white);
    c.translate(40, 40);
    painter.paint(c, const Size(920, 920));
    final img = await rec.endRecording().toImage(1000, 1000);
    final bd = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bd == null) throw Exception('görüntü');
    final bytes = bd.buffer.asUint8List();
    final ad = 'QR-${opMasaAfisDosyaAdi(metinOku(m['ad'], 'Masa'))}.png';
    final yol = await FilePicker.platform.saveFile(dialogTitle: 'QR kodunu kaydet', fileName: ad, bytes: bytes, type: FileType.custom, allowedExtensions: ['png']);
    if (yol == null) return; // vazgeçti
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      await File(yol.toLowerCase().endsWith('.png') ? yol : '$yol.png').writeAsBytes(bytes);
    }
    if (context.mounted) kToast(context, '$ad kaydedildi.');
  } catch (e) {
    if (context.mounted) kToast(context, 'QR kodu kaydedilemedi: $e', hata: true);
  }
}

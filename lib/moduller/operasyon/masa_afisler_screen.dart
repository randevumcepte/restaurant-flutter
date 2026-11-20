import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'masa_afis_pdf.dart';

/// Web /masa-afisler — tüm masaların QR afişleri tek belgede (yazdır / PDF indir-paylaş).
/// Veri: aktif şubenin masaları (/masa-yonetim ile aynı kaynak; arşivdeki masalar basılmaz).
/// Uygulamada ek olarak: afiş düzeni (A4'te 4'lü ya da A6 tek afiş) ve bölge süzgeci.
class OpMasaAfislerScreen extends StatelessWidget {
  const OpMasaAfislerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sube = context.read<AuthProvider>().sube ?? 'Restoran';
    return KopruEkran(
      yol: '/masa-yonetim',
      baslik: 'Masa QR Afişleri',
      ikon: Icons.qr_code,
      govde: (ctx, v, yenile) => _Govde(masalar: liste(v['aktif']), sube: sube, yenile: yenile),
    );
  }
}

class _Govde extends StatefulWidget {
  final List<Map<String, dynamic>> masalar;
  final String sube;
  final Future<void> Function() yenile;
  const _Govde({required this.masalar, required this.sube, required this.yenile});
  @override
  State<_Govde> createState() => _GovdeState();
}

class _GovdeState extends State<_Govde> {
  OpMasaAfisDuzen _duzen = OpMasaAfisDuzen.a4;
  String _bolge = '';

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final qrli = widget.masalar.where((m) => metinOku(m['qr_url']).isNotEmpty).toList();
    if (qrli.isEmpty) {
      return KGovde(yenile: widget.yenile, children: const [
        KBos(
          ikon: Icons.qr_code_2,
          baslik: 'Basılacak QR afişi yok',
          aciklama: 'Aktif masa bulunmuyor ya da masaların QR kodu oluşmamış. Masalar "Masa & QR Yönetimi" ekranından eklenir; her yeni masaya QR kodu otomatik verilir.',
        ),
      ]);
    }
    final bolgeler = <String>{for (final m in qrli) metinOku(m['bolge'], 'Bölgesiz')}.toList();
    final secili = _bolge.isEmpty ? qrli : qrli.where((m) => metinOku(m['bolge'], 'Bölgesiz') == _bolge).toList();
    final sayfa = _duzen == OpMasaAfisDuzen.a4 ? (secili.length / 4).ceil() : secili.length;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            KIkon(Icons.restaurant, renk: t.mor1),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${widget.sube} · Masa QR Afişleri', style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
                Text('${secili.length} masa · $sayfa sayfa', style: TextStyle(color: t.sub, fontSize: 12.5)),
              ]),
            ),
          ]),
          const SizedBox(height: 10),
          KCipler(
            secenekler: const [('a4', 'A4 · sayfada 4 afiş'), ('a6', 'A6 · masa başına 1 afiş')],
            secili: _duzen == OpMasaAfisDuzen.a4 ? 'a4' : 'a6',
            onSec: (k) => setState(() => _duzen = k == 'a4' ? OpMasaAfisDuzen.a4 : OpMasaAfisDuzen.a6),
          ),
          if (bolgeler.length > 1)
            KCipler(
              secenekler: [('', 'Tüm bölgeler'), for (final b in bolgeler) (b, b)],
              secili: _bolge,
              onSec: (k) => setState(() => _bolge = k),
            ),
        ]),
      ),
      Expanded(
        child: PdfPreview(
          key: ValueKey('${_duzen.name}|$_bolge|${secili.length}'),
          build: (_) => opMasaAfisPdf(widget.sube, secili, _duzen),
          canChangePageFormat: false,
          canChangeOrientation: false,
          canDebug: false,
          allowPrinting: true,
          allowSharing: true,
          pdfFileName: 'QR-Afisleri-${opMasaAfisDosyaAdi(widget.sube)}.pdf',
          scrollViewDecoration: BoxDecoration(color: t.bg),
          pdfPreviewPageDecoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8)]),
          loadingWidget: const KYukleniyor(metin: 'Afişler hazırlanıyor…'),
          onError: (c, e) => KHata('Afiş belgesi hazırlanamadı: $e'),
        ),
      ),
    ]);
  }
}

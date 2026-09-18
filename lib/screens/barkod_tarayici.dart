import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// ORTAK BARKOD TARAYICI — kamerayı açar, okunan kodu Navigator.pop ile döndürür.
/// Kullanım:  final kod = await BarkodTarayici.oku(context);
class BarkodTarayici extends StatefulWidget {
  final String baslik;
  const BarkodTarayici({super.key, this.baslik = 'Barkod Okut'});

  static Future<String?> oku(BuildContext context, {String baslik = 'Barkod Okut'}) {
    return Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => BarkodTarayici(baslik: baslik), fullscreenDialog: true));
  }

  @override
  State<BarkodTarayici> createState() => _BarkodTarayiciState();
}

class _BarkodTarayiciState extends State<BarkodTarayici> {
  final MobileScannerController _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _verildi = false;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _yakala(String kod) {
    if (_verildi) return;
    _verildi = true;
    Navigator.of(context).pop(kod);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text(widget.baslik),
        actions: [
          IconButton(onPressed: () => _ctrl.toggleTorch(), icon: const Icon(Icons.flash_on)),
        ]),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: (cap) {
            final b = cap.barcodes.isNotEmpty ? cap.barcodes.first : null;
            final v = b?.rawValue;
            if (v != null && v.trim().isNotEmpty) _yakala(v.trim());
          },
        ),
        // orta nişangah
        Center(child: Container(width: 260, height: 150, decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF7C3AED), width: 3), borderRadius: BorderRadius.circular(14)))),
        const Positioned(left: 0, right: 0, bottom: 40, child: Text('Barkodu çerçeveye getir',
          textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14))),
      ]),
    );
  }
}

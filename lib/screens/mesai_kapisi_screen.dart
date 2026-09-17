import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/mesai_servisi.dart';

/// MESAİ KAPISI — garson/personel mesai açık değilken görür. İşletme bilgileri KİLİTLİ;
/// kasadaki QR'ı okutunca mesai başlar (MesaiServisi.kilit false olur → uygulama açılır).
class MesaiKapisiScreen extends StatefulWidget {
  const MesaiKapisiScreen({super.key});
  @override
  State<MesaiKapisiScreen> createState() => _MesaiKapisiScreenState();
}

class _MesaiKapisiScreenState extends State<MesaiKapisiScreen> {
  final MobileScannerController _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _isliyor = false;
  String? _mesaj;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _isle(String kod) async {
    if (_isliyor) return;
    setState(() { _isliyor = true; _mesaj = 'Kontrol ediliyor…'; });
    final r = await MesaiServisi().okut(kod);
    if (!mounted) return;
    if (r['ok'] == 1) {
      final giris = r['durum'] == 'giris';
      setState(() => _mesaj = giris ? 'Mesai başladı ✓ (${r['saat']})' : 'Mesai kapandı ✓');
      // Giriş başarılı → kilit MesaiServisi tarafından açıldı; ekran otomatik kapanır (home dinliyor).
    } else {
      setState(() => _mesaj = (r['hata']?.toString() ?? 'Okunamadı'));
      await Future.delayed(const Duration(milliseconds: 1400));
      if (mounted) setState(() { _isliyor = false; _mesaj = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFF0B1020),
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 18),
          const Icon(Icons.lock_clock, color: Colors.white, size: 42),
          const SizedBox(height: 10),
          Text('Mesai Başlat', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text('${auth.ad ?? 'Personel'} — kasadaki QR kodunu okut. Mesai başlamadan işletme bilgileri görünmez.',
                textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13, height: 1.35)),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 280, height: 280,
                  child: Stack(fit: StackFit.expand, children: [
                    MobileScanner(
                      controller: _ctrl,
                      onDetect: (cap) {
                        final b = cap.barcodes.isNotEmpty ? cap.barcodes.first : null;
                        final v = b?.rawValue;
                        if (v != null && v.isNotEmpty) _isle(v);
                      },
                    ),
                    // çerçeve
                    IgnorePointer(child: Container(decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: t.mor1, width: 3)))),
                    if (_isliyor) Container(color: Colors.black54, alignment: Alignment.center,
                        child: const CircularProgressIndicator(color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ),
          if (_mesaj != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_mesaj!, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () { MesaiServisi().cikisYap(); auth.cikis(); },
            icon: const Icon(Icons.logout, color: Color(0xFFF87171), size: 18),
            label: const Text('Çıkış Yap', style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
        ]),
      ),
    );
  }
}

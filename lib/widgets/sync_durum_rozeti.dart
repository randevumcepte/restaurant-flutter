import 'package:flutter/material.dart';
import '../local/cihaz_rol.dart';
import '../local/sync_service.dart';

/// Senkron durum rozeti (app bar): cevrimici/cevrimdisi + bekleyen islem + son senkron.
/// SyncService (ChangeNotifier singleton) dinler -> durum degisince kendini yeniler.
/// Dokununca elle senkron tetikler.
class SyncDurumRozeti extends StatelessWidget {
  const SyncDurumRozeti({super.key});

  String _zamanOnce(DateTime? t) {
    if (t == null) return 'henüz yok';
    final fark = DateTime.now().difference(t);
    if (fark.inSeconds < 10) return 'az önce';
    if (fark.inMinutes < 1) return '${fark.inSeconds} sn önce';
    if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
    return '${fark.inHours} sa önce';
  }

  @override
  Widget build(BuildContext context) {
    // TERMINAL: senkron etmez (veriyi kasadan ceker) -> senkron durumu yaniltici olur.
    // Bunun yerine sade "Terminal" rozeti goster.
    if (CihazRol.rol == Rol.terminal) {
      return Container(
        margin: const EdgeInsets.only(right: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lan_outlined, size: 15, color: Color(0xFF6366F1)),
          SizedBox(width: 6),
          Text('Terminal', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1))),
        ]),
      );
    }
    final s = SyncService.instance;
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        // Durum -> renk / ikon / metin
        Color renk;
        IconData ikon;
        String metin;
        if (s.calisiyor) {
          renk = const Color(0xFF6366F1); // indigo
          ikon = Icons.sync;
          metin = 'Senkron…';
        } else if (!s.online) {
          renk = const Color(0xFF94A3B8); // slate
          ikon = Icons.cloud_off;
          metin = s.bekleyen > 0 ? 'Çevrimdışı · ${s.bekleyen}' : 'Çevrimdışı';
        } else if (s.bekleyen > 0) {
          renk = const Color(0xFFF59E0B); // amber
          ikon = Icons.cloud_upload;
          metin = '${s.bekleyen} bekliyor';
        } else {
          renk = const Color(0xFF10B981); // emerald
          ikon = Icons.cloud_done;
          metin = 'Güncel';
        }

        return Tooltip(
          message: 'Senkron: ${s.online ? "çevrimiçi" : "çevrimdışı"}\n'
              'Bekleyen: ${s.bekleyen}\nSon senkron: ${_zamanOnce(s.sonSenkron)}\n(dokun: şimdi senkronla)',
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: s.online ? () => s.simdiSenkronla() : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: renk.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  s.calisiyor
                      ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: renk))
                      : Icon(ikon, size: 15, color: renk),
                  const SizedBox(width: 6),
                  Text(metin, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: renk)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

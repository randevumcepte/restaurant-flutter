import '../../kopru/ekran_kayit.dart';
import 'kurye_canli_screen.dart';
import 'wa_hatlar_screen.dart';
import 'whatsapp_yonetim_screen.dart';
import 'yasal_bilgiler_screen.dart';

/// Operasyon › İletişim + yasal + kurye: WhatsApp yönetimi, çoklu WA hattı, yasal bilgiler, canlı kurye haritası.
void kayitOperasyonIletisim() {
  EkranKayit.tam('/whatsapp', (u, a) => const OpWhatsappScreen());
  EkranKayit.tam('/wa-hatlar', (u, a) => const OpWaHatlarScreen());
  EkranKayit.tam('/yasal-bilgiler', (u, a) => const OpYasalBilgilerScreen());
  EkranKayit.onek('/yasal-onizle/', (u, a) {
    final tip = u.split('?').first.split('/').last;
    return OpYasalOnizleScreen(tip: tip, baslik: a.isEmpty ? 'Yasal Belge' : a);
  });
  EkranKayit.tam('/kurye-canli', (u, a) => const OpKuryeCanliScreen());
}

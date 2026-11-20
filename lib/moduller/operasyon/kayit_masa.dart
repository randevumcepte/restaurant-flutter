import '../../kopru/ekran_kayit.dart';
import '../../screens/salon_sema_screen.dart';
import 'masa_afisler_screen.dart';
import 'masa_yonetim_screen.dart';
import 'odeme_ayar_screen.dart';

/// Operasyon › Masa & salon & ödeme ayarları.
void kayitOperasyonMasa() {
  EkranKayit.tam('/masa-yonetim', (u, a) => const OpMasaYonetimScreen());
  EkranKayit.tam('/masa-afisler', (u, a) => const OpMasaAfislerScreen());
  // Salon şema: web sayfası bu ekranın birebir karşılığı (aynı uçlar /api/patron/salon-sema(-kaydet), aynı veri biçimi) → eski yerel ekran
  EkranKayit.tam('/salon-sema', (u, a) => const SalonSemaScreen());
  EkranKayit.tam('/odeme-ayar', (u, a) => const OpOdemeAyarScreen());
}

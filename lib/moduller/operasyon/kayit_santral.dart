import '../../kopru/ekran_kayit.dart';
import 'cagri_ekran_screen.dart';
import 'cagri_merkezi_screen.dart';
import 'santral_ayar_screen.dart';
import 'santral_egitim_screen.dart';
import 'santral_kayitlar_screen.dart';

/// AI Santral ekranları (web /santral-kayitlar, /cagrilar, /cagri-ekran, /santral-ayar, /santral-egitim).
void kayitOperasyonSantral() {
  EkranKayit.tam('/santral-kayitlar', (u, a) => const OpSantralKayitlarScreen());
  EkranKayit.tam('/cagrilar', (u, a) => const OpCagriMerkeziScreen());
  EkranKayit.tam('/cagri-ekran', (u, a) => const OpCagriEkranScreen());
  EkranKayit.tam('/santral-ayar', (u, a) => const OpSantralAyarScreen());
  EkranKayit.tam('/santral-egitim', (u, a) => const OpSantralEgitimScreen());
}

import '../../kopru/ekran_kayit.dart';
import 'banka_cek_screens.dart';
import 'cari_screen.dart';
import 'donem_screens.dart';
import 'finans_ozet_screen.dart';
import 'gider_screens.dart';
import 'muhasebe_entegrasyon_screen.dart';
import 'muhasebe_screens.dart';
import 'raporlar_kasalar_screens.dart';
import 'tedarikci_yaslandirma_screen.dart';

/// Modül ekran kaydı: web adresi → bu modülün ekranı (EkranKayit.tam / EkranKayit.onek).
/// Not: /kasa ve /z-raporu kasiyerin günlük ekranlarıdır; ekran_kayit.dart'taki mevcut yerel
/// KasaScreen / ZRaporuScreen kaydı korunur (burada üzerine yazılmaz).
void kayitFinans() {
  EkranKayit.tam('/finans', (u, a) => const FinansOzetScreen());
  EkranKayit.tam('/kar-zarar', (u, a) => const KarZararScreen());
  EkranKayit.tam('/bilanco', (u, a) => const BilancoScreen());
  EkranKayit.tam('/kdv-ozet', (u, a) => const KdvOzetScreen());
  EkranKayit.tam('/beyanname', (u, a) => const BeyannameScreen());
  EkranKayit.tam('/vergi-takvimi', (u, a) => const VergiTakvimiScreen());
  EkranKayit.tam('/e-defter', (u, a) => const EDefterScreen());
  EkranKayit.tam('/muhasebe', (u, a) => const MuhasebeDefterScreen());
  EkranKayit.tam('/muhasebe-entegrasyon', (u, a) => const MuhasebeEntegrasyonScreen());
  EkranKayit.tam('/cari', (u, a) => const CariScreen());
  EkranKayit.tam('/banka', (u, a) => const BankaScreen());
  EkranKayit.tam('/cek-senet', (u, a) => const CekSenetScreen());
  EkranKayit.tam('/gider', (u, a) => const GiderlerScreen());
  EkranKayit.tam('/tekrarlayan-gider', (u, a) => const TekrarlayanGiderScreen());
  EkranKayit.tam('/online-komisyon', (u, a) => const OnlineKomisyonScreen());
  EkranKayit.tam('/tedarikci-yaslandirma', (u, a) => const TedarikciYaslandirmaScreen());
  EkranKayit.tam('/amortisman', (u, a) => const AmortismanScreen());
  EkranKayit.tam('/raporlar', (u, a) => const GenelRaporlarScreen());
  EkranKayit.tam('/kasalar', (u, a) => const KasalarScreen());
  EkranKayit.tam('/depozito', (u, a) => const DepozitoScreen());
}

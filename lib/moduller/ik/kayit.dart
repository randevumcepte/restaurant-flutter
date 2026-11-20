import '../../kopru/ekran_kayit.dart';
import 'departman_yonetim_screen.dart';
import 'garson_performans_screen.dart';
import 'garson_yonetimi_screen.dart';
import 'ik_aday_screen.dart';
import 'ik_izin_screen.dart';
import 'ik_ozet_screen.dart';
import 'ik_risk_screen.dart';
import 'ik_sicil_screen.dart';
import 'ik_vardiya_screen.dart';
import 'isletme_duzeni_screen.dart';
import 'isletme_konum_screen.dart';
import 'personel_screen.dart';
import 'personel_yemek_screen.dart';
import 'puantaj_screen.dart';

/// Modül ekran kaydı: web adresi → bu modülün ekranı (EkranKayit.tam / EkranKayit.onek).
void kayitIk() {
  EkranKayit.tam('/personel', (u, a) => const IkPersonelScreen());
  EkranKayit.tam('/departman-yonetim', (u, a) => const IkDepartmanYonetimScreen());
  EkranKayit.tam('/puantaj', (u, a) => const IkPuantajScreen());
  EkranKayit.tam('/garson-performans', (u, a) => const IkGarsonPerformansScreen());
  EkranKayit.tam('/ik-ozet', (u, a) => const IkOzetScreen());
  EkranKayit.tam('/ik-izin', (u, a) => const IkIzinScreen());
  EkranKayit.tam('/ik-vardiya', (u, a) => const IkVardiyaScreen());
  EkranKayit.tam('/ik-sicil', (u, a) => IkSicilScreen(url: u));
  EkranKayit.tam('/ik-aday', (u, a) => const IkAdayScreen());
  EkranKayit.tam('/ik-risk', (u, a) => const IkRiskScreen());
  EkranKayit.tam('/personel-yemek', (u, a) => const IkPersonelYemekScreen());
  EkranKayit.tam('/isletme-duzeni', (u, a) => const IkIsletmeDuzeniScreen());
  EkranKayit.tam('/garson-yonetimi', (u, a) => const IkGarsonYonetimiScreen());
  EkranKayit.tam('/isletme-konum', (u, a) => const IkIsletmeKonumScreen());
}

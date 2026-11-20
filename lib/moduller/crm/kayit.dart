import '../../kopru/ekran_kayit.dart';
import 'crm_cark_screen.dart';
import 'crm_itibar_screen.dart';
import 'crm_musteri360_screen.dart';
import 'crm_musteriler_screen.dart';
import 'crm_odul_raporu_screen.dart';
import 'crm_sadakat_screen.dart';
import 'crm_sosyal_medya_screen.dart';
import 'menu_kayit.dart';
import 'pz_diger_screens.dart';
import 'pz_kampanya_push_screen.dart';
import 'pz_kampanya_screen.dart';

/// Modül ekran kaydı: web adresi → bu modülün ekranı (EkranKayit.tam / EkranKayit.onek).
/// CRM / Pazarlama / Rezervasyon satış / Menü & Ürünler.
void kayitCrm() {
  // ── CRM / Müşteri ilişkileri ──
  EkranKayit.tam('/musteri-360', (u, a) => CrmMusteri360Screen(url: u)); // ?seg=vip / ?seg=kayip url'den okunur
  EkranKayit.tam('/musteriler', (u, a) => const CrmMusterilerScreen());
  EkranKayit.tam('/sadakat', (u, a) => const CrmSadakatScreen());
  EkranKayit.tam('/itibar', (u, a) => const CrmItibarScreen());
  EkranKayit.tam('/social-media', (u, a) => const CrmSosyalMedyaScreen());
  EkranKayit.tam('/odul-raporu', (u, a) => const CrmOdulRaporuScreen());
  EkranKayit.tam('/cark-yonetim', (u, a) => const CrmCarkScreen());
  EkranKayit.tam('/cark-kazananlar', (u, a) => const CrmCarkScreen(ilkSekme: 1));
  EkranKayit.tam('/cark-hatirlatma', (u, a) => const CrmCarkScreen(ilkSekme: 2));

  // ── Pazarlama ──
  EkranKayit.tam('/kampanya', (u, a) => const PzKampanyaScreen());
  EkranKayit.tam('/kampanya-push', (u, a) => PzKampanyaPushScreen(url: u));
  EkranKayit.tam('/segmentler', (u, a) => const PzSegmentlerScreen());
  EkranKayit.tam('/icerik-takvimi', (u, a) => const PzIcerikTakvimiScreen());
  EkranKayit.tam('/kampanya-rapor', (u, a) => const PzKampanyaRaporScreen());

  // ── Rezervasyon satış ──
  EkranKayit.tam('/etkinlik-takvim', (u, a) => const RzEtkinlikTakvimScreen());

  // ── Menü & Ürünler (ayrı dosya) ──
  kayitCrmMenu();
}

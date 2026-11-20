import '../../kopru/ekran_kayit.dart';
import '../../screens/fiyat_radari_screen.dart';
import '../../screens/sube_transfer_screen.dart';
import 'efatura_gelen_screen.dart';
import 'eposta_hesaplari_screen.dart';
import 'fatura_analiz_screen.dart';
import 'fatura_denetim_screen.dart';
import 'fatura_eslestir_screen.dart';
import 'fatura_ocr_screen.dart';
import 'fiyat_anlasmalari_screen.dart';
import 'gelen_teklifler_screen.dart';
import 'hal_fiyatlari_screen.dart';
import 'mal_kabul_screen.dart';
import 'mustahsil_screen.dart';
import 'onay_seviye_screen.dart';
import 'reddedilen_talepler_screen.dart';
import 'satinalma_asistan_screen.dart';
import 'satinalma_butce_screen.dart';
import 'satinalma_islemleri_screen.dart';
import 'satinalma_siparis_screen.dart';
import 'satinalma_talep_screen.dart';
import 'siparis_onerisi_screen.dart';
import 'talep_onaylarim_screen.dart';

int _id(String url) => int.tryParse(Uri.parse(url).queryParameters['id'] ?? '') ?? 0;

/// Modül ekran kaydı: web adresi → bu modülün ekranı (EkranKayit.tam / EkranKayit.onek).
void kayitSatinalma() {
  // Talep → onay → teklif
  EkranKayit.tam('/satinalma-talep', (u, a) => SatinalmaTalepScreen(url: u));
  EkranKayit.tam('/talep-onaylarim', (u, a) => const TalepOnaylarimScreen());
  EkranKayit.tam('/reddedilen-talepler', (u, a) => const ReddedilenTaleplerScreen());
  EkranKayit.tam('/gelen-teklifler', (u, a) => const GelenTekliflerScreen());
  // Sipariş → mal kabul
  EkranKayit.tam('/siparis-onerisi', (u, a) => const SiparisOnerisiScreen());
  EkranKayit.tam('/satinalma-siparis', (u, a) => const SatinalmaSiparisScreen());
  EkranKayit.tam('/satinalma-siparis-detay', (u, a) => _id(u) > 0 ? SiparisDetayScreen(id: _id(u)) : const SatinalmaSiparisScreen());
  EkranKayit.tam('/mal-kabul', (u, a) => MalKabulScreen(url: u));
  EkranKayit.tam('/mal-kabul-liste', (u, a) => const MalKabulListeScreen());
  EkranKayit.tam('/mal-kabul-detay', (u, a) => _id(u) > 0 ? MalKabulDetayScreen(id: _id(u)) : const MalKabulListeScreen());
  EkranKayit.tam('/satinalma-islemleri', (u, a) => const SatinalmaIslemleriScreen());
  // Fatura
  EkranKayit.tam('/efatura-gelen', (u, a) => const EfaturaGelenScreen());
  EkranKayit.onek('/efatura-gelen/', (u, a) {
    final p = Uri.parse(u).pathSegments;
    final id = p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0;
    return id > 0 ? EfaturaDetayScreen(id: id) : const EfaturaGelenScreen();
  });
  EkranKayit.tam('/fatura-denetim', (u, a) => const FaturaDenetimScreen());
  EkranKayit.tam('/fatura-analiz', (u, a) => const FaturaAnalizScreen());
  EkranKayit.onek('/fatura-analiz/', (u, a) => FaturaAnalizScreen(url: u));
  EkranKayit.tam('/fatura-eslestir', (u, a) => FaturaEslestirScreen(url: u));
  EkranKayit.tam('/fatura-ocr', (u, a) => const FaturaOcrScreen());
  EkranKayit.tam('/mustahsil', (u, a) => const MustahsilScreen());
  // Fiyat & analiz
  EkranKayit.tam('/fiyat-radari', (u, a) => const FiyatRadariScreen()); // eski yerel ekran: web v2 ile aynı uçlar (/api/patron/fiyat-radari-v2), güncel
  EkranKayit.tam('/hal-fiyatlari', (u, a) => const HalFiyatlariScreen());
  EkranKayit.tam('/fiyat-anlasmalari', (u, a) => const FiyatAnlasmalariScreen());
  EkranKayit.tam('/fiyat-anlasmalari/rapor', (u, a) => const FiyatAnlasmaRaporScreen());
  // Ayarlar
  EkranKayit.tam('/satinalma-onay-seviye', (u, a) => const OnaySeviyeScreen());
  EkranKayit.tam('/satinalma-butce', (u, a) => const SatinalmaButceScreen());
  EkranKayit.tam('/eposta-hesaplari', (u, a) => const EpostaHesaplariScreen());
  // Şubeler arası transfer: eski yerel ekran web /sube-transfer ile aynı uçları kullanıyor, güncel (grup/franchise kontrolü sunucuda)
  EkranKayit.tam('/sube-transfer', (u, a) => const SubeTransferScreen());
  // AI
  EkranKayit.tam('/satinalma-asistan', (u, a) => const SatinalmaAsistanScreen());
}

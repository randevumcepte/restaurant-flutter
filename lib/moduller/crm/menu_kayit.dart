import '../../kopru/ekran_kayit.dart';
import '../../screens/indirimler_screen.dart';
import '../../screens/menu_yonetimi_screen.dart';
import 'menu_app_kartlar_screen.dart';
import 'menu_fix_menu_screen.dart';
import 'menu_happy_hour_screen.dart';
import 'menu_one_cikanlar_screen.dart';
import 'menu_qr_rengi_screen.dart';
import 'menu_urun_fotolar_screen.dart';

/// Menü & Ürünler grubu: web adresi → uygulama ekranı. kayitCrm() içinden çağrılır.
void kayitCrmMenu() {
  // Eski yerel ekranlar web'le birebir (web sayfası bunlardan kopyalandı; aynı /api/patron uçları) → bağlandı.
  EkranKayit.tam('/menu', (u, a) => const MenuYonetimiScreen());
  EkranKayit.tam('/indirimler', (u, a) => const IndirimlerScreen());
  // Yeni yazılanlar
  EkranKayit.tam('/qr-menu-rengi', (u, a) => const MenuQrRengiScreen());
  EkranKayit.tam('/tema', (u, a) => const MenuQrRengiScreen());
  EkranKayit.tam('/app-yonetim', (u, a) => const MenuAppKartlarScreen());
  EkranKayit.tam('/happy-hour', (u, a) => const MenuHappyHourScreen());
  EkranKayit.tam('/fix-menu', (u, a) => const MenuFixMenuScreen());
  EkranKayit.tam('/one-cikanlar', (u, a) => const MenuOneCikanlarScreen());
  EkranKayit.tam('/urun-fotolar', (u, a) => const MenuUrunFotolarScreen());
}

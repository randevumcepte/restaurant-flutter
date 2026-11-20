import 'package:flutter/material.dart';
import '../screens/dashboard_screen.dart';
import '../screens/masalar_screen.dart';
import '../screens/mutfak_screen.dart';
import '../screens/paket_screen.dart';
import '../screens/rezervasyon_screen.dart';
import '../screens/garson_cagrilari_screen.dart';
import '../screens/servis_akis_screen.dart';
import '../screens/karsilama_screen.dart';
import '../screens/kasa_screen.dart';
import '../screens/z_raporu_screen.dart';
import '../screens/odul_dogrula_screen.dart';
import '../screens/bildirim_ayar_screen.dart';
import '../screens/lan_ayar_screen.dart';
import '../screens/departman_is_screen.dart';
import '../screens/santral_ses_screen.dart';
import '../screens/dahili_yonetim_screen.dart';
import '../screens/freepbx_ayar_screen.dart';
import '../screens/mesai_qr_screen.dart';
import 'genel_sayfa_screen.dart';
import 'rapor_merkezi_screen.dart';
import '../moduller/satinalma/kayit.dart';
import '../moduller/stok/kayit.dart';
import '../moduller/finans/kayit.dart';
import '../moduller/ik/kayit.dart';
import '../moduller/crm/kayit.dart';
import '../moduller/operasyon/kayit.dart';
import '../moduller/ai/kayit.dart';

/// WEB ADRESİ → UYGULAMA EKRANI. Menü (sunucudan, web'in aynısı) bir bağlantı verir; burası onu açar.
///  1) tam adres (sorgu dahil)  2) sorgusuz adres  3) en uzun önek  4) yoksa GenelSayfaScreen
/// (GenelSayfa: sayfanın web verisini düzenli gösterir — hiçbir bağlantı boş/çalışmaz kalmaz).
typedef EkranUret = Widget Function(String url, String ad);

class EkranKayit {
  static final Map<String, EkranUret> _tam = {};
  static final Map<String, EkranUret> _onek = {};

  /// Tam adres (ör. '/stok' ya da '/kalite-kayit?tip=numune')
  static void tam(String url, EkranUret f) => _tam[url] = f;
  /// Önek (ör. '/mutfak-raporlar/' → altındaki tüm sayfalar)
  static void onek(String onek, EkranUret f) => _onek[onek] = f;

  static Widget uret(String url, String ad) {
    final f = _tam[url] ?? _tam[url.split('?').first];
    if (f != null) return f(url, ad);
    String? enUzun;
    for (final o in _onek.keys) {
      if (url.startsWith(o) && (enUzun == null || o.length > enUzun.length)) enUzun = o;
    }
    if (enUzun != null) return _onek[enUzun]!(url, ad);
    return GenelSayfaScreen(url: url, baslik: ad);
  }

  /// Bu adresin uygulamada özel (yerel) ekranı var mı (yoksa genel görünüm)
  static bool ozelMi(String url) {
    if (_tam.containsKey(url) || _tam.containsKey(url.split('?').first)) return true;
    return _onek.keys.any((o) => url.startsWith(o));
  }
}

/// Uygulama açılışında bir kez çağrılır (main.dart).
void ekranlariKaydet() {
  // ── Mevcut yerel ekranlar (web ile aynı veriyi kullanan, güncel olanlar) ──
  EkranKayit.tam('/dashboard', (u, a) => const DashboardScreen());
  EkranKayit.tam('/pos', (u, a) => const MasalarScreen());
  EkranKayit.tam('/mutfak', (u, a) => const MutfakScreen());
  EkranKayit.tam('/paket', (u, a) => const PaketScreen());
  EkranKayit.tam('/rezervasyon', (u, a) => const RezervasyonScreen());
  EkranKayit.tam('/garson-cagrilari', (u, a) => const GarsonCagrilariScreen());
  EkranKayit.tam('/servis', (u, a) => const ServisAkisScreen());
  EkranKayit.tam('/karsilama', (u, a) => const KarsilamaScreen());
  EkranKayit.tam('/kasa', (u, a) => const KasaScreen());
  EkranKayit.tam('/z-raporu', (u, a) => const ZRaporuScreen());
  EkranKayit.tam('/odul-dogrula', (u, a) => const OdulDogrulaScreen());
  EkranKayit.tam('/bildirim-ayar', (u, a) => const BildirimAyarScreen());
  EkranKayit.tam('/lan-ayar', (u, a) => const LanAyarScreen());
  EkranKayit.tam('/santral-ses', (u, a) => const SantralSesScreen());
  EkranKayit.tam('/dahili-yonetim', (u, a) => const DahiliYonetimScreen());
  EkranKayit.tam('/freepbx-ayar', (u, a) => const FreepbxAyarScreen());
  EkranKayit.tam('/mesai-qr', (u, a) => const MesaiQrScreen());
  // Departman iş ekranları (web /temizlik, /guvenlik, /teknik, /bulasik ile aynı uçlar)
  EkranKayit.tam('/temizlik', (u, a) => const DepartmanIsScreen(kod: 'temizlik', baslik: 'Temizlik / Hijyen', renk: Color(0xFF0EA5E9)));
  EkranKayit.tam('/guvenlik', (u, a) => const DepartmanIsScreen(kod: 'guvenlik', baslik: 'Güvenlik', renk: Color(0xFF475569)));
  EkranKayit.tam('/teknik', (u, a) => const DepartmanIsScreen(kod: 'teknik', baslik: 'Teknik Servis / Bakım-Onarım', renk: Color(0xFFF97316)));
  EkranKayit.tam('/bulasik', (u, a) => const DepartmanIsScreen(kod: 'bulasik', baslik: 'Bulaşıkhane / Steward', renk: Color(0xFF06B6D4)));

  // ── Raporlar (satın alma / mutfak / departman raporları): tek rapor merkezi ──
  for (final o in kRaporOnekleri) {
    EkranKayit.onek(o, (u, a) => RaporMerkeziScreen(url: u, baslik: a));
  }

  // ── Modüller (her biri kendi ekranlarını kaydeder; aynı adres sonra kaydedilirse onu geçerli kılar) ──
  kayitSatinalma();
  kayitStok();
  kayitFinans();
  kayitIk();
  kayitCrm();
  kayitOperasyon();
  kayitAi();
}

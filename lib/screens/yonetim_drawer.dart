import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import 'kasa_screen.dart';
import 'finans_screen.dart';
import 'isletme_hub_screen.dart';
import 'uretim_riski_screen.dart';
import 'sayim_screen.dart';
import 'menu_yonetimi_screen.dart';
import 'tema_secim_screen.dart';
import 'indirimler_screen.dart';
import 'odeme_modu_screen.dart';
import 'garson_cagrilari_screen.dart';
import 'cari_hesaplar_screen.dart';
import 'rezervasyon_screen.dart';
import 'personel_screen.dart';
import 'masa_atama_screen.dart';
import 'masa_yonetim_screen.dart';
import 'lan_ayar_screen.dart';
import 'garson_performans_screen.dart';
import 'salon_sema_screen.dart';
import 'gider_screen.dart';
import 'raporlar_screen.dart';
import 'bagli_cihazlar_screen.dart';
import 'hareketler_screen.dart';
import 'yazici_ayarlari_screen.dart';
import 'sebep_yonetimi_screen.dart';
import 'asistan_screen.dart';
import 'odul_dogrula_screen.dart';
import 'departman_panel_screen.dart';
import 'servis_akis_screen.dart';
import 'karsilama_screen.dart';
import 'bildirim_ayar_screen.dart';
import 'patron_ai_brief_screen.dart';

/// Yönetim menüsü (drawer) — HER SAYFADAN erişilebilsin diye paylaşımlı bileşen.
/// Navigasyon kararını çağırana bırakır: [onGit] ekran açar, [onWeb] tarayıcı linki açar.
/// (Telefonda home Scaffold'a takılır; alt bar + mikrofon kalıcı kalsın diye _govdeNav'a push eder.)
class YonetimDrawer extends StatelessWidget {
  final void Function(Widget ekran) onGit;
  final void Function(String path) onWeb;
  const YonetimDrawer({super.key, required this.onGit, required this.onWeb});

  String _rolAd(String? r) => r == 'sahip' ? 'Sahip' : (r == 'mudur' ? 'Müdür' : (r == 'kasa' ? 'Kasa' : (r ?? 'Personel')));

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final auth = context.watch<AuthProvider>();
    final patron = auth.rol == 'sahip' || auth.rol == 'mudur';

    void kapat() => Navigator.of(context).pop();
    Widget oge(IconData ikon, String baslik, VoidCallback onTap, {Color? renk}) {
      final r = renk ?? t.ink;
      return ListTile(
        leading: Icon(ikon, color: r, size: 22),
        title: Text(baslik, style: TextStyle(color: r, fontSize: 15, fontWeight: FontWeight.w600)),
        onTap: onTap, dense: true, visualDensity: const VisualDensity(vertical: -1),
      );
    }

    Widget git(IconData i, String b, Widget e, {Color? renk}) => oge(i, b, () { kapat(); onGit(e); }, renk: renk);
    Widget web(IconData i, String b, String p, {Color? renk}) => oge(i, b, () { kapat(); onWeb(p); }, renk: renk);

    return Drawer(
      backgroundColor: t.card,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
            decoration: BoxDecoration(gradient: LinearGradient(colors: [t.mor1, t.mavi])),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('ResteOS', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(auth.sube ?? '', style: const TextStyle(color: Colors.white, fontSize: 14)),
              Text('${auth.ad ?? ''} · ${_rolAd(auth.rol)}', style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 12)),
            ]),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(padding: EdgeInsets.zero, children: [
              // Ödül Doğrula — hem kasa hem garson (müşteri ödül QR kodunu okut/onayla)
              git(Icons.qr_code_scanner, 'Ödül Doğrula', const OdulDogrulaScreen(), renk: const Color(0xFF22C55E)),
              // Departman paneli — alt personel kendi alanının özetini görür (patronda zaten dashboard var).
              if (!patron) git(Icons.dashboard_customize, 'Panelim', const DepartmanPanelScreen(), renk: const Color(0xFF4F46E5)),
              // Servis/Garson iş akışı (A: çağrı+servise hazır+açık masa; sorumlu → Ekip görünümü içeriden)
              if (!patron) git(Icons.room_service, 'Servis — İş Akışım', const ServisAkisScreen(), renk: const Color(0xFF0EA5E9)),
              // Karşılama / Host — bekleme listesi + rezervasyon + oturt (host departmanı)
              git(Icons.co_present, 'Karşılama / Host', const KarsilamaScreen(), renk: const Color(0xFF0EA5E9)),
              if (patron) git(Icons.wb_sunny_outlined, 'Patron AI — Sabah Brifingi', const PatronAiBriefScreen(), renk: const Color(0xFF7C3AED)),
              if (patron) git(Icons.point_of_sale, 'Kasa (Vardiya)', const KasaScreen()),
              if (patron) git(Icons.analytics_outlined, 'Finans / Kâr-Zarar', const FinansScreen()),
              if (patron) git(Icons.inventory_2_outlined, 'Stok & Satın Alma', const IsletmeHubScreen()),
              if (patron) git(Icons.warning_amber_outlined, 'Üretim Riski', const UretimRiskiScreen(), renk: const Color(0xFFF59E0B)),
              if (patron) git(Icons.fact_check_outlined, 'Sayım (Envanter)', const SayimScreen(), renk: const Color(0xFF0EA5E9)),
              if (patron) git(Icons.restaurant_menu, 'Menü Yönetimi', const MenuYonetimiScreen()),
              if (patron) git(Icons.palette_outlined, 'QR Menü Rengi', const TemaSecimScreen(), renk: const Color(0xFFF6CE63)),
              if (patron) git(Icons.local_offer_outlined, 'İndirimler', const IndirimlerScreen(), renk: const Color(0xFF22C55E)),
              if (patron) git(Icons.shield_outlined, 'Kaçak Önleme', const OdemeModuScreen(), renk: const Color(0xFFF43F5E)),
              git(Icons.notifications_active, 'Garson Çağrıları', const GarsonCagrilariScreen(), renk: const Color(0xFFF43F5E)),
              git(Icons.account_balance_wallet_outlined, 'Cari / Açık Hesaplar', const CariHesaplarScreen()),
              git(Icons.event_available_outlined, 'Rezervasyonlar', const RezervasyonScreen()),
              if (patron) web(Icons.map_outlined, 'Canlı Kurye Haritası', '/kurye-canli', renk: const Color(0xFF10B981)),
              if (patron) web(Icons.phone_in_talk_outlined, 'Gelen Çağrı Ekranı', '/cagri-ekran'),
              if (patron) git(Icons.qr_code_2, 'Masa & QR Yönetimi', const MasaYonetimScreen(), renk: const Color(0xFFF6CE63)),
              git(Icons.lan_outlined, 'LAN / Kasa Sunucu', const LanAyarScreen(), renk: const Color(0xFF6366F1)), // her rolde: cihaz kurulumu (terminal garson tabletinde de lazim)
              if (patron) git(Icons.badge_outlined, 'Personel & Maaş', const PersonelScreen()),
              if (patron) git(Icons.table_restaurant_outlined, 'Masa & Bölge Atama', const MasaAtamaScreen()),
              if (patron) git(Icons.emoji_events_outlined, 'Garson Performansı', const GarsonPerformansScreen(), renk: const Color(0xFF10B981)),
              if (patron) git(Icons.grid_on_outlined, 'Salon Şeması', const SalonSemaScreen(), renk: const Color(0xFF0EA5E9)),
              if (patron) git(Icons.receipt_long_outlined, 'Giderler', const GiderScreen()),
              if (patron) git(Icons.bar_chart_outlined, 'Raporlar', const RaporlarScreen()),
              if (patron) git(Icons.devices_other_outlined, 'Bağlı Cihazlar', const BagliCihazlarScreen(), renk: const Color(0xFF0EA5E9)),
              if (patron) git(Icons.history, 'Hareketler (Log)', const HareketlerScreen(), renk: const Color(0xFF7C3AED)),
              if (patron) git(Icons.print_outlined, 'Yazıcı Ayarları', const YaziciAyarlariScreen(), renk: const Color(0xFF14B8A6)),
              if (patron) git(Icons.rule_folder_outlined, 'İptal / İkram Sebepleri', const SebepYonetimiScreen()),
              git(Icons.auto_awesome, 'Patron Asistan', const AsistanScreen(), renk: const Color(0xFFC4B5FD)),
              git(Icons.notifications_active, 'Bildirim Ayarları', const BildirimAyarScreen(), renk: const Color(0xFF0EA5E9)),
            ]),
          ),
          Divider(height: 1, color: t.line),
          oge(Icons.logout, 'Çıkış', () { kapat(); context.read<AuthProvider>().cikis(); }, renk: const Color(0xFFF87171)),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'menu_hamburger.dart';
import 'stok_screen.dart';
import 'recete_screen.dart';
import 'alis_fatura_screen.dart';
import 'tedarikci_screen.dart';
import 'gider_screen.dart';
import 'fiyat_radari_screen.dart';
import 'satinalma_analiz_screen.dart';
import 'parti_takip_screen.dart';
import 'hal_fiyatlari_screen.dart';
import 'satinalma_asistan_screen.dart';
import 'satinalma_siparis_screen.dart';
import 'siparis_onerisi_screen.dart';
import 'fatura_eslestir_screen.dart';
import 'mal_kabul_screen.dart';
import 'satinalma_talep_screen.dart';
import '../responsive.dart';
import '../ui/masaustu_kit.dart';
import '../providers/tema_provider.dart';

/// İşletme / Stok & Finans hub — stok, reçete, alış faturası, tedarikçi,
/// gider ve finansal özet ekranlarına tek yerden erişim.
class IsletmeHubScreen extends StatelessWidget {
  const IsletmeHubScreen({super.key});

  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);

  @override
  Widget build(BuildContext context) {
    if (genisMi(context)) return _masaustu(context);
    final ogeler = <_Hub>[
      _Hub('Satın Alma Talebi', 'Departman talep · teklif · onay', Icons.assignment_outlined, const Color(0xFF7C3AED), const SatinalmaTalepScreen()),
      _Hub('Stok / Malzeme', 'Mevcut stok · kritik · fire', Icons.inventory_2_outlined, const Color(0xFF4F46E5), const StokScreen()),
      _Hub('Reçeteler', 'Ürün maliyeti · food-cost', Icons.menu_book_outlined, const Color(0xFF7C3AED), const ReceteScreen()),
      _Hub('Alış Faturaları', 'Stok girişi · fiyat uyarısı', Icons.receipt_long_outlined, const Color(0xFFD97706), const AlisFaturaScreen()),
      _Hub('Sipariş Önerisi', 'Neyi · ne kadar al', Icons.auto_awesome, const Color(0xFF7C3AED), const SiparisOnerisiScreen()),
      _Hub('Satınalma Siparişi', 'Sipariş ver · PO', Icons.shopping_cart_checkout, const Color(0xFF4F46E5), const SatinalmaSiparisScreen()),
      _Hub('Mal Kabul', 'İrsaliye · gelen/kabul/red · lot', Icons.inventory_outlined, const Color(0xFF0EA5E9), const MalKabulScreen()),
      _Hub('Fatura Eşleştir', 'Sipariş↔irsaliye↔fatura', Icons.fact_check_outlined, const Color(0xFFF59E0B), const FaturaEslestirScreen()),
      _Hub('Tedarikçiler', 'Cari · toplam alış', Icons.local_shipping_outlined, const Color(0xFF0EA5E9), const TedarikciScreen()),
      _Hub('Giderler', 'Kira · fatura · maaş', Icons.account_balance_wallet_outlined, const Color(0xFFF43F5E), const GiderScreen()),
      _Hub('Fiyat Radarı', 'Gizli zam · ucuz tedarikçi', Icons.radar, const Color(0xFFEC4899), const FiyatRadariScreen()),
      _Hub('Satınalma Analizi', 'Tedarikçi karne · harcama', Icons.leaderboard_outlined, const Color(0xFF4F46E5), const SatinalmaAnalizScreen()),
      _Hub('Parti / SKT Takip', 'FEFO · son kullanma', Icons.event_busy_outlined, const Color(0xFFF43F5E), const PartiTakipScreen()),
      _Hub('Hal Fiyatları', 'Sen vs hal · toptan', Icons.storefront_outlined, const Color(0xFF059669), const HalFiyatlariScreen()),
      _Hub('Satınalma Asistanı', 'AI sohbet · öneri', Icons.smart_toy_outlined, const Color(0xFF7C3AED), const SatinalmaAsistanScreen()),
    ];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, elevation: 0, iconTheme: const IconThemeData(color: Colors.white), title: const Text('Stok & Satın Alma', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)), actions: const [MenuHamburger()]),
      body: GridView.count(
        padding: const EdgeInsets.all(14),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.98,
        children: [for (final o in ogeler) _kart(context, o)],
      ),
    );
  }

  Widget _kart(BuildContext context, _Hub o) => GestureDetector(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => o.ekran)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFF232B42))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: o.renk.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
              child: Icon(o.ikon, color: o.renk, size: 26),
            ),
            const SizedBox(height: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(o.baslik, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(o.alt, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
            ]),
          ]),
        ),
      );

  // ---- MASAÜSTÜ (PC/tablet) görünüm ----
  Widget _masaustu(BuildContext context) {
    final ogeler = <_Hub>[
      _Hub('Satın Alma Talebi', 'Departman talep · teklif · onay', Icons.assignment_outlined, const Color(0xFF7C3AED), const SatinalmaTalepScreen()),
      _Hub('Stok / Malzeme', 'Mevcut stok · kritik · fire', Icons.inventory_2_outlined, const Color(0xFF4F46E5), const StokScreen()),
      _Hub('Reçeteler', 'Ürün maliyeti · food-cost', Icons.menu_book_outlined, const Color(0xFF7C3AED), const ReceteScreen()),
      _Hub('Alış Faturaları', 'Stok girişi · fiyat uyarısı', Icons.receipt_long_outlined, const Color(0xFFD97706), const AlisFaturaScreen()),
      _Hub('Sipariş Önerisi', 'Neyi · ne kadar al', Icons.auto_awesome, const Color(0xFF7C3AED), const SiparisOnerisiScreen()),
      _Hub('Satınalma Siparişi', 'Sipariş ver · PO', Icons.shopping_cart_checkout, const Color(0xFF4F46E5), const SatinalmaSiparisScreen()),
      _Hub('Mal Kabul', 'İrsaliye · gelen/kabul/red · lot', Icons.inventory_outlined, const Color(0xFF0EA5E9), const MalKabulScreen()),
      _Hub('Fatura Eşleştir', 'Sipariş↔irsaliye↔fatura', Icons.fact_check_outlined, const Color(0xFFF59E0B), const FaturaEslestirScreen()),
      _Hub('Tedarikçiler', 'Cari · toplam alış', Icons.local_shipping_outlined, const Color(0xFF0EA5E9), const TedarikciScreen()),
      _Hub('Giderler', 'Kira · fatura · maaş', Icons.account_balance_wallet_outlined, const Color(0xFFF43F5E), const GiderScreen()),
      _Hub('Fiyat Radarı', 'Gizli zam · ucuz tedarikçi', Icons.radar, const Color(0xFFEC4899), const FiyatRadariScreen()),
      _Hub('Satınalma Analizi', 'Tedarikçi karne · harcama', Icons.leaderboard_outlined, const Color(0xFF4F46E5), const SatinalmaAnalizScreen()),
      _Hub('Parti / SKT Takip', 'FEFO · son kullanma', Icons.event_busy_outlined, const Color(0xFFF43F5E), const PartiTakipScreen()),
      _Hub('Hal Fiyatları', 'Sen vs hal · toptan', Icons.storefront_outlined, const Color(0xFF059669), const HalFiyatlariScreen()),
      _Hub('Satınalma Asistanı', 'AI sohbet · öneri', Icons.smart_toy_outlined, const Color(0xFF7C3AED), const SatinalmaAsistanScreen()),
    ];
    return MasaustuSayfa(
      baslik: 'Stok & Satın Alma',
      ikon: Icons.inventory_2_outlined,
      altBaslik: 'Stok, reçete, alış ve gider yönetimi',
      govde: GridView.count(
        padding: const EdgeInsets.all(24),
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.6,
        children: [for (final o in ogeler) _masaustuKart(context, o)],
      ),
    );
  }

  Widget _masaustuKart(BuildContext context, _Hub o) {
    final t = context.watch<TemaProvider>();
    return MKart(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => o.ekran)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: o.renk.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(16)),
          child: Icon(o.ikon, color: o.renk, size: 30),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(o.baslik, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(o.alt, style: TextStyle(color: t.sub, fontSize: 12)),
          ]),
        ),
        Icon(Icons.chevron_right, color: t.sub, size: 22),
      ]),
    );
  }
}

class _Hub {
  final String baslik;
  final String alt;
  final IconData ikon;
  final Color renk;
  final Widget ekran;
  _Hub(this.baslik, this.alt, this.ikon, this.renk, this.ekran);
}

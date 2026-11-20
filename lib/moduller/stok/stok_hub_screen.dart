import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /stok — "Stok & Satın Alma" merkezi: alt sayfalara dağıtan kartlar (web stok_hub ile aynı 5 kart).
class StokHubScreen extends StatelessWidget {
  const StokHubScreen({super.key});

  static const List<(String, String, String, IconData, Color)> _kartlar = [
    ('/stok/malzeme', 'Stok / Malzeme', 'Mevcut stok · kritik · fire', Icons.inventory_2_outlined, Color(0xFF4F46E5)),
    ('/recete', 'Reçeteler', 'Ürün maliyeti · food-cost', Icons.menu_book_outlined, Color(0xFF7C3AED)),
    ('/alis-fatura', 'Alış Faturaları', 'Stok girişi · fiyat uyarısı', Icons.receipt_long_outlined, Color(0xFFD97706)),
    ('/tedarikci', 'Tedarikçiler', 'Cari · toplam alış', Icons.local_shipping_outlined, Color(0xFF0EA5E9)),
    ('/gider', 'Giderler', 'Kira · fatura · maaş', Icons.account_balance_wallet_outlined, Color(0xFFF43F5E)),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final genis = genisMi(context);
    Widget kart((String, String, String, IconData, Color) k) => KKart(
          onTap: () => stAc(context, k.$1, k.$2),
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            KIkon(k.$4, renk: k.$5, boyut: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(k.$2, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(k.$3, style: TextStyle(color: t.sub, fontSize: 12.5)),
              ]),
            ),
            Icon(Icons.chevron_right, color: t.sub),
          ]),
        );
    return KSayfa(
      baslik: 'Stok & Satın Alma',
      ikon: Icons.inventory_2_outlined,
      altBaslik: 'Stok, reçete, alış ve gider yönetimi',
      govde: KGovde(children: [
        if (genis)
          LayoutBuilder(builder: (c, s) {
            final sutun = s.maxWidth > 1000 ? 3 : 2;
            final w = (s.maxWidth - (sutun - 1) * 14) / sutun;
            return Wrap(spacing: 14, children: [for (final k in _kartlar) SizedBox(width: w, child: kart(k))]);
          })
        else
          for (final k in _kartlar) kart(k),
      ]),
    );
  }
}

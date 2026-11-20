import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// /finans — Finans / Kâr-Zarar özeti (web: ?period=gunluk|haftalik|aylik)
class FinansOzetScreen extends StatefulWidget {
  const FinansOzetScreen({super.key});
  @override
  State<FinansOzetScreen> createState() => _FinansOzetScreenState();
}

const _tipAd = {'nakit': 'Nakit', 'kredi': 'Kredi Kartı', 'yemek_karti': 'Yemek Kartı', 'acik_hesap': 'Açık Hesap'};
const _katAd = {'kira': 'Kira', 'fatura': 'Fatura', 'malzeme': 'Malzeme / Alış', 'maas': 'Maaş / Personel', 'vergi': 'Vergi', 'diger': 'Diğer'};

class _FinansOzetScreenState extends State<FinansOzetScreen> {
  final _k = GlobalKey<KopruEkranState>();

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/finans',
      baslik: 'Finans',
      ikon: Icons.account_balance_wallet_outlined,
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final period = metinOku(v['period'], 'aylik');
    final gelir = sayiOku(v['gelir']);
    final gider = sayiOku(v['gider']);
    final bahsis = sayiOku(v['bahsis']);
    final net = sayiOku(v['net']);
    final alis = sayiOku(v['alis_toplam']);
    final gelirTip = liste(v['gelir_tip']);
    final giderKat = liste(v['gider_kategori']);
    final kar = net >= 0;

    Widget gelirBlok() => KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KBaslik('Gelir — Ödeme Tipi', ikon: Icons.payments_outlined, renk: t.yesil, sag: KRozet('${gelirTip.length}', renk: t.yesil)),
            if (gelirTip.isEmpty)
              const KBos(baslik: 'Bu dönem tahsilat yok', aciklama: 'Adisyon ödemesi alındıkça (Masalar / Paket ekranından) burada ödeme tipine göre görünür.', ikon: Icons.payments_outlined)
            else
              for (final g in gelirTip) FSatir(_tipAd[metinOku(g['tip'])] ?? metinOku(g['tip'], '—'), tl(g['tutar']), renk: t.yesil),
          ]),
        );
    Widget giderBlok() => KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KBaslik('Gider — Kategori', ikon: Icons.receipt_long_outlined, renk: t.kirmizi, sag: KRozet('${giderKat.length}', renk: t.kirmizi)),
            if (giderKat.isEmpty)
              KBos(
                baslik: 'Bu dönem gider yok',
                aciklama: 'Kira, fatura, maaş gibi giderler Giderler ekranından girilir.',
                ikon: Icons.receipt_long_outlined,
                aksiyon: KButon('Giderler', ikon: Icons.add, ikincil: true, onTap: () => sayfaAc(context, '/gider', 'Giderler')),
              )
            else
              for (final g in giderKat) FSatir(_katAd[metinOku(g['kategori'])] ?? metinOku(g['kategori'], '—'), tl(g['tutar']), renk: t.kirmizi),
            if (alis > 0) ...[
              const SizedBox(height: 14),
              KBaslik('Tedarikçi Alışı', ikon: Icons.local_shipping_outlined, renk: t.amber),
              FSatir('Toplam alış faturası', tl(alis), renk: t.amber),
            ],
          ]),
        );

    return KGovde(yenile: yenile, children: [
      KCipler(
        secenekler: const [('gunluk', 'Bugün'), ('haftalik', 'Bu Hafta'), ('aylik', 'Bu Ay')],
        secili: period,
        onSec: (p) => _k.currentState?.sorgu({'period': p}),
      ),
      FHero(
        etiket: '${kar ? 'Net Kâr' : 'Net Zarar'} (${metinOku(v['aralik_metin'])})',
        deger: tl(net),
        renk: kar ? t.mor1 : t.kirmizi,
        ikon: kar ? Icons.trending_up : Icons.trending_down,
        ekler: [
          FHeroMini('Gelir', tl(gelir, kisa: true), Icons.arrow_downward),
          FHeroMini('Gider', tl(gider, kisa: true), Icons.arrow_upward),
          if (bahsis > 0) FHeroMini('Bahşiş', tl(bahsis, kisa: true), Icons.volunteer_activism_outlined),
        ],
      ),
      KKpiIzgara([
        KKpi(etiket: 'Gelir', deger: tl(gelir), ikon: Icons.payments_outlined, renk: t.yesil, alt: bahsis > 0 ? 'Bahşiş ${tl(bahsis)}' : '${gelirTip.length} ödeme tipi'),
        KKpi(etiket: 'Gider', deger: tl(gider), ikon: Icons.receipt_long_outlined, renk: t.kirmizi, alt: alis > 0 ? 'Tedarikçi alışı ${tl(alis)}' : '${giderKat.length} kategori'),
        KKpi(etiket: kar ? 'Net Kâr' : 'Net Zarar', deger: tl(net), ikon: kar ? Icons.trending_up : Icons.trending_down, renk: kar ? t.mor1 : t.kirmizi),
      ]),
      FIzgara([gelirBlok(), giderBlok()], minGenislik: 420),
      FNot('Gelir = alınan ödemeler (ödeme tarihine göre); gider = Giderler ekranına girilen kayıtlar. Tedarikçi alış faturaları net kâra katılmaz, ayrıca gösterilir.', baglantilar: [
        FGecis('Kâr-Zarar (P&L)', () => sayfaAc(context, '/kar-zarar', 'Kâr-Zarar')),
        FGecis('Giderler', () => sayfaAc(context, '/gider', 'Giderler')),
      ]),
    ]);
  }
}

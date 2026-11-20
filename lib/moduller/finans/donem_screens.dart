import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Aylık dönem ekranları (web: ?ay=YYYY-MM) — /kar-zarar, /kdv-ozet, /beyanname, /online-komisyon ortak kabuğu.
class AyliKopruEkran extends StatefulWidget {
  final String yol;
  final String baslik;
  final IconData ikon;
  /// sayfa verisinden aktif ayı oku (çoğunda d.ay, bazılarında ay)
  final String Function(Map<String, dynamic> v) ayOku;
  final List<Widget> Function(BuildContext context, Map<String, dynamic> v) icerik;
  const AyliKopruEkran({super.key, required this.yol, required this.baslik, required this.ikon, required this.ayOku, required this.icerik});
  @override
  State<AyliKopruEkran> createState() => _AyliKopruEkranState();
}

class _AyliKopruEkranState extends State<AyliKopruEkran> {
  final _k = GlobalKey<KopruEkranState>();
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: widget.yol,
      baslik: widget.baslik,
      ikon: widget.ikon,
      govde: (ctx, v, yenile) {
        final ay = metinOku(widget.ayOku(v), buAy());
        return KGovde(yenile: yenile, maxGenislik: 900, children: [
          AySecici(ay: ay, onSec: (a) => _k.currentState?.sorgu({'ay': a})),
          ...widget.icerik(ctx, v),
        ]);
      },
    );
  }
}

// ───────────────────────── /kar-zarar ─────────────────────────
class KarZararScreen extends StatelessWidget {
  const KarZararScreen({super.key});
  @override
  Widget build(BuildContext context) => AyliKopruEkran(
        yol: '/kar-zarar',
        baslik: 'Kâr-Zarar (P&L)',
        ikon: Icons.account_balance_outlined,
        ayOku: (v) => metinOku(harita(v['d'])['ay']),
        icerik: (ctx, v) {
          final t = ctx.watch<TemaProvider>();
          final d = harita(v['d']);
          final net = sayiOku(d['netKar']);
          final art = net >= 0;
          final marj = d['marj'];
          return [
            KKpiIzgara([
              KKpi(etiket: art ? 'NET KÂR' : 'NET ZARAR', deger: tl(net.abs(), kisa: true), alt: 'net satış ${tl(d['ciroNet'], kisa: true)} üzerinden', ikon: art ? Icons.trending_up : Icons.trending_down, renk: art ? t.yesil : t.kirmizi),
              KKpi(etiket: 'Net kâr marjı', deger: marj == null ? '—' : yuzde(marj), alt: 'brüt kâr ${tl(d['brutKar'], kisa: true)}', ikon: Icons.percent, renk: art ? t.yesil : t.kirmizi),
            ]),
            KKart(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(children: [
                FSatir('Net satış (KDV hariç)', tl(d['ciroNet']), ikon: Icons.payments_outlined),
                FSatir('Satılan malın maliyeti (SMM)', '− ${tl(d['smm'])}', ikon: Icons.inventory_2_outlined, renk: t.kirmizi),
                FSatir('= Brüt kâr', tl(d['brutKar']), vurgu: true),
                FSatir('İşletme giderleri', '− ${tl(d['gider'])}', girinti: true, renk: t.kirmizi),
                FSatir('Personel (bordro hakediş)', '− ${tl(d['bordro'])}', girinti: true, renk: t.kirmizi),
                FSatir('Toplam gider', '− ${tl(d['toplamGider'])}', ikon: Icons.request_quote_outlined, renk: t.kirmizi),
                FSatir('= ${art ? 'Net kâr' : 'Net zarar'}', tl(net), vurgu: true, renk: art ? t.yesil : t.kirmizi),
              ]),
            ),
            if (sayiOku(d['ciroNet']) == 0)
              const KBos(
                baslik: 'Bu ay satış yok',
                aciklama: 'Kapanmış (ödenmiş) adisyon olmadığı için net satış ve SMM sıfır. Satışlar Masalar / Paket ekranından ödeme alındıkça buraya yansır.',
                ikon: Icons.point_of_sale,
              ),
            FNot('SMM reçete maliyetinden (maliyet girilmemiş üründe satışın %30\'u varsayılır), bordro İK hakedişinden gelir. Maaşları ayrıca "Giderler"e de girdiysen çift sayım olabilir — kontrol et. KDV ve vergi hariç yönetim raporudur, resmi gelir tablosu değildir.', baglantilar: [
              FGecis('Giderler', () => sayfaAc(ctx, '/gider', 'Giderler')),
              FGecis('KDV Özeti', () => sayfaAc(ctx, '/kdv-ozet', 'KDV Özeti')),
            ]),
          ];
        },
      );
}

// ───────────────────────── /kdv-ozet ─────────────────────────
class KdvOzetScreen extends StatelessWidget {
  const KdvOzetScreen({super.key});
  @override
  Widget build(BuildContext context) => AyliKopruEkran(
        yol: '/kdv-ozet',
        baslik: 'KDV Özeti',
        ikon: Icons.receipt_long_outlined,
        ayOku: (v) => metinOku(harita(v['d'])['ay']),
        icerik: (ctx, v) {
          final t = ctx.watch<TemaProvider>();
          final d = harita(v['d']);
          final od = sayiOku(d['odenecekKDV']);
          final odRenk = od > 0 ? t.kirmizi : t.yesil;
          return [
            Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [KRozet('KDV oranı %${metinOku(d['oran'], '10')}', renk: t.mor1, ikon: Icons.percent)])),
            KKpiIzgara([
              KKpi(etiket: 'Hesaplanan KDV (satış)', deger: tl(d['hesKDV']), alt: 'matrah ${tl(d['ciroNet'])}', ikon: Icons.trending_up, renk: t.mavi),
              KKpi(etiket: 'İndirilecek KDV (alış)', deger: tl(d['indKDV']), alt: 'alış ${tl(d['alisBrut'])}', ikon: Icons.trending_down, renk: t.amber),
              KKpi(etiket: od >= 0 ? 'Ödenecek KDV' : 'Devreden KDV', deger: tl(od.abs()), alt: 'hesaplanan − indirilecek', ikon: Icons.account_balance_outlined, renk: odRenk),
            ]),
            KKart(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(children: [
                FSatir('Brüt ciro (KDV dahil)', tl(d['ciroBrut'])),
                FSatir('Matrah (KDV hariç)', tl(d['ciroNet'])),
                FSatir('Hesaplanan KDV', tl(d['hesKDV'])),
                FSatir('İndirilecek KDV', '− ${tl(d['indKDV'])}'),
                FSatir(od >= 0 ? 'Ödenecek KDV' : 'Sonraki döneme devreden', tl(od.abs()), vurgu: true, renk: odRenk),
              ]),
            ),
            FNot('Bu özet tahminidir (tek oran %${metinOku(d['oran'], '10')} üzerinden). Gerçek beyanname oran kırılımı (%1/%10/%20), tevkifat (KDV2) ve istisnalarla değişir — mali müşavirinle kesinleştir. Oranı Muhasebe Entegrasyonu ekranından değiştirebilirsin.', baglantilar: [
              FGecis('Muhasebe Entegrasyonu', () => sayfaAc(ctx, '/muhasebe-entegrasyon', 'Muhasebe Entegrasyonu')),
              FGecis('Beyanname Hazırlık', () => sayfaAc(ctx, '/beyanname', 'Beyanname Hazırlık')),
            ]),
          ];
        },
      );
}

// ───────────────────────── /beyanname ─────────────────────────
class BeyannameScreen extends StatelessWidget {
  const BeyannameScreen({super.key});
  @override
  Widget build(BuildContext context) => AyliKopruEkran(
        yol: '/beyanname',
        baslik: 'Beyanname Hazırlık',
        ikon: Icons.description_outlined,
        ayOku: (v) => metinOku(harita(v['d'])['ay']),
        icerik: (ctx, v) {
          final t = ctx.watch<TemaProvider>();
          final d = harita(v['d']);
          final vt = liste(v['vt']);
          final od = sayiOku(d['odenecekKDV']);
          final odRenk = od > 0 ? t.kirmizi : t.yesil;
          return [
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KBaslik('KDV Beyannamesi (KDV1)', ikon: Icons.receipt_long_outlined, sag: KRozet('${od > 0 ? 'Ödenecek' : 'Devreden'} ${tl(od.abs())}', renk: odRenk)),
                FSatir('Teslim matrahı (KDV hariç satış)', tl(d['ciroNet'])),
                FSatir('Hesaplanan KDV', tl(d['hesKDV'])),
                FSatir('İndirilecek KDV (alış)', '− ${tl(d['indKDV'])}'),
                FSatir(od >= 0 ? 'Ödenecek KDV' : 'Devreden KDV', tl(od.abs()), vurgu: true, renk: odRenk),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  FGecis('KDV Özeti', () => sayfaAc(ctx, '/kdv-ozet', 'KDV Özeti')),
                  FGecis('Mahsup fişini aktar', () => sayfaAc(ctx, '/muhasebe-entegrasyon', 'Muhasebe Entegrasyonu')),
                ]),
              ]),
            ),
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KBaslik('Muhtasar ve Prim Hizmet (hazırlık)', ikon: Icons.groups_outlined),
                FSatir('Dönem bordro hakedişi (brüt)', tl(d['bordro'])),
                FSatir('Gelir vergisi stopajı + SGK', 'bordrodan hesaplanır', renk: t.sub2),
                const SizedBox(height: 10),
                Wrap(children: [FGecis('İK / Bordro', () => sayfaAc(ctx, '/ik-ozet', 'İK Özeti'))]),
              ]),
            ),
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KBaslik('Yaklaşan son tarihler', ikon: Icons.event_available_outlined),
                if (vt.isEmpty) const KBos(baslik: 'Takvim boş', ikon: Icons.event_available_outlined),
                for (final x in vt.take(4))
                  FSatir(metinOku(x['ad']), '${tarihYaz(x['tarih'], saat: false)} · ${tamOku(x['kalan']).clamp(0, 9999)} gün', renk: _kalanRenk(t, tamOku(x['kalan']))),
                const SizedBox(height: 10),
                Wrap(children: [FGecis('Tüm vergi takvimi', () => sayfaAc(ctx, '/vergi-takvimi', 'Vergi Takvimi'))]),
              ]),
            ),
            const FNot('Bu ekran hazırlık özetidir; resmî beyanname değildir. Rakamlar tahminidir (tek KDV oranı, bordrodan türetilen stopaj). Kesin beyan ve gönderim mali müşavirin veya Defter-Beyan/entegratör üzerinden yapılır.'),
          ];
        },
      );
}

Color _kalanRenk(TemaProvider t, int kalan) => kalan < 0 ? t.sub : (kalan <= 3 ? t.kirmizi : (kalan <= 7 ? t.amber : t.ink));

// ───────────────────────── /online-komisyon ─────────────────────────
class OnlineKomisyonScreen extends StatelessWidget {
  const OnlineKomisyonScreen({super.key});
  @override
  Widget build(BuildContext context) => AyliKopruEkran(
        yol: '/online-komisyon',
        baslik: 'Online Komisyon',
        ikon: Icons.delivery_dining_outlined,
        ayOku: (v) => metinOku(v['ay']),
        icerik: (ctx, v) {
          final t = ctx.watch<TemaProvider>();
          final l = liste(v['liste']);
          final gen = genisMi(ctx);
          return [
            KKpiIzgara([
              KKpi(etiket: 'Online ciro (brüt)', deger: tl(v['topCiro']), ikon: Icons.shopping_bag_outlined, renk: t.mavi),
              KKpi(etiket: 'Tahmini komisyon', deger: '− ${tl(v['topKom'])}', ikon: Icons.percent, renk: t.kirmizi),
              KKpi(etiket: 'Net (komisyon sonrası)', deger: tl(v['topNet']), ikon: Icons.account_balance_wallet_outlined, renk: t.yesil),
            ]),
            if (l.isEmpty)
              const KKart(
                child: KBos(
                  baslik: 'Bu ay online kanal siparişi görünmüyor',
                  aciklama: 'Yemeksepeti / Getir / Trendyol gibi kanallardan gelen siparişler, adisyonun "platform" alanından okunur. Entegrasyon bağlı değilse ya da bu ay kanal siparişi yoksa liste boş kalır.',
                  ikon: Icons.delivery_dining_outlined,
                ),
              )
            else if (gen)
              KKart(
                child: KTablo(
                  basliklar: const ['Kanal', 'Sipariş', 'Oran', 'Ciro', 'Komisyon', 'Net'],
                  sagaYasla: const {1, 2, 3, 4, 5},
                  satirlar: [
                    for (final r in l) [metinOku(r['platform']), sayiYaz(r['adet']), '%${sayiYaz(r['oran'])}', tl(r['ciro']), '− ${tl(r['komisyon'])}', tl(r['net'])],
                  ],
                ),
              )
            else
              for (final r in l)
                KKart(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    KSatir(
                      baslik: metinOku(r['platform']),
                      alt: '${sayiYaz(r['adet'])} sipariş · %${sayiYaz(r['oran'])} komisyon',
                      solIkon: KIkon(Icons.delivery_dining_outlined, renk: t.mavi),
                      cizgi: false,
                    ),
                    FSatir('Ciro', tl(r['ciro'])),
                    FSatir('Komisyon', '− ${tl(r['komisyon'])}', renk: t.kirmizi),
                    FSatir('Net', tl(r['net']), renk: t.yesil, vurgu: true),
                  ]),
                ),
            const FNot('Komisyon oranları varsayılandır (Yemeksepeti / Getir / Trendyol / Migros %18, diğer %15). Kanal, adisyonun platform alanından okunur.'),
          ];
        },
      );
}

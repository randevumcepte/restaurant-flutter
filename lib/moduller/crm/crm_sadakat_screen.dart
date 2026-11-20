import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'crm_ortak.dart';

/// Web /sadakat — sadakat kampanyaları (aç/kapat: /sadakat/toggle) + en sadık 10 müşteri + özet sayılar.
class CrmSadakatScreen extends StatefulWidget {
  const CrmSadakatScreen({super.key});

  @override
  State<CrmSadakatScreen> createState() => _CrmSadakatScreenState();
}

class _CrmSadakatScreenState extends State<CrmSadakatScreen> {
  final Set<int> _bekleyen = {};

  static const _tipAd = {
    'yuzde': 'Yüzde indirim', 'tutar': 'Tutar indirim', 'ikinci_bedava': '2. ürün bedava', 'urun_hediye': 'Ürün hediye', 'puan_carpani': 'Puan çarpanı',
  };

  String _deger(Map<String, dynamic> k) {
    final tip = metinOku(k['tip']);
    if (tip == 'yuzde') return yuzde(k['deger']);
    if (tip == 'tutar') return tl(k['deger'], kisa: true);
    if (tip == 'puan_carpani') return '${sayiYaz(k['deger'])}x puan';
    return '—';
  }

  Future<void> _toggle(Map<String, dynamic> k, Future<void> Function() yenile) async {
    final id = tamOku(k['id']);
    setState(() => _bekleyen.add(id));
    final c = await kopruGonderCevap(context, '/sadakat/toggle', {'id': id});
    if (!mounted) return;
    setState(() => _bekleyen.remove(id));
    if (c != null && c.ok) {
      kToast(context, tamOku(c.j['aktif']) == 1 ? 'Kampanya açıldı.' : 'Kampanya kapatıldı.');
      yenile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/sadakat',
      baslik: 'Sadakat & Kampanyalar',
      ikon: Icons.loyalty_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final kamp = liste(v['kampanyalar']);
        final top = liste(v['topMusteri']);
        final kampKart = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KBaslik('Kampanyalar', ikon: Icons.local_offer_outlined, alt: 'Açık kampanyalar POS ve müşteri uygulamasında uygulanır'),
          if (kamp.isEmpty)
            const KBos(
              baslik: 'Tanımlı sadakat kampanyası yok',
              aciklama: 'Bu şubede kampanyalar tablosunda kayıt bulunmuyor. Kampanyalar kurulumda ya da sistem yönetimi tarafından tanımlanır; indirim tanımlamak için Menü & Ürünler > İndirimler ekranını kullanın.',
              ikon: Icons.local_offer_outlined,
            )
          else
            for (final k in kamp)
              KKart(
                renk: tamOku(k['aktif']) == 1 ? t.yesil : t.sub,
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(metinOku(k['ad'], 'Kampanya'), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text(
                        [
                          _tipAd[metinOku(k['tip'])] ?? metinOku(k['tip']),
                          _deger(k),
                          if (sayiOku(k['min_tutar']) > 0) 'min ${tl(k['min_tutar'], kisa: true)}',
                          '${sayiYaz(k['kullanim'])} kez kullanıldı',
                        ].join(' · '),
                        style: TextStyle(color: t.sub, fontSize: 12.5),
                      ),
                    ]),
                  ),
                  _bekleyen.contains(tamOku(k['id']))
                      ? const SizedBox(width: 44, height: 44, child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)))
                      : Switch(value: tamOku(k['aktif']) == 1, activeThumbColor: t.yesil, onChanged: (_) => _toggle(k, yenile)),
                ]),
              ),
        ]);
        final topKart = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const KBaslik('En sadık müşteriler', ikon: Icons.emoji_events_outlined, alt: 'Puana göre ilk 10'),
          if (top.isEmpty)
            const KBos(
              baslik: 'Puan biriktiren müşteri yok',
              aciklama: 'Müşteriler hesap kapanışında adisyona bağlandıkça puan kazanır. POS\'ta adisyona müşteri bağlayın ya da müşteri uygulamasını tanıtın.',
              ikon: Icons.emoji_events_outlined,
            )
          else
            KKart(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < top.length; i++)
                  KSatir(
                    cizgi: i > 0,
                    solIkon: CrmAvatar(metinOku(top[i]['ad'], 'M'), renk: i < 3 ? t.gold : t.mor1, boyut: 38),
                    baslik: '${i + 1}. ${metinOku(top[i]['ad'], 'Müşteri')}',
                    alt: '${sayiYaz(top[i]['siparis_sayisi'])} sipariş · ${tl(top[i]['toplam_harcama'], kisa: true)}',
                    sag: KRozet('${sayiYaz(top[i]['puan'])} puan', renk: t.amber),
                  ),
              ]),
            ),
        ]);
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Aktif kampanya', deger: sayiYaz(v['aktifKampanya']), ikon: Icons.local_offer_outlined, renk: t.mor1),
            KKpi(etiket: 'Toplam sadakat puanı', deger: sayiYaz(v['toplamPuan']), ikon: Icons.stars_outlined, renk: t.amber),
            KKpi(etiket: 'Kayıtlı müşteri', deger: sayiYaz(v['musteriSayisi']), ikon: Icons.groups_outlined, renk: t.mavi),
          ]),
          const SizedBox(height: 14),
          if (genisMi(ctx))
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: kampKart),
              const SizedBox(width: 16),
              Expanded(child: topKart),
            ])
          else ...[
            kampKart,
            const SizedBox(height: 8),
            topKart,
          ],
          const SizedBox(height: 6),
          Wrap(spacing: 10, runSpacing: 10, children: [
            KButon('Ödül Raporu', ikon: Icons.redeem_outlined, ikincil: true, onTap: () => crmSayfaAc(ctx, '/odul-raporu', 'Ödül Raporu')),
            KButon('Çarkıfelek', ikon: Icons.casino_outlined, ikincil: true, onTap: () => crmSayfaAc(ctx, '/cark-yonetim', 'Çarkıfelek')),
          ]),
        ]);
      },
    );
  }
}

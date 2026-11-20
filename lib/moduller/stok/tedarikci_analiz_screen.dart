import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

String _yildiz(double p) => '★' * p.round().clamp(0, 5);

/// Web /satinalma-analiz — tedarikçi karnesi (alış, fatura, zamanında teslim, red oranı, puan) + son 6 ay harcama.
class SatinalmaAnalizScreen extends StatelessWidget {
  const SatinalmaAnalizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/satinalma-analiz',
      baslik: 'Satın Alma Analizi',
      ikon: Icons.query_stats,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final karne = liste(v['karne']);
        final aylik = liste(v['aylik']);
        final enCok = aylik.fold<double>(0, (m, a) => sayiOku(a['t']) > m ? sayiOku(a['t']) : m);
        const aylar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Toplam alış', deger: tl(v['toplamAlis'], kisa: true), ikon: Icons.payments_outlined, renk: t.mavi),
            KKpi(etiket: 'Tedarikçi', deger: '${karne.length}', ikon: Icons.local_shipping_outlined, renk: t.mor1),
          ]),
          const SizedBox(height: 6),
          KBaslik('Aylık harcama (son 6 ay)', ikon: Icons.bar_chart),
          if (aylik.isEmpty)
            const KBos(baslik: 'Harcama verisi yok', ikon: Icons.bar_chart, aciklama: 'Son 6 ayda alış faturası girilmemiş. Alış Faturaları ekranından fatura girildikçe grafik dolar.')
          else
            KKart(
              child: SizedBox(
                height: 170,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final a in aylik)
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        Text(tl(a['t'], kisa: true), style: TextStyle(color: t.sub2, fontSize: 10.5, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        Container(
                          width: 34,
                          height: enCok > 0 ? 110 * sayiOku(a['t']) / enCok + 4 : 4,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [t.mavi, t.mor1], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(() {
                          final ay = int.tryParse(metinOku(a['ay']).split('-').last) ?? 0;
                          return ay >= 1 && ay <= 12 ? aylar[ay - 1] : metinOku(a['ay']);
                        }(), style: TextStyle(color: t.sub, fontSize: 11)),
                      ]),
                    ),
                ]),
              ),
            ),
          KBaslik('Tedarikçi karnesi', ikon: Icons.grading, alt: 'Puan: zamanında teslim yükseltir, red/eksik oranı düşürür (1–5).'),
          if (karne.isEmpty)
            const KBos(baslik: 'Karne için veri yok', ikon: Icons.grading, aciklama: 'Tedarikçiye bağlı alış faturası yok. Faturada tedarikçi seçildikçe karne oluşur; teslim puanı için sipariş + mal kabul gerekir.')
          else if (genisMi(context))
            KKart(
              padding: EdgeInsets.zero,
              child: KTablo(
                basliklar: const ['Tedarikçi', 'Toplam alış', 'Fatura', 'Zamanında', 'Red', 'Puan'],
                sagaYasla: const {1, 2},
                satirlar: [
                  for (final k in karne)
                    [
                      '${k['ad']}',
                      tl(k['toplam'], kisa: true),
                      '${k['fatura']}',
                      k['zamaninda'] == null ? '—' : '%${k['zamaninda']}',
                      sayiOku(k['red_oran']) > 0 ? yuzde(k['red_oran']) : '—',
                      '${sayiOku(k['puan']).toStringAsFixed(1)} ${_yildiz(sayiOku(k['puan']))}',
                    ],
                ],
              ),
            )
          else
            for (final k in karne)
              KKart(
                renk: sayiOku(k['puan']) >= 4 ? t.yesil : (sayiOku(k['puan']) >= 3 ? t.amber : t.kirmizi),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${k['ad']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))),
                    KRozet('${sayiOku(k['puan']).toStringAsFixed(1)} ${_yildiz(sayiOku(k['puan']))}', renk: t.gold),
                  ]),
                  const SizedBox(height: 4),
                  Text('${tl(k['toplam'], kisa: true)} · ${k['fatura']} fatura · zamanında ${k['zamaninda'] == null ? '—' : '%${k['zamaninda']}'} · red ${sayiOku(k['red_oran']) > 0 ? yuzde(k['red_oran']) : '—'}',
                      style: TextStyle(color: t.sub, fontSize: 12.5)),
                ]),
              ),
        ]);
      },
    );
  }
}

/// Web /tedarikci-karne — sipariş bazlı tedarikçi karnesi (sipariş, tutar, teslim, zamanında %, ort. gecikme).
class TedarikciKarneScreen extends StatelessWidget {
  const TedarikciKarneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/tedarikci-karne',
      baslik: 'Tedarikçi Karnesi',
      ikon: Icons.grading,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final rows = liste(v['rows']);
        Color zRenk(dynamic z) => z == null ? t.sub : (sayiOku(z) >= 90 ? t.yesil : (sayiOku(z) >= 70 ? t.amber : t.kirmizi));
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Tedarikçi', deger: '${rows.length}', ikon: Icons.local_shipping_outlined, renk: t.mavi),
            KKpi(etiket: 'Sipariş tutarı', deger: tl(rows.fold<double>(0, (s, r) => s + sayiOku(r['tutar'])), kisa: true), ikon: Icons.payments_outlined, renk: t.mor1),
          ]),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const KBos(
              baslik: 'Karne için sipariş yok',
              ikon: Icons.grading,
              aciklama: 'Karne satın alma siparişlerinden (PO) ve mal kabullerden hesaplanır. Satın Alma Siparişi açıp malı Mal Kabul ile teslim aldıkça dolar.',
            )
          else if (genisMi(context))
            KKart(
              padding: EdgeInsets.zero,
              child: KTablo(
                basliklar: const ['Tedarikçi', 'Sipariş', 'Tutar', 'Teslim', 'Zamanında', 'Ort. gecikme', 'Son'],
                sagaYasla: const {1, 2},
                satirlar: [
                  for (final r in rows)
                    [
                      '${r['ad']}${tamOku(r['anlasmali']) == 1 ? ' ⭐' : ''}',
                      '${r['siparis']}',
                      tl(r['tutar']),
                      '${r['teslim']}',
                      r['zamaninda_pct'] == null ? 'veri yok' : '%${r['zamaninda_pct']}',
                      sayiOku(r['ort_gecikme']) > 0 ? '${r['ort_gecikme']} gün' : '—',
                      tarihYaz(r['son'], saat: false),
                    ],
                ],
              ),
            )
          else
            for (final r in rows)
              KKart(
                renk: zRenk(r['zamaninda_pct']),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text('${r['ad']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))),
                    if (tamOku(r['anlasmali']) == 1) KRozet('⭐ anlaşmalı', renk: t.amber),
                  ]),
                  const SizedBox(height: 4),
                  Text('${r['siparis']} sipariş · ${tl(r['tutar'])} · ${r['teslim']} teslim', style: TextStyle(color: t.sub, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    KRozet(r['zamaninda_pct'] == null ? 'Zamanında: veri yok' : 'Zamanında %${r['zamaninda_pct']}', renk: zRenk(r['zamaninda_pct'])),
                    if (sayiOku(r['ort_gecikme']) > 0) KRozet('Ort. gecikme ${r['ort_gecikme']} gün', renk: t.kirmizi),
                    KRozet('Son: ${tarihYaz(r['son'], saat: false)}', renk: t.sub),
                  ]),
                ]),
              ),
        ]);
      },
    );
  }
}

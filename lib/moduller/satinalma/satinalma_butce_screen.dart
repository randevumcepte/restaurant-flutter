import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /satinalma-butce — aylık satın alma bütçesi vs gerçekleşen harcama (son 6 ay). Bütçeyi yalnız sahip/müdür belirler (`duzenle`).
class SatinalmaButceScreen extends StatelessWidget {
  const SatinalmaButceScreen({super.key});

  static const _aylar = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
  static String ayAd(String ym) {
    final p = ym.split('-');
    if (p.length != 2) return ym;
    final m = int.tryParse(p[1]) ?? 0;
    return m >= 1 && m <= 12 ? '${_aylar[m - 1]} ${p[0]}' : ym;
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/satinalma-butce',
      baslik: 'Satın Alma Bütçe',
      ikon: Icons.account_balance_wallet_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final s = liste(v['satirlar']);
        final buAy = metinOku(v['buAy']);
        final bu = s.firstWhere((x) => x['ay'] == buAy, orElse: () => const {});
        final duzen = v['duzenle'] == true;
        final yz = bu['yuzde'] == null ? null : sayiOku(bu['yuzde']);
        Color renk(double? y) => y == null ? t.sub : (y >= 100 ? t.kirmizi : (y >= 80 ? t.amber : t.yesil));
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Bu ay bütçe', deger: sayiOku(v['mevcutButce']) > 0 ? tl(v['mevcutButce'], kisa: true) : 'Belirlenmedi', ikon: Icons.flag_outlined, renk: t.mor1),
            KKpi(etiket: 'Bu ay harcama', deger: tl(bu['harcama'], kisa: true), ikon: Icons.shopping_cart_outlined, renk: t.mavi),
            KKpi(etiket: 'Kullanım', deger: yz == null ? '—' : '%${yz.round()}', alt: yz == null ? 'Bütçe girilince hesaplanır' : (yz >= 100 ? 'Bütçe aşıldı' : 'Kalan ${tl(sayiOku(bu['butce']) - sayiOku(bu['harcama']), kisa: true)}'), ikon: Icons.speed, renk: renk(yz)),
          ]),
          const SaBilgi('Harcama = iptal ve taslak dışındaki satın alma siparişlerinin genel toplamı (sipariş tarihine göre).', ikon: Icons.info_outline),
          if (duzen)
            Align(alignment: Alignment.centerLeft, child: KButon('Bütçe belirle', ikon: Icons.edit_outlined, onTap: () => _kaydet(ctx, s, buAy, yenile)))
          else
            Text('Bütçeyi yalnızca sahip / müdür belirler.', style: TextStyle(color: t.sub, fontSize: 12.5)),
          const SizedBox(height: 12),
          KBaslik('Son 6 ay', ikon: Icons.calendar_month_outlined),
          for (final x in s)
            Builder(builder: (_) {
              final y = x['yuzde'] == null ? null : sayiOku(x['yuzde']);
              return KKart(
                renk: renk(y),
                onTap: duzen ? () => _kaydet(ctx, s, metinOku(x['ay']), yenile) : null,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text(ayAd(metinOku(x['ay'])), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5))),
                    if (y != null) KRozet('%${y.round()}', renk: renk(y)),
                  ]),
                  const SizedBox(height: 4),
                  Text('Harcama ${tl(x['harcama'], kisa: true)} / Bütçe ${sayiOku(x['butce']) > 0 ? tl(x['butce'], kisa: true) : 'yok'}', style: TextStyle(color: t.sub2, fontSize: 13)),
                  if (y != null) ...[
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: (y / 100).clamp(0.0, 1.0), minHeight: 7, backgroundColor: t.line, color: renk(y)),
                  ],
                ]),
              );
            }),
        ]);
      },
    );
  }

  Future<void> _kaydet(BuildContext context, List<Map<String, dynamic>> s, String ay, Future<void> Function() yenile) async {
    var secAy = ay;
    final mevcut = s.firstWhere((x) => x['ay'] == ay, orElse: () => const {});
    final tutar = TextEditingController(text: sayiOku(mevcut['butce']) > 0 ? '${sayiOku(mevcut['butce'])}' : '');
    final ok = await kAltSayfa<bool>(context, baslik: 'Aylık bütçe', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KSecim<String>('Ay', deger: secAy, secenekler: [for (final x in s) (metinOku(x['ay']), ayAd(metinOku(x['ay'])))], onSec: (x) => ss(() {
                  secAy = x ?? ay;
                  final m = s.firstWhere((y) => y['ay'] == secAy, orElse: () => const {});
                  tutar.text = sayiOku(m['butce']) > 0 ? '${sayiOku(m['butce'])}' : '';
                })),
            KAlan('Bütçe tutarı (₺)', tutar, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
            KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () => Navigator.pop(c, true)),
          ]);
        }));
    if (ok != true || !context.mounted) return;
    await saGonder(context, '/satinalma-butce/kaydet', {'yil_ay': secAy, 'tutar': tutar.text.trim()}, json: false);
    yenile();
  }
}

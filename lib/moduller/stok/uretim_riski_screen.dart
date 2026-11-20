import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /uretim-riski — kritik stoktaki malzemeler + stok yüzünden az porsiyon yapılabilecek ürünler (darboğaz).
class UretimRiskiScreen extends StatefulWidget {
  const UretimRiskiScreen({super.key});

  @override
  State<UretimRiskiScreen> createState() => _UretimRiskiScreenState();
}

class _UretimRiskiScreenState extends State<UretimRiskiScreen> {
  final _k = GlobalKey<KopruEkranState>();

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/uretim-riski',
      baslik: 'Üretim Riski',
      ikon: Icons.warning_amber_outlined,
      otomatik: const Duration(minutes: 2),
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final kritik = liste(v['kritik']);
        final riskli = liste(v['riskli']);
        final esik = tamOku(v['esik']);
        return KGovde(yenile: yenile, children: [
          KKart(
            renk: riskli.isEmpty && kritik.isEmpty ? t.yesil : t.kirmizi,
            child: Row(children: [
              KIkon(riskli.isEmpty && kritik.isEmpty ? Icons.verified_outlined : Icons.crisis_alert, renk: riskli.isEmpty && kritik.isEmpty ? t.yesil : t.kirmizi),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  riskli.isEmpty && kritik.isEmpty
                      ? 'Şu an üretimi tehlikeye atan stok yok.'
                      : '${riskli.length} ürün en fazla $esik porsiyon yapılabilir · ${kritik.length} malzeme kritik seviyede.',
                  style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ),
            ]),
          ),
          Text('Risk eşiği (porsiyon)', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          KCipler(
            secenekler: const [('5', '≤ 5'), ('10', '≤ 10'), ('15', '≤ 15'), ('30', '≤ 30'), ('50', '≤ 50')],
            secili: '$esik',
            onSec: (s) => _k.currentState?.sorgu({'esik': s}),
          ),
          const SizedBox(height: 8),
          KBaslik('Riskli ürünler', ikon: Icons.restaurant_menu, alt: 'Mevcut stokla en fazla bu kadar porsiyon yapılabilir; darboğaz malzeme yanında.'),
          if (riskli.isEmpty)
            KBos(
              baslik: 'Riskli ürün yok',
              ikon: Icons.check_circle_outline,
              aciklama: 'Reçetesi tanımlı her ürün $esik porsiyondan fazla yapılabiliyor. (Reçetesi olmayan ürün hesaba girmez — Reçeteler ekranından tanımlayın.)',
            )
          else
            for (final r in riskli)
              KKart(
                renk: tamOku(r['yapilabilir']) <= 0 ? t.kirmizi : t.amber,
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r['urun']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Darboğaz: ${metinOku(r['darbogaz'], '—')}', style: TextStyle(color: t.sub, fontSize: 12.5)),
                    ]),
                  ),
                  KRozet(tamOku(r['yapilabilir']) <= 0 ? 'Yapılamaz' : '${r['yapilabilir']} porsiyon', renk: tamOku(r['yapilabilir']) <= 0 ? t.kirmizi : t.amber),
                ]),
              ),
          const SizedBox(height: 8),
          KBaslik('Kritik stoktaki malzemeler', ikon: Icons.inventory_2_outlined,
              sag: TextButton(onPressed: () => stAc(context, '/stok/malzeme', 'Stok / Malzeme'), child: const Text('Stok'))),
          if (kritik.isEmpty)
            const KBos(baslik: 'Kritik malzeme yok', ikon: Icons.check_circle_outline, aciklama: 'Kritik seviyesi tanımlı malzemelerin hepsi eşiğin üstünde. Eşiği malzeme kartından girersiniz.')
          else
            for (final m in kritik)
              KSatir(
                solIkon: Icon(Icons.warning_amber_outlined, color: t.kirmizi),
                baslik: '${m['ad']}',
                alt: 'Kritik seviye: ${mik(m['kritik'])} ${m['birim']}',
                sag: Text('${mik(m['mevcut'])} ${m['birim']}', style: TextStyle(color: t.kirmizi, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
        ]);
      },
    );
  }
}

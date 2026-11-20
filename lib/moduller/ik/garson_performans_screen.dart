import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// /garson-performans — Garson karnesi (web ile aynı veri): dönem seçimi, toplam adım/km,
/// garson başına ciro · adisyon · kalem · ort. servis · adım + saatlik yoğunluk grafiği.
class IkGarsonPerformansScreen extends StatefulWidget {
  const IkGarsonPerformansScreen({super.key});
  @override
  State<IkGarsonPerformansScreen> createState() => _IkGarsonPerformansScreenState();
}

class _IkGarsonPerformansScreenState extends State<IkGarsonPerformansScreen> {
  String _period = 'gunluk';
  String _sirala = 'ciro';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/garson-performans',
      q: {'period': _period},
      baslik: 'Garson Performansı',
      ikon: Icons.emoji_events_outlined,
      govde: (c, v, yenile) {
        final t = c.watch<TemaProvider>();
        final gs = liste(v['garsonlar']);
        gs.sort((a, b) => sayiOku(b[_sirala]).compareTo(sayiOku(a[_sirala])));
        final adim = gs.fold<double>(0, (a, g) => a + sayiOku(g['adim']));
        final km = adim * 0.75 / 1000;
        final ciro = gs.fold<double>(0, (a, g) => a + sayiOku(g['ciro']));
        final adisyon = gs.fold<double>(0, (a, g) => a + sayiOku(g['adisyon']));
        return KGovde(yenile: yenile, children: [
          KCipler(
            secenekler: const [('gunluk', 'Günlük'), ('haftalik', 'Haftalık'), ('aylik', 'Aylık'), ('yillik', 'Yıllık')],
            secili: _period,
            onSec: (k) => setState(() => _period = k),
          ),
          KKart(
            renk: const Color(0xFFF97316),
            onTap: () => Navigator.of(c).push(MaterialPageRoute(builder: (_) => EkranKayit.uret('/garson-yonetimi', 'Garson Yönetimi'))),
            child: Row(children: [
              const KIkon(Icons.local_fire_department_outlined, renk: Color(0xFFF97316)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Isı Haritası ve Alan Uyumu', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('Tüm salonu görün, garsonun kendi alanında mı çalıştığını kontrol edin.', style: TextStyle(color: t.sub, fontSize: 12.5)),
                ]),
              ),
              Icon(Icons.chevron_right, color: t.sub),
            ]),
          ),
          KKpiIzgara([
            KKpi(etiket: 'Toplam ciro', deger: tl(ciro, kisa: true), ikon: Icons.payments_outlined, renk: t.yesil),
            KKpi(etiket: 'Masa / adisyon', deger: sayiYaz(adisyon), ikon: Icons.receipt_long_outlined, renk: t.mavi),
            KKpi(etiket: 'Toplam adım', deger: sayiYaz(adim), ikon: Icons.directions_walk, renk: t.mor1),
            KKpi(etiket: 'Yürünen yol', deger: '${km >= 1 ? km.toStringAsFixed(1) : km.toStringAsFixed(2)} km'.replaceAll('.', ','), ikon: Icons.route_outlined, renk: t.amber),
          ]),
          KBaslik('Garson Karnesi', ikon: Icons.emoji_events_outlined, alt: 'Sıralama: ${_sirala == 'ciro' ? 'ciro' : _sirala == 'adisyon' ? 'adisyon' : 'adım'}'),
          if (gs.isNotEmpty)
            KCipler(
              secenekler: const [('ciro', 'Ciroya göre'), ('adisyon', 'Adisyona göre'), ('adim', 'Adıma göre')],
              secili: _sirala,
              onSec: (k) => setState(() => _sirala = k),
            ),
          if (gs.isEmpty)
            const KBos(
              ikon: Icons.person_search_outlined,
              baslik: 'Bu dönemde garson verisi yok',
              aciklama: 'Karne, garsonların POS\'ta açıp kapattığı adisyonlardan oluşur. Bu dönemde garson rolünde personelin kapattığı adisyon yoksa boş görünür. '
                  'Garsonları Personel & Maaş ekranından ekleyebilirsiniz; adım verisi garsonun uygulamada adım iznini vermesiyle gelir.',
            )
          else
            LayoutBuilder(builder: (ctx, cs) {
              final n = genisMi(c) ? (cs.maxWidth >= 1100 ? 3 : 2) : 1;
              const ara = 12.0;
              final g = (cs.maxWidth - ara * (n - 1)) / n;
              return Wrap(spacing: ara, children: [
                for (var i = 0; i < gs.length; i++) SizedBox(width: g, child: _Karne(g: gs[i], sira: i + 1)),
              ]);
            }),
        ]);
      },
    );
  }
}

class _Karne extends StatelessWidget {
  final Map<String, dynamic> g;
  final int sira;
  const _Karne({required this.g, required this.sira});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final ad = metinOku(g['ad'], '?');
    final saatler = liste(g['saat_dagilim']);
    var maxS = 1;
    for (final s in saatler) {
      if (tamOku(s['adisyon']) > maxS) maxS = tamOku(s['adisyon']);
    }
    final bosMu = saatler.every((s) => tamOku(s['adisyon']) == 0);
    Widget metrik(String d, String e) => Expanded(
          child: Column(children: [
            Text(d, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(e, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 11.5)),
          ]),
        );
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: t.mor1.withValues(alpha: .15),
            child: Text(ad.substring(0, 1).toUpperCase(), style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ad, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700)),
              Text('$sira. sırada', style: TextStyle(color: t.sub, fontSize: 12)),
            ]),
          ),
          Text(tl(g['ciro'], kisa: true), style: TextStyle(color: t.yesil, fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          metrik(sayiYaz(g['adisyon']), 'Masa/Adisyon'),
          metrik(sayiYaz(g['kalem']), 'Ürün kalemi'),
          metrik('${tamOku(g['ort_servis_dk'])} dk', 'Ort. servis'),
          metrik(sayiYaz(g['adim']), 'Adım'),
        ]),
        const SizedBox(height: 12),
        Text('Saatlik yoğunluk', style: TextStyle(color: t.sub2, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SizedBox(
          height: 54,
          child: (saatler.isEmpty || bosMu)
              ? Center(child: Text('Bu dönemde adisyon yok', style: TextStyle(color: t.sub, fontSize: 12)))
              : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final s in saatler)
                    Expanded(
                      child: Tooltip(
                        message: '${tamOku(s['saat']).toString().padLeft(2, '0')}:00 · ${tamOku(s['adisyon'])} adisyon',
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          height: tamOku(s['adisyon']) > 0 ? (54 * (tamOku(s['adisyon']) / maxS)).clamp(5, 54).toDouble() : 3,
                          decoration: BoxDecoration(
                            color: tamOku(s['adisyon']) > 0 ? t.mor1 : t.line,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                ]),
        ),
        if (saatler.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Row(children: [
              Text(tamOku(saatler.first['saat']).toString().padLeft(2, '0'), style: TextStyle(color: t.sub, fontSize: 11)),
              const Spacer(),
              Text(tamOku(saatler.last['saat']).toString().padLeft(2, '0'), style: TextStyle(color: t.sub, fontSize: 11)),
            ]),
          ),
      ]),
    );
  }
}

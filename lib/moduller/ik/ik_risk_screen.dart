import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';

/// /ik-risk — Personel Risk Radarı (web ile aynı veri): seviye özetleri, seviye filtresi,
/// her personel için nedenler + öneri + sicil kartına geçiş.
class IkRiskScreen extends StatefulWidget {
  const IkRiskScreen({super.key});
  @override
  State<IkRiskScreen> createState() => _IkRiskScreenState();
}

const _seviyeRenk = {
  'yuksek': Color(0xFFF43F5E),
  'orta': Color(0xFFF59E0B),
  'dusuk': Color(0xFFEAB308),
  'yok': Color(0xFF10B981),
};
const _seviyeAd = {'yuksek': 'YÜKSEK RİSK', 'orta': 'ORTA', 'dusuk': 'DÜŞÜK', 'yok': 'İZLE'};

class _IkRiskScreenState extends State<IkRiskScreen> {
  String _filtre = 'hepsi';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/ik-risk',
      baslik: 'Personel Risk Radarı',
      ikon: Icons.crisis_alert,
      govde: (c, v, yenile) {
        final t = c.watch<TemaProvider>();
        final tum = liste(v['risk']);
        final say = <String, int>{'yuksek': 0, 'orta': 0, 'dusuk': 0};
        for (final r in tum) {
          final s = metinOku(r['seviye']);
          if (say.containsKey(s)) say[s] = say[s]! + 1;
        }
        final gorunen = _filtre == 'hepsi' ? tum : tum.where((r) => metinOku(r['seviye']) == _filtre).toList();
        return KGovde(yenile: yenile, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Devamsızlık, avans yoğunluğu ve kıdeme göre erken uyarı — ayrılma/sorun riskini önceden yakalayın.',
                style: TextStyle(color: t.sub, fontSize: 13)),
          ),
          KKpiIzgara([
            KKpi(etiket: 'Yüksek risk', deger: '${say['yuksek']}', renk: _seviyeRenk['yuksek'], ikon: Icons.warning_amber_outlined, onTap: () => setState(() => _filtre = 'yuksek')),
            KKpi(etiket: 'Orta', deger: '${say['orta']}', renk: _seviyeRenk['orta'], ikon: Icons.report_outlined, onTap: () => setState(() => _filtre = 'orta')),
            KKpi(etiket: 'Düşük / izlenecek', deger: '${say['dusuk']}', renk: _seviyeRenk['dusuk'], ikon: Icons.visibility_outlined, onTap: () => setState(() => _filtre = 'dusuk')),
          ]),
          if (tum.isNotEmpty)
            KCipler(
              secenekler: const [('hepsi', 'Tümü'), ('yuksek', 'Yüksek'), ('orta', 'Orta'), ('dusuk', 'Düşük'), ('yok', 'İzle')],
              secili: _filtre,
              onSec: (k) => setState(() => _filtre = k),
            ),
          if (tum.isEmpty)
            const KBos(
              ikon: Icons.verified_user_outlined,
              baslik: 'Risk sinyali yok',
              aciklama: 'Şu an devamsızlık, avans yoğunluğu veya yeni personel kaynaklı dikkat gerektiren durum görünmüyor. '
                  'Radar; puantaj (QR mesai), vardiya planı ve avans hareketlerinden beslenir — bunlar girilmezse sinyal üretemez.',
            )
          else if (gorunen.isEmpty)
            const KBos(ikon: Icons.filter_alt_off_outlined, baslik: 'Bu seviyede personel yok', aciklama: 'Filtreyi "Tümü" yapın.')
          else
            for (final r in gorunen) _kart(c, r),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Risk skoru; son 30 gün vardiya devamsızlığı, bu ayki avans sıklığı/tutarı ve kıdem bilgisinden hesaplanır. '
                'Daha isabetli sonuç için puantaj (QR mesai) ve vardiya planı kullanılmalıdır.', style: TextStyle(color: t.sub, fontSize: 12)),
          ),
        ]);
      },
    );
  }

  Widget _kart(BuildContext context, Map<String, dynamic> r) {
    final t = context.watch<TemaProvider>();
    final s = metinOku(r['seviye']);
    final renk = _seviyeRenk[s] ?? t.sub;
    final nedenler = dizi(r['nedenler']);
    final oneri = metinOku(r['oneri']);
    return KKart(
      renk: renk,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: metinOku(r['ad'], '—'), style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
              TextSpan(text: '  ${metinOku(r['rol'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
            ])),
          ),
          KRozet(_seviyeAd[s] ?? '—', renk: renk),
        ]),
        const SizedBox(height: 6),
        for (final n in nedenler)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.chevron_right, size: 17, color: renk),
              const SizedBox(width: 4),
              Expanded(child: Text(metinOku(n), style: TextStyle(color: t.sub2, fontSize: 13))),
            ]),
          ),
        if (oneri.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.lightbulb_outline, size: 17, color: t.amber),
              const SizedBox(width: 6),
              Expanded(child: Text(oneri, style: TextStyle(color: t.ink, fontSize: 13))),
            ]),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EkranKayit.uret('/ik-sicil?id=${tamOku(r['id'])}', 'Sicil Kartı'))),
            icon: Icon(Icons.folder_shared_outlined, size: 18, color: t.mavi),
            label: Text('Sicil kartını aç', style: TextStyle(color: t.mavi, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}

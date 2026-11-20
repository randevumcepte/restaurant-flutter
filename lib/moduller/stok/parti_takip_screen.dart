import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /parti-takip — SKT / parti takibi (FEFO): aktif partiler, son kullanma geçmiş / yaklaşan.
class PartiTakipScreen extends StatefulWidget {
  const PartiTakipScreen({super.key});

  @override
  State<PartiTakipScreen> createState() => _PartiTakipScreenState();
}

class _PartiTakipScreenState extends State<PartiTakipScreen> {
  String _f = 'tumu';
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/parti-takip',
      baslik: 'SKT / Parti Takibi',
      ikon: Icons.event_note_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final partiler = liste(v['partiler']);
        final esik = tamOku(v['esik']);
        final q = _ara.toLowerCase();
        final gorunen = partiler.where((p) {
          if (_f != 'tumu' && p['durum'] != _f) return false;
          if (q.isNotEmpty && !'${p['malzeme']} ${p['lot_no'] ?? ''} ${p['tedarikci'] ?? ''}'.toLowerCase().contains(q)) return false;
          return true;
        }).toList();
        final gecmis = tamOku(v['gecmisSay']), yaklasan = tamOku(v['yaklasanSay']);
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Son kullanma GEÇMİŞ', deger: '$gecmis', ikon: Icons.dangerous_outlined, renk: t.kirmizi, onTap: () => setState(() => _f = 'gecmis')),
            KKpi(etiket: '$esik güne kadar YAKLAŞAN', deger: '$yaklasan', ikon: Icons.hourglass_bottom, renk: t.amber, onTap: () => setState(() => _f = 'yaklasan')),
            KKpi(etiket: 'Aktif parti (kalan > 0)', deger: '${partiler.length}', ikon: Icons.inventory_outlined, renk: t.mavi, onTap: () => setState(() => _f = 'tumu')),
          ]),
          if (gecmis > 0 || yaklasan > 0)
            KKart(
              renk: t.amber,
              child: Row(children: [
                Icon(Icons.warning_amber_outlined, color: t.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Dikkat gereken partiler var: $gecmis parti son kullanma geçti, $yaklasan parti yaklaşıyor. Önce en yakın SKT\'li partiyi kullanın (FEFO).',
                      style: TextStyle(color: t.ink, fontSize: 13.5, height: 1.35)),
                ),
              ]),
            ),
          const SizedBox(height: 4),
          KAra(ipucu: 'Malzeme, lot ya da tedarikçi ara', onDegis: (s) => setState(() => _ara = s)),
          const SizedBox(height: 8),
          KCipler(
            secenekler: [('tumu', 'Tümü'), ('gecmis', 'Geçmiş $gecmis'), ('yaklasan', 'Yaklaşan $yaklasan'), ('normal', 'Normal')],
            secili: _f,
            onSec: (s) => setState(() => _f = s),
          ),
          const SizedBox(height: 8),
          if (partiler.isEmpty)
            const KBos(
              baslik: 'Aktif parti yok',
              ikon: Icons.event_note_outlined,
              aciklama: 'Partiler mal kabulde (lot + SKT girilerek) ve yarı mamül üretiminde oluşur. Mal Kabul ekranında SKT girin; satıldıkça en yakın SKT\'li partiden düşülür.',
            )
          else if (gorunen.isEmpty)
            const KBos(baslik: 'Bu filtrede parti yok', ikon: Icons.filter_alt_off_outlined)
          else if (genisMi(context))
            KKart(
              padding: EdgeInsets.zero,
              child: KTablo(
                basliklar: const ['Malzeme', 'Lot / Parti', 'SKT', 'Durum', 'Kalan', 'Tedarikçi', 'Giriş'],
                sagaYasla: const {4},
                satirlar: [
                  for (final p in gorunen)
                    [
                      '${p['malzeme']}',
                      metinOku(p['lot_no'], '—'),
                      tarihYaz(p['skt'], saat: false),
                      _durumMetin(p),
                      mik(p['kalan_miktar']),
                      metinOku(p['tedarikci'], '—'),
                      tarihYaz(p['giris_tarihi'], saat: false),
                    ],
                ],
              ),
            )
          else
            for (final p in gorunen)
              KKart(
                renk: stDurumRenk(t, '${p['durum']}'),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${p['malzeme']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('Lot ${metinOku(p['lot_no'], '—')} · SKT ${tarihYaz(p['skt'], saat: false)}', style: TextStyle(color: t.sub, fontSize: 12.5)),
                      Text('${metinOku(p['tedarikci'], 'Tedarikçi yok')} · Giriş ${tarihYaz(p['giris_tarihi'], saat: false)}', style: TextStyle(color: t.sub, fontSize: 12)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(mik(p['kalan_miktar']), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
                    if (p['durum'] != 'normal') KRozet(_durumMetin(p), renk: stDurumRenk(t, '${p['durum']}')),
                  ]),
                ]),
              ),
        ]);
      },
    );
  }

  String _durumMetin(Map<String, dynamic> p) {
    final g = p['kalan_gun'];
    if (p['durum'] == 'gecmis') return g == null ? 'Geçti' : 'Geçti (${tamOku(g).abs()} gün)';
    if (p['durum'] == 'yaklasan') return '${tamOku(g)} gün';
    return p['skt'] == null ? 'SKT yok' : 'Normal';
  }
}

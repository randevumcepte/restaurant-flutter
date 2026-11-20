import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

const Map<String, String> kAlerjenIkon = {
  'Gluten': '🌾', 'Kabuklu deniz ürünleri': '🦐', 'Yumurta': '🥚', 'Balık': '🐟', 'Yer fıstığı': '🥜', 'Soya': '🫘', 'Süt (laktoz)': '🥛',
  'Sert kabuklu yemiş': '🌰', 'Kereviz': '🥬', 'Hardal': '🌶️', 'Susam': '⚪', 'Sülfit': '🍷', 'Acı bakla (lupin)': '🌱', 'Yumuşakça': '🐌',
};

/// Web /alerjen — alerjen matrisi: her ürünün 14 yasal alerjeni (işaretle → kaydet).
class AlerjenScreen extends StatefulWidget {
  const AlerjenScreen({super.key});

  @override
  State<AlerjenScreen> createState() => _AlerjenScreenState();
}

class _AlerjenScreenState extends State<AlerjenScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _ara = '';
  String _f = 'tumu';
  bool _matris = false;

  List<String> _sec(Map<String, dynamic> u) => metinOku(u['alerjenler']).split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  Future<void> _duzenle(Map<String, dynamic> u, List<String> alerjenler) async {
    final secili = {..._sec(u)};
    final ok = await kAltSayfa<bool>(context, baslik: '${u['ad']} · Alerjenler', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.read<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Üründe bulunan (iz miktarı dahil) alerjenleri işaretleyin. Menüde ve QR siparişte müşteriye gösterilir.', style: TextStyle(color: t.sub, fontSize: 13, height: 1.35)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final a in alerjenler)
                FilterChip(
                  selected: secili.contains(a),
                  onSelected: (b) => ss(() => b ? secili.add(a) : secili.remove(a)),
                  label: Text('${kAlerjenIkon[a] ?? '⚠️'} $a', style: TextStyle(fontSize: 13.5, color: secili.contains(a) ? Colors.white : t.ink, fontWeight: FontWeight.w600)),
                  selectedColor: t.kirmizi,
                  checkmarkColor: Colors.white,
                  backgroundColor: t.card2,
                  side: BorderSide(color: t.line),
                ),
            ]),
            const SizedBox(height: 14),
            KButon('Kaydet (${secili.length})', ikon: Icons.check, genis: true, onTap: () async {
              final r = await stGonder(c, '/alerjen/kaydet', {'urun_id': u['id'], 'alerjenler': [for (final a in alerjenler) if (secili.contains(a)) a]}, basari: 'Alerjen bilgisi kaydedildi.');
              if (r.ok && c.mounted) Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok == true) _k.currentState?.yukle();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/alerjen',
      baslik: 'Alerjen Matrisi',
      ikon: Icons.health_and_safety_outlined,
      araclar: (ctx, v, y) => [
        if (genisMi(ctx))
          IconButton(
            tooltip: _matris ? 'Kart görünümü' : 'Matris (tablo) görünümü',
            icon: Icon(_matris ? Icons.view_agenda_outlined : Icons.grid_on),
            onPressed: () => setState(() => _matris = !_matris),
          ),
      ],
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final urunler = liste(v['urunler']);
        final alerjenler = [for (final a in dizi(v['alerjenler'])) '$a'];
        final eksik = urunler.where((u) => _sec(u).isEmpty).length;
        final q = _ara.toLowerCase();
        final gorunen = urunler.where((u) {
          if (q.isNotEmpty && !'${u['ad']}'.toLowerCase().contains(q)) return false;
          if (_f == 'eksik' && _sec(u).isNotEmpty) return false;
          if (_f == 'var' && _sec(u).isEmpty) return false;
          return true;
        }).toList();
        return KGovde(yenile: yenile, maxGenislik: _matris ? 1600 : 1180, children: [
          KKpiIzgara([
            KKpi(etiket: 'Aktif ürün', deger: '${urunler.length}', ikon: Icons.restaurant_menu, renk: t.mavi, onTap: () => setState(() => _f = 'tumu')),
            KKpi(etiket: 'Alerjen girilmemiş', deger: '$eksik', ikon: Icons.help_outline, renk: eksik > 0 ? t.amber : t.yesil, onTap: () => setState(() => _f = 'eksik')),
          ]),
          if (eksik > 0)
            KKart(
              renk: t.amber,
              child: Text('$eksik üründe alerjen bilgisi yok. Gıda mevzuatı menüde alerjen beyanı ister; ürüne dokunup işaretleyin (alerjen yoksa boş kaydedin).',
                  style: TextStyle(color: t.ink, fontSize: 13.5, height: 1.35)),
            ),
          KAra(ipucu: 'Ürün ara', onDegis: (s) => setState(() => _ara = s)),
          const SizedBox(height: 8),
          KCipler(secenekler: [('tumu', 'Tümü'), ('eksik', 'Girilmemiş $eksik'), ('var', 'Alerjenli')], secili: _f, onSec: (s) => setState(() => _f = s)),
          const SizedBox(height: 8),
          if (urunler.isEmpty)
            const KBos(baslik: 'Aktif ürün yok', ikon: Icons.restaurant_menu, aciklama: 'Alerjen matrisi menüdeki aktif ürünleri listeler. Menü Yönetimi ekranından ürün ekleyin.')
          else if (gorunen.isEmpty)
            const KBos(baslik: 'Bu filtrede ürün yok', ikon: Icons.filter_alt_off_outlined)
          else if (_matris && genisMi(context))
            _matrisTablo(context, gorunen, alerjenler)
          else
            for (final u in gorunen)
              KKart(
                renk: _sec(u).isEmpty ? t.amber : t.kirmizi,
                onTap: () => _duzenle(u, alerjenler),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${u['ad']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      if (_sec(u).isEmpty)
                        Text('Alerjen girilmemiş', style: TextStyle(color: t.amber, fontSize: 12.5, fontWeight: FontWeight.w600))
                      else
                        Wrap(spacing: 6, runSpacing: 6, children: [for (final a in _sec(u)) KRozet('${kAlerjenIkon[a] ?? '⚠️'} $a', renk: t.kirmizi)]),
                    ]),
                  ),
                  Icon(Icons.edit_outlined, color: t.sub),
                ]),
              ),
        ]);
      },
    );
  }

  Widget _matrisTablo(BuildContext context, List<Map<String, dynamic>> urunler, List<String> alerjenler) {
    final t = context.read<TemaProvider>();
    return KKart(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 70,
          columnSpacing: 10,
          columns: [
            DataColumn(label: Text('Ürün', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold))),
            for (final a in alerjenler)
              DataColumn(
                label: Tooltip(
                  message: a,
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(kAlerjenIkon[a] ?? '⚠️', style: const TextStyle(fontSize: 18)),
                    SizedBox(width: 54, child: Text(a, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 10))),
                  ]),
                ),
              ),
          ],
          rows: [
            for (final u in urunler)
              DataRow(
                onSelectChanged: (_) => _duzenle(u, alerjenler),
                cells: [
                  DataCell(Text('${u['ad']}', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600))),
                  for (final a in alerjenler)
                    DataCell(Center(child: _sec(u).contains(a) ? Icon(Icons.circle, size: 14, color: t.kirmizi) : Text('·', style: TextStyle(color: t.sub)))),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

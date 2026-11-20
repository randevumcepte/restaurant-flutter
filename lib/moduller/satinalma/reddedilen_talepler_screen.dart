import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';
import 'satinalma_talep_screen.dart';

/// Web /reddedilen-talepler — departman reddi + patron fiyat reddi kaydı (sebep, kim, ne zaman).
class ReddedilenTaleplerScreen extends StatefulWidget {
  const ReddedilenTaleplerScreen({super.key});
  @override
  State<ReddedilenTaleplerScreen> createState() => _ReddedilenTaleplerScreenState();
}

class _ReddedilenTaleplerScreenState extends State<ReddedilenTaleplerScreen> {
  String _sekme = 'tum';
  String _dep = '';
  int _gun = 0;
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(yol: '/reddedilen-talepler', baslik: 'Reddedilen Talepler', ikon: Icons.block, govde: _govde);
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final rt = liste(v['kayitlar']);
    final benId = tamOku(v['benId']);
    final yonetici = v['yonetici'] == true;
    final simdi = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final ay = rt.where((r) => tamOku(r['red_ts']) > 0 && simdi - tamOku(r['red_ts']) <= 30 * 86400).length;
    (String, int)? enCok(Iterable<String> it) {
      final m = <String, int>{};
      for (final s in it) {
        if (s.isNotEmpty) m[s] = (m[s] ?? 0) + 1;
      }
      if (m.isEmpty) return null;
      final e = m.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return (e.key, e.value);
    }

    final dep = enCok(rt.map((r) => metinOku(r['departman'])));
    final urun = enCok(rt.expand((r) => liste(r['kalemler']).map((k) => metinOku(k['ad']))));
    final depler = <String>{for (final r in rt) metinOku(r['departman'])}.toList()..sort();
    bool uy(Map<String, dynamic> r, {bool sekmeYok = false}) {
      if (!sekmeYok && _sekme != 'tum' && r['tip'] != _sekme) return false;
      if (_dep.isNotEmpty && r['departman'] != _dep) return false;
      if (_gun > 0 && (tamOku(r['red_ts']) == 0 || simdi - tamOku(r['red_ts']) > _gun * 86400)) return false;
      return saIcerir('${r['departman']} ${r['isteyen_ad']} ${r['reddeden']} ${r['sebep']} #${r['id']} ${liste(r['kalemler']).map((k) => k['ad']).join(' ')}', _ara);
    }

    final b = rt.where((r) => uy(r, sekmeYok: true)).toList();
    final gorunen = rt.where(uy).toList();
    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Toplam red', deger: '${rt.length}', alt: '${rt.where((r) => r['tip'] == 'dept').length} departman · ${rt.where((r) => r['tip'] == 'fiyat').length} patron fiyat', ikon: Icons.block, renk: t.kirmizi),
        KKpi(etiket: 'Son 30 gün', deger: '$ay', alt: ay > 0 ? 'son ayda geri çevrilen' : 'son ayda red yok', ikon: Icons.event_outlined, renk: t.mavi),
        KKpi(etiket: 'En çok red alan', deger: dep?.$1 ?? '—', alt: dep != null ? '${dep.$2} talep' : 'henüz kayıt yok', ikon: Icons.groups_outlined, renk: t.mor1),
        KKpi(etiket: 'En çok reddedilen ürün', deger: urun?.$1 ?? '—', alt: urun != null ? '${urun.$2} kez' : 'henüz kayıt yok', ikon: Icons.inventory_2_outlined, renk: t.amber),
      ]),
      KCipler(secenekler: [
        ('tum', 'Tümü ${b.length}'),
        ('dept', 'Departman reddi ${b.where((r) => r['tip'] == 'dept').length}'),
        ('fiyat', 'Patron fiyat reddi ${b.where((r) => r['tip'] == 'fiyat').length}'),
      ], secili: _sekme, onSec: (k) => setState(() => _sekme = k)),
      KCipler(secenekler: const [('0', 'Tüm zamanlar'), ('7', 'Son 7 gün'), ('30', 'Son 30 gün'), ('90', 'Son 90 gün')], secili: '$_gun', onSec: (k) => setState(() => _gun = int.parse(k))),
      if (depler.length > 1)
        KCipler(secenekler: [('', 'Tüm departmanlar'), for (final d in depler) (d, d)], secili: _dep, onSec: (k) => setState(() => _dep = k)),
      KAra(ipucu: 'Departman, kişi, ürün, sebep ara…', onDegis: (s) => setState(() => _ara = s)),
      if (rt.isEmpty)
        const KBos(
            baslik: 'Henüz reddedilen talep yok',
            aciklama: 'Bir talep reddedildiğinde burada sebebiyle, isteyenle ve reddedenle birlikte görünür.\n\nDepartman reddi: sorumlu, ekibinden gelen talebi "stokta var" gibi bir sebeple reddeder; talep kapanır.\nPatron fiyat reddi: patron gelen fiyatları pahalı bulur; talep silinmez, tekrar fiyat araştırmasına döner.',
            ikon: Icons.verified_outlined)
      else if (gorunen.isEmpty)
        const KBos(baslik: 'Bu filtreye uyan kayıt yok', aciklama: 'Aramayı, departmanı veya dönemi değiştirip tekrar deneyin.', ikon: Icons.search_off)
      else
        SaIzgara([for (final r in gorunen) _kart(r, benId, yonetici, yenile)], minGenislik: 460),
    ]);
  }

  Widget _kart(Map<String, dynamic> r, int benId, bool yonetici, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final fiyat = r['tip'] == 'fiyat';
    final kalemler = liste(r['kalemler']);
    final kendi = tamOku(r['isteyen_id']) == benId || yonetici;
    return KKart(
      renk: fiyat ? t.amber : t.kirmizi,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          KRozet(fiyat ? 'Patron fiyat reddi' : 'Departman reddi', renk: fiyat ? t.amber : t.kirmizi, ikon: fiyat ? Icons.price_change_outlined : Icons.block),
          Text('${metinOku(r['departman'])} · Talep #${r['id']}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14)),
          if (r['acil'] == true) KRozet('ACİL', renk: t.kirmizi),
          if (fiyat) KRozet('Şu an: ${metinOku(r['durum'])}', renk: t.mavi),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (kalemler.isEmpty) Text('Ürün bilgisi yok', style: TextStyle(color: t.sub, fontSize: 12.5)),
          for (final k in kalemler.take(12))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(8)),
              child: Text('${metinOku(k['ad'])}${metinOku(k['miktar']).isNotEmpty ? '  ${k['miktar']}' : ''}', style: TextStyle(color: t.ink, fontSize: 12.5)),
            ),
          if (kalemler.length > 12) Text('+${kalemler.length - 12} ürün', style: TextStyle(color: t.sub, fontSize: 12.5)),
        ]),
        const SizedBox(height: 8),
        Text('${fiyat ? 'Neden' : 'Red sebebi'}: ${metinOku(r['sebep'], '—')}', style: TextStyle(color: fiyat ? t.amber : t.kirmizi, fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text('İsteyen: ${metinOku(r['isteyen_ad'])}${metinOku(r['talep_tarih']).isNotEmpty ? ' · Talep: ${r['talep_tarih']}' : ''}', style: TextStyle(color: t.sub, fontSize: 12.5)),
        Text('${fiyat ? 'Fiyatı reddeden' : 'Reddeden'}: ${metinOku(r['reddeden'])}${metinOku(r['red_tarih']).isNotEmpty ? ' · ${r['red_tarih']}' : ''}${metinOku(r['sure']).isNotEmpty ? ' · Karar süresi: ${r['sure']}' : ''}',
            style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (!fiyat && kendi)
            KButon('Düzenle ve tekrar gönder', ikon: Icons.edit_note, onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SatinalmaTalepScreen(url: '/satinalma-talep?kopya=${r['id']}')));
              yenile();
            }),
          KButon('Talebi aç', ikon: Icons.open_in_new, ikincil: true, onTap: () async {
            await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SatinalmaTalepScreen(url: '/satinalma-talep?ac=${r['id']}')));
            yenile();
          }),
          if (fiyat) KButon('Gelen tekliflere bak', ikon: Icons.mark_email_read_outlined, ikincil: true, onTap: () => saAc(context, '/gelen-teklifler', 'Gelen Teklifler')),
        ]),
      ]),
    );
  }
}

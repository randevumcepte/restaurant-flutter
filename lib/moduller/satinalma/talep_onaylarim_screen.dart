import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';
import 'satinalma_talep_screen.dart';

/// Web /talep-onaylarim — departman onayı bekleyen talepler (onayla / reddet / toplu onay).
/// Departman sorumlusu web'de Satın Alma Talepleri'ne (durum=departman_onay) yönlenir; uygulama da aynısını yapar.
class TalepOnaylarimScreen extends StatefulWidget {
  const TalepOnaylarimScreen({super.key});
  @override
  State<TalepOnaylarimScreen> createState() => _TalepOnaylarimScreenState();
}

class _TalepOnaylarimScreenState extends State<TalepOnaylarimScreen> {
  String _filtre = 'hepsi';
  final Set<int> _secili = {};
  bool _toplu = false;

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/talep-onaylarim',
      baslik: 'Onay Bekleyen Talepler',
      ikon: Icons.fact_check_outlined,
      govde: (ctx, v, yenile) {
        if (metinOku(v['yonlendir']).startsWith('/satinalma-talep')) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const SatinalmaTalepScreen(url: '/satinalma-talep?durum=departman_onay')));
          });
          return const KYukleniyor(metin: 'Satın Alma Talepleri açılıyor…');
        }
        return _govde(ctx, v, yenile);
      },
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    if (v['yetkisiz'] == true) {
      return const KBos(
          baslik: 'Onaylayacağınız talep yok',
          aciklama: 'Bu ekran departman sorumlularına ve yöneticilere açıktır. Sorumlu olduğunuz bir departman yok. Sorumluluk Personel & Departman ekranından atanır.',
          ikon: Icons.lock_outline);
    }
    final talepler = liste(v['talepler']);
    final acilSay = talepler.where((x) => x['aciliyet'] == 'acil').length;
    final depler = <String>{for (final x in talepler) metinOku(x['departman'], '—')}.toList();
    final gorunen = talepler.where((x) {
      if (_filtre == 'acil') return x['aciliyet'] == 'acil';
      if (_filtre.startsWith('dep:')) return metinOku(x['departman'], '—') == _filtre.substring(4);
      return true;
    }).toList();
    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Onay bekleyen', deger: '${talepler.length}', ikon: Icons.hourglass_top, renk: const Color(0xFF8B5CF6)),
        KKpi(etiket: 'Acil', deger: '$acilSay', ikon: Icons.priority_high, renk: t.kirmizi),
        KKpi(etiket: 'Departman', deger: '${depler.length}', ikon: Icons.groups_outlined, renk: t.mavi),
      ]),
      if (talepler.isNotEmpty)
        KCipler(secenekler: [
          ('hepsi', 'Tümü ${talepler.length}'),
          if (acilSay > 0) ('acil', 'Acil $acilSay'),
          if (depler.length > 1) for (final d in depler) ('dep:$d', '$d ${talepler.where((x) => metinOku(x['departman'], '—') == d).length}'),
        ], secili: _filtre, onSec: (k) => setState(() => _filtre = k)),
      if (_secili.isNotEmpty)
        KKart(
          renk: t.yesil,
          child: Row(children: [
            Expanded(child: Text('${_secili.length} talep seçili', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
            TextButton(onPressed: () => setState(_secili.clear), child: const Text('Temizle')),
            KButon('Seçilenleri Onayla', ikon: Icons.done_all, renk: t.yesil, yukleniyor: _toplu, onTap: () => _topluOnay(yenile)),
          ]),
        ),
      if (talepler.isEmpty)
        const KBos(baslik: 'Onay bekleyen talep yok', aciklama: 'Ekibinizden yeni bir satın alma talebi geldiğinde burada görünür; onaylayınca satın almaya gider.', ikon: Icons.verified_outlined)
      else
        SaIzgara([for (final x in gorunen) _kart(x, yenile)], minGenislik: 420),
    ]);
  }

  Widget _kart(Map<String, dynamic> x, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final id = tamOku(x['id']);
    final acil = x['aciliyet'] == 'acil';
    final kd = liste(x['kalemDetay']);
    return KKart(
      renk: acil ? t.kirmizi : const Color(0xFF8B5CF6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Checkbox(value: _secili.contains(id), onChanged: (b) => setState(() => b == true ? _secili.add(id) : _secili.remove(id))),
          Expanded(child: Text(metinOku(x['departman'], '—'), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15))),
          if (acil) KRozet('ACİL', renk: t.kirmizi),
        ]),
        Text('${metinOku(x['isteyen_ad'], '—')} · #$id · ${gecenZaman(x['created_at'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 8),
        if (kd.isNotEmpty)
          for (final k in kd)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                Icon(Icons.inventory_2_outlined, size: 15, color: t.sub),
                const SizedBox(width: 6),
                Expanded(child: Text(metinOku(k['ad']), style: TextStyle(color: t.ink, fontSize: 13.5))),
                Text('${metinOku(k['miktar'])} ${metinOku(k['birim'])}', style: TextStyle(color: t.sub2, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            )
        else
          for (final k in dizi(x['kalemler'])) Text('• $k', style: TextStyle(color: t.ink, fontSize: 13)),
        if (metinOku(x['not']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Not: ${x['not']}', style: TextStyle(color: t.sub2, fontSize: 12.5))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: KButon('Onayla ve Satın Almaya Gönder', ikon: Icons.check_circle_outline, renk: t.yesil, onTap: () => _onay(x, yenile))),
          const SizedBox(width: 8),
          KButon('Reddet', ikon: Icons.close, renk: t.kirmizi, ikincil: true, onTap: () => _red(x, yenile)),
        ]),
      ]),
    );
  }

  Future<void> _onay(Map<String, dynamic> x, Future<void> Function() yenile) async {
    if (!await kOnay(context, 'Talep onaylansın mı?', aciklama: '${metinOku(x['departman'])} talebi satın almaya iletilecek.', evet: 'Onayla')) return;
    if (!mounted) return;
    final c = await saGonder(context, '/satinalma-talep/dept-onayla', {'id': x['id']}, basari: 'Onaylandı — satın almaya iletildi.');
    if (c?.ok == true) {
      _secili.remove(tamOku(x['id']));
      yenile();
    }
  }

  Future<void> _red(Map<String, dynamic> x, Future<void> Function() yenile) async {
    final s = await saMetinSor(context, 'Talep reddedilsin mi?',
        aciklama: '${metinOku(x['departman'])} · #${x['id']}',
        ipucu: 'Red sebebi (zorunlu) — talebi açan bu sebebi görecek',
        hazirlar: const ['Stokta yeterli var', 'Miktar fazla, düzeltip tekrar gönder', 'Bütçe uygun değil', 'Başka tedarikçiden alınacak'],
        enAz: 3,
        evet: 'Reddet ve Kapat',
        tehlikeli: true);
    if (s == null || !mounted) return;
    final c = await saGonder(context, '/satinalma-talep/dept-reddet', {'id': x['id'], 'sebep': s}, basari: 'Talep reddedildi.');
    if (c?.ok == true) {
      _secili.remove(tamOku(x['id']));
      yenile();
    }
  }

  Future<void> _topluOnay(Future<void> Function() yenile) async {
    if (!await kOnay(context, '${_secili.length} talep onaylansın mı?', aciklama: 'Seçilen talepler satın almaya iletilecek.', evet: 'Hepsini Onayla')) return;
    if (!mounted) return;
    setState(() => _toplu = true);
    var ok = 0, hata = 0;
    for (final id in _secili.toList()) {
      if (!mounted) return;
      final c = await saGonder(context, '/satinalma-talep/dept-onayla', {'id': id}, sessiz: true, hataSessiz: true);
      if (c?.ok == true) {
        ok++;
        _secili.remove(id);
      } else {
        hata++;
      }
    }
    if (!mounted) return;
    setState(() => _toplu = false);
    kToast(context, hata == 0 ? '$ok talep onaylandı.' : '$ok onaylandı, $hata talep onaylanamadı.', hata: hata > 0);
    yenile();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /satinalma-onay-seviye — satın almacı onay limitleri (sipariş başı + aylık), departman kuralları (limit / her zaman patron onayı),
/// kendi onayıyla geçilen son siparişler, çok-kademeli onay aç/kapa, onay zinciri (kademe ekle / sil). İşlemler sahip/müdür içindir (sunucu kontrol eder).
class OnaySeviyeScreen extends StatefulWidget {
  const OnaySeviyeScreen({super.key});
  @override
  State<OnaySeviyeScreen> createState() => _OnaySeviyeScreenState();
}

class _OnaySeviyeScreenState extends State<OnaySeviyeScreen> {
  Map<String, (TextEditingController, TextEditingController)>? _lim;
  Map<String, String>? _dep;
  bool _mesgul = false;

  String _bin(dynamic v) => sayiOku(v) > 0 ? sayiYaz(sayiOku(v).round()) : '';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(yol: '/satinalma-onay-seviye', baslik: 'Onay Limitleri & Kademeler', ikon: Icons.approval_outlined, govde: _govde);
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final sa = liste(v['satinalmacilar']);
    final dep = liste(v['departmanlar']);
    final son = liste(v['sonSiparisler']);
    final sev = liste(v['seviyeler']);
    final adMap = harita(v['adMap']);
    final acik = v['acik'] == true;
    _lim ??= {for (final s in sa) '${s['id']}': (TextEditingController(text: _bin(s['sa_siparis_limit'])), TextEditingController(text: _bin(s['sa_aylik_limit'])))};
    _dep ??= {for (final d in dep) '${d['id']}': metinOku(d['kural'], 'limit')};
    Future<void> yen() async {
      _lim = null;
      _dep = null;
      await yenile();
    }

    return KGovde(yenile: yen, maxGenislik: 1000, children: [
      SaBilgi(
          'Satın almacı onay limiti: satın almacı, kartına yazdığınız tutara kadar olan siparişleri patron onayı beklemeden kendisi onaylayıp geçer; her birinden bildirim alırsınız. Limiti boş bırakılan satın almacı her talebi patrona gönderir. "Her zaman patron onayı" seçilen departmanın talepleri tutar ne olursa olsun onaya gider. Aynı gün aynı tedarikçiye yapılan siparişler toplanır — sipariş bölünerek limit aşılamaz.',
          renk: t.yesil,
          ikon: Icons.account_balance_wallet_outlined),
      KBaslik('Satın Almacı Limitleri', ikon: Icons.account_balance_wallet_outlined, alt: 'boş = kendi onayı yok', renk: t.yesil),
      if (sa.isEmpty)
        const KBos(baslik: 'Satın almacı yok', aciklama: 'Rolü "Satın Almacı" olan aktif personel yok. Personel kartında rolü "Satın Almacı" yapınca burada listelenir.', ikon: Icons.person_off_outlined)
      else
        for (final s in sa)
          Builder(builder: (_) {
            final ay = sayiOku(s['sa_aylik_limit']);
            final oran = ay > 0 ? (sayiOku(s['kullanilan']) / ay).clamp(0.0, 1.0) : 0.0;
            final c = _lim!['${s['id']}']!;
            return KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(metinOku(s['ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(child: KAlan('Sipariş başı limit (₺)', c.$1, ipucu: 'ör. 15.000', klavye: const TextInputType.numberWithOptions(decimal: true))),
                  const SizedBox(width: 8),
                  Expanded(child: KAlan('Aylık limit (₺)', c.$2, ipucu: 'sınırsız', klavye: const TextInputType.numberWithOptions(decimal: true))),
                ]),
                Text('Bu ay kendi onayıyla: ${tl(s['kullanilan'], kisa: true)}${ay > 0 ? ' / ${tl(ay, kisa: true)}' : ''}', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
                if (ay > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(value: oran, minHeight: 6, backgroundColor: t.line, color: oran >= .9 ? t.kirmizi : (oran >= .7 ? t.amber : t.yesil)),
                  ),
              ]),
            );
          }),
      KBaslik('Departman Kuralları', ikon: Icons.rule, alt: 'talebi açan departmana göre'),
      if (dep.isEmpty)
        const KBos(baslik: 'Departman tanımlı değil', aciklama: 'Tüm talepler için satın almacı limiti geçerli. Departmanlar Personel & Departman ekranından tanımlanır.', ikon: Icons.apartment_outlined)
      else
        SaIzgara([
          for (final d in dep)
            KKart(
              renk: renkOku(d['renk']),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  KIkon(ikonAdi(metinOku(d['ikon']), Icons.apartment_outlined), renk: renkOku(d['renk'])),
                  const SizedBox(width: 10),
                  Expanded(child: Text(metinOku(d['ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
                ]),
                const SizedBox(height: 8),
                KCipler(secenekler: const [('limit', 'Limit geçerli'), ('onay', 'Her zaman patron onayı')], secili: _dep!['${d['id']}'] ?? 'limit', onSec: (k) => setState(() => _dep!['${d['id']}'] = k)),
              ]),
            ),
        ], minGenislik: 320),
      if (sa.isNotEmpty || dep.isNotEmpty) KButon('Limitleri Kaydet', ikon: Icons.save_outlined, renk: t.yesil, genis: true, yukleniyor: _mesgul, onTap: () => _limitKaydet(yen)),
      const SizedBox(height: 10),
      KBaslik('Kendi Onayıyla Geçilen Son Siparişler', ikon: Icons.verified_outlined),
      if (son.isEmpty)
        const KBos(baslik: 'Henüz yok', aciklama: 'Satın almacının kendi limitiyle geçtiği sipariş olduğunda burada listelenir.', ikon: Icons.verified_outlined)
      else
        KKart(
          child: KTablo(basliklar: const ['Tarih', 'Sipariş', 'Satın almacı', 'Tedarikçi', 'Talep', 'Tutar'], sagaYasla: const {5}, satirlar: [
            for (final s in son) [tarihYaz(s['tarih'], saat: false), metinOku(s['siparis_no']), metinOku(s['satinalmaci'], '—'), metinOku(s['tedarikci'], '—'), metinOku(s['notlar']), tl(s['genel_toplam'])],
          ]),
        ),
      const SizedBox(height: 10),
      const SaBilgi('Çok-kademeli onay: satın alma talebi onaylanmadan önce sırayla belirlediğiniz kişilerden geçsin (ör. Şef → Maliyet Kontrol → Ana Depo). Her kademeye bir onaylayan + tatildeyse vekil atayabilirsiniz. Küçük işletmede gerekmez.'),
      KKart(
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: acik,
          onChanged: (b) async {
            await saGonder(context, '/satinalma-onay-seviye/flag', {if (b) 'acik': '1'}, json: false);
            yen();
          },
          title: Text('Çok-Kademeli Onay', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
          subtitle: Text(acik ? 'Açık — talepler kademelerden geçer' : 'Kapalı — patron/satın almacı direkt onaylar', style: TextStyle(color: t.sub, fontSize: 12.5)),
        ),
      ),
      KBaslik('Onay Zinciri', ikon: Icons.account_tree_outlined, sag: TextButton.icon(onPressed: () => _kademeEkle(v, yen), icon: const Icon(Icons.add), label: const Text('Kademe Ekle'))),
      if (sev.isEmpty)
        const KBos(baslik: 'Henüz onay kademesi yok', aciklama: '"Kademe Ekle" ile ekleyin; sırayla eklediğiniz kişiler kademe olur.', ikon: Icons.account_tree_outlined)
      else ...[
        KSatir(solIkon: KIkon(Icons.assignment_outlined, renk: t.sub), baslik: 'Talep', cizgi: false),
        for (final s in sev)
          KKart(
            child: KSatir(
              cizgi: false,
              solIkon: CircleAvatar(radius: 16, backgroundColor: t.mor1, child: Text('${s['seviye']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              baslik: metinOku(adMap['${s['onaylayan_id']}'], '—'),
              alt: [
                if (s['vekil_id'] != null) 'vekil: ${metinOku(adMap['${s['vekil_id']}'], '—')}${metinOku(s['vekil_bitis']).isNotEmpty ? ' (${tarihYaz(s['vekil_bitis'], saat: false)} tarihine dek)' : ''}',
                if (tamOku(s['anlasma_atla']) == 1) 'anlaşmalı taleplerde atlanır',
              ].join(' · '),
              sag: IconButton(tooltip: 'Kademeyi sil', icon: Icon(Icons.close, color: t.kirmizi), onPressed: () async {
                if (!await kOnay(context, 'Bu kademe silinsin mi?', tehlikeli: true, evet: 'Sil')) return;
                if (!context.mounted) return;
                await saGonder(context, '/satinalma-onay-seviye/sil', {'id': s['id']}, json: false);
                yen();
              }),
            ),
          ),
        KSatir(solIkon: KIkon(Icons.check_circle_outline, renk: t.yesil), baslik: 'Onaylandı → Sipariş', cizgi: false),
      ],
    ]);
  }

  Future<void> _limitKaydet(Future<void> Function() yenile) async {
    setState(() => _mesgul = true);
    await saGonder(context, '/satinalma-limit/kaydet', {
      'limit': {for (final e in _lim!.entries) e.key: {'siparis': e.value.$1.text.trim(), 'aylik': e.value.$2.text.trim()}},
      'dep': _dep,
    }, json: false, basari: 'Onay limitleri kaydedildi.');
    if (!mounted) return;
    setState(() => _mesgul = false);
    yenile();
  }

  Future<void> _kademeEkle(Map<String, dynamic> v, Future<void> Function() yenile) async {
    int? onay, vekil;
    var bitis = '';
    var atla = false;
    final per = liste(v['personeller']);
    final ok = await kAltSayfa<bool>(context, baslik: 'Kademe Ekle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.watch<TemaProvider>();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KSecim<int>('Onaylayan *', deger: onay, secenekler: [for (final p in per) (tamOku(p['id']), '${p['ad']} (${p['rol']})')], onSec: (x) => ss(() => onay = x)),
            KSecim<int>('Vekil (tatildeyse — opsiyonel)', deger: vekil, secenekler: [(0, '— yok —'), for (final p in per) (tamOku(p['id']), metinOku(p['ad']))], onSec: (x) => ss(() => vekil = x == 0 ? null : x)),
            KSatir(baslik: 'Vekil geçerlilik bitişi (ops.)', alt: bitis.isEmpty ? 'Seçilmedi' : tarihYaz(bitis, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
              final s = await saTarihSec(c, ilk: bitis);
              if (s != null) ss(() => bitis = s);
            }),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: atla, onChanged: (b) => ss(() => atla = b == true), title: Text('Fiyat anlaşması olan taleplerde bu onayı atla', style: TextStyle(color: t.ink, fontSize: 13.5))),
            KButon('Kademe Ekle', ikon: Icons.add, genis: true, onTap: () {
              if (onay == null) return kToast(c, 'Onaylayan seçin.', hata: true);
              Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok != true || !mounted) return;
    await saGonder(context, '/satinalma-onay-seviye/ekle', {'onaylayan_id': onay, 'vekil_id': vekil ?? '', 'vekil_bitis': bitis, if (atla) 'anlasma_atla': '1'}, json: false);
    yenile();
  }
}

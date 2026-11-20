import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'efatura_gelen_screen.dart';
import 'ortak.dart';

const _fdDurum = {
  'acik': ('Açık', Color(0xFFF59E0B)),
  'itiraz': ('İtiraz edildi', Color(0xFF4F46E5)),
  'cozuldu': ('Çözüldü', Color(0xFF10B981)),
  'yoksay': ('Yok sayıldı', Color(0xFF64748B)),
  'tumu': ('Tümü', Color(0xFF7C3AED)),
};
const _fdSeviye = {'kritik': Color(0xFFF43F5E), 'uyari': Color(0xFFF59E0B), 'bilgi': Color(0xFF4F46E5)};

/// Web /fatura-denetim — gelen faturaların otomatik denetim bulguları (sözleşme/sipariş fiyatı, fazla faturalama, hesap hatası, zam…),
/// filtre, toplu durum (itiraz / çözüldü / yok say / açık), tedarikçiye itiraz yazısı (/fatura-denetim/itiraz), yeniden denetle, Excel.
class FaturaDenetimScreen extends StatefulWidget {
  const FaturaDenetimScreen({super.key});
  @override
  State<FaturaDenetimScreen> createState() => _FaturaDenetimScreenState();
}

class _FaturaDenetimScreenState extends State<FaturaDenetimScreen> {
  final _ekran = GlobalKey<KopruEkranState>();
  final Set<int> _sec = {};
  bool _mesgul = false;

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _ekran,
      yol: '/fatura-denetim',
      baslik: 'Fatura Denetim',
      ikon: Icons.fact_check_outlined,
      govde: _govde,
      araclar: (ctx, v, yenile) => [
        IconButton(
          tooltip: 'Fatura Excel\'i',
          onPressed: () {
            final f = harita(v['f']);
            saDosyaIndir(context, '/efatura-gelen/excel', 'fatura-analizi.xlsx', q: {
              for (final k in ['ted', 'bas', 'bit'])
                if (metinOku(f[k]).isNotEmpty) k: metinOku(f[k]),
            });
          },
          icon: const Icon(Icons.table_view_outlined),
        ),
      ],
    );
  }

  void _sorgu(Map<String, dynamic> f, Map<String, String?> yeni) {
    final q = <String, String>{};
    for (final k in ['durum', 'tur', 'ted', 'bas', 'bit']) {
      final x = yeni.containsKey(k) ? yeni[k] : metinOku(f[k]);
      if (x != null && x.isNotEmpty) q[k] = x;
    }
    final bilgi = yeni.containsKey('bilgi') ? yeni['bilgi'] == '1' : f['bilgi'] == true;
    if (bilgi) q['bilgi'] = '1';
    _sec.clear();
    _ekran.currentState?.sorgu(q, birlestir: false);
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final ozet = harita(v['ozet']);
    final f = harita(v['f']);
    final turler = harita(v['turler']);
    final turSay = harita(v['turSay']);
    final l = liste(v['liste']);
    final tedler = liste(v['tedler']);
    final durum = metinOku(f['durum'], 'acik');
    final gruplar = <String, List<Map<String, dynamic>>>{};
    for (final d in l) {
      gruplar.putIfAbsent(metinOku(d['satici_vkn'], '—'), () => []).add(d);
    }
    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Geri istenecek (açık)', deger: tl(ozet['acik_tl']), alt: '${ozet['acik']} açık bulgu', renk: t.kirmizi, ikon: Icons.money_off),
        KKpi(etiket: 'İtiraz edildi, bekleniyor', deger: tl(ozet['itiraz_tl']), alt: '${ozet['itiraz']} bulgu', renk: t.mavi, ikon: Icons.mail_outline),
        KKpi(etiket: 'Geri alındı', deger: tl(ozet['cozuldu_tl']), alt: '"Çözüldü" işaretlenen alacaklar', renk: t.yesil, ikon: Icons.check_circle_outline),
        KKpi(etiket: 'Zamların maliyet etkisi', deger: tl(ozet['etki_tl']), alt: 'Zam + gizli zam (alacak değil)', renk: t.amber, ikon: Icons.trending_up),
      ]),
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KSecim<String>('Tedarikçi', deger: metinOku(f['ted']), secenekler: [('', 'Tümü'), for (final x in tedler) (metinOku(x['satici_vkn']), metinOku(x['ad'], metinOku(x['satici_vkn'])))],
              onSec: (x) => _sorgu(f, {'ted': x ?? ''})),
          Row(children: [
            Expanded(child: KSatir(baslik: 'Başlangıç', alt: metinOku(f['bas']).isEmpty ? 'Seçilmedi' : tarihYaz(f['bas'], saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
              final s = await saTarihSec(context, ilk: metinOku(f['bas']));
              if (s != null) _sorgu(f, {'bas': s});
            })),
            const SizedBox(width: 8),
            Expanded(child: KSatir(baslik: 'Bitiş', alt: metinOku(f['bit']).isEmpty ? 'Seçilmedi' : tarihYaz(f['bit'], saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
              final s = await saTarihSec(context, ilk: metinOku(f['bit']));
              if (s != null) _sorgu(f, {'bit': s});
            })),
          ]),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: f['bilgi'] == true,
            onChanged: (b) => _sorgu(f, {'bilgi': b == true ? '1' : '0'}),
            title: Text('Küçük zamlar ve KDV bilgileri de', style: TextStyle(color: t.ink, fontSize: 13.5)),
          ),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (metinOku(f['ted']).isNotEmpty || metinOku(f['bas']).isNotEmpty || metinOku(f['bit']).isNotEmpty)
              KButon('Süzgeci temizle', ikon: Icons.filter_alt_off_outlined, ikincil: true, onTap: () => _sorgu(f, {'ted': '', 'bas': '', 'bit': ''})),
            KButon('Yeniden denetle', ikon: Icons.refresh, ikincil: true, yukleniyor: _mesgul, onTap: () async {
              setState(() => _mesgul = true);
              await saGonder(context, '/fatura-denetim/yenile', {}, json: false);
              if (!mounted) return;
              setState(() => _mesgul = false);
              yenile();
            }),
          ]),
        ]),
      ),
      KCipler(secenekler: [for (final e in _fdDurum.entries) (e.key, e.value.$1)], secili: durum, onSec: (k) => _sorgu(f, {'durum': k})),
      KCipler(secenekler: [
        ('', 'Tüm türler'),
        for (final e in turler.entries)
          if (tamOku(turSay[e.key]) > 0) (e.key, '${dizi(e.value).isNotEmpty ? dizi(e.value)[0] : e.key} (${tamOku(turSay[e.key])})'),
      ], secili: metinOku(f['tur']), onSec: (k) => _sorgu(f, {'tur': k})),
      if (l.isEmpty)
        KBos(
          baslik: tamOku(ozet['fatura']) == 0 ? 'Henüz fatura yok' : 'Bu filtrede bulgu yok',
          aciklama: tamOku(ozet['fatura']) == 0
              ? 'Faturalar Gelen e-Faturalar ekranından XML/ZIP yüklenince ya da entegratörden çekilince otomatik denetlenir.'
              : 'Sözleşme fiyatlarını (Fiyat Anlaşmaları) girip siparişleri sistemden verdikçe kontroller genişler; sonra "Yeniden denetle"ye basın.',
          ikon: Icons.fact_check_outlined,
        )
      else
        for (final e in gruplar.entries) _grup(e.key, e.value, durum, turler, t, yenile),
      if (_sec.isNotEmpty)
        KKart(
          renk: t.mor1,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('${_sec.length} bulgu seçili', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              KButon('İtiraz edildi', ikincil: true, onTap: () => _durum('itiraz', yenile)),
              KButon('Çözüldü (geri alındı)', ikincil: true, renk: t.yesil, onTap: () => _durum('cozuldu', yenile)),
              KButon('Yok say', ikincil: true, renk: t.sub, onTap: () => _durum('yoksay', yenile)),
              KButon('Açığa al', ikincil: true, renk: t.amber, onTap: () => _durum('acik', yenile)),
            ]),
          ]),
        ),
    ]);
  }

  Widget _grup(String vkn, List<Map<String, dynamic>> l, String durum, Map<String, dynamic> turler, TemaProvider t, Future<void> Function() yenile) {
    final gt = l.fold<double>(0, (a, d) => a + sayiOku(d['fark_tutar']));
    final ge = l.fold<double>(0, (a, d) => a + sayiOku(d['etki_tutar']));
    final faturaSay = l.map((d) => d['gelen_id']).toSet().length;
    final hepsi = l.every((d) => _sec.contains(tamOku(d['id'])));
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Checkbox(value: hepsi, onChanged: (b) => setState(() {
                for (final d in l) {
                  b == true ? _sec.add(tamOku(d['id'])) : _sec.remove(tamOku(d['id']));
                }
              })),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(l.first['satici_ad'], 'Tedarikçi'), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15)),
              Text('VKN $vkn · ${l.length} bulgu · $faturaSay fatura', style: TextStyle(color: t.sub, fontSize: 12.5)),
            ]),
          ),
        ]),
        Wrap(spacing: 12, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          if (gt > 0) Text('Geri istenecek: ${tl(gt)}', style: TextStyle(color: t.kirmizi, fontWeight: FontWeight.w700)),
          if (ge > 0) Text('Maliyet etkisi: ${tl(ge)}', style: TextStyle(color: t.amber, fontWeight: FontWeight.w700)),
          if (durum == 'acik' && vkn != '—') KButon('İtiraz yazısı', ikon: Icons.mail_outline, onTap: () => _itiraz(vkn, yenile)),
        ]),
        const Divider(),
        for (final d in l)
          InkWell(
            onTap: () => setState(() => _sec.contains(tamOku(d['id'])) ? _sec.remove(tamOku(d['id'])) : _sec.add(tamOku(d['id']))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Checkbox(value: _sec.contains(tamOku(d['id'])), onChanged: (b) => setState(() => b == true ? _sec.add(tamOku(d['id'])) : _sec.remove(tamOku(d['id'])))),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      KRozet(dizi(turler[d['tur']]).isNotEmpty ? '${dizi(turler[d['tur']])[0]}' : metinOku(d['tur']), renk: _fdSeviye[d['seviye']] ?? t.sub),
                      Text(metinOku(d['baslik']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13.5)),
                    ]),
                    const SizedBox(height: 3),
                    Text(metinOku(d['aciklama']), style: TextStyle(color: t.sub2, fontSize: 12.5)),
                    if (metinOku(d['not']).isNotEmpty) Text('Not: ${d['not']}', style: TextStyle(color: t.sub, fontSize: 12, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      InkWell(
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EfaturaDetayScreen(id: tamOku(d['gelen_id'])))),
                        child: Text('${metinOku(d['fatura_no'], '#${d['gelen_id']}')} · ${tarihYaz(d['tarih'], saat: false)}', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ),
                      if (sayiOku(d['fark_tutar']) > 0) Text('Geri: ${tl(d['fark_tutar'])}', style: TextStyle(color: t.kirmizi, fontWeight: FontWeight.w700, fontSize: 12.5)),
                      if (sayiOku(d['etki_tutar']) != 0) Text('Etki: ${tl(d['etki_tutar'])}', style: TextStyle(color: t.amber, fontSize: 12.5)),
                      KRozet(_fdDurum[d['durum']]?.$1 ?? metinOku(d['durum']), renk: _fdDurum[d['durum']]?.$2 ?? t.sub),
                    ]),
                  ]),
                ),
              ]),
            ),
          ),
      ]),
    );
  }

  Future<void> _durum(String d, Future<void> Function() yenile) async {
    final not = await saMetinSor(context, '${_sec.length} bulgu: ${_fdDurum[d]!.$1}', ipucu: 'Not (isteğe bağlı)', satir: 2, evet: 'Uygula');
    if (not == null || !mounted) return;
    final c = await saGonder(context, '/fatura-denetim/durum', {'durum': d, 'ids': _sec.toList(), 'not': not}, sessiz: true);
    if (c?.ok == true && mounted) {
      kToast(context, '${c!.j['n'] ?? _sec.length} bulgu güncellendi.');
      _sec.clear();
      yenile();
    }
  }

  Future<void> _itiraz(String vkn, Future<void> Function() yenile) async {
    final c = await saAl(context, '/fatura-denetim/itiraz', q: {'ted': vkn});
    if (c == null || !mounted) return;
    if (!c.ok) return kToast(context, saHata(c), hata: true);
    final j = c.j;
    final metin = TextEditingController(text: metinOku(j['metin']));
    final ids = dizi(j['ids']);
    await kAltSayfa(context, baslik: 'Tedarikçiye itiraz yazısı', icerik: (cx) {
      final t = cx.watch<TemaProvider>();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Toplam fark: ${tl(j['tutar'])}', style: TextStyle(color: t.kirmizi, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        KAlan('Metin', metin, satir: 12),
        Text('Metni düzenleyebilirsiniz. Gönderdikten sonra "İtiraz edildi olarak işaretle"ye basın; alacak geri gelince bulguyu "Çözüldü" yapın.', style: TextStyle(color: t.sub, fontSize: 12)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          KButon('Kopyala', ikon: Icons.content_copy, ikincil: true, onTap: () => saKopyala(cx, metin.text, 'Metin kopyalandı.')),
          KButon('WhatsApp', ikon: Icons.chat_outlined, ikincil: true, renk: const Color(0xFF25D366), onTap: () => launchUrl(Uri.parse('https://wa.me/${metinOku(j['telefon'])}?text=${Uri.encodeComponent(metin.text)}'), mode: LaunchMode.externalApplication)),
          KButon('E-posta', ikon: Icons.alternate_email, ikincil: true, onTap: () => launchUrl(Uri.parse('mailto:${metinOku(j['email'])}?subject=${Uri.encodeComponent('Fatura fiyat farkı talebi')}&body=${Uri.encodeComponent(metin.text)}'))),
        ]),
        const SizedBox(height: 10),
        KButon('İtiraz edildi olarak işaretle', genis: true, onTap: () async {
          final r = await saGonder(cx, '/fatura-denetim/durum', {'durum': 'itiraz', 'ids': ids}, sessiz: true);
          if (r?.ok == true && cx.mounted) {
            kToast(cx, '${ids.length} bulgu itiraz edildi olarak işaretlendi.');
            Navigator.pop(cx);
          }
        }),
      ]);
    });
    yenile();
  }
}

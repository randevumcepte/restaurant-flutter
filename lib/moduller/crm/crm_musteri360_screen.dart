import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'crm_ortak.dart';

/// Web /musteri-360 (+ ?seg=vip|aktif|risk|kayip|uyuyan|yeni, ?q=arama, ?id=detay).
/// Liste: en çok harcayan 100 müşteri, sağlık durumu (son ziyaret sıklığı), arama + segment çipleri.
/// Detay: KPI'lar, favori ürünler, son siparişler, not, hızlı aksiyon (CRM AI / Ara / Sadakat).
class CrmMusteri360Screen extends StatefulWidget {
  final String url;
  const CrmMusteri360Screen({super.key, this.url = '/musteri-360'});

  @override
  State<CrmMusteri360Screen> createState() => _CrmMusteri360ScreenState();
}

class _CrmMusteri360ScreenState extends State<CrmMusteri360Screen> {
  final _k = GlobalKey<KopruEkranState>();
  late String _seg;
  String _q = '';
  Timer? _zaman;

  static const _segler = [
    ('', 'Tümü'), ('vip', 'VIP'), ('aktif', 'Aktif'), ('risk', 'Riskli'), ('kayip', 'Kayıp'), ('uyuyan', 'Uyuyan'), ('yeni', 'Yeni'),
  ];

  @override
  void initState() {
    super.initState();
    _seg = Uri.parse(widget.url).queryParameters['seg'] ?? '';
  }

  @override
  void dispose() {
    _zaman?.cancel();
    super.dispose();
  }

  void _ara(String v) {
    _zaman?.cancel();
    _zaman = Timer(const Duration(milliseconds: 450), () {
      _q = v.trim();
      _k.currentState?.sorgu({'q': _q, 'seg': _seg});
    });
  }

  String get _baslik => _seg == 'vip' ? 'VIP Müşteriler' : _seg == 'kayip' ? 'Kayıp Müşteriler' : 'Müşteri 360';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/musteri-360',
      q: {if (_seg.isNotEmpty) 'seg': _seg},
      baslik: _baslik,
      ikon: Icons.support_agent_outlined,
      araclar: (ctx, v, y) => [
        IconButton(tooltip: 'CRM AI', onPressed: () => crmSayfaAc(ctx, '/crm-sohbet', 'CRM AI'), icon: const Icon(Icons.smart_toy_outlined)),
      ],
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final o = harita(v['ozet']);
    final l = liste(v['liste']);
    final genis = genisMi(context);
    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Toplam müşteri', deger: sayiYaz(o['toplam']), alt: 'Bu ay yeni: ${sayiYaz(o['yeni'])}', ikon: Icons.groups_outlined, renk: t.mor1),
        KKpi(etiket: 'VIP (5.000 ₺+)', deger: sayiYaz(o['vip']), alt: 'Cironun ${yuzde(o['vipPay'])}', ikon: Icons.workspace_premium_outlined, renk: kCrmDurumRenk['vip'],
            onTap: () => _segSec('vip')),
        KKpi(etiket: 'Riskli / Kayıp', deger: '${sayiYaz(o['risk'])} / ${sayiYaz(o['kayip'])}', alt: '30-60 g / 60-120 g gelmedi', ikon: Icons.person_off_outlined, renk: kCrmDurumRenk['kayip'],
            onTap: () => _segSec('kayip')),
        KKpi(etiket: 'Ortalama fiş', deger: tl(o['ortFis'], kisa: true),
            alt: o['memOrt'] == null ? 'Memnuniyet verisi yok' : 'Memnuniyet ${sayiYaz(o['memOrt'])}/5 · ${sayiYaz(o['memAcik'])} açık şikâyet',
            ikon: Icons.receipt_long_outlined, renk: t.yesil),
      ]),
      const SizedBox(height: 12),
      KAra(ipucu: 'İsim veya telefonla müşteri ara…', onDegis: _ara),
      const SizedBox(height: 10),
      KCipler(secenekler: _segler, secili: _seg, onSec: _segSec),
      const SizedBox(height: 12),
      if (l.isEmpty)
        KBos(
          baslik: _q.isNotEmpty || _seg.isNotEmpty ? 'Bu filtreyle müşteri bulunamadı' : 'Henüz müşteri kaydı yok',
          aciklama: _q.isNotEmpty || _seg.isNotEmpty
              ? 'Aramayı ya da segmenti değiştirin. Segment, müşterinin son ziyaretinden hesaplanır (adisyona müşteri bağlanmışsa).'
              : 'Müşteriler POS\'ta adisyona müşteri bağlanınca, paket siparişte ya da QR menü / sadakat uygulamasıyla kayıt olunca burada listelenir.',
          ikon: Icons.person_search_outlined,
        )
      else if (genis)
        KKart(
          padding: EdgeInsets.zero,
          child: Column(children: [for (final m in l) _satir(context, t, m)]),
        )
      else
        ...[for (final m in l) KKart(padding: EdgeInsets.zero, child: _satir(context, t, m, cizgi: false))],
      const SizedBox(height: 4),
      const CrmNot('Müşteri sağlık durumu son ziyaret sıklığından hesaplanır: Aktif 30 gün içinde, Riskli 30-60 gün, Kayıp 60-120 gün önce geldi. '
          'VIP = 5.000 ₺+ harcayan. Kayıp/riskli müşterileri CRM AI ile geri kazanabilirsin (toplu WhatsApp yok — yalnız uygulama bildirimi).'),
    ]);
  }

  void _segSec(String s) {
    setState(() => _seg = s);
    _k.currentState?.sorgu({'seg': s, 'q': _q});
  }

  Widget _satir(BuildContext context, TemaProvider t, Map<String, dynamic> m, {bool cizgi = true}) {
    final d = metinOku(m['durum'], 'yeni');
    final r = kCrmDurumRenk[d] ?? t.sub;
    final sonGun = m['son_gun'];
    final ad = metinOku(m['ad'], 'İsimsiz müşteri');
    return KSatir(
      cizgi: cizgi,
      solIkon: CrmAvatar(ad, renk: r),
      baslik: ad,
      alt: '${metinOku(m['telefon'], '—')} · ${sayiYaz(m['siparis_sayisi'])} sipariş${sonGun == null ? '' : ' · son ${sayiYaz(sonGun)} g önce'}',
      sag: Row(mainAxisSize: MainAxisSize.min, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          Text(tl(m['toplam_harcama'], kisa: true), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold)),
          Text('toplam', style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
        const SizedBox(width: 8),
        KRozet(kCrmDurumAd[d] ?? d, renk: r, ikon: kCrmDurumIkon[d]),
      ]),
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => CrmMusteriDetayScreen(id: tamOku(m['id']), ad: ad))),
    );
  }
}

/// Web /musteri-360?id=X — tek müşteri 360 görünümü
class CrmMusteriDetayScreen extends StatelessWidget {
  final int id;
  final String ad;
  const CrmMusteriDetayScreen({super.key, required this.id, this.ad = 'Müşteri'});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/musteri-360',
      q: {'id': '$id'},
      baslik: ad,
      ikon: Icons.support_agent_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final m = harita(v['m']);
        final d = harita(v['detay']);
        if (m.isEmpty) {
          return const KBos(baslik: 'Müşteri bulunamadı', aciklama: 'Kayıt silinmiş ya da başka bir şubeye ait olabilir. Listeye dönüp tekrar seçin.', ikon: Icons.person_off_outlined);
        }
        final dur = metinOku(d['durum'], 'yeni');
        final r = kCrmDurumRenk[dur] ?? t.sub;
        final tel = metinOku(m['telefon']);
        final favori = dizi(d['favori']).map((e) => metinOku(e)).where((e) => e.isNotEmpty).toList();
        final sip = liste(d['siparisler']);
        final uyelik = metinOku(m['created_at']);
        return KGovde(yenile: yenile, children: [
          KKart(
            child: Row(children: [
              CrmAvatar(metinOku(m['ad'], 'M'), renk: r, boyut: 62),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(metinOku(m['ad'], 'Müşteri'), style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    [tel.isEmpty ? '—' : tel, if (metinOku(m['eposta']).isNotEmpty) metinOku(m['eposta']), if (uyelik.length >= 7) 'üyelik ${uyelik.substring(5, 7)}.${uyelik.substring(0, 4)}'].join(' · '),
                    style: TextStyle(color: t.sub, fontSize: 13),
                  ),
                ]),
              ),
              KRozet(kCrmDurumAd[dur] ?? dur, renk: r, ikon: kCrmDurumIkon[dur]),
            ]),
          ),
          KKpiIzgara([
            KKpi(etiket: 'Toplam harcama', deger: tl(m['toplam_harcama'], kisa: true), ikon: Icons.payments_outlined, renk: t.yesil),
            KKpi(etiket: 'Sipariş sayısı', deger: sayiYaz(m['siparis_sayisi']), ikon: Icons.receipt_long_outlined, renk: t.mavi),
            KKpi(etiket: 'Ortalama fiş', deger: tl(d['ort_fis'], kisa: true), ikon: Icons.analytics_outlined, renk: t.mor1),
            KKpi(etiket: 'Son ziyaret', deger: d['son_gun'] == null ? '—' : '${sayiYaz(d['son_gun'])} gün önce', ikon: Icons.history, renk: r),
          ]),
          const SizedBox(height: 12),
          if (favori.isNotEmpty)
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const KBaslik('Favori ürünler', ikon: Icons.restaurant_outlined),
                Wrap(spacing: 7, runSpacing: 7, children: [for (final f in favori) KRozet(f, renk: t.mor1)]),
              ]),
            ),
          KKart(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const KBaslik('Son siparişler', ikon: Icons.history),
              if (sip.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text('Kapanmış sipariş kaydı yok. Adisyona bu müşteri bağlanıp hesap kapatılınca burada görünür.', style: TextStyle(color: t.sub, fontSize: 13)),
                )
              else
                for (final s in sip)
                  KSatir(
                    solIkon: Icon(Icons.receipt_long_outlined, color: t.sub2, size: 20),
                    baslik: tarihYaz(s['kapanis']),
                    alt: tamOku(s['kisi_sayisi']) > 0 ? '${sayiYaz(s['kisi_sayisi'])} kişi' : null,
                    sag: Text(tl(s['toplam'], kisa: true), style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 14.5)),
                  ),
            ]),
          ),
          if (metinOku(m['notlar']).isNotEmpty)
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const KBaslik('Not', ikon: Icons.sticky_note_2_outlined),
                Text(metinOku(m['notlar']), style: TextStyle(color: t.ink, fontSize: 14, height: 1.5)),
              ]),
            ),
          KKart(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const KBaslik('Hızlı aksiyon', ikon: Icons.bolt),
              Wrap(spacing: 10, runSpacing: 10, children: [
                KButon('CRM AI ile işlem yap', ikon: Icons.smart_toy_outlined, onTap: () => crmSayfaAc(ctx, '/crm-sohbet', 'CRM AI')),
                if (tel.isNotEmpty) KButon('Ara', ikon: Icons.call_outlined, ikincil: true, onTap: () => launchUrl(Uri.parse('tel:$tel'))),
                KButon('Sadakat / Puan', ikon: Icons.loyalty_outlined, ikincil: true, onTap: () => crmSayfaAc(ctx, '/sadakat', 'Sadakat / Puan')),
              ]),
            ]),
          ),
        ]);
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'crm_ortak.dart';
import 'pz_kampanya_push_screen.dart';

/// Web /segmentler — müşteri segmentleri (uygulama/push açık müşteriler üzerinden) + segmente kampanya gönder.
/// Not: web'deki "Kampanya gönder" bağlantısı /kampanya?segment=X'e gidiyor ama bu anahtarlar push kampanyasının
/// segmentleri; uygulamada doğru ekran olan Push Kampanya (segment seçili) açılır.
class PzSegmentlerScreen extends StatelessWidget {
  const PzSegmentlerScreen({super.key});

  static const _ikon = {
    'groups': Icons.groups_outlined, 'person_add': Icons.person_add_outlined, 'favorite': Icons.favorite_outline,
    'bedtime': Icons.bedtime_outlined, 'stars': Icons.stars_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/segmentler',
      baslik: 'Müşteri Segmentleri',
      ikon: Icons.pie_chart_outline,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final segs = liste(v['segmentler']);
        final genis = genisMi(ctx);
        Widget kart(Map<String, dynamic> s) {
          final r = renkOku(metinOku(s['renk'], '#7C3AED'));
          return KKart(
            renk: r,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                KIkon(_ikon[metinOku(s['ikon'])] ?? ikonAdi(metinOku(s['ikon']), Icons.groups_outlined), renk: r),
                const SizedBox(width: 10),
                Expanded(child: Text(metinOku(s['ad']), style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold))),
                Text(sayiYaz(s['sayi']), style: TextStyle(color: r, fontSize: 24, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 6),
              Text(metinOku(s['aciklama']), style: TextStyle(color: t.sub, fontSize: 13)),
              const SizedBox(height: 10),
              KButon('Kampanya gönder', ikon: Icons.campaign_outlined, ikincil: true, onTap: () {
                final url = '/kampanya-push?segment=${metinOku(s['key'])}';
                Navigator.of(ctx).push(MaterialPageRoute(builder: (_) => PzKampanyaPushScreen(url: url)));
              }),
            ]),
          );
        }

        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Uygulama/push açık müşteri (kampanya hedefi)', deger: sayiYaz(v['pushliMusteri']), ikon: Icons.notifications_active_outlined, renk: t.mor1),
          ]),
          const SizedBox(height: 12),
          if (segs.isEmpty)
            const KBos(baslik: 'Segment bulunamadı', aciklama: 'Sunucu segment listesi döndürmedi. Sayfayı yenileyin.')
          else if (genis)
            Wrap(spacing: 12, children: [for (final s in segs) SizedBox(width: 360, child: kart(s))])
          else
            for (final s in segs) kart(s),
          const CrmNot('Segmentler müşteri kayıt + sipariş verisinden otomatik hesaplanır. Kampanya yalnızca uygulamayı indiren (push açık) müşterilere gider — toplu WhatsApp yapılmaz (ban riski). '
              'Sayılar 0 ise: müşteriler henüz müşteri uygulamasını indirip bildirime izin vermemiş demektir.'),
        ]);
      },
    );
  }
}

/// Web /kampanya-rapor — son 50 kampanya gönderimi (push + CRM AI), toplam gönderim ve ulaşılan müşteri.
class PzKampanyaRaporScreen extends StatelessWidget {
  const PzKampanyaRaporScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/kampanya-rapor',
      baslik: 'Kampanya Raporu',
      ikon: Icons.bar_chart,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final l = liste(v['liste']);
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Toplam gönderim', deger: sayiYaz(v['topGonderim']), ikon: Icons.campaign_outlined, renk: t.mor1),
            KKpi(etiket: 'Ulaşılan müşteri (toplam)', deger: sayiYaz(v['topKisi']), ikon: Icons.groups_outlined, renk: t.yesil),
          ]),
          const SizedBox(height: 12),
          if (l.isEmpty)
            KBos(
              baslik: 'Henüz kampanya gönderilmedi',
              aciklama: 'Push kampanyası (Kampanya Push) ya da CRM AI ile gönderilen geri kazanım bildirimleri burada listelenir.',
              ikon: Icons.campaign_outlined,
              aksiyon: KButon('Push kampanya oluştur', ikon: Icons.add, onTap: () => crmSayfaAc(ctx, '/kampanya-push', 'Push Kampanya')),
            )
          else if (genisMi(ctx))
            KKart(
              padding: const EdgeInsets.all(6),
              child: KTablo(
                basliklar: const ['Kampanya', 'Tarih', 'Kanal', 'Segment', 'Ulaşan', 'Hedef'],
                sagaYasla: const {4, 5},
                satirlar: [
                  for (final k in l)
                    [metinOku(k['baslik'], '—'), tarihYaz(k['created_at']), metinOku(k['kanal'], '—'), metinOku(k['segment'], '—'), sayiYaz(k['gonderilen']), sayiYaz(k['hedef'])]
                ],
              ),
            )
          else
            for (final k in l)
              KKart(
                child: KSatir(
                  cizgi: false,
                  solIkon: KIkon(Icons.campaign_outlined, renk: t.mor1),
                  baslik: metinOku(k['baslik'], '—'),
                  alt: '${tarihYaz(k['created_at'])} · ${metinOku(k['kanal'])} · ${metinOku(k['segment'])}',
                  sag: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${sayiYaz(k['gonderilen'])}/${sayiYaz(k['hedef'])}', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold, fontSize: 15)),
                    Text('ulaşan/hedef', style: TextStyle(color: t.sub, fontSize: 11)),
                  ]),
                ),
              ),
        ]);
      },
    );
  }
}

/// Web /icerik-takvimi — haftalık sosyal içerik planı (örnek plan ya da ?uret=1 ile AI üretir); caption + hashtag kopyala.
class PzIcerikTakvimiScreen extends StatefulWidget {
  const PzIcerikTakvimiScreen({super.key});

  @override
  State<PzIcerikTakvimiScreen> createState() => _PzIcerikTakvimiScreenState();
}

class _PzIcerikTakvimiScreenState extends State<PzIcerikTakvimiScreen> {
  final _k = GlobalKey<KopruEkranState>();
  bool _uretiyor = false;

  Future<void> _uret() async {
    setState(() => _uretiyor = true);
    await _k.currentState?.sorgu({'uret': '1'});
    if (mounted) setState(() => _uretiyor = false);
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/icerik-takvimi',
      baslik: 'Sosyal İçerik Takvimi',
      ikon: Icons.calendar_month_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final plan = liste(v['plan']);
        final ai = metinOku(v['kaynak']) == 'ai';
        Widget kart(int i, Map<String, dynamic> p) => KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(Icons.event, color: t.mor1, size: 20),
                  const SizedBox(width: 6),
                  Text(metinOku(p['gun'], '—'), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                const SizedBox(height: 8),
                _satir(t, Icons.photo_camera_outlined, 'Çekim', metinOku(p['fikir'])),
                _satir(t, Icons.edit_note, 'Caption', metinOku(p['caption'])),
                _satir(t, Icons.tag, '', metinOku(p['hashtag']), renk: t.mavi),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => crmKopyala(ctx, '${metinOku(p['caption'])}\n\n${metinOku(p['hashtag'])}', mesaj: 'Caption + hashtag kopyalandı.'),
                    icon: const Icon(Icons.content_copy, size: 18),
                    label: const Text('Caption + hashtag kopyala'),
                  ),
                ),
              ]),
            );
        return KGovde(yenile: yenile, children: [
          KBaslik('Haftalık içerik planı',
              ikon: Icons.calendar_month_outlined,
              sag: KRozet(ai ? '✨ AI üretti' : 'Örnek plan', renk: ai ? t.mor1 : t.sub)),
          KButon('AI ile üret', ikon: Icons.auto_awesome, genis: true, yukleniyor: _uretiyor, onTap: _uret),
          const SizedBox(height: 12),
          if (plan.isEmpty)
            const KBos(baslik: 'Plan boş', aciklama: 'AI geçerli bir plan döndürmedi. "AI ile üret"e tekrar basın ya da sayfayı yenileyin (örnek plan gelir).')
          else if (genisMi(ctx))
            Wrap(spacing: 12, children: [for (var i = 0; i < plan.length; i++) SizedBox(width: 540, child: kart(i, plan[i]))])
          else
            for (var i = 0; i < plan.length; i++) kart(i, plan[i]),
          const CrmNot('AI içeriği hazırlar; siz fotoğrafı çekip metni kopyala-yapıştır yaparak Instagram/TikTok\'ta paylaşırsınız. Otomatik paylaşım için platform API bağlantısı gerekir.'),
        ]);
      },
    );
  }

  Widget _satir(TemaProvider t, IconData ikon, String etiket, String metin, {Color? renk}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ikon, size: 18, color: t.sub),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText.rich(TextSpan(children: [
              if (etiket.isNotEmpty) TextSpan(text: '$etiket: ', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
              TextSpan(text: metin, style: TextStyle(color: renk ?? t.sub2)),
            ]), style: const TextStyle(fontSize: 14, height: 1.4)),
          ),
        ]),
      );
}

/// Web /etkinlik-takvim — önümüzdeki 14 günün rezervasyon ve grup/etkinlikleri (8+ kişi = GRUP), güne göre gruplu.
class RzEtkinlikTakvimScreen extends StatefulWidget {
  const RzEtkinlikTakvimScreen({super.key});

  @override
  State<RzEtkinlikTakvimScreen> createState() => _RzEtkinlikTakvimScreenState();
}

class _RzEtkinlikTakvimScreenState extends State<RzEtkinlikTakvimScreen> {
  bool _yalnizGrup = false;

  static const _durRenk = {'bekliyor': Color(0xFFF59E0B), 'onaylandi': Color(0xFF2FBE94), 'geldi': Color(0xFF5B8DEF), 'gelmedi': Color(0xFFF43F5E)};
  static const _durAd = {'bekliyor': 'Bekliyor', 'onaylandi': 'Onaylı', 'geldi': 'Geldi', 'gelmedi': 'Gelmedi'};
  static const _gunAd = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
  static const _ayAd = ['Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

  String _gunBaslik(String s) {
    final d = DateTime.tryParse(s);
    if (d == null) return s;
    return '${d.day} ${_ayAd[d.month - 1]}, ${_gunAd[d.weekday - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/etkinlik-takvim',
      baslik: 'Etkinlik / Grup Takvimi',
      ikon: Icons.event_note_outlined,
      araclar: (ctx, v, y) => [
        IconButton(tooltip: 'Rezervasyonlar', onPressed: () => crmSayfaAc(ctx, '/rezervasyon', 'Rezervasyon'), icon: const Icon(Icons.event_available_outlined)),
      ],
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final g = harita(v['gunler']);
        final tarihler = g.keys.toList()..sort();
        var toplamRez = 0, toplamKisi = 0, grup = 0;
        for (final k in tarihler) {
          for (final r in liste(g[k])) {
            toplamRez++;
            toplamKisi += tamOku(r['kisi']);
            if (tamOku(r['kisi']) >= 8) grup++;
          }
        }
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: '14 günde rezervasyon', deger: sayiYaz(toplamRez), ikon: Icons.event_available_outlined, renk: t.mor1),
            KKpi(etiket: 'Toplam kişi', deger: sayiYaz(toplamKisi), ikon: Icons.groups_outlined, renk: t.mavi),
            KKpi(etiket: 'Grup / etkinlik (8+)', deger: sayiYaz(grup), ikon: Icons.celebration_outlined, renk: const Color(0xFFA855F7),
                onTap: () => setState(() => _yalnizGrup = !_yalnizGrup)),
          ]),
          const SizedBox(height: 12),
          KCipler(secenekler: const [('tumu', 'Tümü'), ('grup', 'Yalnız gruplar (8+)')], secili: _yalnizGrup ? 'grup' : 'tumu', onSec: (x) => setState(() => _yalnizGrup = x == 'grup')),
          const SizedBox(height: 12),
          if (tarihler.isEmpty)
            KBos(
              baslik: 'Önümüzdeki 14 günde rezervasyon yok',
              aciklama: 'İptal edilmemiş rezervasyonlar burada güne göre listelenir. Rezervasyon ekranından yeni rezervasyon ekleyebilirsiniz.',
              ikon: Icons.event_available_outlined,
              aksiyon: KButon('Rezervasyon ekle', ikon: Icons.add, onTap: () => crmSayfaAc(ctx, '/rezervasyon', 'Rezervasyon')),
            )
          else
            for (final k in tarihler)
              Builder(builder: (_) {
                final tum = liste(g[k]);
                final rez = _yalnizGrup ? tum.where((r) => tamOku(r['kisi']) >= 8).toList() : tum;
                if (rez.isEmpty) return const SizedBox.shrink();
                final kisi = tum.fold<int>(0, (a, r) => a + tamOku(r['kisi']));
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  KBaslik(_gunBaslik(k), ikon: Icons.event, alt: '${tum.length} rezervasyon · $kisi kişi'),
                  KKart(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (var i = 0; i < rez.length; i++)
                        Builder(builder: (_) {
                          final r = rez[i];
                          final d = metinOku(r['durum']);
                          final grupMu = tamOku(r['kisi']) >= 8;
                          final saat = metinOku(r['saat'], '—');
                          return KSatir(
                            cizgi: i > 0,
                            solIkon: SizedBox(width: 50, child: Text(saat.length >= 5 ? saat.substring(0, 5) : saat, style: TextStyle(color: t.mor1, fontWeight: FontWeight.bold, fontSize: 15))),
                            baslik: '${metinOku(r['ad'], 'Misafir')}${grupMu ? '  · GRUP' : ''}',
                            alt: [metinOku(r['telefon']), metinOku(r['not'])].where((e) => e.isNotEmpty).join(' · '),
                            sag: Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.group_outlined, size: 17, color: grupMu ? const Color(0xFFA855F7) : t.sub),
                              const SizedBox(width: 3),
                              Text(sayiYaz(r['kisi']), style: TextStyle(color: grupMu ? const Color(0xFFA855F7) : t.sub2, fontWeight: FontWeight.w700)),
                              const SizedBox(width: 8),
                              KRozet(_durAd[d] ?? d, renk: _durRenk[d] ?? t.sub),
                            ]),
                          );
                        }),
                    ]),
                  ),
                ]);
              }),
        ]);
      },
    );
  }
}

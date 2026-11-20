import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/ekran_kayit.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// /ik-ozet — İK Özet. Web'de bu adres İK Sabah Brifingi'ne (/departman-brief?dep=ik) yönlenir;
/// uygulama da aynı veriyi gösterir: KPI'lar, bugünün öncelikleri, AI yorumu, hızlı erişim, detaylı analiz,
/// dün yapılanlar + "Senin için yapabilirim" WhatsApp aksiyonları (web /ik-aksiyon).
class IkOzetScreen extends StatelessWidget {
  const IkOzetScreen({super.key});

  static const _tint = {
    't-rose': Color(0xFFF56A8B),
    't-green': Color(0xFF2FBE94),
    't-amber': Color(0xFFF6A623),
    't-blue': Color(0xFF5B8DEF),
    't-red': Color(0xFFF5576C),
    't-mor': Color(0xFF7C3AED),
  };
  static const _durRenk = {'risk': Color(0xFFF43F5E), 'dikkat': Color(0xFFF59E0B), 'iyi': Color(0xFF10B981), 'notr': Color(0xFF64748B)};
  static const _durAd = {'risk': 'RİSK', 'dikkat': 'DİKKAT', 'iyi': 'İYİ', 'notr': 'NÖTR'};

  static String _duz(dynamic v) => metinOku(v)
      .replaceAll(RegExp(r'<small>'), ' ')
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .trim();

  static void _ac(BuildContext c, String url, String ad) {
    if (url.isEmpty) return;
    Navigator.of(c).push(MaterialPageRoute(builder: (_) => EkranKayit.uret(url, ad)));
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/departman-brief',
      q: const {'dep': 'ik'},
      baslik: 'İK Özet',
      ikon: Icons.groups_outlined,
      govde: (c, v, yenile) {
        final t = c.watch<TemaProvider>();
        final kpis = liste(v['kpis']);
        final isler = liste(v['isler']);
        final analiz = liste(v['analiz']);
        final dun = liste(v['dunYapilanlar']);
        final hizli = liste(v['hizli']);
        final aiLink = harita(v['aiLink']);
        final rozet = liste(v['rozetler']);
        final genis = genisMi(c);

        final islerKart = KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KBaslik('Bugün önceliklerin', ikon: Icons.track_changes, sag: isler.isEmpty ? null : KRozet('${isler.length}', renk: t.mor1)),
            if (isler.isEmpty)
              const KBos(ikon: Icons.task_alt, baslik: 'Bekleyen iş yok', aciklama: 'Bugün İK tarafında yapılacak iş görünmüyor — her şey yolunda.')
            else
              for (final i in isler) _isSatir(c, i),
          ]),
        );
        final aiKart = KKart(
          renk: t.mor1,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KBaslik('${metinOku(v['deptAd'], 'İK')} AI ne diyor?', ikon: Icons.smart_toy_outlined),
            Text(_duz(v['aiOzet']).isEmpty ? 'Bugün için özel bir yorum yok.' : _duz(v['aiOzet']), style: TextStyle(color: t.ink, fontSize: 14, height: 1.45)),
            if (metinOku(aiLink['url']).isNotEmpty) ...[
              const SizedBox(height: 12),
              KButon(metinOku(aiLink['lbl'], 'AI ile konuş'), ikon: Icons.forum_outlined, genis: true, onTap: () => _ac(c, metinOku(aiLink['url']), metinOku(aiLink['lbl'], 'İK AI'))),
            ],
            if (hizli.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Hızlı erişim', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final h in hizli)
                  ActionChip(
                    avatar: Icon(ikonAdi(metinOku(h['ikon']), Icons.open_in_new), size: 18, color: t.mor1),
                    label: Text(metinOku(h['lbl']), style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                    backgroundColor: t.card2,
                    side: BorderSide(color: t.line),
                    onPressed: () => _ac(c, metinOku(h['url']), metinOku(h['lbl'])),
                  ),
              ]),
            ],
          ]),
        );

        return KGovde(yenile: yenile, children: [
          if (rozet.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                for (final r in rozet) KRozet(metinOku(r['metin']), renk: renkOku(r['renk'], t.mor1), ikon: ikonAdi(metinOku(r['ikon']), Icons.info_outline)),
              ]),
            ),
          if (kpis.isNotEmpty)
            KKpiIzgara([
              for (final k in kpis)
                KKpi(
                  etiket: metinOku(k['label']),
                  deger: _duz(k['deger']),
                  alt: metinOku(k['alt']).isEmpty ? null : metinOku(k['alt']),
                  ikon: ikonAdi(metinOku(k['ikon']), Icons.insights),
                  renk: _tint[metinOku(k['tint'])] ?? t.mor1,
                  onTap: metinOku(k['link']).isEmpty ? null : () => _ac(c, metinOku(k['link']), metinOku(k['label'])),
                ),
            ]),
          if (genis)
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 3, child: islerKart),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: aiKart),
            ])
          else ...[islerKart, aiKart],
          _AksiyonKart(),
          if (analiz.isNotEmpty) ...[
            const KBaslik('Detaylı AI analizi', ikon: Icons.analytics_outlined),
            LayoutBuilder(builder: (ctx, cs) {
              final n = cs.maxWidth >= 1000 ? 3 : (cs.maxWidth >= 620 ? 2 : 1);
              final g = (cs.maxWidth - 12 * (n - 1)) / n;
              return Wrap(spacing: 12, children: [
                for (final a in analiz)
                  SizedBox(
                    width: g,
                    child: KKart(
                      renk: _durRenk[metinOku(a['durum'])] ?? _durRenk['notr'],
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          KIkon(ikonAdi(metinOku(a['ikon']), Icons.insights), renk: renkOku(a['renk'], t.mor1), boyut: 34),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(metinOku(a['baslik']), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                              if (metinOku(a['alt']).isNotEmpty) Text(metinOku(a['alt']), style: TextStyle(color: t.sub, fontSize: 12)),
                            ]),
                          ),
                          KRozet(_durAd[metinOku(a['durum'])] ?? 'NÖTR', renk: _durRenk[metinOku(a['durum'])] ?? _durRenk['notr']!),
                        ]),
                        const SizedBox(height: 8),
                        Text(metinOku(a['yorum']), style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4)),
                      ]),
                    ),
                  ),
              ]);
            }),
          ],
          const KBaslik('Dün yapılanlar', ikon: Icons.done_all),
          KKart(
            child: dun.isEmpty
                ? Text('Dün İK tarafında kayıtlı hareket yok.', style: TextStyle(color: t.sub, fontSize: 13))
                : Column(children: [
                    for (final y in dun)
                      KSatir(
                        baslik: _duz(y['mtn']),
                        solIkon: KIkon(Icons.check, renk: t.yesil, boyut: 30),
                        sag: metinOku(y['link']).isEmpty ? null : Icon(Icons.chevron_right, color: t.sub),
                        onTap: metinOku(y['link']).isEmpty ? null : () => _ac(c, metinOku(y['link']), 'Ayrıntı'),
                      ),
                  ]),
          ),
        ]);
      },
    );
  }

  Widget _isSatir(BuildContext c, Map<String, dynamic> i) {
    final t = c.watch<TemaProvider>();
    final r = renkOku(i['renk'], t.mor1);
    final ak = harita(i['aksiyon']);
    final url = metinOku(ak['url']);
    return KSatir(
      solIkon: KIkon(ikonAdi(metinOku(i['ikon']), Icons.task_alt), renk: r),
      baslik: metinOku(i['baslik']),
      alt: [if (metinOku(i['grup']).isNotEmpty) metinOku(i['grup']), if (metinOku(i['aciklama']).isNotEmpty) metinOku(i['aciklama'])].join(' · '),
      sag: url.isEmpty
          ? null
          : TextButton(onPressed: () => _ac(c, url, metinOku(ak['lbl'], 'Aç')), child: Text(metinOku(ak['lbl'], 'Aç'), style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700))),
      onTap: url.isEmpty ? null : () => _ac(c, url, metinOku(ak['lbl'], 'Aç')),
    );
  }
}

/// "Senin için yapabilirim" — web /ik-aksiyon: WhatsApp şablon mesajını ilgili personele toplu gönderir.
class _AksiyonKart extends StatelessWidget {
  static const _aks = [
    ('dogum-kutla', 'Doğum günü kutla', 'Önümüzdeki 7 gün doğum günü olanlara kutlama mesajı', Icons.cake_outlined),
    ('yildonumu-kutla', 'İş yıldönümü kutla', 'Bu ay işe giriş yıldönümü olanlara teşekkür mesajı', Icons.celebration_outlined),
    ('eksik-bilgi-iste', 'Eksik özlük bilgisini iste', 'IBAN / TC / doğum / işe başlama eksik olanlara', Icons.forward_to_inbox_outlined),
    ('belge-hatirlat', 'Belge yenileme hatırlat', '30 gün içinde süresi dolan belgelerin sahiplerine', Icons.event_busy_outlined),
    ('gelmeyene-sor', 'Bugün gelmeyene sor', 'Vardiyası olup giriş yapmayanlara "iyi misiniz?" mesajı', Icons.person_off_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const KBaslik('Senin için yapabilirim', ikon: Icons.bolt, alt: 'WhatsApp ile tek dokunuşta (işletme WhatsApp hattı bağlı olmalı)'),
        for (final (k, ad, alt, ik) in _aks)
          KSatir(
            solIkon: KIkon(ik, renk: t.yesil),
            baslik: ad,
            alt: alt,
            sag: Icon(Icons.send_outlined, color: t.yesil, size: 20),
            onTap: () async {
              if (!await kOnay(context, '$ad?', aciklama: '$alt. Mesaj işletmenin WhatsApp hattından gönderilir.', evet: 'Gönder')) return;
              if (!context.mounted) return;
              await kopruGonder(context, '/ik-aksiyon', {'key': k}, basariMesaji: 'Gönderildi.');
            },
          ),
      ]),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'crm_ortak.dart';

/// Web /kampanya — AI Kampanya Stüdyosu (WhatsApp): hedef kitle seç (winback/dogum/vip/son30/tumu) → AI mesaj yaz (/kampanya/ai-metin)
/// → düzenle → gönder (/kampanya/gonder, {ad} kişiselleştirme, 1 mesaj = 1 kontör). Son 15 kampanya listesi.
/// AI yazma ve gönderme web'de yalnız sahip/müdüre açık.
class PzKampanyaScreen extends StatefulWidget {
  const PzKampanyaScreen({super.key});

  @override
  State<PzKampanyaScreen> createState() => _PzKampanyaScreenState();
}

class _PzKampanyaScreenState extends State<PzKampanyaScreen> {
  static const _segRenk = {'winback': Color(0xFFF59E0B), 'dogum': Color(0xFFEC4899), 'vip': Color(0xFFD4A72C), 'son30': Color(0xFF10B981), 'tumu': Color(0xFF4F46E5)};
  static const _segIkon = {'winback': Icons.person_off_outlined, 'dogum': Icons.cake_outlined, 'vip': Icons.workspace_premium_outlined, 'son30': Icons.bolt, 'tumu': Icons.groups_outlined};
  String _seg = '';
  final _teklif = TextEditingController();
  final _mesaj = TextEditingController();
  bool _yaziyor = false, _gonderiyor = false, _mesajVar = false;
  String? _sonuc;

  @override
  void dispose() {
    _teklif.dispose();
    _mesaj.dispose();
    super.dispose();
  }

  Future<void> _aiYaz() async {
    if (_seg.isEmpty) return kToast(context, 'Önce hedef kitle seçin.', hata: true);
    setState(() => _yaziyor = true);
    final c = await kopruGonderCevap(context, '/kampanya/ai-metin', {'segment': _seg, 'teklif': _teklif.text.trim()}, json: true);
    if (!mounted) return;
    setState(() => _yaziyor = false);
    if (c != null && c.ok) {
      setState(() {
        _mesaj.text = metinOku(c.j['metin']);
        _mesajVar = true;
      });
    }
  }

  Future<void> _gonder(Map<String, dynamic> v, Future<void> Function() yenile) async {
    final mesaj = _mesaj.text.trim();
    if (_seg.isEmpty) return kToast(context, 'Önce hedef kitle seçin.', hata: true);
    if (mesaj.isEmpty) return kToast(context, 'Mesaj boş.', hata: true);
    final say = tamOku(harita(v['sayilar'])[_seg]);
    final ad = metinOku(dizi(harita(v['segmentler'])[_seg]).firstOrNull, _seg);
    final ok = await kOnay(context, '$ad kitlesine gönderilsin mi?',
        evet: 'Gönder', aciklama: '$say müşteriye WhatsApp ile gidecek (en fazla 500). Her mesaj 1 kontör. Mevcut kontör: ${sayiYaz(v['kontor'])}.');
    if (!ok || !mounted) return;
    setState(() => _gonderiyor = true);
    final c = await kopruGonderCevap(context, '/kampanya/gonder', {'segment': _seg, 'mesaj': mesaj}, json: true);
    if (!mounted) return;
    setState(() => _gonderiyor = false);
    if (c != null && c.ok) {
      setState(() => _sonuc = '✅ ${sayiYaz(c.j['gonderilen'])} müşteriye gönderildi'
          '${tamOku(c.j['atlanan']) > 0 ? ' · ${sayiYaz(c.j['atlanan'])} atlandı (telefon yok / gönderilemedi)' : ''} · hedef ${sayiYaz(c.j['hedef'])}.');
      kToast(context, 'Kampanya gönderildi.');
      yenile();
    }
  }

  @override
  Widget build(BuildContext context) {
    final patron = crmPatronMu(context);
    return KopruEkran(
      yol: '/kampanya',
      baslik: 'Kampanya Stüdyosu',
      ikon: Icons.campaign_outlined,
      araclar: (ctx, v, y) => [
        IconButton(tooltip: 'Kampanya raporu', onPressed: () => crmSayfaAc(ctx, '/kampanya-rapor', 'Kampanya Raporu'), icon: const Icon(Icons.bar_chart)),
      ],
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final segs = harita(v['segmentler']);
        final say = harita(v['sayilar']);
        final gecmis = liste(v['gecmis']);
        final genis = genisMi(ctx);
        Widget segKart(String k) {
          final s = dizi(segs[k]);
          final r = _segRenk[k] ?? t.mor1;
          final sec = _seg == k;
          return KKart(
            renk: r,
            onTap: () => setState(() => _seg = k),
            child: Row(children: [
              KIkon(_segIkon[k] ?? Icons.groups_outlined, renk: r),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(metinOku(s.isNotEmpty ? s[0] : k), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text(metinOku(s.length > 1 ? s[1] : ''), style: TextStyle(color: t.sub, fontSize: 12.5)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(sayiYaz(say[k]), style: TextStyle(color: r, fontSize: 20, fontWeight: FontWeight.w800)),
                Text('müşteri', style: TextStyle(color: t.sub, fontSize: 11)),
              ]),
              const SizedBox(width: 6),
              Icon(sec ? Icons.radio_button_checked : Icons.radio_button_off, color: sec ? t.mor1 : t.sub),
            ]),
          );
        }

        final keys = segs.keys.toList();
        return KGovde(yenile: yenile, children: [
          CrmNot('Hedef kitleyi seç → AI kişiselleştirilmiş WhatsApp mesajı yazsın → onayla → tek dokunuşla gönder. Mesajda {ad} otomatik müşteri adıyla değişir. '
              'Kontör: ${sayiYaz(v['kontor'])}', ikon: Icons.auto_awesome_outlined),
          const KBaslik('1. Hedef kitle seç', ikon: Icons.groups_outlined),
          if (keys.isEmpty)
            const KBos(baslik: 'Segment bulunamadı', aciklama: 'Sunucudan hedef kitle listesi gelmedi. Sayfayı yenileyin.')
          else if (genis)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 4.2,
              crossAxisSpacing: 12,
              children: [for (final k in keys) segKart(k)],
            )
          else
            for (final k in keys) segKart(k),
          KKart(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const KBaslik('2. Mesajı oluştur', ikon: Icons.auto_awesome_outlined),
              if (!patron)
                const CrmNot('AI ile mesaj yazma ve WhatsApp kampanyası gönderme yalnız sahip / müdür hesabında açıktır.', ikon: Icons.lock_outline)
              else ...[
                KAlan('Kampanya / teklif detayı (opsiyonel — AI buna göre yazar)', _teklif, ipucu: 'örn. bu hafta sonu tüm tatlılarda %20 indirim'),
                Text(
                  _seg.isEmpty ? 'Önce hedef kitle seçin' : '${metinOku(dizi(segs[_seg]).firstOrNull, _seg)} — ${sayiYaz(say[_seg])} müşteriye gidecek',
                  style: TextStyle(color: _seg.isEmpty ? t.sub : t.mor1, fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                KButon('AI metin yaz', ikon: Icons.auto_awesome, genis: true, yukleniyor: _yaziyor, onTap: _aiYaz),
                if (_mesajVar) ...[
                  const SizedBox(height: 14),
                  KAlan('Mesaj (düzenleyebilirsin — {ad} müşteri adıyla değişir)', _mesaj, satir: 5),
                  Wrap(spacing: 10, runSpacing: 10, children: [
                    KButon('Kampanyayı gönder', ikon: Icons.send, renk: t.yesil, yukleniyor: _gonderiyor, onTap: () => _gonder(v, yenile)),
                    KButon('Yeniden yaz', ikon: Icons.refresh, ikincil: true, onTap: _yaziyor ? null : _aiYaz),
                  ]),
                  const SizedBox(height: 8),
                  Text('Gönderim WhatsApp üzerinden; her mesaj 1 kontör.', style: TextStyle(color: t.sub, fontSize: 12.5)),
                ],
                if (_sonuc != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_sonuc!, style: TextStyle(color: t.yesil, fontWeight: FontWeight.w700))),
              ],
            ]),
          ),
          const KBaslik('Son kampanyalar', ikon: Icons.history),
          if (gecmis.isEmpty)
            const KBos(baslik: 'Henüz WhatsApp kampanyası gönderilmedi', aciklama: 'Yukarıdan hedef kitle seçip mesajı gönderdiğinizde burada listelenir.', ikon: Icons.history)
          else
            KKart(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < gecmis.length; i++)
                  KSatir(
                    cizgi: i > 0,
                    solIkon: KRozet(metinOku(dizi(segs[metinOku(gecmis[i]['segment'])]).firstOrNull, metinOku(gecmis[i]['segment'])),
                        renk: _segRenk[metinOku(gecmis[i]['segment'])] ?? t.mor1),
                    baslik: metinOku(gecmis[i]['mesaj']),
                    alt: tarihYaz(gecmis[i]['created_at']),
                    sag: Text('${sayiYaz(gecmis[i]['gonderilen'])}/${sayiYaz(gecmis[i]['hedef'])}', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
        ]);
      },
    );
  }
}

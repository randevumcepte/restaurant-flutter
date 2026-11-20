import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'crm_ortak.dart';

/// Web /kampanya-push — resimli uygulama bildirimi (push) kampanyası: başlık (60), mesaj (180), görsel URL, hedef segment
/// (tumu/yeni/sadik/uyuyan/yuksek_puan) → /kampanya-push/gonder. Canlı telefon önizlemesi + son 10 gönderim.
/// Yalnız müşteri uygulamasını indiren (push açık) müşterilere gider — toplu WhatsApp yok.
class PzKampanyaPushScreen extends StatefulWidget {
  final String url;
  const PzKampanyaPushScreen({super.key, this.url = '/kampanya-push'});

  @override
  State<PzKampanyaPushScreen> createState() => _PzKampanyaPushScreenState();
}

class _PzKampanyaPushScreenState extends State<PzKampanyaPushScreen> {
  final _baslik = TextEditingController();
  final _metin = TextEditingController();
  final _gorsel = TextEditingController();
  late String _seg;
  bool _gonderiyor = false;

  @override
  void initState() {
    super.initState();
    _seg = Uri.parse(widget.url).queryParameters['segment'] ?? 'tumu';
    for (final c in [_baslik, _metin, _gorsel]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _baslik.dispose();
    _metin.dispose();
    _gorsel.dispose();
    super.dispose();
  }

  Future<void> _gonder(List<Map<String, dynamic>> segs, Future<void> Function() yenile) async {
    if (_baslik.text.trim().isEmpty || _metin.text.trim().isEmpty) return kToast(context, 'Başlık ve mesaj gerekli.', hata: true);
    final s = segs.firstWhere((x) => metinOku(x['key']) == _seg, orElse: () => const {});
    final ok = await kOnay(context, 'Seçili segmentteki müşterilere bildirim gönderilsin mi?',
        evet: 'Gönder', aciklama: '${metinOku(s['ad'], _seg)} — ${sayiYaz(s['sayi'])} müşteri (yalnız uygulaması ve bildirimi açık olanlara ulaşır).');
    if (!ok || !mounted) return;
    setState(() => _gonderiyor = true);
    final gitti = await kopruGonder(context, '/kampanya-push/gonder', {
      'baslik': _baslik.text.trim(),
      'metin': _metin.text.trim(),
      'gorsel': _gorsel.text.trim(),
      'segment': _seg,
    });
    if (!mounted) return;
    setState(() => _gonderiyor = false);
    if (gitti) {
      _baslik.clear();
      _metin.clear();
      _gorsel.clear();
      yenile();
    }
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/kampanya-push',
      baslik: 'Push Kampanya',
      ikon: Icons.notifications_active_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final segs = liste(v['segmentler']);
        final gecmis = liste(v['gecmis']);
        final form = KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const KBaslik('Kampanya içeriği', ikon: Icons.edit_note),
            KAlan('Başlık (en fazla 60)', _baslik, ipucu: 'Hafta sonu %20 kahvaltı!', zorunlu: true),
            KAlan('Mesaj (en fazla 180)', _metin, ipucu: 'Cumartesi-Pazar serpme kahvaltıda %20 indirim. Seni bekliyoruz!', satir: 3, zorunlu: true),
            KAlan('Görsel linki (URL) — opsiyonel', _gorsel, ipucu: 'https://... (jpg/png)', klavye: TextInputType.url),
            KSecim<String>('Hedef segment', deger: _seg, secenekler: [
              for (final s in segs) (metinOku(s['key']), '${metinOku(s['ad'])} (${sayiYaz(s['sayi'])})'),
            ], onSec: (x) => setState(() => _seg = x ?? 'tumu')),
            if (_baslik.text.length > 60 || _metin.text.length > 180)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Başlık 60, mesaj 180 karakteri geçmemeli (şu an ${_baslik.text.length} / ${_metin.text.length}).', style: TextStyle(color: t.kirmizi, fontSize: 12.5)),
              ),
            KButon('Segmente gönder', ikon: Icons.send, genis: true, yukleniyor: _gonderiyor, onTap: () => _gonder(segs, yenile)),
          ]),
        );
        final gorsel = _gorsel.text.trim();
        final onizleme = KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const KBaslik('Önizleme (müşteri telefonu)', ikon: Icons.smartphone),
            Container(
              decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
              clipBehavior: Clip.antiAlias,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: 150,
                  child: gorsel.isEmpty
                      ? Icon(Icons.image_outlined, size: 40, color: t.sub)
                      : Image.network(gorsel, fit: BoxFit.cover, errorBuilder: (_, _, _) => Icon(Icons.broken_image_outlined, size: 40, color: t.sub)),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_baslik.text.trim().isEmpty ? 'Başlık buraya' : _baslik.text.trim(), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_metin.text.trim().isEmpty ? 'Mesaj metni buraya gelecek…' : _metin.text.trim(), style: TextStyle(color: t.sub2, fontSize: 13.5)),
                  ]),
                ),
              ]),
            ),
          ]),
        );
        return KGovde(yenile: yenile, children: [
          const CrmNot('Kampanya yalnızca müşteri uygulamasını indiren (bildirimi açık) müşterilere gider — toplu WhatsApp yapılmaz (ban riski).', ikon: Icons.notifications_active_outlined),
          if (genisMi(ctx))
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: form),
              const SizedBox(width: 16),
              Expanded(child: onizleme),
            ])
          else ...[
            form,
            onizleme,
          ],
          KBaslik('Son gönderimler', ikon: Icons.history, sag: TextButton(onPressed: () => crmSayfaAc(ctx, '/kampanya-rapor', 'Kampanya Raporu'), child: const Text('Rapor →'))),
          if (gecmis.isEmpty)
            const KBos(baslik: 'Henüz push kampanyası gönderilmedi', aciklama: 'Yukarıdaki formu doldurup "Segmente gönder" deyin. Gönderimler burada ve Kampanya Raporu\'nda görünür.', ikon: Icons.history)
          else
            KKart(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < gecmis.length; i++)
                  KSatir(
                    cizgi: i > 0,
                    solIkon: KIkon(Icons.campaign_outlined, renk: t.mor1),
                    baslik: metinOku(gecmis[i]['baslik'], '—'),
                    alt: '${tarihYaz(gecmis[i]['created_at'])} · ${metinOku(gecmis[i]['segment'])}',
                    sag: Text('${sayiYaz(gecmis[i]['gonderilen'])}/${sayiYaz(gecmis[i]['hedef'])} kişi', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
                  ),
              ]),
            ),
        ]);
      },
    );
  }
}

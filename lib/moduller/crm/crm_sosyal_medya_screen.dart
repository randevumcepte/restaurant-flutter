import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'crm_ortak.dart';

/// Web /social-media — AI Sosyal Medya: konu yaz → AI Instagram/Facebook gönderi metni + hashtag üretir (/social-media/ai),
/// düzenle, kopyala, taslak kaydet (/social-media/kaydet), taslak sil (/social-media/kaydet sil=id).
/// AI üretme + kaydet + sil web'de yalnız sahip/müdüre açık; diğer rollerde bu düğmeler gizlenir.
class CrmSosyalMedyaScreen extends StatefulWidget {
  const CrmSosyalMedyaScreen({super.key});

  @override
  State<CrmSosyalMedyaScreen> createState() => _CrmSosyalMedyaScreenState();
}

class _CrmSosyalMedyaScreenState extends State<CrmSosyalMedyaScreen> {
  final _konu = TextEditingController();
  final _metin = TextEditingController();
  String _platform = 'instagram';
  bool _uretiyor = false, _kaydediyor = false, _sonucVar = false;

  @override
  void dispose() {
    _konu.dispose();
    _metin.dispose();
    super.dispose();
  }

  Future<void> _aiYaz() async {
    setState(() => _uretiyor = true);
    final c = await kopruGonderCevap(context, '/social-media/ai', {'konu': _konu.text.trim(), 'platform': _platform}, json: true);
    if (!mounted) return;
    setState(() => _uretiyor = false);
    if (c != null && c.ok) {
      setState(() {
        _metin.text = metinOku(c.j['metin']);
        _sonucVar = true;
      });
    }
  }

  Future<void> _kaydet(Future<void> Function() yenile) async {
    if (_metin.text.trim().isEmpty) {
      kToast(context, 'Gönderi metni boş.', hata: true);
      return;
    }
    setState(() => _kaydediyor = true);
    final ok = await kopruGonder(context, '/social-media/kaydet', {'platform': _platform, 'konu': _konu.text.trim(), 'metin': _metin.text.trim()},
        basariMesaji: 'Taslak kaydedildi.');
    if (!mounted) return;
    setState(() => _kaydediyor = false);
    if (ok) yenile();
  }

  @override
  Widget build(BuildContext context) {
    final patron = crmPatronMu(context);
    return KopruEkran(
      yol: '/social-media',
      baslik: 'AI Sosyal Medya',
      ikon: Icons.share_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final taslak = liste(v['taslaklar']);
        final olustur = KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const KBaslik('Gönderi oluştur', ikon: Icons.auto_awesome_outlined),
            if (!patron)
              const CrmNot('AI ile gönderi üretme ve taslak kaydetme yalnız sahip / müdür hesabında açıktır. Taslakları görüp kopyalayabilirsiniz.', ikon: Icons.lock_outline)
            else ...[
              KCipler(secenekler: const [('instagram', 'Instagram'), ('facebook', 'Facebook')], secili: _platform, onSec: (x) => setState(() => _platform = x)),
              const SizedBox(height: 10),
              KAlan('Konu / ürün / kampanya', _konu, ipucu: 'örn. yeni künefe tatlımız, hafta sonu brunch'),
              KButon('AI Yaz', ikon: Icons.auto_awesome, genis: true, yukleniyor: _uretiyor, renk: const Color(0xFFDB2777), onTap: _aiYaz),
              if (_sonucVar) ...[
                const SizedBox(height: 14),
                KAlan('Gönderi metni (düzenleyebilirsin)', _metin, satir: 7),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  KButon('Kopyala', ikon: Icons.content_copy, renk: t.yesil, onTap: () => crmKopyala(ctx, _metin.text, mesaj: 'Metin kopyalandı — Instagram/Facebook\'a yapıştırın.')),
                  KButon('Taslak kaydet', ikon: Icons.bookmark_add_outlined, ikincil: true, yukleniyor: _kaydediyor, onTap: () => _kaydet(yenile)),
                  KButon('Yeniden', ikon: Icons.refresh, ikincil: true, onTap: _uretiyor ? null : _aiYaz),
                ]),
              ],
            ],
            const SizedBox(height: 10),
            Text('Otomatik paylaşım (Instagram/Facebook\'a doğrudan gönderme) Meta Graph API bağlantısı gerektirir. Şimdilik AI metni üretir, siz kopyalayıp paylaşırsınız.',
                style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4)),
          ]),
        );
        final taslaklar = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KBaslik('Taslaklar', ikon: Icons.bookmarks_outlined, alt: 'Son 30 taslak'),
          if (taslak.isEmpty)
            const KBos(
              baslik: 'Henüz taslak yok',
              aciklama: 'Soldaki/yukarıdaki "Gönderi oluştur" bölümünden AI ile metin üretip "Taslak kaydet" deyin.',
              ikon: Icons.bookmarks_outlined,
            )
          else
            for (final s in taslak)
              KKart(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    KRozet(metinOku(s['platform']) == 'facebook' ? 'Facebook' : 'Instagram',
                        renk: metinOku(s['platform']) == 'facebook' ? const Color(0xFF1877F2) : const Color(0xFFDB2777)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(metinOku(s['konu']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12.5))),
                    Text(tarihYaz(s['created_at'], saat: false), style: TextStyle(color: t.sub, fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                  SelectableText(metinOku(s['metin']), style: TextStyle(color: t.ink, fontSize: 14, height: 1.45)),
                  const SizedBox(height: 6),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    TextButton.icon(onPressed: () => crmKopyala(ctx, metinOku(s['metin'])), icon: const Icon(Icons.content_copy, size: 18), label: const Text('Kopyala')),
                    if (patron)
                      TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: t.kirmizi),
                        onPressed: () async {
                          if (!await kOnay(ctx, 'Taslak silinsin mi?', tehlikeli: true, evet: 'Sil')) return;
                          if (!ctx.mounted) return;
                          if (await kopruGonder(ctx, '/social-media/kaydet', {'sil': '${s['id']}'}, basariMesaji: 'Silindi.')) yenile();
                        },
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Sil'),
                      ),
                  ]),
                ]),
              ),
        ]);
        return KGovde(yenile: yenile, children: [
          const CrmNot('Konu/ürün/kampanya yaz → AI sana Instagram/Facebook gönderi metni + hashtag hazırlasın. Düzenle, kopyala, taslak olarak sakla.', ikon: Icons.auto_awesome_outlined),
          if (genisMi(ctx))
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: olustur),
              const SizedBox(width: 16),
              Expanded(child: taslaklar),
            ])
          else ...[
            olustur,
            taslaklar,
          ],
        ]);
      },
    );
  }
}

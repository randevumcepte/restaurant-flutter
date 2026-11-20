import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../config/app_config.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'crm_ortak.dart';

/// Web /itibar — Memnuniyet Nabzı: masadaki QR'dan gelen puanlar, dağılım, mutsuz (1-3) bildirimleri çözme (/itibar/coz),
/// sahip/müdür için ayarlar (Google yorum linki + uyarı WhatsApp no: /itibar-ayar) ve masa değerlendirme linkleri (QR).
class CrmItibarScreen extends StatefulWidget {
  const CrmItibarScreen({super.key});

  @override
  State<CrmItibarScreen> createState() => _CrmItibarScreenState();
}

class _CrmItibarScreenState extends State<CrmItibarScreen> {
  String _filtre = 'tumu';

  static const _emoji = {5: '😍', 4: '🙂', 3: '😐', 2: '🙁', 1: '😡'};

  Color _puanRenk(TemaProvider t, int p) => p >= 4 ? t.yesil : (p == 3 ? t.amber : t.kirmizi);

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/itibar',
      baslik: 'İtibar / Memnuniyet',
      ikon: Icons.reviews_outlined,
      araclar: (ctx, v, yenile) => [
        if (v['patronMu'] == true)
          IconButton(tooltip: 'Ayarlar', onPressed: () => _ayar(ctx, v, yenile), icon: const Icon(Icons.settings_outlined)),
      ],
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final hepsi = liste(v['liste']);
        final dag = harita(v['dagilim']);
        final maxDag = [for (var i = 1; i <= 5; i++) tamOku(dag['$i'])].fold<int>(1, (a, b) => b > a ? b : a);
        final l = hepsi.where((y) {
          final bekliyor = metinOku(y['durum']) == 'yeni' && tamOku(y['puan']) <= 3;
          if (_filtre == 'bekleyen') return bekliyor;
          if (_filtre == 'mutsuz') return tamOku(y['puan']) <= 3;
          if (_filtre == 'mutlu') return tamOku(y['puan']) >= 4;
          return true;
        }).toList();
        final patron = v['patronMu'] == true;
        final dagKart = KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const KBaslik('Puan dağılımı', ikon: Icons.bar_chart),
            for (var p = 5; p >= 1; p--)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  SizedBox(width: 48, child: Text('${_emoji[p]} $p', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(value: tamOku(dag['$p']) / maxDag, minHeight: 12, backgroundColor: t.card2, color: _puanRenk(t, p)),
                    ),
                  ),
                  SizedBox(width: 36, child: Text(sayiYaz(dag['$p']), textAlign: TextAlign.right, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700))),
                ]),
              ),
          ]),
        );
        return KGovde(yenile: yenile, children: [
          const CrmNot('Memnuniyet Nabzı: müşteri masada QR okutup deneyimini puanlar. Mutlu (4-5) → Google\'a davet edilir. '
              'Mutsuz (1-3) → Google\'a gitmez, anında size bildirim düşer → masaya gidip oracıkta çözersiniz.', ikon: Icons.favorite_outline),
          KKpiIzgara([
            KKpi(etiket: 'Ortalama puan', deger: sayiOku(v['ort']) > 0 ? sayiYaz(v['ort']) : '—', ikon: Icons.star_outline, renk: t.amber),
            KKpi(etiket: 'Bekleyen (çözülmedi)', deger: sayiYaz(v['bekleyen']), ikon: Icons.priority_high, renk: tamOku(v['bekleyen']) > 0 ? t.kirmizi : t.sub,
                onTap: () => setState(() => _filtre = 'bekleyen')),
            KKpi(etiket: 'Toplam değerlendirme', deger: sayiYaz(hepsi.length), ikon: Icons.reviews_outlined, renk: t.mor1),
          ]),
          const SizedBox(height: 12),
          if (hepsi.isNotEmpty) dagKart,
          if (patron)
            KKart(
              onTap: () => _masaLinkleri(ctx, liste(v['masalar'])),
              child: KSatir(
                cizgi: false,
                solIkon: KIkon(Icons.qr_code_2, renk: t.mor1),
                baslik: 'Masa değerlendirme linkleri (QR)',
                alt: '${liste(v['masalar']).length} masa · masa kartına / fişe koyun',
                sag: Icon(Icons.chevron_right, color: t.sub),
              ),
            ),
          KBaslik('Değerlendirmeler', ikon: Icons.list_alt),
          KCipler(
            secenekler: const [('tumu', 'Tümü'), ('bekleyen', 'Bekleyen'), ('mutsuz', 'Mutsuz (1-3)'), ('mutlu', 'Mutlu (4-5)')],
            secili: _filtre,
            onSec: (x) => setState(() => _filtre = x),
          ),
          const SizedBox(height: 10),
          if (l.isEmpty)
            KBos(
              baslik: hepsi.isEmpty ? 'Henüz değerlendirme yok' : 'Bu filtrede değerlendirme yok',
              aciklama: hepsi.isEmpty
                  ? 'Masa QR\'larına değerlendirme linkini ekleyince gelmeye başlar. Linkleri yukarıdaki "Masa değerlendirme linkleri" bölümünden alabilirsiniz (sahip/müdür).'
                  : 'Başka bir filtre seçin.',
              ikon: Icons.rate_review_outlined,
            )
          else
            for (final y in l) _yorum(ctx, t, y, yenile),
        ]);
      },
    );
  }

  Widget _yorum(BuildContext context, TemaProvider t, Map<String, dynamic> y, Future<void> Function() yenile) {
    final p = tamOku(y['puan']);
    final r = _puanRenk(t, p);
    final bekliyor = metinOku(y['durum']) == 'yeni' && p <= 3;
    final cozuldu = metinOku(y['durum']) == 'cozuldu' && p <= 3;
    return KKart(
      renk: bekliyor ? t.kirmizi : null,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: r.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
          child: Text(_emoji[p] ?? '•', style: const TextStyle(fontSize: 22)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(metinOku(y['masa_ad'], 'Masa'), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
              KRozet('$p/5', renk: r),
              if (bekliyor) KRozet('Bekliyor', renk: t.kirmizi),
              if (cozuldu) KRozet('Çözüldü', renk: t.yesil),
            ]),
            if (metinOku(y['sebepler']).isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 5), child: Text('⚠️ ${metinOku(y['sebepler'])}', style: TextStyle(color: t.kirmizi, fontSize: 13, fontWeight: FontWeight.w600))),
            if (metinOku(y['not']).isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 4), child: Text('"${metinOku(y['not'])}"', style: TextStyle(color: t.sub2, fontSize: 13.5, fontStyle: FontStyle.italic))),
            Padding(padding: const EdgeInsets.only(top: 4), child: Text(tarihYaz(y['created_at']), style: TextStyle(color: t.sub, fontSize: 12))),
          ]),
        ),
        if (bekliyor)
          KButon('Çözüldü', ikon: Icons.check, renk: t.yesil, onTap: () async {
            if (!await kOnay(context, 'Çözüldü olarak işaretlensin mi?', aciklama: 'Masaya gidip sorunu çözdüyseniz işaretleyin.')) return;
            if (!context.mounted) return;
            if (await kopruGonder(context, '/itibar/coz', {'id': '${y['id']}'}, basariMesaji: 'Çözüldü olarak işaretlendi.')) yenile();
          }),
      ]),
    );
  }

  Future<void> _ayar(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) async {
    final gC = TextEditingController(text: metinOku(v['googleLink']));
    final wC = TextEditingController(text: metinOku(v['waNo']));
    bool gonderiyor = false;
    await kAltSayfa(context, baslik: 'Memnuniyet ayarları', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Google yorum linki (mutlu müşteri buraya yönlenir)', gC, ipucu: 'https://g.page/r/.../review', klavye: TextInputType.url),
            KAlan('Uyarı WhatsApp no (mutsuz puan bildirimi)', wC, ipucu: '05xx…', klavye: TextInputType.phone),
            KButon('Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: gonderiyor, onTap: () async {
              ss(() => gonderiyor = true);
              final ok = await kopruGonder(c, '/itibar-ayar', {'google_link': gC.text.trim(), 'wa_no': wC.text.trim()}, basariMesaji: 'Ayarlar kaydedildi.');
              if (!c.mounted) return;
              ss(() => gonderiyor = false);
              if (ok) {
                Navigator.pop(c);
                yenile();
              }
            }),
          ]);
        }));
  }

  Future<void> _masaLinkleri(BuildContext context, List<Map<String, dynamic>> masalar) async {
    final t = context.read<TemaProvider>();
    await kAltSayfa(context, baslik: 'Masa değerlendirme linkleri', icerik: (c) {
      if (masalar.isEmpty) {
        return const KBos(
          baslik: 'QR\'lı masa yok',
          aciklama: 'Masalara QR token atanınca burada linkleri çıkar. Masa & QR yönetimi ekranından masa ekleyin.',
          ikon: Icons.qr_code_2,
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Bu linklerin QR\'ını masa kartına / fişe koyun. Mevcut masa QR afişlerinizle aynı token\'ı kullanır.', style: TextStyle(color: t.sub, fontSize: 13)),
        const SizedBox(height: 8),
        for (final m in masalar)
          Builder(builder: (_) {
            final url = '${AppConfig.baseUrl}/memnuniyet/${metinOku(m['qr_token'])}';
            final ad = metinOku(m['ad'], 'Masa ${m['id']}');
            return KSatir(
              solIkon: KIkon(Icons.table_restaurant_outlined, renk: t.mor1),
              baslik: ad,
              alt: url,
              sag: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(tooltip: 'Kopyala', onPressed: () => crmKopyala(c, url, mesaj: 'Link kopyalandı.'), icon: Icon(Icons.copy, color: t.sub2)),
                IconButton(
                  tooltip: 'QR göster',
                  onPressed: () => showDialog(
                    context: c,
                    builder: (d) => AlertDialog(
                      backgroundColor: t.card,
                      title: Text(ad, style: TextStyle(color: t.ink)),
                      content: SizedBox(
                        width: genisMi(context) ? 260 : 230,
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          Container(color: Colors.white, padding: const EdgeInsets.all(10), child: QrImageView(data: url, size: 210, backgroundColor: Colors.white)),
                          const SizedBox(height: 8),
                          Text('Memnuniyet değerlendirmesi', style: TextStyle(color: t.sub, fontSize: 12.5)),
                        ]),
                      ),
                      actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('Kapat'))],
                    ),
                  ),
                  icon: Icon(Icons.qr_code_2, color: t.mor1),
                ),
              ]),
            );
          }),
      ]);
    });
  }
}

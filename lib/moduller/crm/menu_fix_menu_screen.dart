import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'menu_ortak.dart';

/// Web /fix-menu — sabit fiyatlı set menü (İftar / Düğün / Tabldot): kurs grupları + ürünler.
/// İşlemler: set menü oluştur (/fix-menu/ekle), ürün ekle (/fix-menu/kalem-ekle), menü ya da kalem sil (/fix-menu/sil).
/// Sayfa web'de yalnız sahip/müdüre açık (diğerleri 403 görür).
class MenuFixMenuScreen extends StatelessWidget {
  const MenuFixMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/fix-menu',
      baslik: 'Fix Menü',
      ikon: Icons.dinner_dining_outlined,
      govde: (ctx, v, yenile) => _Govde(veri: v, yenile: yenile),
      fab: (ctx, v, yenile) => FloatingActionButton.extended(
        onPressed: () => _yeniMenu(ctx, yenile),
        icon: const Icon(Icons.add),
        label: const Text('Yeni set menü', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  static Future<void> _yeniMenu(BuildContext context, Future<void> Function() yenile) async {
    final adC = TextEditingController();
    final fiyatC = TextEditingController();
    final acC = TextEditingController();
    bool gonderiyor = false;
    await kAltSayfa(context, baslik: 'Yeni set menü', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Menü adı', adC, ipucu: 'örn. İftar Menüsü', zorunlu: true),
            KAlan('Fiyat (₺)', fiyatC, ipucu: 'örn. 450', klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
            KAlan('Açıklama (opsiyonel)', acC, ipucu: 'örn. 4 kap, çay dahil'),
            const SizedBox(height: 6),
            KButon('Set menü oluştur', ikon: Icons.add, genis: true, yukleniyor: gonderiyor, onTap: () async {
              if (adC.text.trim().isEmpty || fiyatC.text.trim().isEmpty) {
                kToast(c, 'Menü adı ve fiyat zorunlu.', hata: true);
                return;
              }
              ss(() => gonderiyor = true);
              final ok = await kopruGonder(c, '/fix-menu/ekle', {'ad': adC.text.trim(), 'fiyat': fiyatC.text.trim(), 'aciklama': acC.text.trim()},
                  basariMesaji: 'Set menü oluşturuldu. Şimdi ürün ekleyin.');
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
}

class _Govde extends StatelessWidget {
  final Map<String, dynamic> veri;
  final Future<void> Function() yenile;
  const _Govde({required this.veri, required this.yenile});

  Future<void> _kalemEkle(BuildContext context, Map<String, dynamic> m, List<Map<String, dynamic>> urunler) async {
    final grupC = TextEditingController();
    final adC = TextEditingController();
    int? urunId;
    bool zorunlu = true;
    bool gonderiyor = false;
    await kAltSayfa(context, baslik: '${metinOku(m['ad'], 'Set menü')} · ürün ekle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Grup / kurs', grupC, ipucu: 'örn. Ana Yemek, Tatlı'),
            KSecim<int?>('Ürün', deger: urunId, secenekler: [(null, '— Serbest yaz —'), for (final u in urunler) (tamOku(u['id']), metinOku(u['ad']))], onSec: (x) => ss(() => urunId = x)),
            if (urunId == null) KAlan('veya ürün adı', adC, ipucu: 'Menüde yoksa yazın'),
            MenuAnahtar(baslik: 'Zorunlu', alt: 'Kapalıysa müşterinin seçimine bağlı kalem', deger: zorunlu, onDegis: (x) => ss(() => zorunlu = x)),
            KButon('Ekle', ikon: Icons.add, genis: true, yukleniyor: gonderiyor, onTap: () async {
              if (urunId == null && adC.text.trim().isEmpty) {
                kToast(c, 'Bir ürün seçin ya da ürün adı yazın.', hata: true);
                return;
              }
              ss(() => gonderiyor = true);
              final ok = await kopruGonder(c, '/fix-menu/kalem-ekle', {
                'fix_menu_id': '${m['id']}',
                'grup': grupC.text.trim(),
                'urun_id': urunId?.toString() ?? '',
                'urun_ad': adC.text.trim(),
                if (zorunlu) 'zorunlu': '1',
              }, basariMesaji: 'Ürün eklendi.');
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

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final menuler = liste(veri['menuler']);
    final kalemler = harita(veri['kalemler']);
    final urunler = liste(veri['urunler']);

    Widget kart(Map<String, dynamic> m) {
      final kl = liste(kalemler['${m['id']}']);
      final gruplar = <String, List<Map<String, dynamic>>>{};
      for (final k in kl) {
        gruplar.putIfAbsent(metinOku(k['grup'], 'Diğer'), () => []).add(k);
      }
      final aktif = tamOku(m['aktif']) == 1;
      return KKart(
        renk: aktif ? t.mor1 : t.sub,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            KIkon(Icons.dinner_dining_outlined, renk: t.mor1),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(metinOku(m['ad'], 'Set menü'), style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold))),
                  if (!aktif) ...[const SizedBox(width: 6), KRozet('Pasif', renk: t.sub)],
                ]),
                if (metinOku(m['aciklama']).isNotEmpty)
                  Padding(padding: const EdgeInsets.only(top: 2), child: Text(metinOku(m['aciklama']), style: TextStyle(color: t.sub, fontSize: 12.5))),
              ]),
            ),
            Text(tl(m['fiyat'], kisa: true), style: TextStyle(color: t.yesil, fontSize: 18, fontWeight: FontWeight.w800)),
            IconButton(
              tooltip: 'Set menüyü sil',
              icon: Icon(Icons.delete_outline, color: t.kirmizi),
              onPressed: () async {
                if (!await kOnay(context, '${metinOku(m['ad'])} set menüsü silinsin mi?', aciklama: 'İçindeki tüm ürünler de silinir.', tehlikeli: true, evet: 'Sil')) return;
                if (!context.mounted) return;
                if (await kopruGonder(context, '/fix-menu/sil', {'menu_id': '${m['id']}'}, basariMesaji: 'Silindi.')) yenile();
              },
            ),
          ]),
          const SizedBox(height: 8),
          if (kl.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('Henüz ürün yok — aşağıdaki "Ürün ekle" ile kurs grubu ve ürün ekleyin.', style: TextStyle(color: t.sub, fontSize: 13)),
            ),
          for (final g in gruplar.entries) ...[
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(g.key.toUpperCase(), style: TextStyle(color: t.mor1, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: .5)),
            ),
            for (final it in g.value)
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  Expanded(child: Text(metinOku(it['urun_ad'], 'Ürün'), style: TextStyle(color: t.ink, fontSize: 14))),
                  KRozet(tamOku(it['zorunlu']) == 1 ? 'zorunlu' : 'seçime bağlı', renk: tamOku(it['zorunlu']) == 1 ? t.mavi : t.amber),
                  IconButton(
                    tooltip: 'Kalemi kaldır',
                    icon: Icon(Icons.close, size: 18, color: t.kirmizi),
                    onPressed: () async {
                      if (await kopruGonder(context, '/fix-menu/sil', {'kalem_id': '${it['id']}'}, basariMesaji: 'Silindi.')) yenile();
                    },
                  ),
                ]),
              ),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: KButon('Ürün ekle', ikon: Icons.add, ikincil: true, onTap: () => _kalemEkle(context, m, urunler)),
          ),
        ]),
      );
    }

    return KGovde(yenile: yenile, children: [
      KKart(
        renk: t.mor1,
        child: Text(
          'Fix / Set Menü: sabit fiyatlı menü oluşturun (ör. İftar Menüsü, Düğün Menüsü). İçine kurs grupları (Ara Sıcak, Ana Yemek, Tatlı…) '
          've ürünler ekleyin. İftar, etkinlik ve banket için idealdir.',
          style: TextStyle(color: t.sub2, fontSize: 13, height: 1.45),
        ),
      ),
      if (menuler.isEmpty)
        const KBos(
          baslik: 'Henüz set menü yok',
          aciklama: 'Sağ alttaki "Yeni set menü" ile ad ve fiyat girin; ardından kartın altındaki "Ürün ekle" ile kursları doldurun.',
          ikon: Icons.dinner_dining_outlined,
        )
      else if (genisMi(context))
        LayoutBuilder(builder: (c, k) {
          final w = (k.maxWidth - 12) / 2;
          return Wrap(spacing: 12, children: [for (final m in menuler) SizedBox(width: w, child: kart(m))]);
        })
      else
        ...menuler.map(kart),
    ]);
  }
}

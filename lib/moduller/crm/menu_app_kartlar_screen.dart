import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'menu_ortak.dart';

/// Web /app-yonetim — müşteri uygulaması / QR menüdeki Hero (üst büyük) ve Kampanya (yatay) kartları.
/// İşlemler: kart ekle/düzenle (görsel URL ya da dosya yükleme), gizle/göster, sil.
class MenuAppKartlarScreen extends StatelessWidget {
  const MenuAppKartlarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/app-yonetim',
      baslik: 'App Kartları / QR Menü',
      ikon: Icons.apps,
      govde: (ctx, v, yenile) => _Govde(veri: v, yenile: yenile),
      fab: (ctx, v, yenile) => FloatingActionButton.extended(
        onPressed: () => kartFormu(ctx, null, yenile),
        icon: const Icon(Icons.add),
        label: const Text('Yeni kart', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Kart önizlemesi (web'deki canlı önizlemeyle aynı: renk geçişi + görsel + karartma + metin)
class _KartOnizleme extends StatelessWidget {
  final String baslik, metin, renk, renk2, gorsel;
  final XFile? dosya;
  final double yukseklik;
  const _KartOnizleme({required this.baslik, required this.metin, required this.renk, required this.renk2, required this.gorsel, this.dosya, this.yukseklik = 150});

  @override
  Widget build(BuildContext context) {
    final r1 = hexRenk(renk) ?? const Color(0xFF14342B);
    final r2 = hexRenk(renk2) ?? (hexRenk(renk) ?? const Color(0xFF333333));
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: yukseklik,
        child: Stack(fit: StackFit.expand, children: [
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [r1, r2], begin: Alignment.topLeft, end: Alignment.bottomRight))),
          if (dosya != null)
            FutureBuilder(
              future: dosya!.readAsBytes(),
              builder: (c, s) => s.hasData ? Image.memory(s.data!, fit: BoxFit.cover) : const SizedBox.shrink(),
            )
          else if (gorsel.startsWith('http'))
            Image.network(gorsel, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          const DecoratedBox(
            decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0x00000000), Color(0xB3000000)])),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(baslik.isEmpty ? 'Başlık' : baslik, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(metin.isEmpty ? 'Açıklama' : metin, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xE6FFFFFF), fontSize: 12.5)),
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<void> kartFormu(BuildContext context, Map<String, dynamic>? k, Future<void> Function() yenile) async {
  final baslikC = TextEditingController(text: metinOku(k?['baslik']));
  final metinC = TextEditingController(text: metinOku(k?['metin']));
  final gorselC = TextEditingController(text: metinOku(k?['gorsel']));
  final detayC = TextEditingController(text: metinOku(k?['detay']));
  final butonC = TextEditingController(text: metinOku(k?['buton']));
  final puanC = TextEditingController(text: '${tamOku(k?['odul_puan'])}');
  final kuponC = TextEditingController(text: metinOku(k?['kupon_kodu']));
  final linkC = TextEditingController(text: metinOku(k?['link']));
  final renkC = TextEditingController(text: metinOku(k?['renk'], '#14342B'));
  final renk2C = TextEditingController(text: metinOku(k?['renk2']));
  final siraC = TextEditingController(text: '${k == null ? 1 : tamOku(k['sira'])}');
  String tip = metinOku(k?['tip']) == 'kampanya' ? 'kampanya' : 'hero';
  bool aktif = k == null || tamOku(k['aktif']) == 1;
  XFile? dosya;
  bool gonderiyor = false;

  await kAltSayfa(context, baslik: k == null ? 'Yeni kart ekle' : 'Kartı düzenle', icerik: (c) {
    final t = c.watch<TemaProvider>();
    return StatefulBuilder(builder: (c, ss) {
      void yenidenCiz(String _) => ss(() {});
      Future<void> kaydet() async {
        ss(() => gonderiyor = true);
        final alanlar = <String, String>{
          if (k != null) 'id': '${k['id']}',
          'tip': tip,
          'sira': siraC.text.trim().isEmpty ? '1' : siraC.text.trim(),
          'baslik': baslikC.text.trim(),
          'metin': metinC.text.trim(),
          'gorsel': gorselC.text.trim(),
          'detay': detayC.text.trim(),
          'buton': butonC.text.trim(),
          'odul_puan': puanC.text.trim().isEmpty ? '0' : puanC.text.trim(),
          'kupon_kodu': kuponC.text.trim(),
          'link': linkC.text.trim(),
          'renk': renkC.text.trim(),
          'renk2': renk2C.text.trim(),
          'aktif': aktif ? '1' : '',
        };
        bool ok;
        if (dosya != null) {
          final cv = await menuDosyaGonder(c, '/app-yonetim/kaydet', alanlar, 'gorsel_dosya', dosya!, basariMesaji: 'Kart kaydedildi.');
          ok = cv?.ok ?? false;
        } else {
          ok = await kopruGonder(c, '/app-yonetim/kaydet', alanlar, basariMesaji: 'Kart kaydedildi.');
        }
        if (!c.mounted) return;
        ss(() => gonderiyor = false);
        if (ok) {
          Navigator.pop(c);
          yenile();
        }
      }

      Widget renkAlani(String etiket, TextEditingController ctl, String ipucu) {
        final r = hexRenk(ctl.text);
        return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: _HexAlan(etiket: etiket, ctl: ctl, ipucu: ipucu, onDegis: yenidenCiz)),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: r ?? t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
              child: r == null ? Icon(Icons.block, size: 18, color: t.sub) : null,
            ),
          ),
        ]);
      }

      final iki = genisMi(c);
      Widget satir(Widget a, Widget b) => iki
          ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)])
          : Column(children: [a, b]);

      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('CANLI ÖNİZLEME', style: TextStyle(color: t.sub, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: .6)),
        const SizedBox(height: 6),
        _KartOnizleme(baslik: baslikC.text, metin: metinC.text, renk: renkC.text, renk2: renk2C.text, gorsel: gorselC.text, dosya: dosya),
        const SizedBox(height: 14),
        satir(
          KSecim<String>('Tür', deger: tip, secenekler: const [('hero', 'Hero (üst büyük)'), ('kampanya', 'Kampanya (yatay)')], onSec: (x) => ss(() => tip = x ?? 'hero')),
          KAlan('Sıra', siraC, klavye: TextInputType.number),
        ),
        _MetinAlan(etiket: 'Başlık', ctl: baslikC, ipucu: 'Örn: 2.ye %50 az öde! 🍂', onDegis: yenidenCiz),
        _MetinAlan(etiket: 'Kısa açıklama (kartta görünür)', ctl: metinC, ipucu: 'Örn: Grande ve Venti boylarda 2.ye %50 az öde!', satir: 2, onDegis: yenidenCiz),
        _MetinAlan(etiket: 'Görsel — bağlantı (URL)', ctl: gorselC, ipucu: 'https://...jpg', onDegis: yenidenCiz),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            KButon(dosya == null ? 'veya görsel yükle' : 'Görseli değiştir', ikon: Icons.add_photo_alternate_outlined, ikincil: true, onTap: () async {
              final x = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1800, imageQuality: 85);
              if (x != null) ss(() => dosya = x);
            }),
            if (dosya != null) ...[
              Text(dosya!.name, style: TextStyle(color: t.sub, fontSize: 12.5)),
              IconButton(tooltip: 'Seçimi kaldır', onPressed: () => ss(() => dosya = null), icon: Icon(Icons.close, color: t.sub)),
            ],
          ]),
        ),
        KAlan('Detay metni (uzun açıklama · her satır ayrı madde)', detayC, satir: 4, ipucu: 'Kampanya 15–18 Ekim tarihlerinde geçerlidir.\nStoklarla sınırlıdır.'),
        satir(KAlan('Buton yazısı', butonC, ipucu: 'Kullan'), KAlan('Kullanınca +Puan', puanC, klavye: TextInputType.number, ipucu: '0')),
        KAlan('Kupon kodu (ops. — "Kullan"da müşteriye gösterilir)', kuponC, ipucu: 'Örn: SONBAHAR50'),
        KAlan('Paylaşım / yönlendirme linki (ops.)', linkC, ipucu: 'https://... (paylaş butonu bu linki paylaşır)', klavye: TextInputType.url),
        satir(renkAlani('Yedek renk 1', renkC, '#14342B'), renkAlani('Yedek renk 2 (ops.)', renk2C, '#333333')),
        MenuAnahtar(baslik: 'Yayında', alt: 'Uygulamada / QR menüde görünsün', deger: aktif, onDegis: (x) => ss(() => aktif = x)),
        KButon('Kaydet', ikon: Icons.check, genis: true, yukleniyor: gonderiyor, onTap: kaydet),
      ]);
    });
  });
}

class _MetinAlan extends StatelessWidget {
  final String etiket;
  final TextEditingController ctl;
  final String? ipucu;
  final int satir;
  final ValueChanged<String> onDegis;
  const _MetinAlan({required this.etiket, required this.ctl, this.ipucu, this.satir = 1, required this.onDegis});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiket, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        TextField(
          controller: ctl,
          maxLines: satir,
          onChanged: onDegis,
          style: TextStyle(color: t.ink, fontSize: 15),
          decoration: InputDecoration(
            hintText: ipucu,
            hintStyle: TextStyle(color: t.sub),
            filled: true,
            fillColor: t.card2,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.mor1, width: 1.6)),
          ),
        ),
      ]),
    );
  }
}

class _HexAlan extends StatelessWidget {
  final String etiket;
  final TextEditingController ctl;
  final String ipucu;
  final ValueChanged<String> onDegis;
  const _HexAlan({required this.etiket, required this.ctl, required this.ipucu, required this.onDegis});

  @override
  Widget build(BuildContext context) => _MetinAlan(etiket: etiket, ctl: ctl, ipucu: ipucu, onDegis: onDegis);
}

class _Govde extends StatelessWidget {
  final Map<String, dynamic> veri;
  final Future<void> Function() yenile;
  const _Govde({required this.veri, required this.yenile});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final kartlar = liste(veri['kartlar']);
    final hero = kartlar.where((k) => metinOku(k['tip']) != 'kampanya').toList();
    final kamp = kartlar.where((k) => metinOku(k['tip']) == 'kampanya').toList();
    final yayinda = kartlar.where((k) => tamOku(k['aktif']) == 1).length;

    Widget kart(Map<String, dynamic> k) {
      final aktif = tamOku(k['aktif']) == 1;
      return KKart(
        padding: const EdgeInsets.all(10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Opacity(
            opacity: aktif ? 1 : .55,
            child: _KartOnizleme(
              baslik: metinOku(k['baslik']), metin: metinOku(k['metin']), renk: metinOku(k['renk'], '#14342B'),
              renk2: metinOku(k['renk2']), gorsel: metinOku(k['gorsel']), yukseklik: 130,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            metinOku(k['tip']) == 'kampanya' ? KRozet('Kampanya', renk: t.amber) : KRozet('Hero', renk: t.mavi),
            if (!aktif) KRozet('Pasif', renk: t.sub, ikon: Icons.visibility_off_outlined),
            KRozet('#${tamOku(k['sira'])}', renk: t.sub2),
            if (metinOku(k['kupon_kodu']).isNotEmpty) KRozet('Kupon: ${metinOku(k['kupon_kodu'])}', renk: t.mor1, ikon: Icons.confirmation_number_outlined),
            if (tamOku(k['odul_puan']) > 0) KRozet('+${tamOku(k['odul_puan'])} puan', renk: t.yesil, ikon: Icons.stars_outlined),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: KButon('Düzenle', ikon: Icons.edit_outlined, ikincil: true, onTap: () => kartFormu(context, k, yenile))),
            const SizedBox(width: 6),
            Expanded(
              child: KButon(aktif ? 'Gizle' : 'Göster', ikon: aktif ? Icons.visibility_off_outlined : Icons.visibility_outlined, ikincil: true, renk: t.amber, onTap: () async {
                if (await kopruGonder(context, '/app-yonetim/aktif', {'id': '${k['id']}'}, basariMesaji: aktif ? 'Kart gizlendi' : 'Kart yayında')) yenile();
              }),
            ),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Sil',
              icon: Icon(Icons.delete_outline, color: t.kirmizi),
              onPressed: () async {
                if (!await kOnay(context, 'Kart silinsin mi?', aciklama: metinOku(k['baslik']), tehlikeli: true, evet: 'Sil')) return;
                if (!context.mounted) return;
                if (await kopruGonder(context, '/app-yonetim/sil', {'id': '${k['id']}'}, basariMesaji: 'Kart silindi')) yenile();
              },
            ),
          ]),
        ]),
      );
    }

    Widget izgara(List<Map<String, dynamic>> l) => LayoutBuilder(builder: (c, s) {
          final sutun = s.maxWidth >= 1000 ? 3 : (s.maxWidth >= 640 ? 2 : 1);
          final w = (s.maxWidth - (sutun - 1) * 12) / sutun;
          return Wrap(spacing: 12, children: [for (final k in l) SizedBox(width: w, child: kart(k))]);
        });

    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Toplam kart', deger: '${kartlar.length}', ikon: Icons.apps, renk: t.mor1),
        KKpi(etiket: 'Yayında', deger: '$yayinda', ikon: Icons.visibility_outlined, renk: t.yesil),
        KKpi(etiket: 'Hero', deger: '${hero.length}', ikon: Icons.view_carousel_outlined, renk: t.mavi),
        KKpi(etiket: 'Kampanya', deger: '${kamp.length}', ikon: Icons.local_offer_outlined, renk: t.amber),
      ]),
      const SizedBox(height: 12),
      if (kartlar.isEmpty)
        const KBos(
          baslik: 'Henüz kart yok',
          aciklama: 'Müşteri uygulamasının / QR menünün üstündeki büyük "Hero" ve yatay "Kampanya" kartlarını buradan eklersiniz. Sağ alttaki "Yeni kart" ile başlayın.',
          ikon: Icons.apps,
        )
      else ...[
        if (hero.isNotEmpty) ...[KBaslik('Hero kartları', ikon: Icons.view_carousel_outlined, alt: 'Uygulamanın üstündeki büyük kartlar'), izgara(hero)],
        if (kamp.isNotEmpty) ...[const SizedBox(height: 8), KBaslik('Kampanya kartları', ikon: Icons.local_offer_outlined, alt: 'Yatay kaydırılan kampanya şeridi'), izgara(kamp)],
      ],
    ]);
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'menu_ortak.dart';

/// Web /happy-hour — belirli ürün/kategoride gün + saat aralığında POS'ta otomatik indirim / özel fiyat.
/// İşlemler: kural ekle (/happy-hour/ekle), durdur/aç ve sil (/happy-hour/durum). Düzenleme sahip/müdür.
class MenuHappyHourScreen extends StatelessWidget {
  const MenuHappyHourScreen({super.key});

  static const Map<int, String> gunAd = {1: 'Pzt', 2: 'Sal', 3: 'Çar', 4: 'Per', 5: 'Cum', 6: 'Cmt', 7: 'Paz'};

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/happy-hour',
      baslik: 'Happy Hour',
      ikon: Icons.local_bar_outlined,
      govde: (ctx, v, yenile) => _Govde(veri: v, yenile: yenile),
      fab: (ctx, v, yenile) => menuYoneticiMi(ctx)
          ? FloatingActionButton.extended(
              onPressed: () => _yeniKural(ctx, v, yenile),
              icon: const Icon(Icons.add),
              label: const Text('Yeni kural', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : const SizedBox.shrink(),
    );
  }

  static bool simdiAktifMi(Map<String, dynamic> h) {
    if (tamOku(h['aktif']) != 1) return false;
    final n = DateTime.now();
    final gunler = metinOku(h['gunler']);
    if (gunler.isNotEmpty && !gunler.split(',').map((e) => int.tryParse(e.trim())).contains(n.weekday)) return false;
    final bugun = '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    final bt = metinOku(h['baslangic_tarih']), st = metinOku(h['bitis_tarih']);
    if (bt.isNotEmpty && bugun.compareTo(bt.substring(0, bt.length.clamp(0, 10))) < 0) return false;
    if (st.isNotEmpty && bugun.compareTo(st.substring(0, st.length.clamp(0, 10))) > 0) return false;
    final bs = metinOku(h['baslangic_saat']), ss = metinOku(h['bitis_saat']);
    if (bs.isNotEmpty && ss.isNotEmpty) {
      final s = '${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
      final a = bs.substring(0, 5), b = ss.substring(0, 5);
      if (a.compareTo(b) <= 0) {
        if (s.compareTo(a) < 0 || s.compareTo(b) > 0) return false;
      } else {
        if (s.compareTo(a) < 0 && s.compareTo(b) > 0) return false; // gece yarısını aşan aralık
      }
    }
    return true;
  }

  static Future<void> _yeniKural(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) async {
    final urunler = liste(v['urunler']);
    final kategoriler = liste(v['kategoriler']);
    final adC = TextEditingController();
    final yuzdeC = TextEditingController();
    final fiyatC = TextEditingController();
    int? urunId;
    int? katId;
    String? basSaat, bitSaat, basTarih, bitTarih;
    final gunler = <int>{1, 2, 3, 4, 5, 6, 7};
    bool gonderiyor = false;
    await kAltSayfa(context, baslik: 'Yeni Happy Hour kuralı', icerik: (c) {
      final t = c.watch<TemaProvider>();
      return StatefulBuilder(builder: (c, ss) {
        Future<void> kaydet() async {
          if (gunler.isEmpty) {
            kToast(c, 'En az bir gün seçin.', hata: true);
            return;
          }
          if (sayiOku(yuzdeC.text) <= 0 && sayiOku(fiyatC.text) <= 0) {
            kToast(c, 'İndirim yüzdesi ya da sabit happy fiyat girin.', hata: true);
            return;
          }
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/happy-hour/ekle', {
            'ad': adC.text.trim(),
            'urun_id': urunId?.toString() ?? '',
            'kategori_id': katId?.toString() ?? '',
            'baslangic_saat': basSaat ?? '',
            'bitis_saat': bitSaat ?? '',
            'indirim_yuzde': yuzdeC.text.trim(),
            'happy_fiyat': fiyatC.text.trim(),
            'baslangic_tarih': basTarih ?? '',
            'bitis_tarih': bitTarih ?? '',
            'gunler': (gunler.toList()..sort()).map((e) => '$e').toList(),
          }, basariMesaji: 'Happy Hour kuralı eklendi.');
          if (!c.mounted) return;
          ss(() => gonderiyor = false);
          if (ok) {
            Navigator.pop(c);
            yenile();
          }
        }

        final iki = genisMi(c);
        Widget satir(Widget a, Widget b) => iki
            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: a), const SizedBox(width: 12), Expanded(child: b)])
            : Column(children: [a, b]);
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          KAlan('Kural adı', adC, ipucu: 'örn. Akşam Bira Saati'),
          KSecim<int?>('Ürün (belirli)', deger: urunId, secenekler: [(null, '— Tüm ürünler / kategori —'), for (final u in urunler) (tamOku(u['id']), metinOku(u['ad']))], onSec: (x) => ss(() => urunId = x)),
          KSecim<int?>('Veya kategori (ürün boşsa)', deger: katId, secenekler: [(null, '— Yok —'), for (final k in kategoriler) (tamOku(k['id']), metinOku(k['ad']))], onSec: (x) => ss(() => katId = x)),
          satir(
            MenuSeciciKutu(etiket: 'Başlangıç saati', deger: basSaat, onTap: () async { final s = await menuSaatSec(c, basSaat); if (s != null) ss(() => basSaat = s); }, onTemizle: () => ss(() => basSaat = null)),
            MenuSeciciKutu(etiket: 'Bitiş saati', deger: bitSaat, onTap: () async { final s = await menuSaatSec(c, bitSaat); if (s != null) ss(() => bitSaat = s); }, onTemizle: () => ss(() => bitSaat = null)),
          ),
          satir(
            KAlan('İndirim %', yuzdeC, ipucu: 'örn. 20', klavye: const TextInputType.numberWithOptions(decimal: true)),
            KAlan('veya sabit happy fiyat (₺)', fiyatC, ipucu: 'örn. 50', klavye: const TextInputType.numberWithOptions(decimal: true)),
          ),
          satir(
            MenuSeciciKutu(etiket: 'Başlangıç tarihi (ops.)', deger: basTarih, ikon: Icons.event, onTap: () async { final s = await menuTarihSec(c, basTarih); if (s != null) ss(() => basTarih = s); }, onTemizle: () => ss(() => basTarih = null)),
            MenuSeciciKutu(etiket: 'Bitiş tarihi (ops.)', deger: bitTarih, ikon: Icons.event, onTap: () async { final s = await menuTarihSec(c, bitTarih); if (s != null) ss(() => bitTarih = s); }, onTemizle: () => ss(() => bitTarih = null)),
          ),
          Text('Geçerli günler', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in gunAd.entries)
              FilterChip(
                label: Text(e.value, style: TextStyle(fontWeight: FontWeight.w700, color: gunler.contains(e.key) ? Colors.white : t.sub2)),
                selected: gunler.contains(e.key),
                selectedColor: t.mor1,
                backgroundColor: t.card2,
                showCheckmark: false,
                onSelected: (s) => ss(() => s ? gunler.add(e.key) : gunler.remove(e.key)),
              ),
          ]),
          const SizedBox(height: 18),
          KButon('Kuralı ekle', ikon: Icons.check, genis: true, yukleniyor: gonderiyor, onTap: kaydet),
        ]);
      });
    });
  }
}

class _Govde extends StatelessWidget {
  final Map<String, dynamic> veri;
  final Future<void> Function() yenile;
  const _Govde({required this.veri, required this.yenile});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final kurallar = liste(veri['kurallar']);
    final urunAd = harita(veri['urunAd']);
    final katAd = harita(veri['katAd']);
    final yonetici = menuYoneticiMi(context);
    final aktifSay = kurallar.where((h) => tamOku(h['aktif']) == 1).length;
    final simdi = kurallar.where(MenuHappyHourScreen.simdiAktifMi).length;

    Widget kart(Map<String, dynamic> h) {
      final aktif = tamOku(h['aktif']) == 1;
      final hedef = tamOku(h['urun_id']) > 0
          ? metinOku(urunAd['${h['urun_id']}'], 'ürün')
          : tamOku(h['kategori_id']) > 0
              ? 'Kategori: ${metinOku(katAd['${h['kategori_id']}'])}'
              : 'Tüm ürünler';
      final parca = <String>[hedef];
      final bs = metinOku(h['baslangic_saat']);
      if (bs.isNotEmpty) parca.add('⏰ ${bs.length >= 5 ? bs.substring(0, 5) : bs}-${metinOku(h['bitis_saat']).padRight(5).substring(0, 5).trim()}');
      final g = metinOku(h['gunler']);
      if (g.isNotEmpty) parca.add(g.split(',').map((x) => MenuHappyHourScreen.gunAd[int.tryParse(x.trim()) ?? 0] ?? '').where((x) => x.isNotEmpty).join(', '));
      final bt = metinOku(h['baslangic_tarih']);
      if (bt.isNotEmpty) parca.add('📅 ${tarihYaz(bt, saat: false)} → ${metinOku(h['bitis_tarih']).isEmpty ? '…' : tarihYaz(h['bitis_tarih'], saat: false)}');
      final deger = sayiOku(h['happy_fiyat']) > 0 ? tl(h['happy_fiyat'], kisa: true) : yuzde(h['indirim_yuzde']);
      final simdiAktif = MenuHappyHourScreen.simdiAktifMi(h);
      return KKart(
        renk: aktif ? (simdiAktif ? t.yesil : t.amber) : t.sub,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            KIkon(Icons.local_bar_outlined, renk: aktif ? t.amber : t.sub),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(metinOku(h['ad'], 'Happy Hour'), style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 3),
                Text(parca.join(' · '), style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.35)),
              ]),
            ),
            const SizedBox(width: 8),
            Text(deger, style: TextStyle(color: t.mor1, fontSize: 19, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (!aktif) KRozet('Pasif', renk: t.sub, ikon: Icons.pause_circle_outline)
            else if (simdiAktif) KRozet('Şu an uygulanıyor', renk: t.yesil, ikon: Icons.bolt)
            else KRozet('Açık · saati bekliyor', renk: t.amber, ikon: Icons.schedule),
            if (yonetici) ...[
              KButon(aktif ? 'Durdur' : 'Aç', ikon: aktif ? Icons.pause : Icons.play_arrow, ikincil: true, renk: aktif ? t.amber : t.yesil, onTap: () async {
                if (await kopruGonder(context, '/happy-hour/durum', {'id': '${h['id']}'}, basariMesaji: 'Güncellendi.')) yenile();
              }),
              KButon('Sil', ikon: Icons.delete_outline, ikincil: true, renk: t.kirmizi, onTap: () async {
                if (!await kOnay(context, 'Kural silinsin mi?', aciklama: metinOku(h['ad'], 'Happy Hour'), tehlikeli: true, evet: 'Sil')) return;
                if (!context.mounted) return;
                if (await kopruGonder(context, '/happy-hour/durum', {'id': '${h['id']}', 'sil': '1'}, basariMesaji: 'Silindi.')) yenile();
              }),
            ],
          ]),
        ]),
      );
    }

    return KGovde(yenile: yenile, children: [
      KKart(
        renk: t.amber,
        child: Text(
          'Happy Hour: belirli ürün/kategoride, seçtiğin gün + saat aralığında POS\'ta otomatik indirim ya da özel fiyat uygulanır. '
          'Örn. "Hafta içi 17:00-19:00 bira %20". Garson ürünü eklerken fiyat kendiliğinden düşer.',
          style: TextStyle(color: t.sub2, fontSize: 13, height: 1.45),
        ),
      ),
      KKpiIzgara([
        KKpi(etiket: 'Toplam kural', deger: '${kurallar.length}', ikon: Icons.list_alt, renk: t.mor1),
        KKpi(etiket: 'Açık', deger: '$aktifSay', ikon: Icons.play_circle_outline, renk: t.amber),
        KKpi(etiket: 'Şu an uygulanan', deger: '$simdi', ikon: Icons.bolt, renk: t.yesil),
      ]),
      const SizedBox(height: 12),
      KBaslik('Tanımlı kurallar', ikon: Icons.list),
      if (kurallar.isEmpty)
        KBos(
          baslik: 'Henüz Happy Hour kuralı yok',
          aciklama: yonetici
              ? 'Sağ alttaki "Yeni kural" ile ürün ya da kategori seçip gün/saat aralığı ve indirim girin.'
              : 'Kuralları yalnız işletme sahibi ya da müdür ekleyebilir.',
          ikon: Icons.local_bar_outlined,
        )
      else if (genisMi(context))
        LayoutBuilder(builder: (c, s) {
          final w = (s.maxWidth - 12) / 2;
          return Wrap(spacing: 12, children: [for (final h in kurallar) SizedBox(width: w, child: kart(h))]);
        })
      else
        ...kurallar.map(kart),
    ]);
  }
}

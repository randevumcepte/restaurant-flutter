import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

// ───────────────────────── /raporlar ─────────────────────────
/// Genel raporlar: menü mühendisliği (popülerlik × ciro), ödeme tipleri, saatlik yoğunluk — son 30 gün
class GenelRaporlarScreen extends StatefulWidget {
  const GenelRaporlarScreen({super.key});
  @override
  State<GenelRaporlarScreen> createState() => _GenelRaporlarScreenState();
}

class _GenelRaporlarScreenState extends State<GenelRaporlarScreen> {
  String _sinif = 'hepsi';

  static (String, Color) _sinifla(Map<String, dynamic> m, double ortAdet, double ortCiro) {
    final pop = sayiOku(m['adet']) >= ortAdet;
    final kar = sayiOku(m['ciro']) >= ortCiro;
    if (pop && kar) return ('Yıldız', const Color(0xFF10B981));
    if (pop) return ('İş Atı', const Color(0xFF0EA5E9));
    if (kar) return ('Bilmece', const Color(0xFFF59E0B));
    return ('Köpek', const Color(0xFFF43F5E));
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/raporlar',
      baslik: 'Raporlar',
      ikon: Icons.bar_chart,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final menu = liste(v['menuMuh']);
        final odeme = liste(v['odemeTipi']);
        final saatHam = v['saatlik'];
        final saat = <int, int>{};
        if (saatHam is Map) {
          saatHam.forEach((k, x) => saat[int.tryParse('$k') ?? -1] = tamOku(x));
        } else if (saatHam is List) {
          for (var i = 0; i < saatHam.length; i++) {
            saat[i] = tamOku(saatHam[i]);
          }
        }
        final ortAdet = menu.isEmpty ? 1.0 : menu.fold<double>(0, (a, m) => a + sayiOku(m['adet'])) / menu.length;
        final ortCiro = menu.isEmpty ? 1.0 : menu.fold<double>(0, (a, m) => a + sayiOku(m['ciro'])) / menu.length;
        final sayac = <String, int>{};
        for (final m in menu) {
          final s = _sinifla(m, ortAdet, ortCiro).$1;
          sayac[s] = (sayac[s] ?? 0) + 1;
        }
        final menuF = _sinif == 'hepsi' ? menu : menu.where((m) => _sinifla(m, ortAdet, ortCiro).$1 == _sinif).toList();
        final toplamOdeme = odeme.fold<double>(0, (a, o) => a + sayiOku(o['tutar']));
        var maxSaat = 1;
        for (var h = 9; h <= 23; h++) {
          if ((saat[h] ?? 0) > maxSaat) maxSaat = saat[h]!;
        }

        final menuKart = KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KBaslik('Menü mühendisliği', ikon: Icons.restaurant_menu_outlined, alt: 'Popülerlik × ciro, son 30 gün'),
            if (menu.isNotEmpty)
              KCipler(
                secenekler: [('hepsi', 'Tümü ${menu.length}'), for (final s in const ['Yıldız', 'İş Atı', 'Bilmece', 'Köpek']) if (sayac[s] != null) (s, '$s ${sayac[s]}')],
                secili: _sinif,
                onSec: (s) => setState(() => _sinif = s),
              ),
            if (menu.isEmpty)
              const KBos(baslik: 'Son 30 günde satış yok', aciklama: 'Ödenmiş adisyon kalemi olmadığı için ürün sınıflandırması yapılamıyor. Satış oldukça ürünler burada sınıflanır.', ikon: Icons.restaurant_menu_outlined)
            else if (genisMi(ctx))
              KTablo(
                basliklar: const ['Ürün', 'Adet', 'Ciro', 'Sınıf'],
                sagaYasla: const {1, 2},
                satirlar: [for (final m in menuF) [metinOku(m['urun_adi']), sayiYaz(m['adet']), tl(m['ciro'], kisa: true), _sinifla(m, ortAdet, ortCiro).$1]],
              )
            else
              for (final m in menuF)
                KSatir(
                  baslik: metinOku(m['urun_adi']),
                  alt: '${sayiYaz(m['adet'])} adet · ${tl(m['ciro'], kisa: true)}',
                  sag: KRozet(_sinifla(m, ortAdet, ortCiro).$1, renk: _sinifla(m, ortAdet, ortCiro).$2),
                ),
            const SizedBox(height: 8),
            Text('Yıldız: çok satan + kârlı · İş Atı: çok satan az kârlı · Bilmece: az satan kârlı · Köpek: ikisi de düşük (menüden çıkarmayı düşün)', style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4)),
          ]),
        );

        final odemeKart = KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KBaslik('Ödeme tipleri', ikon: Icons.payments_outlined, alt: 'Son 30 gün', renk: t.yesil),
            if (odeme.isEmpty)
              const KBos(baslik: 'Ödeme yok', aciklama: 'Son 30 günde alınmış ödeme bulunmuyor.', ikon: Icons.payments_outlined)
            else
              for (final o in odeme) ...[
                FSatir('${_tipYaz(o['tip'])} (${sayiYaz(o['adet'])})', tl(o['tutar'], kisa: true)),
                if (toplamOdeme > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: sayiOku(o['tutar']) / toplamOdeme, minHeight: 6, color: t.yesil, backgroundColor: t.card2),
                    ),
                  ),
              ],
          ]),
        );

        final saatKart = KKart(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KBaslik('Saatlik yoğunluk', ikon: Icons.schedule, alt: 'Adisyon açılış saatine göre, son 30 gün', renk: t.mavi),
            SizedBox(
              height: 150,
              child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (var h = 9; h <= 23; h++)
                  Expanded(
                    child: Tooltip(
                      message: '$h:00 → ${saat[h] ?? 0} adisyon',
                      child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                        if ((saat[h] ?? 0) > 0) Text('${saat[h]}', style: TextStyle(color: t.sub, fontSize: 10)),
                        Container(
                          height: ((saat[h] ?? 0) / maxSaat * 110).clamp(2, 110).toDouble(),
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(color: t.mavi.withValues(alpha: .75), borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
                        ),
                        const SizedBox(height: 3),
                        Text('$h', style: TextStyle(color: t.sub, fontSize: 10)),
                      ]),
                    ),
                  ),
              ]),
            ),
          ]),
        );

        return KGovde(yenile: yenile, children: [
          if (genisMi(ctx))
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(flex: 2, child: menuKart),
              const SizedBox(width: 12),
              Expanded(child: Column(children: [odemeKart, saatKart])),
            ])
          else ...[saatKart, odemeKart, menuKart],
          Wrap(spacing: 8, runSpacing: 8, children: [
            FGecis('Finans raporları', () => sayfaAc(ctx, '/finans-raporlar/donemsel', 'Finans Raporları')),
            FGecis('Z Raporu', () => sayfaAc(ctx, '/z-raporu', 'Z Raporu')),
          ]),
        ]);
      },
    );
  }

  static String _tipYaz(dynamic v) {
    final s = metinOku(v, '—');
    return const {'nakit': 'Nakit', 'kredi': 'Kredi kartı', 'yemek_karti': 'Yemek kartı', 'acik_hesap': 'Açık hesap'}[s] ?? s.replaceAll('_', ' ');
  }
}

// ───────────────────────── /kasalar ─────────────────────────
/// Kasa noktaları (çoklu kasa): ekle / ad değiştir / aktif-pasif / kapat, kasiyer sayfaları, personel ataması
const _kasaSayfalari = [
  ('/pos', 'Masalar'), ('/departman-brief', 'Sabah Brifingim'), ('/dashboard', 'Özet'), ('/mutfak', 'Mutfak'),
  ('/rezervasyon', 'Rezervasyon'), ('/paket', 'Paket'), ('/kasa', 'Kasa (Vardiya)'), ('/z-raporu', 'Z Raporu'),
];

class KasalarScreen extends StatelessWidget {
  const KasalarScreen({super.key});
  static const _turuncu = Color(0xFFD97706);

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/kasalar',
      baslik: 'Kasa Noktaları',
      ikon: Icons.storefront_outlined,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(heroTag: 'kasa_ekle', backgroundColor: _turuncu, onPressed: () => _ekle(ctx, yenile), icon: const Icon(Icons.add), label: const Text('Kasa ekle')),
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final kasalar = liste(v['kasalar']);
        final per = liste(v['personeller']);
        final aktifler = kasalar.where((k) => tamOku(k['aktif'] ?? 1) == 1).toList();
        return KGovde(yenile: yenile, children: [
          KKart(
            renk: _turuncu,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline, color: _turuncu),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Kasa noktası nedir?', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Her fiziksel kasa (Kasa 1, Bar, Üst Kat…) bir kasa noktasıdır — kendi vardiyası ve nakit çekmecesi olur. Personeli bir kasaya atarsan giriş yapınca otomatik o kasada çalışır. Atamazsan ve birden fazla kasa varsa girişte hangi kasada olduğunu seçer.',
                      style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4)),
                  const SizedBox(height: 4),
                  Text('Hiç kasa noktası tanımlamazsan sistem tek-havuz (tek çekmece) çalışır — küçük işletme için yeterlidir.', style: TextStyle(color: t.sub, fontSize: 12.5)),
                ]),
              ),
            ]),
          ),
          KBaslik('Kasalar', ikon: Icons.storefront_outlined, renk: _turuncu, sag: KRozet('${aktifler.length} aktif', renk: _turuncu)),
          if (kasalar.isEmpty)
            KKart(
              child: KBos(
                baslik: 'Henüz kasa noktası yok',
                aciklama: 'Tek-havuz modunda çalışıyorsunuz. Birden fazla kasanız varsa "Kasa ekle" ile tanımlayın.',
                ikon: Icons.storefront_outlined,
                aksiyon: KButon('Kasa ekle', ikon: Icons.add, renk: _turuncu, onTap: () => _ekle(ctx, yenile)),
              ),
            )
          else
            FIzgara([for (final k in kasalar) _KasaKart(k: k, yenile: yenile)], minGenislik: 360),
          if (aktifler.isNotEmpty && per.isNotEmpty) ...[
            const SizedBox(height: 8),
            KBaslik('Personel ataması', ikon: Icons.badge_outlined, renk: t.mavi,
                alt: 'Atanan personel girişte otomatik o kasada çalışır. Boş bırakırsan, birden fazla kasa varsa girişte seçer.'),
            KKart(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [
                for (final p in per)
                  KSatir(
                    baslik: metinOku(p['ad']),
                    alt: _rolAd(p['rol']),
                    sag: SizedBox(
                      width: genisMi(ctx) ? 260 : 170,
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: aktifler.any((k) => tamOku(k['id']) == tamOku(p['varsayilan_kasa_id'])) ? tamOku(p['varsayilan_kasa_id']) : 0,
                        dropdownColor: t.card,
                        underline: const SizedBox.shrink(),
                        style: TextStyle(color: t.ink, fontSize: 14),
                        items: [
                          const DropdownMenuItem(value: 0, child: Text('— Girişte seçsin —', overflow: TextOverflow.ellipsis)),
                          for (final k in aktifler) DropdownMenuItem(value: tamOku(k['id']), child: Text(metinOku(k['ad']), overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (x) async {
                          if (await kopruGonder(ctx, '/kasalar/atama', {'personel_id': p['id'], 'kasa_id': x ?? 0}, basariMesaji: 'Atama güncellendi.')) await yenile();
                        },
                      ),
                    ),
                  ),
              ]),
            ),
          ],
          FNot('Kasa vardiyası (açma / para koy-al / kapatma) Kasa ekranından yapılır.', baglantilar: [FGecis('Kasa (Vardiya)', () => sayfaAc(ctx, '/kasa', 'Kasa'))]),
        ]);
      },
    );
  }

  static String _rolAd(dynamic r) {
    final s = metinOku(r, '-');
    return s.isEmpty ? '-' : '${s[0].toUpperCase()}${s.substring(1)}';
  }

  static Future<void> _ekle(BuildContext context, Future<void> Function() yenile) async {
    final ad = TextEditingController();
    bool gonderiyor = false;
    bool eklendi = false;
    await kAltSayfa(context, baslik: 'Yeni kasa noktası', icerik: (c) => StatefulBuilder(builder: (c, ss) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KAlan('Kasa adı', ad, ipucu: 'Örn. "Kasa 1", "Bar Kasa", "Üst Kat"', zorunlu: true),
        KButon('Ekle', ikon: Icons.add, genis: true, renk: _turuncu, yukleniyor: gonderiyor, onTap: () async {
          if (ad.text.trim().isEmpty) {
            kToast(c, 'Kasa adı girin.', hata: true);
            return;
          }
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/kasalar/ekle', {'ad': ad.text.trim()});
          if (!c.mounted) return;
          ss(() => gonderiyor = false);
          if (ok) {
            eklendi = true;
            Navigator.pop(c);
          }
        }),
      ]);
    }));
    if (eklendi) await yenile();
  }
}

class _KasaKart extends StatefulWidget {
  final Map<String, dynamic> k;
  final Future<void> Function() yenile;
  const _KasaKart({required this.k, required this.yenile});
  @override
  State<_KasaKart> createState() => _KasaKartState();
}

class _KasaKartState extends State<_KasaKart> {
  late TextEditingController _ad;
  late Set<String> _sec;

  @override
  void initState() {
    super.initState();
    _kur();
  }

  @override
  void didUpdateWidget(covariant _KasaKart old) {
    super.didUpdateWidget(old);
    if (old.k.toString() != widget.k.toString()) _kur();
  }

  void _kur() {
    _ad = TextEditingController(text: metinOku(widget.k['ad']));
    final tum = {for (final (u, _) in _kasaSayfalari) u};
    final ham = metinOku(widget.k['sayfalar']);
    Set<String>? j;
    if (ham.startsWith('[')) {
      j = {for (final m in RegExp(r'"([^"]+)"').allMatches(ham)) m.group(1)!.replaceAll(r'\/', '/')};
    }
    _sec = j == null ? tum : {'/pos', ...j.where(tum.contains)};
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final k = widget.k;
    final pasif = tamOku(k['aktif'] ?? 1) != 1;
    final acik = k['acik'] == true || k['acik'] == 1;
    return Opacity(
      opacity: pasif ? .6 : 1,
      child: KKart(
        renk: KasalarScreen._turuncu,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.storefront_outlined, color: KasalarScreen._turuncu),
            const SizedBox(width: 8),
            Expanded(child: Text(metinOku(k['ad']), style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold))),
            if (acik)
              KRozet('Vardiya açık', renk: t.yesil, ikon: Icons.circle)
            else if (pasif)
              KRozet('Pasif', renk: t.sub)
            else
              KRozet('Kapalı', renk: t.sub2),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _ad,
                maxLength: 60,
                style: TextStyle(color: t.ink, fontSize: 14.5),
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  filled: true,
                  fillColor: t.card2,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Adı kaydet',
              icon: Icon(Icons.save_outlined, color: t.mor1),
              onPressed: () async {
                if (_ad.text.trim().isEmpty) return;
                if (await kopruGonder(context, '/kasalar/duzenle', {'id': k['id'], 'ad': _ad.text.trim()})) await widget.yenile();
              },
            ),
          ]),
          const SizedBox(height: 10),
          Text('KASİYER BU KASADA HANGİ SAYFALARI GÖRSÜN', style: TextStyle(color: t.sub2, fontSize: 11.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final (u, ad) in _kasaSayfalari)
              FilterChip(
                label: Text(u == '/pos' ? '$ad (hep açık)' : ad, style: TextStyle(fontSize: 12.5, color: _sec.contains(u) ? Colors.white : t.sub2, fontWeight: FontWeight.w700)),
                selected: _sec.contains(u),
                selectedColor: KasalarScreen._turuncu,
                backgroundColor: t.card2,
                checkmarkColor: Colors.white,
                onSelected: u == '/pos' ? null : (x) => setState(() => x ? _sec.add(u) : _sec.remove(u)),
              ),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            TextButton(onPressed: () => setState(() => _sec = {for (final (u, _) in _kasaSayfalari) u}), child: const Text('Ana Kasa')),
            TextButton(onPressed: () => setState(() => _sec = {'/pos'}), child: const Text('Sadece Sipariş')),
            KButon('Sayfaları kaydet', ikon: Icons.save_outlined, renk: KasalarScreen._turuncu, onTap: () async {
              if (await kopruGonder(context, '/kasalar/sayfalar', {'id': k['id'], 'sayfa': _sec.toList()})) await widget.yenile();
            }),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: KButon(pasif ? 'Aktif et' : 'Pasife al', ikon: pasif ? Icons.toggle_on_outlined : Icons.toggle_off_outlined, ikincil: true, onTap: () async {
                if (await kopruGonder(context, '/kasalar/duzenle', {'id': k['id'], 'aktif': pasif ? '1' : '0'})) await widget.yenile();
              }),
            ),
            const SizedBox(width: 8),
            KButon('Kapat', ikon: Icons.delete_outline, ikincil: true, renk: t.kirmizi, onTap: () async {
              if (!await kOnay(context, '${metinOku(k['ad'])} kapatılsın mı?', tehlikeli: true, evet: 'Kapat', aciklama: 'Geçmiş kayıtlar korunur, kasa pasife alınır ve bu kasaya atanmış personelin ataması kaldırılır.')) return;
              if (!context.mounted) return;
              if (await kopruGonder(context, '/kasalar/sil', {'id': k['id']})) await widget.yenile();
            }),
          ]),
        ]),
      ),
    );
  }
}

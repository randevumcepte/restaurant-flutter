import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../screens/barkod_tarayici.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

bool get _kameraVar => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Etiket boyutu / adet / tür sorup PDF etiket basar (web'deki tarayıcıdan yazdırmanın uygulama karşılığı)
Future<void> stEtiketSorBas(BuildContext context, List<StEtiket> etiketler, {String tip = 'c128', bool adetSor = true, bool tipSor = false, String ad = 'Etiket'}) async {
  String boyut = '50x30';
  String tur = tip;
  final adetK = TextEditingController(text: '1');
  final ok = await kAltSayfa<bool>(context, baslik: 'Etiket Bas', icerik: (c) => StatefulBuilder(builder: (c, ss) {
        final t = c.read<TemaProvider>();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${etiketler.length} farklı etiket · PDF hazırlanır; yazdırma penceresinde etiket yazıcınızı (ya da A4) seçin.', style: TextStyle(color: t.sub, fontSize: 13)),
          const SizedBox(height: 10),
          KSecim<String>('Etiket boyutu', deger: boyut, secenekler: [for (final b in kStEtiketBoyutlar) (b.$1, b.$2)], onSec: (s) => ss(() => boyut = s ?? boyut)),
          if (tipSor)
            KSecim<String>('Tür', deger: tur, secenekler: const [('c128', 'Barkod (Code 128)'), ('ean13', 'EAN-13'), ('qr', 'QR kod')], onSec: (s) => ss(() => tur = s ?? tur)),
          if (adetSor) KAlan('Her birinden kaç adet', adetK, klavye: TextInputType.number),
          KButon('PDF Hazırla ve Yazdır', ikon: Icons.print_outlined, genis: true, onTap: () => Navigator.pop(c, true)),
        ]);
      }));
  if (ok != true || !context.mounted) return;
  final adet = adetSor ? (int.tryParse(adetK.text.trim()) ?? 1).clamp(1, 500) : null;
  final liste = [for (final e in etiketler) StEtiket(kod: e.kod, ust: e.ust, ad: e.ad, alt: e.alt, adet: adet ?? e.adet)];
  await stEtiketYazdir(context, liste, tip: tur, boyut: boyut, ad: ad);
}

/// Web /barkod — ürün ve malzemelere çoklu barkod: liste, ara, ekle (okut ya da yaz), sil, etiket bas.
class BarkodScreen extends StatefulWidget {
  const BarkodScreen({super.key});

  @override
  State<BarkodScreen> createState() => _BarkodScreenState();
}

class _BarkodScreenState extends State<BarkodScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _ara = '';
  String _tur = 'hepsi';

  Future<void> _ekle(Map<String, dynamic> v) async {
    final urunler = liste(v['urunler']);
    final malzemeler = liste(v['malzemeler']);
    final kod = TextEditingController();
    String tur = 'urun';
    int? hedef;
    final ok = await kAltSayfa<bool>(context, baslik: 'Barkod Ekle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.read<TemaProvider>();
          final kaynak = tur == 'urun' ? urunler : malzemeler;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(child: KAlan('Barkod', kod, ipucu: 'Okutun ya da yazın', zorunlu: true)),
              if (_kameraVar)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12, left: 6),
                  child: IconButton.filledTonal(
                    tooltip: 'Kamerayla okut',
                    onPressed: () async {
                      final s = await BarkodTarayici.oku(c);
                      if (s != null) ss(() => kod.text = s);
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                  ),
                ),
            ]),
            Text('Tür', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            KCipler(secenekler: const [('urun', 'Ürün (menü)'), ('malzeme', 'Malzeme (stok)')], secili: tur, onSec: (s) => ss(() { tur = s; hedef = null; })),
            const SizedBox(height: 6),
            KSecim<int>(tur == 'urun' ? 'Ürün' : 'Malzeme', deger: hedef, secenekler: [for (final x in kaynak) (tamOku(x['id']), '${x['ad']}')], onSec: (i) => ss(() => hedef = i)),
            if (kaynak.isEmpty)
              Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(tur == 'urun' ? 'Menüde ürün yok.' : 'Malzeme kartı yok.', style: TextStyle(color: t.amber, fontSize: 12.5))),
            KButon('Ekle', ikon: Icons.add, genis: true, onTap: () async {
              if (kod.text.trim().isEmpty || hedef == null) {
                kToast(c, 'Eksik bilgi: barkod ve öğe seçilmeli.', hata: true);
                return;
              }
              final r = await stGonder(c, '/barkod/ekle', {
                'barkod': kod.text.trim(), 'tur': tur, if (tur == 'urun') 'hedef_id_urun': hedef, if (tur == 'malzeme') 'hedef_id_malzeme': hedef,
              }, basari: 'Barkod eklendi.');
              if (r.ok && c.mounted) Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok == true) _k.currentState?.yukle();
  }

  Future<void> _sil(Map<String, dynamic> b) async {
    if (!await kOnay(context, 'Bu barkod silinsin mi?', aciklama: '${b['barkod']} · ${metinOku(b['hedef_ad'], '—')}', evet: 'Sil', tehlikeli: true)) return;
    if (!mounted) return;
    final r = await stGonder(context, '/barkod/sil', {'id': b['id']}, basari: 'Barkod silindi.');
    if (r.ok) _k.currentState?.yukle();
  }

  Future<void> _etiket(List<Map<String, dynamic>> secim) async {
    final c = await stAl(context, '/barkod/etiket', q: {'ids': secim.map((b) => '${b['id']}').join(','), 'adet': '1'});
    if (!mounted) return;
    final et = c.ok ? liste(c.veri['etiketler']) : <Map<String, dynamic>>[];
    final etiketler = et.isNotEmpty
        ? [for (final e in et) StEtiket(kod: '${e['barkod']}', ust: metinOku(e['ust']), ad: metinOku(e['ad']), alt: metinOku(e['alt']))]
        : [for (final b in secim) StEtiket(kod: '${b['barkod']}', ad: metinOku(b['hedef_ad']), alt: b['tur'] == 'urun' ? '' : 'Malzeme')];
    final hepsiEan = etiketler.every((e) => RegExp(r'^\d{13}$').hasMatch(e.kod));
    await stEtiketSorBas(context, etiketler, tip: hepsiEan ? 'ean13' : 'c128', ad: 'Barkod-Etiket');
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/barkod',
      baslik: 'Barkod Yönetimi',
      ikon: Icons.qr_code,
      araclar: (ctx, v, y) => [
        IconButton(tooltip: 'Barkod & Etiket Merkezi', icon: const Icon(Icons.local_offer_outlined), onPressed: () => stAc(ctx, '/barkod-etiket', 'Barkod & Etiket')),
      ],
      fab: (ctx, v, y) => FloatingActionButton.extended(
        heroTag: 'brkFab',
        onPressed: () => _ekle(v),
        icon: const Icon(Icons.add),
        label: const Text('Barkod', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final barkodlar = liste(v['barkodlar']);
        final q = _ara.toLowerCase();
        final gorunen = barkodlar.where((b) {
          if (_tur != 'hepsi' && b['tur'] != _tur) return false;
          if (q.isNotEmpty && !'${b['barkod']} ${b['hedef_ad'] ?? ''}'.toLowerCase().contains(q)) return false;
          return true;
        }).toList();
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Toplam barkod', deger: '${barkodlar.length}', ikon: Icons.qr_code, renk: t.mavi),
            KKpi(etiket: 'Ürün', deger: '${barkodlar.where((b) => b['tur'] == 'urun').length}', ikon: Icons.restaurant_menu, renk: t.mor1),
            KKpi(etiket: 'Malzeme', deger: '${barkodlar.where((b) => b['tur'] == 'malzeme').length}', ikon: Icons.inventory_2_outlined, renk: t.yesil),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: KAra(ipucu: 'Barkod ya da öğe ara', onDegis: (s) => setState(() => _ara = s))),
            if (_kameraVar)
              IconButton(
                tooltip: 'Okutarak ara',
                onPressed: () async {
                  final s = await BarkodTarayici.oku(context);
                  if (s != null) setState(() => _ara = s);
                },
                icon: Icon(Icons.qr_code_scanner, color: t.mor1),
              ),
          ]),
          const SizedBox(height: 8),
          KCipler(secenekler: const [('hepsi', 'Tümü'), ('urun', 'Ürün'), ('malzeme', 'Malzeme')], secili: _tur, onSec: (s) => setState(() => _tur = s)),
          if (gorunen.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _etiket(gorunen),
                icon: const Icon(Icons.print_outlined),
                label: Text('Görünen ${gorunen.length} barkodun etiketini bas'),
              ),
            ),
          if (barkodlar.isEmpty)
            const KBos(
              baslik: 'Henüz barkod tanımlı değil',
              ikon: Icons.qr_code,
              aciklama: 'Ürün ya da malzemeye barkod bağlayın: satışta ve sayımda okutunca doğrudan bulunur. Sağ alttaki "Barkod" düğmesiyle ekleyin.',
            )
          else if (gorunen.isEmpty)
            const KBos(baslik: 'Aramaya uyan barkod yok', ikon: Icons.search_off)
          else
            for (final b in gorunen)
              KKart(
                padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                child: Row(children: [
                  KIkon(b['tur'] == 'urun' ? Icons.restaurant_menu : Icons.inventory_2_outlined, renk: b['tur'] == 'urun' ? t.mor1 : t.yesil),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${b['barkod']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold, fontFeatures: const [FontFeature.tabularFigures()])),
                      Text('${b['tur'] == 'urun' ? 'Ürün' : 'Malzeme'} · ${metinOku(b['hedef_ad'], 'Silinmiş öğe')}', style: TextStyle(color: t.sub, fontSize: 12.5)),
                    ]),
                  ),
                  IconButton(tooltip: 'Etiket bas', onPressed: () => _etiket([b]), icon: Icon(Icons.print_outlined, color: t.mor1)),
                  IconButton(tooltip: 'Sil', onPressed: () => _sil(b), icon: Icon(Icons.delete_outline, color: t.kirmizi)),
                ]),
              ),
        ]);
      },
    );
  }
}

/// Web /barkod-etiket/barkod — serbest barkod/QR üret (metinden) + barkodsuz ürünlere mağaza içi barkod ver.
class BarkodUretScreen extends StatefulWidget {
  const BarkodUretScreen({super.key});

  @override
  State<BarkodUretScreen> createState() => _BarkodUretScreenState();
}

class _BarkodUretScreenState extends State<BarkodUretScreen> {
  final _k = GlobalKey<KopruEkranState>();
  final _kod = TextEditingController();
  final _ust = TextEditingController();
  final _adet = TextEditingController(text: '1');
  String _tip = 'c128';
  String _boyut = '50x30';

  @override
  void dispose() {
    _kod.dispose();
    _ust.dispose();
    _adet.dispose();
    super.dispose();
  }

  // web /barkod-etiket/serbest doğrulamasının aynısı
  int _eanKontrol(String d12) {
    var t = 0;
    for (var i = 0; i < 12; i++) {
      t += int.parse(d12[i]) * (i.isEven ? 1 : 3);
    }
    return (10 - t % 10) % 10;
  }

  Future<void> _bas() async {
    final satirlar = _kod.text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).take(200).toList();
    if (satirlar.isEmpty) {
      kToast(context, 'Barkoda dönüşecek metni yaz.', hata: true);
      return;
    }
    final kodlar = <String>[];
    for (final s in satirlar) {
      if (_tip == 'ean13') {
        var d = s.replaceAll(RegExp(r'\D'), '');
        if (d.length == 12) d = '$d${_eanKontrol(d)}';
        if (d.length != 13 || _eanKontrol(d.substring(0, 12)) != int.parse(d[12])) {
          kToast(context, '"$s" geçerli bir EAN-13 değil (12 ya da 13 rakam olmalı, son hane kontrol hanesi).', hata: true);
          return;
        }
        kodlar.add(d);
      } else if (_tip == 'c128') {
        if (!RegExp(r'^[\x20-\x7E]{1,48}$').hasMatch(s)) {
          kToast(context, '"$s" barkoda çevrilemez: Türkçe karakter olmadan en çok 48 karakter.', hata: true);
          return;
        }
        kodlar.add(s);
      } else {
        kodlar.add(s.length > 300 ? s.substring(0, 300) : s);
      }
    }
    final adet = (int.tryParse(_adet.text.trim()) ?? 1).clamp(1, 100);
    await stEtiketYazdir(context, [for (final k in kodlar) StEtiket(kod: k, ust: _ust.text.trim(), adet: adet)], tip: _tip, boyut: _boyut, ad: '${kodlar.length}-barkod');
  }

  Future<void> _icBarkod(int sayi) async {
    if (!await kOnay(context, '$sayi ürüne mağaza içi barkod verilsin mi?', aciklama: 'Barkodu olmayan (tartılı olmayan) ürünlere işletme içi okutma için benzersiz barkod üretilir.')) return;
    if (!mounted) return;
    final r = await stGonder(context, '/barkod-etiket/ic-barkod', {}, basari: 'Mağaza içi barkod verildi.');
    if (r.ok) _k.currentState?.yukle();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/barkod-etiket/barkod',
      baslik: 'Barkod Üret',
      ikon: Icons.qr_code_2,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final duzenler = v['duzenler'] == true;
        final barkodsuz = liste(v['liste']).where((u) {
          final turler = metinOku(u['turler']).split(',');
          final tl0 = dizi(u['tur_liste']).map((e) => '$e').toList();
          final hepsi = tl0.isNotEmpty ? tl0 : turler;
          return metinOku(u['barkod']).isEmpty && !(hepsi.contains('tarti') && !hepsi.contains('paket'));
        }).toList();
        return KGovde(yenile: yenile, children: [
          KBaslik('Serbest barkod / QR', ikon: Icons.qr_code_2, alt: 'Her satır bir etiket: raf kodu, depo yeri, link… PDF olarak yazdırılır.'),
          KKart(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              KAlan('Metin (her satır bir barkod)', _kod, satir: 5, ipucu: 'RAF-A-01\nRAF-A-02\nhttps://…'),
              KSecim<String>('Tür', deger: _tip, secenekler: const [('c128', 'Barkod (Code 128)'), ('ean13', 'EAN-13 (13 rakam)'), ('qr', 'QR kod')], onSec: (s) => setState(() => _tip = s ?? _tip)),
              Row(children: [
                Expanded(child: KSecim<String>('Etiket boyutu', deger: _boyut, secenekler: [for (final b in kStEtiketBoyutlar) (b.$1, b.$2)], onSec: (s) => setState(() => _boyut = s ?? _boyut))),
                const SizedBox(width: 10),
                SizedBox(width: 110, child: KAlan('Her birinden', _adet, klavye: TextInputType.number)),
              ]),
              KAlan('Üst yazı (isteğe bağlı)', _ust, ipucu: 'Ana depo'),
              KButon('Etiketleri Hazırla ve Yazdır', ikon: Icons.print_outlined, genis: true, onTap: _bas),
            ]),
          ),
          const SizedBox(height: 6),
          KBaslik('Mağaza içi barkod', ikon: Icons.qr_code_scanner, alt: 'Barkodu olmayan ürünlere işletme içinde okutulabilen barkod verir.'),
          if (barkodsuz.isEmpty)
            const KBos(baslik: 'Barkodsuz ürün yok', ikon: Icons.check_circle_outline, aciklama: 'Barkod & Etiket Merkezi\'ndeki tüm ürünlerin barkodu var (tartılı ürünlerin barkodu teraziden gelir).')
          else ...[
            KKart(
              renk: t.amber,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${barkodsuz.length} ürünün barkodu yok', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(barkodsuz.take(12).map((u) => '${u['ad']}').join(', ') + (barkodsuz.length > 12 ? '…' : ''), style: TextStyle(color: t.sub, fontSize: 12.5)),
                const SizedBox(height: 10),
                if (duzenler)
                  KButon('Hepsine mağaza içi barkod ver', ikon: Icons.auto_awesome, onTap: () => _icBarkod(barkodsuz.length))
                else
                  Text('Barkod vermek için düzenleme yetkisi gerekir (Demirbaş & Etiket yetkisi).', style: TextStyle(color: t.sub, fontSize: 12)),
              ]),
            ),
          ],
          TextButton.icon(onPressed: () => stAc(ctx, '/barkod-etiket', 'Barkod & Etiket'), icon: const Icon(Icons.local_offer_outlined), label: const Text('Barkod & Etiket Merkezi\'ne dön')),
        ]);
      },
    );
  }
}

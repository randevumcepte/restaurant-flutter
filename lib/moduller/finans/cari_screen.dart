import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

const Map<String, (String, IconData, Color)> _cariTip = {
  'patron': ('Patron', Icons.star_outline, Color(0xFF7C3AED)),
  'firma': ('Firma', Icons.business_outlined, Color(0xFF4F46E5)),
  'musteri': ('Müşteri', Icons.person_outline, Color(0xFF10B981)),
  'personel': ('Personel', Icons.badge_outlined, Color(0xFFD97706)),
};

(String, IconData, Color) _tip(dynamic k) => _cariTip[metinOku(k)] ?? (metinOku(k, '—'), Icons.group_outlined, const Color(0xFF64748B));

/// /cari — Cari hesaplar: liste + arama/filtre, yeni cari, cari detay (ekstre) + tahsilat (web ?id=)
class CariScreen extends StatefulWidget {
  const CariScreen({super.key});
  @override
  State<CariScreen> createState() => _CariScreenState();
}

class _CariScreenState extends State<CariScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _filtre = 'hepsi';
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/cari',
      baslik: 'Cari Hesaplar',
      ikon: Icons.account_balance_wallet_outlined,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(heroTag: 'cari_ekle', onPressed: () => _yeni(ctx, yenile), icon: const Icon(Icons.person_add_alt), label: const Text('Yeni cari')),
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final cariler = liste(v['cariler']);
    final ozet = harita(v['ozet']);
    final detay = v['detay'] is Map ? harita(v['detay']) : null;
    final aktifId = tamOku(v['aktifId']);
    final borclu = cariler.where((c) => sayiOku(c['bakiye']) > 0).length;
    final q = _ara.toLowerCase();
    final l = cariler.where((c) {
      final b = sayiOku(c['bakiye']) > 0;
      if (_filtre == 'borc' && !b) return false;
      if (_filtre == 'temiz' && b) return false;
      if (_cariTip.containsKey(_filtre) && metinOku(c['tip']) != _filtre) return false;
      if (q.isEmpty) return true;
      return '${metinOku(c['ad'])} ${metinOku(c['telefon'])}'.toLowerCase().contains(q);
    }).toList();
    final tipSay = <String, int>{};
    for (final c in cariler) {
      tipSay[metinOku(c['tip'])] = (tipSay[metinOku(c['tip'])] ?? 0) + 1;
    }

    final listeW = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KAra(ipucu: 'Cari ara (ad / telefon)…', onDegis: (s) => setState(() => _ara = s)),
      KCipler(
        secenekler: [
          ('hepsi', 'Tümü'),
          ('borc', 'Borçlu $borclu'),
          ('temiz', 'Temiz ${cariler.length - borclu}'),
          for (final e in tipSay.entries) (e.key, '${_tip(e.key).$1} ${e.value}'),
        ],
        secili: _filtre,
        onSec: (s) => setState(() => _filtre = s),
      ),
      if (cariler.isEmpty)
        KKart(
          child: KBos(
            baslik: 'Henüz cari hesap yok',
            aciklama: 'Veresiye çalışan müşteri, firma ya da personel için cari hesap aç. Açık hesap satışlar borç olarak yazılır, tahsilatı buradan alırsın.',
            ikon: Icons.account_balance_wallet_outlined,
            aksiyon: KButon('Yeni cari', ikon: Icons.person_add_alt, onTap: () => _yeni(context, yenile)),
          ),
        )
      else if (l.isEmpty)
        const KKart(child: KBos(baslik: 'Aramaya uyan cari yok', ikon: Icons.search_off))
      else
        KKart(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            for (final c in l)
              Container(
                color: tamOku(c['id']) == aktifId ? t.mor1.withValues(alpha: .07) : null,
                child: KSatir(
                  solIkon: KIkon(_tip(c['tip']).$2, renk: _tip(c['tip']).$3),
                  baslik: metinOku(c['ad']),
                  alt: '${_tip(c['tip']).$1}${metinOku(c['telefon']).isEmpty ? '' : ' · ${metinOku(c['telefon'])}'}',
                  sag: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(tl(c['bakiye']), style: TextStyle(color: sayiOku(c['bakiye']) > 0 ? t.kirmizi : t.yesil, fontSize: 15, fontWeight: FontWeight.bold)),
                    Text(sayiOku(c['bakiye']) > 0 ? 'borç' : 'temiz', style: TextStyle(color: t.sub, fontSize: 12)),
                  ]),
                  onTap: () => _ac(context, c),
                ),
              ),
          ]),
        ),
    ]);

    final gen = genisMi(context);
    return KGovde(yenile: yenile, maxGenislik: 1240, children: [
      FHero(
        etiket: 'Toplam açık alacak',
        deger: tl(ozet['toplam_alacak']),
        renk: t.mor1,
        ikon: Icons.account_balance_wallet_outlined,
        ekler: [
          FHeroMini('Hesap', sayiYaz(ozet['adet']), Icons.groups_outlined),
          if (borclu > 0) FHeroMini('Borçlu', '$borclu', Icons.warning_amber_outlined),
        ],
      ),
      if (gen && detay != null)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 5, child: listeW),
          const SizedBox(width: 14),
          Expanded(flex: 6, child: _CariDetay(id: aktifId, detay: detay, hareketler: liste(v['hareketler']), yenile: yenile, kapat: () => _k.currentState?.sorgu({}, birlestir: false))),
        ])
      else
        listeW,
    ]);
  }

  void _ac(BuildContext context, Map<String, dynamic> c) {
    if (genisMi(context)) {
      _k.currentState?.sorgu({'id': '${c['id']}'});
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CariDetayScreen(id: tamOku(c['id']), ad: metinOku(c['ad'])))).then((_) => _k.currentState?.yukle());
    }
  }

  Future<void> _yeni(BuildContext context, Future<void> Function() yenile) async {
    final ad = TextEditingController();
    final tel = TextEditingController();
    String tip = 'musteri';
    bool gonderiyor = false;
    bool eklendi = false;
    await kAltSayfa(context, baslik: 'Yeni cari hesap', icerik: (c) => StatefulBuilder(builder: (c, ss) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KAlan('İsim / Ünvan', ad, ipucu: 'örn. Et Dünyası', zorunlu: true),
        KAlan('Telefon', tel, ipucu: '05xx xxx xx xx', klavye: TextInputType.phone),
        KCipler(secenekler: const [('musteri', 'Müşteri'), ('firma', 'Firma'), ('personel', 'Personel')], secili: tip, onSec: (x) => ss(() => tip = x)),
        const SizedBox(height: 6),
        KButon('Cari oluştur', ikon: Icons.check, genis: true, yukleniyor: gonderiyor, onTap: () async {
          if (ad.text.trim().isEmpty) {
            kToast(c, 'İsim / ünvan girin.', hata: true);
            return;
          }
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/cari/ekle', {'ad': ad.text.trim(), 'telefon': tel.text.trim(), 'tip': tip}, basariMesaji: '${ad.text.trim()} cari hesabı eklendi.');
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

/// Telefonda cari detayı ayrı ekran (web /cari?id=X)
class CariDetayScreen extends StatelessWidget {
  final int id;
  final String ad;
  const CariDetayScreen({super.key, required this.id, required this.ad});
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/cari',
      q: {'id': '$id'},
      baslik: ad,
      ikon: Icons.account_balance_wallet_outlined,
      govde: (ctx, v, yenile) {
        final d = v['detay'] is Map ? harita(v['detay']) : null;
        if (d == null) return const KBos(baslik: 'Cari bulunamadı', aciklama: 'Hesap silinmiş ya da başka şubeye ait olabilir.', ikon: Icons.person_off_outlined);
        return KGovde(yenile: yenile, children: [_CariDetay(id: id, detay: d, hareketler: liste(v['hareketler']), yenile: yenile)]);
      },
    );
  }
}

class _CariDetay extends StatelessWidget {
  final int id;
  final Map<String, dynamic> detay;
  final List<Map<String, dynamic>> hareketler;
  final Future<void> Function() yenile;
  final VoidCallback? kapat;
  const _CariDetay({required this.id, required this.detay, required this.hareketler, required this.yenile, this.kapat});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final bk = sayiOku(detay['bakiye']);
    final tp = _tip(detay['tip']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KKart(
        renk: tp.$3,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            KIkon(tp.$2, renk: tp.$3, boyut: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(metinOku(detay['ad']), style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
                Text('${tp.$1}${metinOku(detay['telefon']).isEmpty ? '' : ' · ${metinOku(detay['telefon'])}'}', style: TextStyle(color: t.sub, fontSize: 13)),
              ]),
            ),
            if (kapat != null) IconButton(tooltip: 'Kapat', onPressed: kapat, icon: Icon(Icons.close, color: t.sub)),
          ]),
          const SizedBox(height: 12),
          KKpiIzgara([
            KKpi(etiket: 'Bakiye', deger: tl(bk), renk: bk > 0 ? t.kirmizi : t.yesil, alt: bk > 0 ? 'borçlu' : 'temiz'),
            KKpi(etiket: 'Toplam borç', deger: tl(detay['toplam_borc'], kisa: true), renk: t.amber),
            KKpi(etiket: 'Toplam tahsilat', deger: tl(detay['toplam_tahsilat'], kisa: true), renk: t.yesil),
          ]),
          KButon('Tahsilat al', ikon: Icons.payments_outlined, genis: true, renk: t.yesil, onTap: () => _tahsilat(context, bk)),
        ]),
      ),
      KBaslik('Hesap ekstresi', ikon: Icons.receipt_long_outlined, alt: 'Son 80 hareket', sag: KRozet('${hareketler.length}', renk: t.mor1)),
      KKart(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: hareketler.isEmpty
            ? const KBos(baslik: 'Hareket yok', aciklama: 'Bu cariye açık hesap satış yapıldığında borç, tahsilat alındığında tahsilat olarak burada listelenir.', ikon: Icons.receipt_long_outlined)
            : Column(children: [
                for (final h in hareketler)
                  KSatir(
                    solIkon: KIkon(metinOku(h['tip']) == 'borc' ? Icons.shopping_bag_outlined : Icons.payments_outlined, renk: metinOku(h['tip']) == 'borc' ? t.kirmizi : t.yesil),
                    baslik: metinOku(h['tip']) == 'borc' ? 'Satış · Borç' : 'Tahsilat${metinOku(h['odeme_sekli']).isEmpty ? '' : ' · ${_sekilAd(h['odeme_sekli'])}'}',
                    alt: '${metinOku(h['zaman'])}${metinOku(h['aciklama']).isEmpty ? '' : ' · ${metinOku(h['aciklama'])}'}',
                    sag: Text('${metinOku(h['tip']) == 'borc' ? '+' : '−'} ${tl(h['tutar'])}',
                        style: TextStyle(color: metinOku(h['tip']) == 'borc' ? t.kirmizi : t.yesil, fontSize: 14.5, fontWeight: FontWeight.w700)),
                  ),
              ]),
      ),
    ]);
  }

  static String _sekilAd(dynamic s) => const {'nakit': 'Nakit', 'havale': 'Havale', 'kredi': 'Kart'}[metinOku(s)] ?? metinOku(s);

  Future<void> _tahsilat(BuildContext context, double bakiye) async {
    final tutar = TextEditingController(text: bakiye > 0 ? bakiye.round().toString() : '');
    String sekil = 'nakit';
    bool gonderiyor = false;
    bool eklendi = false;
    await kAltSayfa(context, baslik: 'Tahsilat al · ${metinOku(detay['ad'])}', icerik: (c) => StatefulBuilder(builder: (c, ss) {
      final t = c.watch<TemaProvider>();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (bakiye > 0) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Güncel borç: ${tl(bakiye)}', style: TextStyle(color: t.kirmizi, fontSize: 14, fontWeight: FontWeight.w700))),
        KAlan('Tutar (₺)', tutar, ipucu: 'örn. 500', klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
        Text('Ödeme şekli', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        KCipler(secenekler: const [('nakit', 'Nakit'), ('havale', 'Havale'), ('kredi', 'Kart')], secili: sekil, onSec: (x) => ss(() => sekil = x)),
        if (sekil == 'nakit') Padding(padding: const EdgeInsets.only(bottom: 10), child: Text('Nakit tahsilat açık kasa vardiyasına giriş olarak yazılır.', style: TextStyle(color: t.sub, fontSize: 12.5))),
        KButon('Tahsil et', ikon: Icons.check, genis: true, renk: t.yesil, yukleniyor: gonderiyor, onTap: () async {
          final tt = sayiOku(tutar.text);
          if (tt <= 0) {
            kToast(c, 'Geçerli bir tutar girin.', hata: true);
            return;
          }
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/cari/tahsilat', {'cari_id': id, 'tutar': tt, 'odeme_sekli': sekil}, basariMesaji: '${tl(tt, kisa: true)} tahsil edildi.');
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

const Map<String, (String, IconData, Color)> kGiderKat = {
  'kira': ('Kira', Icons.home_work_outlined, Color(0xFFD97706)),
  'fatura': ('Fatura', Icons.bolt_outlined, Color(0xFF4F46E5)),
  'malzeme': ('Malzeme', Icons.inventory_2_outlined, Color(0xFF10B981)),
  'maas': ('Maaş', Icons.groups_outlined, Color(0xFF7C3AED)),
  'vergi': ('Vergi', Icons.account_balance_outlined, Color(0xFFF43F5E)),
  'diger': ('Diğer', Icons.more_horiz, Color(0xFF64748B)),
};

(String, IconData, Color) _kat(dynamic k) {
  final s = metinOku(k, 'diger');
  return kGiderKat[s] ?? (s.isEmpty ? 'Diğer' : '${s[0].toUpperCase()}${s.substring(1)}', Icons.more_horiz, const Color(0xFF64748B));
}

// ───────────────────────── /gider ─────────────────────────
class GiderlerScreen extends StatefulWidget {
  const GiderlerScreen({super.key});
  @override
  State<GiderlerScreen> createState() => _GiderlerScreenState();
}

class _GiderlerScreenState extends State<GiderlerScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _filtre = 'hepsi';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/gider',
      baslik: 'Giderler',
      ikon: Icons.receipt_long_outlined,
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
      fab: (ctx, v, yenile) => FloatingActionButton.extended(
        heroTag: 'gider_ekle',
        onPressed: () => _ekle(ctx, metinOku(v['ay'], buAy()), yenile),
        icon: const Icon(Icons.add),
        label: const Text('Gider ekle'),
      ),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final ay = metinOku(v['ay'], buAy());
    final tum = liste(v['giderler']);
    final kat = harita(v['kategoriler']);
    final toplam = sayiOku(v['toplam']);
    final l = _filtre == 'hepsi' ? tum : tum.where((g) => metinOku(g['kategori']) == _filtre).toList();
    String? enBuyuk;
    for (final e in kat.entries) {
      if (enBuyuk == null || sayiOku(e.value) > sayiOku(kat[enBuyuk])) enBuyuk = e.key;
    }
    final sayac = <String, int>{};
    for (final g in tum) {
      final k = metinOku(g['kategori'], 'diger');
      sayac[k] = (sayac[k] ?? 0) + 1;
    }
    return KGovde(yenile: yenile, children: [
      AySecici(ay: ay, onSec: (a) => setState(() { _filtre = 'hepsi'; _k.currentState?.sorgu({'ay': a}); })),
      FHero(
        etiket: 'Toplam gider',
        deger: tl(toplam),
        alt: '${tum.length} kayıt${enBuyuk == null ? '' : ' · en yüksek: ${_kat(enBuyuk).$1}'}',
        renk: t.kirmizi,
        ikon: Icons.receipt_long_outlined,
      ),
      if (kat.isNotEmpty)
        KKpiIzgara([
          for (final e in kat.entries) KKpi(etiket: _kat(e.key).$1, deger: tl(e.value, kisa: true), ikon: _kat(e.key).$2, renk: _kat(e.key).$3),
        ]),
      if (tum.isNotEmpty)
        KCipler(
          secenekler: [('hepsi', 'Tümü ${tum.length}'), for (final e in sayac.entries) (e.key, '${_kat(e.key).$1} ${e.value}')],
          secili: _filtre,
          onSec: (s) => setState(() => _filtre = s),
        ),
      if (l.isEmpty)
        KKart(
          child: KBos(
            baslik: 'Bu ay gider kaydı yok',
            aciklama: 'Kira, fatura, malzeme, vergi gibi giderleri "Gider ekle" ile gir. Nakit ödenen gider açık kasa vardiyasından da düşülür.',
            ikon: Icons.receipt_long_outlined,
            aksiyon: KButon('Gider ekle', ikon: Icons.add, onTap: () => _ekle(context, ay, yenile)),
          ),
        )
      else if (genisMi(context))
        KKart(
          child: KTablo(
            basliklar: const ['Tarih', 'Kategori', 'Açıklama', 'Tutar'],
            sagaYasla: const {3},
            satirlar: [for (final g in l) [tarihYaz(g['tarih'], saat: false), _kat(g['kategori']).$1, metinOku(g['aciklama'], '—'), tl(g['tutar'])]],
            onSatir: (i) => _sil(context, l[i], ay, yenile),
          ),
        )
      else
        KKart(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(children: [
            for (final g in l)
              KSatir(
                solIkon: KIkon(_kat(g['kategori']).$2, renk: _kat(g['kategori']).$3),
                baslik: _kat(g['kategori']).$1,
                alt: '${tarihYaz(g['tarih'], saat: false)}${metinOku(g['aciklama']).isEmpty ? '' : ' · ${metinOku(g['aciklama'])}'}',
                sag: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(tl(g['tutar']), style: TextStyle(color: t.kirmizi, fontSize: 14.5, fontWeight: FontWeight.w700)),
                  IconButton(tooltip: 'Sil', onPressed: () => _sil(context, g, ay, yenile), icon: Icon(Icons.delete_outline, color: t.sub)),
                ]),
              ),
          ]),
        ),
      if (genisMi(context) && l.isNotEmpty) Text('Silmek için satıra dokunun.', style: TextStyle(color: t.sub, fontSize: 12)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        FGecis('Tekrarlayan giderler', () => sayfaAc(context, '/tekrarlayan-gider', 'Tekrarlayan Gider')),
        FGecis('Finans özeti', () => sayfaAc(context, '/finans', 'Finans')),
      ]),
    ]);
  }

  Future<void> _sil(BuildContext context, Map<String, dynamic> g, String ay, Future<void> Function() yenile) async {
    final ok = await kOnay(context, 'Gider silinsin mi?', tehlikeli: true, evet: 'Sil', aciklama: '${_kat(g['kategori']).$1} · ${tl(g['tutar'])} · ${tarihYaz(g['tarih'], saat: false)}');
    if (!ok || !context.mounted) return;
    if (await kopruGonder(context, '/gider/sil', {'id': g['id'], 'ay': ay}, basariMesaji: 'Gider silindi.')) await yenile();
  }

  Future<void> _ekle(BuildContext context, String ay, Future<void> Function() yenile) async {
    final tutar = TextEditingController();
    final aciklama = TextEditingController();
    String kategori = 'kira';
    String tarih = bugunYmd();
    bool nakit = true;
    bool gonderiyor = false;
    bool eklendi = false;
    await kAltSayfa(context, baslik: 'Yeni Gider', icerik: (c) => StatefulBuilder(builder: (c, ss) {
      final t = c.watch<TemaProvider>();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Kategori', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final k in const ['kira', 'fatura', 'malzeme', 'vergi', 'diger'])
            ChoiceChip(
              avatar: Icon(kGiderKat[k]!.$2, size: 17, color: kategori == k ? Colors.white : kGiderKat[k]!.$3),
              label: Text(kGiderKat[k]!.$1, style: TextStyle(color: kategori == k ? Colors.white : t.ink, fontWeight: FontWeight.w700, fontSize: 13.5)),
              selected: kategori == k,
              selectedColor: kGiderKat[k]!.$3,
              backgroundColor: t.card2,
              showCheckmark: false,
              onSelected: (_) => ss(() => kategori = k),
            ),
        ]),
        const SizedBox(height: 14),
        KAlan('Tutar (₺)', tutar, ipucu: 'örn. 1500', klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
        FTarihAlan('Tarih', deger: tarih, onSec: (s) => ss(() => tarih = s ?? bugunYmd())),
        KAlan('Açıklama (opsiyonel)', aciklama, ipucu: 'örn. Eylül kirası'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: nakit,
          activeThumbColor: t.mor1,
          onChanged: (x) => ss(() => nakit = x),
          title: Text('Kasadan nakit ödendi', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
          subtitle: Text('Açıksa tutar açık kasa vardiyasından çıkış olarak düşülür (web ile aynı).', style: TextStyle(color: t.sub, fontSize: 12.5)),
        ),
        const SizedBox(height: 8),
        KButon('Kaydet', ikon: Icons.check_circle_outline, genis: true, yukleniyor: gonderiyor, onTap: () async {
          final tt = sayiOku(tutar.text);
          if (tt <= 0) {
            kToast(c, 'Tutar sıfırdan büyük olmalı.', hata: true);
            return;
          }
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/gider/ekle', {
            'ay': ay,
            'kategori': kategori,
            'tutar': tt,
            'tarih': tarih,
            'aciklama': aciklama.text.trim(),
            'nakit': nakit ? '1' : '0',
          }, basariMesaji: 'Gider eklendi.');
          if (!c.mounted) return;
          ss(() => gonderiyor = false);
          if (ok) {
            eklendi = true;
            Navigator.pop(c);
          }
        }),
      ]);
    }));
    if (!eklendi) return;
    final yeniAy = tarih.length >= 7 ? tarih.substring(0, 7) : ay;
    if (yeniAy != ay) {
      await _k.currentState?.sorgu({'ay': yeniAy});
    } else {
      await yenile();
    }
  }
}

// ───────────────────────── /tekrarlayan-gider ─────────────────────────
const _tkKat = [('kira', 'Kira'), ('fatura', 'Fatura/Abonelik'), ('maas', 'Maaş/SGK'), ('vergi', 'Vergi'), ('hizmet', 'Hizmet'), ('diger', 'Diğer')];

class TekrarlayanGiderScreen extends StatelessWidget {
  const TekrarlayanGiderScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/tekrarlayan-gider',
      baslik: 'Tekrarlayan Gider',
      ikon: Icons.event_repeat,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(heroTag: 'tg_ekle', onPressed: () => _ekle(ctx, yenile), icon: const Icon(Icons.add), label: const Text('Ekle')),
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final l = liste(v['liste']);
        final aylik = sayiOku(v['aylikTop']);
        final yillik = sayiOku(v['yillikTop']);
        return KGovde(yenile: yenile, maxGenislik: 960, children: [
          KKpiIzgara([
            KKpi(etiket: 'Aylık tekrarlayan yük', deger: tl(aylik, kisa: true), ikon: Icons.calendar_month_outlined, renk: t.kirmizi),
            KKpi(etiket: 'Yıllık tekrarlayan yük', deger: tl(yillik, kisa: true), alt: 'aylık×12 + yıllık = ${tl(aylik * 12 + yillik, kisa: true)}', ikon: Icons.event_repeat, renk: t.amber),
          ]),
          if (l.isEmpty)
            KKart(
              child: KBos(
                baslik: 'Henüz tekrarlayan gider yok',
                aciklama: 'Kira, abonelik, muhasebe ücreti gibi her ay/yıl tekrar eden sabit giderleri ekle; aylık yükü burada görürsün.',
                ikon: Icons.event_repeat,
                aksiyon: KButon('Ekle', ikon: Icons.add, onTap: () => _ekle(ctx, yenile)),
              ),
            )
          else
            KKart(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(children: [
                for (final g in l)
                  Opacity(
                    opacity: tamOku(g['aktif']) == 1 ? 1 : .5,
                    child: KSatir(
                      solIkon: KIkon(Icons.event_repeat, renk: tamOku(g['aktif']) == 1 ? t.mor1 : t.sub),
                      baslik: metinOku(g['ad']),
                      alt: '${_tkKatAd(g['kategori'])} · her ayın ${sayiYaz(g['gun'])}’i · ${metinOku(g['periyot']) == 'yillik' ? 'yıllık' : 'aylık'}${tamOku(g['aktif']) == 1 ? '' : ' · pasif'}',
                      sag: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(tl(g['tutar'], kisa: true), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700)),
                        Switch(
                          value: tamOku(g['aktif']) == 1,
                          activeThumbColor: t.mor1,
                          onChanged: (x) async {
                            if (await kopruGonder(ctx, '/tekrarlayan-gider/durum', {'id': g['id'], 'aktif': x ? 1 : 0}, basariMesaji: x ? 'Aktifleştirildi.' : 'Pasifleştirildi.')) await yenile();
                          },
                        ),
                        IconButton(
                          tooltip: 'Sil',
                          icon: Icon(Icons.delete_outline, color: t.sub),
                          onPressed: () async {
                            if (!await kOnay(ctx, '"${metinOku(g['ad'])}" silinsin mi?', tehlikeli: true, evet: 'Sil')) return;
                            if (!ctx.mounted) return;
                            if (await kopruGonder(ctx, '/tekrarlayan-gider/sil', {'id': g['id']})) await yenile();
                          },
                        ),
                      ]),
                    ),
                  ),
              ]),
            ),
        ]);
      },
    );
  }

  static String _tkKatAd(dynamic k) {
    final s = metinOku(k, 'diger');
    for (final (a, b) in _tkKat) {
      if (a == s) return b;
    }
    return s;
  }

  static Future<void> _ekle(BuildContext context, Future<void> Function() yenile) async {
    final ad = TextEditingController();
    final tutar = TextEditingController();
    final gun = TextEditingController(text: '1');
    String kategori = 'diger';
    String periyot = 'aylik';
    bool gonderiyor = false;
    bool eklendi = false;
    await kAltSayfa(context, baslik: 'Tekrarlayan gider ekle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        KAlan('Gider adı', ad, ipucu: 'Kira, internet, muhasebe ücreti…', zorunlu: true),
        KSecim<String>('Kategori', deger: kategori, secenekler: _tkKat, onSec: (x) => ss(() => kategori = x ?? 'diger')),
        KAlan('Tutar (₺)', tutar, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
        KSecim<String>('Periyot', deger: periyot, secenekler: const [('aylik', 'Aylık'), ('yillik', 'Yıllık')], onSec: (x) => ss(() => periyot = x ?? 'aylik')),
        KAlan('Ayın günü (1-28)', gun, klavye: TextInputType.number),
        KButon('Ekle', ikon: Icons.add, genis: true, yukleniyor: gonderiyor, onTap: () async {
          if (ad.text.trim().isEmpty || sayiOku(tutar.text) <= 0) {
            kToast(c, 'Ad ve tutar gerekli.', hata: true);
            return;
          }
          ss(() => gonderiyor = true);
          final ok = await kopruGonder(c, '/tekrarlayan-gider/ekle', {
            'ad': ad.text.trim(),
            'kategori': kategori,
            'tutar': sayiOku(tutar.text),
            'periyot': periyot,
            'gun': tamOku(gun.text).clamp(1, 28),
          });
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

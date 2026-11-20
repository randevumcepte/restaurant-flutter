import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

// ───────────────────────── /bilanco ─────────────────────────
class BilancoScreen extends StatelessWidget {
  const BilancoScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/bilanco',
      baslik: 'Bilanço (özet)',
      ikon: Icons.balance,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final varlik = harita(v['varliklar']);
        final borc = harita(v['borclar']);
        final oz = sayiOku(v['ozkaynak']);
        Widget sutun(String baslik, IconData ikon, Color renk, Map<String, dynamic> m, dynamic toplam, String topAd) => KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KBaslik(baslik, ikon: ikon, renk: renk),
                for (final e in m.entries) FSatir(e.key, tl(e.value)),
                FSatir(topAd, tl(toplam), vurgu: true, renk: renk),
              ]),
            );
        return KGovde(yenile: yenile, maxGenislik: 960, children: [
          FIzgara([
            sutun('Varlıklar (aktif)', Icons.trending_up, t.yesil, varlik, v['topVar'], 'Toplam varlık'),
            sutun('Borçlar (pasif)', Icons.trending_down, t.kirmizi, borc, v['topBorc'], 'Toplam borç'),
          ], minGenislik: 400),
          FHero(etiket: 'Net özkaynak (varlık − borç)', deger: tl(oz), renk: oz >= 0 ? t.mor1 : t.kirmizi, ikon: Icons.account_balance_outlined),
          FNot('Bu basitleştirilmiş yönetim bilançosudur, resmî bilanço değildir. Kasa nakdi, peşin giderler, amortisman birikmişi, SGK/vergi tahakkukları ve sermaye kalemleri tam yansımaz. Resmî bilanço için mali müşavirinle çalış.', baglantilar: [
            FGecis('Banka hesapları', () => sayfaAc(ctx, '/banka', 'Banka Hesapları')),
            FGecis('Çek / Senet', () => sayfaAc(ctx, '/cek-senet', 'Çek / Senet')),
            FGecis('Demirbaş', () => sayfaAc(ctx, '/demirbas', 'Demirbaş')),
          ]),
        ]);
      },
    );
  }
}

// ───────────────────────── /vergi-takvimi ─────────────────────────
class VergiTakvimiScreen extends StatelessWidget {
  const VergiTakvimiScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/vergi-takvimi',
      baslik: 'Vergi Takvimi',
      ikon: Icons.event_available_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final l = liste(v['liste']);
        return KGovde(yenile: yenile, maxGenislik: 860, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, left: 2),
            child: Text('Yaklaşan beyanname ve ödeme son tarihleri — en yakın üstte. Kırmızı ≤3 gün, turuncu ≤7 gün.', style: TextStyle(color: t.sub, fontSize: 13)),
          ),
          if (l.isEmpty) const KBos(baslik: 'Takvim boş', ikon: Icons.event_available_outlined),
          for (final x in l) _vergiSatir(ctx, t, x),
          FNot('Tarihler standart takvime göre yaklaşıktır; resmî tatil/uzatma olabilir. Kesin tarih ve mükellefiyetini mali müşavirinle teyit et.', baglantilar: [
            FGecis('KDV Özeti', () => sayfaAc(ctx, '/kdv-ozet', 'KDV Özeti')),
          ]),
        ]);
      },
    );
  }

  Widget _vergiSatir(BuildContext context, TemaProvider t, Map<String, dynamic> x) {
    final kalan = tamOku(x['kalan']);
    final kc = kalan < 0 ? t.sub : (kalan <= 3 ? t.kirmizi : (kalan <= 7 ? t.amber : t.yesil));
    final kt = kalan < 0 ? '${kalan.abs()} gün geçti' : (kalan == 0 ? 'BUGÜN' : '$kalan gün kaldı');
    final r = renkOku(x['renk'], t.mor1);
    return KKart(
      renk: kc,
      child: Row(children: [
        KIkon(ikonAdi(metinOku(x['ikon']), Icons.event_note_outlined), renk: r),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(metinOku(x['ad']), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 3),
            Text(metinOku(x['aciklama']), style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.35)),
          ]),
        ),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(tarihYaz(x['tarih'], saat: false), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          KRozet(kt, renk: kc),
        ]),
      ]),
    );
  }
}

// ───────────────────────── /e-defter ─────────────────────────
class EDefterScreen extends StatelessWidget {
  const EDefterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/e-defter',
      baslik: 'e-Defter (hazırlık)',
      ikon: Icons.menu_book_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final g = liste(v['gecmis']);
        Widget adim(int no, String baslik, String acik, [String? url, String? ad]) => KKart(
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                CircleAvatar(radius: 15, backgroundColor: t.mor1, child: Text('$no', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(baslik, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 3),
                    Text(acik, style: TextStyle(color: t.sub, fontSize: 13, height: 1.35)),
                    if (url != null) Padding(padding: const EdgeInsets.only(top: 8), child: FGecis(ad!, () => sayfaAc(ctx, url, ad))),
                  ]),
                ),
              ]),
            );
        return KGovde(yenile: yenile, maxGenislik: 860, children: [
          KKart(
            renk: t.mor1,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('e-Defter berat süreci', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('ResteOS mali hareketlerini mahsup fişi olarak üretir; e-Defter (yevmiye + kebir) ve GİB berat yüklemesi mali müşavirin/entegratör üzerinden yapılır. Bu ekran hazırlık ve takip içindir.',
                  style: TextStyle(color: t.sub2, fontSize: 13.5, height: 1.4)),
            ]),
          ),
          adim(1, 'Mahsup fişini üret & aktar', 'Satış + alış → dengeli mahsup fişi (Logo/Netsis/Excel).', '/muhasebe-entegrasyon', 'Muhasebe Entegrasyonu'),
          adim(2, 'Mali müşavir yevmiye/kebir oluşturur', 'Fişler muhasebe programında e-Deftere dönüşür (aylık dönem).'),
          adim(3, 'Berat üretimi ve GİB\'e yükleme', 'Dönem defteri + berat GİB\'e yüklenir. Son tarih: 3 ay sonraki ayın sonu.', '/vergi-takvimi', 'Vergi Takvimi'),
          adim(4, 'Onay & arşiv', 'GİB onaylı berat arşivlenir; KDV/Muhtasar beyanla tutarlı olmalı.', '/beyanname', 'Beyanname Hazırlık'),
          const SizedBox(height: 6),
          KBaslik('Son muhasebe aktarımları', ikon: Icons.sync_alt, renk: t.mavi),
          KKart(
            child: g.isEmpty
                ? KBos(
                    baslik: 'Henüz mahsup fişi aktarımı yok',
                    aciklama: 'Muhasebe Entegrasyonu ekranından ilk aktarım dosyasını indirdiğinde ya da ERP\'ye gönderdiğinde burada listelenir.',
                    ikon: Icons.sync_alt,
                    aksiyon: KButon('İlk aktarımı yap', ikon: Icons.arrow_forward, ikincil: true, onTap: () => sayfaAc(ctx, '/muhasebe-entegrasyon', 'Muhasebe Entegrasyonu')),
                  )
                : Column(children: [
                    for (final x in g)
                      KSatir(
                        solIkon: KIkon(Icons.sync_alt, renk: t.mavi),
                        baslik: '${metinOku(x['baglanti_tipi'], 'aktarım')}${metinOku(x['donem']).isEmpty ? '' : ' · ${metinOku(x['donem'])}'}',
                        alt: tarihYaz(x['created_at']),
                      ),
                  ]),
          ),
          const FNot('Doğrudan GİB e-Defter/berat gönderimi bu sürümde yoktur (özel entegratör + mali mühür gerektirir). ResteOS mahsup fişini hazırlar, gerisini mali müşavirin yürütür.'),
        ]);
      },
    );
  }
}

// ───────────────────────── /amortisman ─────────────────────────
class AmortismanScreen extends StatelessWidget {
  const AmortismanScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/amortisman',
      baslik: 'Amortisman',
      ikon: Icons.trending_down,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final l = liste(v['liste']);
        final gen = genisMi(ctx);
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Toplam demirbaş (brüt)', deger: tl(v['topBedel'], kisa: true), ikon: Icons.inventory_2_outlined, renk: t.mor1),
            KKpi(etiket: 'Birikmiş amortisman sonrası net', deger: tl(v['topNet'], kisa: true), ikon: Icons.savings_outlined, renk: t.yesil),
            KKpi(etiket: 'Bu yılki amortisman gideri', deger: tl(v['topYillik'], kisa: true), ikon: Icons.trending_down, renk: t.kirmizi),
          ]),
          if (l.isEmpty)
            KKart(
              child: KBos(
                baslik: 'Amortismana tabi demirbaş yok',
                aciklama: 'Amortisman, alış bedeli girilmiş demirbaşlardan hesaplanır. Demirbaş ekranından demirbaş ekleyip alış bedeli ve tarihini gir.',
                ikon: Icons.inventory_2_outlined,
                aksiyon: KButon('Demirbaş ekle', ikon: Icons.add, ikincil: true, onTap: () => sayfaAc(ctx, '/demirbas', 'Demirbaş')),
              ),
            )
          else if (gen)
            KKart(
              child: KTablo(
                basliklar: const ['Demirbaş', 'Kategori', 'Alış tarihi', 'Bedel', 'Oran', 'Yıllık amort.', 'Geçen yıl', 'Birikmiş', 'Net değer'],
                sagaYasla: const {3, 4, 5, 6, 7, 8},
                satirlar: [
                  for (final d in l)
                    [metinOku(d['ad']), metinOku(d['kategori'], '—'), tarihYaz(d['tarih'], saat: false), tl(d['bedel'], kisa: true), '%${sayiYaz(d['oran'])}', tl(d['yillik'], kisa: true), sayiYaz(d['gecen']), tl(d['birikmis'], kisa: true), tl(d['net'], kisa: true)],
                ],
              ),
            )
          else
            for (final d in l)
              KKart(
                renk: sayiOku(d['net']) > 0 ? t.yesil : t.kirmizi,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(metinOku(d['ad']), style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('${metinOku(d['kategori'], '—')} · ${tarihYaz(d['tarih'], saat: false)} · %${sayiYaz(d['oran'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  FSatir('Bedel', tl(d['bedel'], kisa: true)),
                  FSatir('Yıllık amortisman', tl(d['yillik'], kisa: true)),
                  FSatir('Birikmiş (${sayiYaz(d['gecen'])} yıl)', tl(d['birikmis'], kisa: true)),
                  FSatir('Net değer', tl(d['net'], kisa: true), vurgu: true, renk: sayiOku(d['net']) > 0 ? t.yesil : t.kirmizi),
                ]),
              ),
          FNot('Oranlar standart VUK sınıflarına göre yaklaşıktır (normal/doğrusal amortisman). Kıst amortisman, yenileme fonu ve kesin oranlar için mali müşavirinle teyit et. Kategori/bedel Demirbaş ekranından güncellenir.', baglantilar: [
            FGecis('Demirbaş', () => sayfaAc(ctx, '/demirbas', 'Demirbaş')),
          ]),
        ]);
      },
    );
  }
}

// ───────────────────────── /muhasebe ─────────────────────────
class MuhasebeDefterScreen extends StatelessWidget {
  const MuhasebeDefterScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/muhasebe',
      baslik: 'Muhasebe',
      ikon: Icons.menu_book_outlined,
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final gelir = sayiOku(v['gelir']);
        final gider = sayiOku(v['gider']);
        final net = gelir - gider;
        final kasa = liste(v['kasa']);
        final ted = liste(v['tedarikciCari']);
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Gelir (30 gün)', deger: tl(gelir, kisa: true), ikon: Icons.arrow_downward, renk: t.yesil),
            KKpi(etiket: 'Gider / Alış (30 gün)', deger: tl(gider, kisa: true), ikon: Icons.arrow_upward, renk: t.kirmizi),
            KKpi(etiket: 'Brüt (Gelir − Alış)', deger: tl(net, kisa: true), ikon: net >= 0 ? Icons.trending_up : Icons.trending_down, renk: net >= 0 ? t.yesil : t.kirmizi),
          ]),
          FIzgara([
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KBaslik('Kasa / Ödeme Tipi Dağılımı', alt: 'Son 30 gün', ikon: Icons.point_of_sale, renk: t.mavi),
                if (kasa.isEmpty)
                  const KBos(baslik: 'Son 30 günde ödeme yok', aciklama: 'Adisyonlara ödeme alındıkça ödeme tipine göre dağılım burada görünür.', ikon: Icons.point_of_sale)
                else
                  for (final k in kasa) FSatir('${_tipYaz(k['tip'])} (${sayiYaz(k['adet'])} işlem)', tl(k['t'], kisa: true)),
              ]),
            ),
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                KBaslik('Tedarikçi Cari (borç)', ikon: Icons.local_shipping_outlined, renk: t.kirmizi),
                if (ted.isEmpty)
                  const KBos(baslik: 'Cari kayıt yok', aciklama: 'Tedarikçi borcu alış faturalarından oluşur. Alış faturası Satın Alma › Alış Faturaları ekranından girilir.', ikon: Icons.receipt_long_outlined)
                else
                  for (final x in ted) FSatir('${metinOku(x['ad'], 'Tedarikçi')} · ${sayiYaz(x['fatura'])} fatura', tl(x['borc'], kisa: true), renk: t.kirmizi),
              ]),
            ),
          ], minGenislik: 420),
          FNot('Buradaki rakamlar gerçek satış + alış defterinden anlık hesaplanır. Tam muhasebe (cari mutabakat, mizan, e-defter) için muhasebe programı entegrasyonu kullanılır.', baglantilar: [
            FGecis('Muhasebe Entegrasyonu', () => sayfaAc(ctx, '/muhasebe-entegrasyon', 'Muhasebe Entegrasyonu')),
            FGecis('Tedarikçi Yaşlandırma', () => sayfaAc(ctx, '/tedarikci-yaslandirma', 'Tedarikçi Yaşlandırma')),
          ]),
        ]);
      },
    );
  }

  static String _tipYaz(dynamic v) {
    final s = metinOku(v, '—').replaceAll('_', ' ');
    const ad = {'nakit': 'Nakit', 'kredi': 'Kredi kartı', 'yemek karti': 'Yemek kartı', 'acik hesap': 'Açık hesap'};
    return ad[s] ?? (s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}');
  }
}

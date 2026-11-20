import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'crm_ortak.dart';

/// Web /odul-raporu — son 200 ödül kullanımı (odul_kullanimlari + müşteri + kasiyer) ve özet:
///  ozet {adet, puan, bugun, bekleyen}; rows [{id, odul_ad, puan, kod, durum(kullanildi|bekliyor|iptal), kullanildi_at, created_at, m_ad, m_soyad, m_tel, kasiyer_ad}]
class CrmOdulRaporuScreen extends StatefulWidget {
  const CrmOdulRaporuScreen({super.key});

  @override
  State<CrmOdulRaporuScreen> createState() => _CrmOdulRaporuScreenState();
}

class _CrmOdulRaporuScreenState extends State<CrmOdulRaporuScreen> {
  String _filtre = '';
  String _ara = '';

  static const _durumAd = {'kullanildi': 'Kullanıldı', 'bekliyor': 'Bekliyor', 'iptal': 'İptal'};

  Color _durumRenk(TemaProvider t, String d) => d == 'kullanildi' ? t.yesil : (d == 'bekliyor' ? t.amber : t.sub);

  String _musteri(Map<String, dynamic> x) {
    final ad = '${metinOku(x['m_ad'])} ${metinOku(x['m_soyad'])}'.trim();
    return ad.isNotEmpty ? ad : metinOku(x['m_tel'], 'Müşteri');
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/odul-raporu',
      baslik: 'Ödül Raporu',
      ikon: Icons.redeem_outlined,
      araclar: (ctx, v, y) => [
        IconButton(tooltip: 'Ödül doğrula', onPressed: () => crmSayfaAc(ctx, '/odul-dogrula', 'Ödül Doğrula'), icon: const Icon(Icons.verified_outlined)),
      ],
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final o = harita(v['ozet']);
        final hepsi = liste(v['rows']);
        final q = _ara.toLowerCase();
        final l = hepsi.where((x) {
          if (_filtre.isNotEmpty && metinOku(x['durum']) != _filtre) return false;
          if (q.isEmpty) return true;
          return _musteri(x).toLowerCase().contains(q) || metinOku(x['odul_ad']).toLowerCase().contains(q) || metinOku(x['kod']).toLowerCase().contains(q);
        }).toList();
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Kullanılan ödül', deger: sayiYaz(o['adet']), ikon: Icons.redeem_outlined, renk: t.mor1),
            KKpi(etiket: 'Harcanan puan', deger: sayiYaz(o['puan']), ikon: Icons.stars_outlined, renk: t.amber),
            KKpi(etiket: 'Bugün', deger: sayiYaz(o['bugun']), ikon: Icons.today_outlined, renk: t.yesil),
            KKpi(etiket: 'Bekleyen', deger: sayiYaz(o['bekleyen']), ikon: Icons.hourglass_bottom, renk: t.kirmizi, onTap: () => setState(() => _filtre = 'bekliyor')),
          ]),
          const SizedBox(height: 12),
          KAra(ipucu: 'Müşteri, ödül veya kod ara…', onDegis: (x) => setState(() => _ara = x.trim())),
          const SizedBox(height: 10),
          KCipler(
            secenekler: const [('', 'Tümü'), ('kullanildi', 'Kullanıldı'), ('bekliyor', 'Bekliyor'), ('iptal', 'İptal')],
            secili: _filtre,
            onSec: (x) => setState(() => _filtre = x),
          ),
          const SizedBox(height: 12),
          if (l.isEmpty)
            KBos(
              baslik: hepsi.isEmpty ? 'Henüz ödül kullanımı yok' : 'Bu filtrede kayıt yok',
              aciklama: hepsi.isEmpty
                  ? 'Müşteri puanıyla ödül talep edince ya da çarkıfelekte indirim kuponu kazanınca kod oluşur; kasada "Ödül Doğrula" ekranında kod okutulunca burada "Kullanıldı" olarak görünür.'
                  : 'Filtreyi ya da aramayı değiştirin.',
              ikon: Icons.redeem_outlined,
              aksiyon: KButon('Ödül Doğrula', ikon: Icons.verified_outlined, onTap: () => crmSayfaAc(ctx, '/odul-dogrula', 'Ödül Doğrula')),
            )
          else if (genisMi(ctx))
            KKart(
              padding: const EdgeInsets.all(6),
              child: KTablo(
                basliklar: const ['Tarih', 'Müşteri', 'Ödül', 'Kod', 'Puan', 'Kasiyer', 'Durum'],
                sagaYasla: const {4},
                satirlar: [
                  for (final x in l)
                    [
                      tarihYaz(x['kullanildi_at'] ?? x['created_at']),
                      _musteri(x),
                      metinOku(x['odul_ad'], '—'),
                      metinOku(x['kod'], '—'),
                      sayiYaz(x['puan']),
                      metinOku(x['kasiyer_ad'], '—'),
                      _durumAd[metinOku(x['durum'])] ?? metinOku(x['durum']),
                    ]
                ],
              ),
            )
          else
            for (final x in l)
              KKart(
                renk: _durumRenk(t, metinOku(x['durum'])),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('🎁 ${metinOku(x['odul_ad'], 'Ödül')}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      Text('${_musteri(x)} · ${tarihYaz(x['kullanildi_at'] ?? x['created_at'])}', style: TextStyle(color: t.sub2, fontSize: 13)),
                      Text('Kod: ${metinOku(x['kod'], '—')} · Kasiyer: ${metinOku(x['kasiyer_ad'], '—')}', style: TextStyle(color: t.sub, fontSize: 12.5)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${sayiYaz(x['puan'])} puan', style: TextStyle(color: t.mor1, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 4),
                    KRozet(_durumAd[metinOku(x['durum'])] ?? metinOku(x['durum']), renk: _durumRenk(t, metinOku(x['durum']))),
                  ]),
                ]),
              ),
        ]);
      },
    );
  }
}

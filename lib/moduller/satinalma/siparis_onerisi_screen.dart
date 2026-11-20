import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /siparis-onerisi — stoğu azalanlar + son 30 gün tüketim → sipariş listesi; par (hedef stok) düzenle;
/// seçilenlerden sipariş taslağı ya da (patron + satın alma ekibi varsa) satın almaya talep.
class SiparisOnerisiScreen extends StatefulWidget {
  const SiparisOnerisiScreen({super.key});
  @override
  State<SiparisOnerisiScreen> createState() => _SiparisOnerisiScreenState();
}

class _SiparisOnerisiScreenState extends State<SiparisOnerisiScreen> {
  final Map<int, bool> _sec = {};
  final Map<int, TextEditingController> _mik = {};
  bool _gonderiyor = false;

  TextEditingController _k(Map<String, dynamic> o) => _mik.putIfAbsent(tamOku(o['id']), () => TextEditingController(text: sayiYaz(o['oneri']).replaceAll('.', '')));

  @override
  Widget build(BuildContext context) {
    return KopruEkran(yol: '/siparis-onerisi', baslik: 'Sipariş Önerisi', ikon: Icons.auto_awesome_outlined, govde: _govde);
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final l = liste(v['oneriler']);
    final ikili = v['patronMu'] == true && v['satinalmaVar'] == true;
    double toplam = 0, tahmini = 0;
    for (final o in l) {
      final f = sayiOku(harita(o['ted'])['fiyat']);
      tahmini += sayiOku(o['oneri']) * f;
      if (_sec[tamOku(o['id'])] ?? true) toplam += sayiOku(_k(o).text) * f;
    }
    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Sipariş bekleyen malzeme', deger: '${l.length}', ikon: Icons.inventory_2_outlined, renk: t.mor1),
        KKpi(etiket: 'Kritik altında', deger: '${l.where((o) => o['kritikMi'] == true).length}', ikon: Icons.warning_amber_outlined, renk: t.kirmizi),
        KKpi(etiket: 'Tahmini tutar', deger: tl(tahmini, kisa: true), ikon: Icons.payments_outlined, renk: t.mavi),
        KKpi(etiket: 'Seçili toplam', deger: tl(toplam, kisa: true), ikon: Icons.shopping_cart_outlined, renk: t.yesil),
      ]),
      const SaBilgi('Bu ekran sizin yerinize alışveriş listesi çıkarır: stoğu azalan malzemeleri + son 30 günde ne kadar harcandığını hesaplar. Hedef stok (par) = "elimde hep en az şu kadar dursun" dediğiniz miktar; belirlemezseniz kritik stoğun 2 katı hedeflenir.',
          ikon: Icons.lightbulb_outline),
      if (l.isEmpty)
        const KBos(
            baslik: 'Her şey yeterli',
            aciklama: 'Hedef (par) / kritik seviyenin altına düşen malzeme yok. Hedef stok belirlemediyseniz malzeme kartından belirleyebilirsiniz (Stok > Malzemeler).',
            ikon: Icons.check_circle_outline)
      else ...[
        Row(children: [
          Checkbox(
            value: l.every((o) => _sec[tamOku(o['id'])] ?? true),
            onChanged: (b) => setState(() {
              for (final o in l) {
                _sec[tamOku(o['id'])] = b == true;
              }
            }),
          ),
          Text('Tümünü seç', style: TextStyle(color: t.sub2, fontWeight: FontWeight.w700)),
        ]),
        SaIzgara([for (final o in l) _kart(o, t, yenile)], minGenislik: 440),
        const SizedBox(height: 8),
        if (ikili) ...[
          KButon('Satın Almaya Gönder', ikon: Icons.forward_to_inbox, genis: true, yukleniyor: _gonderiyor, onTap: () => _gonder(l, '/siparis-onerisi/talep')),
          const SizedBox(height: 8),
          KButon('Sipariş Oluştur', ikon: Icons.shopping_cart_checkout, genis: true, ikincil: true, yukleniyor: _gonderiyor, onTap: () => _gonder(l, '/siparis-onerisi/olustur')),
          const SizedBox(height: 8),
          const SaBilgi('Satın Almaya Gönder (önerilen): bu listeyi talep olarak satın alma ekibine yollar → onlar Fiyat Araştır / Hemen Sipariş ile devam eder.\nSipariş Oluştur: ekibi atlayıp direkt taslak sipariş oluşturur (tedarikçiye göre gruplu).'),
        ] else ...[
          KButon('Seçililerden Sipariş Taslağı Oluştur', ikon: Icons.shopping_cart_checkout, genis: true, yukleniyor: _gonderiyor, onTap: () => _gonder(l, '/siparis-onerisi/olustur')),
          const SizedBox(height: 8),
          const SaBilgi('Siparişler tedarikçiye göre gruplanıp taslak olarak oluşturulur.'),
        ],
      ],
    ]);
  }

  Widget _kart(Map<String, dynamic> o, TemaProvider t, Future<void> Function() yenile) {
    final id = tamOku(o['id']);
    final ted = harita(o['ted']);
    final kritik = o['kritikMi'] == true;
    final f = sayiOku(ted['fiyat']);
    return KKart(
      renk: kritik ? t.kirmizi : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Checkbox(value: _sec[id] ?? true, onChanged: (b) => setState(() => _sec[id] = b == true)),
          Expanded(child: Text('${metinOku(o['ad'])} / ${metinOku(o['birim'])}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5))),
          if (kritik) KRozet('KRİTİK', renk: t.kirmizi),
        ]),
        Wrap(spacing: 14, runSpacing: 4, children: [
          Text('Mevcut: ${sayiYaz(o['mevcut'])}', style: TextStyle(color: kritik ? t.kirmizi : t.ink, fontWeight: FontWeight.w700, fontSize: 13)),
          Text('Kritik: ${sayiYaz(o['kritik'])}', style: TextStyle(color: t.sub, fontSize: 13)),
          Text('Günlük tüketim: ${sayiYaz(o['gunluk'])}', style: TextStyle(color: t.sub, fontSize: 13)),
        ]),
        const SizedBox(height: 6),
        InkWell(
          onTap: () => _par(o, yenile),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              Icon(Icons.flag_outlined, size: 16, color: t.mor1),
              const SizedBox(width: 6),
              Text('Hedef stok (par): ${sayiOku(o['hedef']) > 0 ? sayiYaz(o['hedef']) : 'belirlenmedi'}', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(width: 4),
              Icon(Icons.edit_outlined, size: 15, color: t.mor1),
            ]),
          ),
        ),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          SizedBox(width: 130, child: KAlan('Sipariş miktarı', _k(o), klavye: const TextInputType.numberWithOptions(decimal: true))),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${metinOku(ted['ad'], '—')}${f > 0 ? ' (${tl(f)})' : ''}', textAlign: TextAlign.right, style: TextStyle(color: t.sub2, fontSize: 12.5)),
                Text(tl(sayiOku(_k(o).text) * f), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15)),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }

  Future<void> _par(Map<String, dynamic> o, Future<void> Function() yenile) async {
    final s = await saMetinSor(context, 'Hedef stok (par) — ${metinOku(o['ad'])}',
        aciklama: '"Elimde hep en az şu kadar dursun" dediğiniz miktar (${metinOku(o['birim'])}).', baslangic: sayiOku(o['hedef']) > 0 ? '${o['hedef']}' : '', satir: 1, klavye: const TextInputType.numberWithOptions(decimal: true), evet: 'Kaydet');
    if (s == null || !mounted) return;
    final c = await saGonder(context, '/siparis-onerisi/par', {'malzeme_id': o['id'], 'hedef_stok': sayiOku(s)}, json: false, sessiz: true);
    if (c?.ok == true && mounted) {
      kToast(context, 'Par (hedef stok) güncellendi.');
      yenile();
    }
  }

  Future<void> _gonder(List<Map<String, dynamic>> l, String yol) async {
    final kal = <Map<String, dynamic>>[];
    for (final o in l) {
      if (!(_sec[tamOku(o['id'])] ?? true)) continue;
      final m = sayiOku(_k(o).text);
      if (m <= 0) continue;
      final ted = harita(o['ted']);
      kal.add({'malzeme_id': tamOku(o['id']), 'tedarikci_id': tamOku(ted['id']), 'birim_id': tamOku(ted['birim_id']), 'miktar': m, 'fiyat': sayiOku(ted['fiyat'])});
    }
    if (kal.isEmpty) return kToast(context, 'En az bir ürün seçin.', hata: true);
    setState(() => _gonderiyor = true);
    final c = await saGonder(context, yol, {'kalemler': jsonEncode(kal)}, json: false, sessiz: true);
    if (!mounted) return;
    setState(() => _gonderiyor = false);
    if (c == null || !c.ok) return;
    // Sunucu hatada aynı sayfaya, başarıda sipariş / talep sayfasına yönlendirir
    if (metinOku(c.j['yonlendir']) == '/siparis-onerisi') {
      kToast(context, metinOku(c.j['hata'], 'İşlem yapılamadı.'), hata: true);
      return;
    }
    kToast(context, metinOku(c.j['mesaj'], yol.endsWith('talep') ? 'Talep satın almaya gönderildi.' : 'Sipariş taslağı oluşturuldu (tedarikçiye göre gruplandı).'));
    final hedef = metinOku(c.j['yonlendir']);
    if (hedef.isNotEmpty) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => EkranAc(url: hedef)));
    }
  }
}

/// Yönlendirilen web adresini aç (kayıtlı ekran ya da genel görünüm)
class EkranAc extends StatelessWidget {
  final String url;
  const EkranAc({super.key, required this.url});
  @override
  Widget build(BuildContext context) => saEkran(url);
}

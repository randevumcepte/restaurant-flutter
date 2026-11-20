import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /hal-fiyatlari — "Sen vs Hal" karşılaştırma + hal fiyatları listesi (ara / sil) + Şimdi Çek (İzmir / Balıkesir) + elle hal fiyatı ekle.
/// Şimdi Çek (İzmir): web'deki gibi bülten uygulamanın kendisinden çekilir (sunucu belediye API'sine bağlanamıyor) → /hal-fiyatlari/yukle.
class HalFiyatlariScreen extends StatefulWidget {
  const HalFiyatlariScreen({super.key});
  @override
  State<HalFiyatlariScreen> createState() => _HalFiyatlariScreenState();
}

class _HalFiyatlariScreenState extends State<HalFiyatlariScreen> {
  String _sekme = 'kiyas';
  String _ara = '';
  String _kaynak = 'izmir';
  String _tarih = '';
  bool _cekiliyor = false;

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/hal-fiyatlari',
      baslik: 'Hal Fiyatları',
      ikon: Icons.storefront_outlined,
      govde: _govde,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(heroTag: 'hal_ekle', onPressed: () => _ekle(yenile), icon: const Icon(Icons.add), label: const Text('Elle ekle', style: TextStyle(fontWeight: FontWeight.w700))),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final hal = liste(v['hal']);
    final kiyas = liste(v['kiyas']);
    final halG = hal.where((h) => saIcerir(metinOku(h['urun_ad']), _ara)).toList();
    final pahali = kiyas.where((k) => sayiOku(k['fark']) > 0).length;
    return KGovde(yenile: yenile, children: [
      KKart(
        renk: const Color(0xFF059669),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Hal bülteni çek', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15)),
          Text('Antalya\'nın açık API\'si yok (yalnız bülten). En yakın güvenilir referans İzmir/Balıkesir; fiyatı trend/bant kozu olarak kullanın. Bugünün bülteni yoksa sayfa açılınca otomatik çekilir.',
              style: TextStyle(color: t.sub, fontSize: 12.5)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: KSecim<String>('Kaynak', deger: _kaynak, secenekler: const [('izmir', 'İzmir Büyükşehir (önerilen)'), ('balikesir', 'Balıkesir Büyükşehir')], onSec: (x) => setState(() => _kaynak = x ?? 'izmir'))),
            const SizedBox(width: 8),
            Expanded(child: KSatir(baslik: 'Tarih (ops.)', alt: _tarih.isEmpty ? 'Bugün' : tarihYaz(_tarih, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
              final s = await saTarihSec(context, ilk: _tarih);
              if (s != null) setState(() => _tarih = s);
            })),
          ]),
          Align(alignment: Alignment.centerLeft, child: KButon('Şimdi Çek', ikon: Icons.sync, renk: const Color(0xFF059669), yukleniyor: _cekiliyor, onTap: () => _cek(yenile))),
        ]),
      ),
      KCipler(secenekler: [('kiyas', 'Sen vs Hal (${kiyas.length})'), ('liste', 'Hal Fiyatları (${hal.length})')], secili: _sekme, onSec: (k) => setState(() => _sekme = k)),
      if (_sekme == 'kiyas') ...[
        KKpiIzgara([
          KKpi(etiket: 'Eşleşen ürün', deger: '${kiyas.length}', ikon: Icons.compare_arrows, renk: t.mavi),
          KKpi(etiket: 'Halden pahalı aldığınız', deger: '$pahali', ikon: Icons.trending_up, renk: t.kirmizi),
          KKpi(etiket: 'Halden ucuz / eşit', deger: '${kiyas.length - pahali}', ikon: Icons.trending_down, renk: t.yesil),
        ]),
        if (kiyas.isEmpty)
          const KBos(
              baslik: 'Karşılaştırılacak ürün yok',
              aciklama: 'Hal ürün adı ile malzeme adınız eşleşmeli ve o malzemenin alış faturası olmalı. Hal bültenini çekin; alış faturaları (Mal Kabul / Fatura Eşleştir / Gelen e-Fatura) girildikçe kıyas dolar.',
              ikon: Icons.compare_arrows)
        else
          SaIzgara([
            for (final k in kiyas)
              KKart(
                renk: sayiOku(k['fark']) > 0 ? t.kirmizi : t.yesil,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(metinOku(k['malzeme']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5))),
                    KRozet('${sayiOku(k['fark']) > 0 ? '+' : ''}${sayiYaz(k['fark'])}%', renk: sayiOku(k['fark']) > 0 ? t.kirmizi : t.yesil),
                  ]),
                  Text('Hal: ${metinOku(k['hal_ad'])} / ${metinOku(k['birim'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
                  const SizedBox(height: 6),
                  SaDeger('Hal Asgari', k['asgari'] != null ? tl(k['asgari']) : '—'),
                  SaDeger('Hal Ortalama', tl(k['hal']), kalin: true),
                  SaDeger('Hal Azami', k['azami'] != null ? tl(k['azami']) : '—'),
                  SaDeger('Sizin son alışınız', tl(k['senin']), kalin: true, renk: sayiOku(k['fark']) > 0 ? t.kirmizi : t.yesil),
                ]),
              ),
          ], minGenislik: 360),
      ] else ...[
        if (hal.isNotEmpty) KAra(ipucu: 'Ürün ara…', onDegis: (s) => setState(() => _ara = s)),
        if (hal.isEmpty)
          const KBos(baslik: 'Henüz hal fiyatı yok', aciklama: '"Şimdi Çek" ile bülteni çekin ya da "Elle ekle" ile girin.', ikon: Icons.storefront_outlined)
        else
          KKart(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(children: [
              for (final h in halG)
                KSatir(
                  baslik: '${metinOku(h['urun_ad'])} / ${metinOku(h['birim'])}',
                  alt: '${tarihYaz(h['tarih'], saat: false)} · Asgari ${h['asgari'] != null ? tl(h['asgari']) : '—'} · Azami ${h['azami'] != null ? tl(h['azami']) : '—'}${metinOku(h['kaynak']) == 'manuel' ? ' · elle' : ''}',
                  sag: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(h['ortalama'] != null ? tl(h['ortalama']) : '—', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                    IconButton(tooltip: 'Sil', onPressed: () => _sil(h, yenile), icon: Icon(Icons.delete_outline, color: t.kirmizi)),
                  ]),
                ),
            ]),
          ),
      ],
    ]);
  }

  Future<void> _cek(Future<void> Function() yenile) async {
    setState(() => _cekiliyor = true);
    final tarih = _tarih.isEmpty ? bugunStr() : _tarih;
    var tamam = false;
    if (_kaynak == 'izmir') {
      try {
        final r = await http.get(Uri.parse('https://openapi.izmir.bel.tr/api/ibb/halfiyatlari/sebzemeyve/$tarih')).timeout(const Duration(seconds: 12));
        if (r.statusCode == 200) {
          final veri = jsonDecode(utf8.decode(r.bodyBytes));
          if (veri is Map && veri['HalFiyatListesi'] is List && (veri['HalFiyatListesi'] as List).isNotEmpty && mounted) {
            final c = await saGonder(context, '/hal-fiyatlari/yukle', {'kaynak': 'izmir', 'tarih': tarih, 'veri': veri, 'sessiz': 0}, sessiz: true, hataSessiz: true);
            if (c != null && c.ok && mounted) {
              tamam = true;
              kToast(context, metinOku(c.j['mesaj'], 'Hal fiyatları güncellendi.'));
            }
          }
        }
      } catch (_) {}
    }
    if (!tamam && mounted) {
      // Uygulama çekemediyse sunucu dener (web'deki form yedeği)
      await saGonder(context, '/hal-fiyatlari/cek', {'kaynak': _kaynak, 'tarih': _tarih}, json: false, sessiz: true);
      if (mounted) kToast(context, 'Sunucudan çekim denendi. Liste güncellenmediyse bülten henüz yayınlanmamış olabilir; birazdan tekrar deneyin.');
    }
    if (!mounted) return;
    setState(() => _cekiliyor = false);
    yenile();
  }

  Future<void> _sil(Map<String, dynamic> h, Future<void> Function() yenile) async {
    if (!await kOnay(context, 'Silinsin mi?', aciklama: '${h['urun_ad']} · ${tarihYaz(h['tarih'], saat: false)}', tehlikeli: true, evet: 'Sil')) return;
    if (!mounted) return;
    await saGonder(context, '/hal-fiyatlari/sil', {'id': h['id']}, json: false, sessiz: true);
    if (mounted) kToast(context, 'Silindi.');
    yenile();
  }

  Future<void> _ekle(Future<void> Function() yenile) async {
    final ad = TextEditingController(), birim = TextEditingController(text: 'kg'), asg = TextEditingController(), azm = TextEditingController(), ort = TextEditingController();
    var tarih = bugunStr();
    final ok = await kAltSayfa<bool>(context, baslik: 'Elle hal fiyatı ekle', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Ürün', ad, ipucu: 'Örn. Domates', zorunlu: true),
            KAlan('Birim', birim),
            Row(children: [
              Expanded(child: KAlan('Asgari', asg, klavye: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              Expanded(child: KAlan('Azami', azm, klavye: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              Expanded(child: KAlan('Ortalama', ort, klavye: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            KSatir(baslik: 'Tarih', alt: tarihYaz(tarih, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
              final s = await saTarihSec(c, ilk: tarih);
              if (s != null) ss(() => tarih = s);
            }),
            const SizedBox(height: 10),
            KButon('Ekle', ikon: Icons.add, genis: true, onTap: () {
              if (ad.text.trim().isEmpty) return kToast(c, 'Ürün adı girin.', hata: true);
              Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok != true || !mounted) return;
    await saGonder(context, '/hal-fiyatlari/ekle', {
      'urun_ad': ad.text.trim(), 'birim': birim.text.trim(), 'asgari': asg.text.trim(), 'azami': azm.text.trim(), 'ortalama': ort.text.trim(), 'tarih': tarih,
    }, json: false, sessiz: true);
    if (mounted) kToast(context, '${ad.text.trim()} hal fiyatı eklendi.');
    yenile();
  }
}

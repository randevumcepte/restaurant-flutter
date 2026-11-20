import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /mustahsil — müstahsil (çiftçi/üretici) makbuzu: liste + toplam (brüt / stopaj / net) + yeni makbuz + sil.
class MustahsilScreen extends StatefulWidget {
  const MustahsilScreen({super.key});
  @override
  State<MustahsilScreen> createState() => _MustahsilScreenState();
}

class _MustahsilScreenState extends State<MustahsilScreen> {
  String _ara = '';

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/mustahsil',
      baslik: 'Müstahsil Makbuzu',
      ikon: Icons.agriculture_outlined,
      govde: _govde,
      fab: (ctx, v, yenile) => FloatingActionButton.extended(heroTag: 'mm_yeni', onPressed: () => _yeni(yenile), icon: const Icon(Icons.add), label: const Text('Yeni Makbuz', style: TextStyle(fontWeight: FontWeight.w700))),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final l = liste(v['liste']).where((m) => saIcerir('${m['makbuz_no']} ${m['mustahsil_ad']} ${m['urun_ad']}', _ara)).toList();
    final top = harita(v['toplam']);
    return KGovde(yenile: yenile, children: [
      KKpiIzgara([
        KKpi(etiket: 'Brüt', deger: tl(top['brut']), ikon: Icons.payments_outlined, renk: t.mor1),
        KKpi(etiket: 'Stopaj', deger: tl(top['stopaj']), ikon: Icons.account_balance_outlined, renk: t.amber),
        KKpi(etiket: 'Net ödenen', deger: tl(top['net']), ikon: Icons.check_circle_outline, renk: t.yesil),
      ]),
      const SaBilgi('Faturası olmayan çiftçi/üreticiden alımda müstahsil makbuzu düzenlenir; stopaj (varsayılan %2) ve varsa Bağ-Kur kesintisi brütten düşülür.', ikon: Icons.info_outline),
      KAra(ipucu: 'Makbuz no, üretici, ürün ara…', onDegis: (s) => setState(() => _ara = s)),
      if (l.isEmpty)
        const KBos(baslik: 'Müstahsil makbuzu yok', aciklama: 'Üreticiden faturasız alım yaptığınızda "Yeni Makbuz" ile kaydedin.', ikon: Icons.receipt_outlined)
      else
        SaIzgara([
          for (final m in l)
            KKart(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(metinOku(m['mustahsil_ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5))),
                  IconButton(tooltip: 'Sil', onPressed: () => _sil(m, yenile), icon: Icon(Icons.delete_outline, color: t.kirmizi)),
                ]),
                Text('${metinOku(m['makbuz_no'])} · ${tarihYaz(m['tarih'], saat: false)}${metinOku(m['mustahsil_tc']).isNotEmpty ? ' · TC ${m['mustahsil_tc']}' : ''}', style: TextStyle(color: t.sub, fontSize: 12.5)),
                Text('${metinOku(m['urun_ad'])} · ${sayiYaz(m['miktar'])} ${metinOku(m['birim'])} × ${tl(m['birim_fiyat'])}', style: TextStyle(color: t.sub2, fontSize: 13)),
                const SizedBox(height: 4),
                SaDeger('Brüt', tl(m['brut'])),
                SaDeger('Stopaj (%${sayiYaz(m['stopaj_oran'])})', tl(m['stopaj'])),
                if (sayiOku(m['bagkur']) > 0) SaDeger('Bağ-Kur (%${sayiYaz(m['bagkur_oran'])})', tl(m['bagkur'])),
                SaDeger('Net ödenecek', tl(m['net']), kalin: true, renk: t.yesil),
              ]),
            ),
        ], minGenislik: 380),
    ]);
  }

  Future<void> _sil(Map<String, dynamic> m, Future<void> Function() yenile) async {
    if (!await kOnay(context, 'Makbuz silinsin mi?', aciklama: '${m['makbuz_no']} · ${m['mustahsil_ad']}', tehlikeli: true, evet: 'Sil')) return;
    if (!mounted) return;
    await saGonder(context, '/mustahsil/sil', {'id': m['id']}, json: false, basari: 'Silindi.');
    yenile();
  }

  Future<void> _yeni(Future<void> Function() yenile) async {
    final k = {for (final x in ['makbuz_no', 'mustahsil_ad', 'mustahsil_tc', 'mustahsil_adres', 'urun_ad', 'miktar', 'birim', 'birim_fiyat']) x: TextEditingController()};
    final so = TextEditingController(text: '2'), bo = TextEditingController(text: '0');
    var tarih = bugunStr();
    final ok = await kAltSayfa<bool>(context, baslik: 'Yeni Müstahsil Makbuzu', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.watch<TemaProvider>();
          final brut = sayiOku(k['miktar']!.text) * sayiOku(k['birim_fiyat']!.text);
          final net = brut - brut * sayiOku(so.text) / 100 - brut * sayiOku(bo.text) / 100;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(child: KSatir(baslik: 'Tarih', alt: tarihYaz(tarih, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
                final s = await saTarihSec(c, ilk: tarih);
                if (s != null) ss(() => tarih = s);
              })),
              const SizedBox(width: 8),
              Expanded(child: KAlan('Makbuz No (ops.)', k['makbuz_no']!, ipucu: 'otomatik')),
            ]),
            KAlan('Müstahsil (üretici) adı', k['mustahsil_ad']!, zorunlu: true),
            KAlan('TC Kimlik (ops.)', k['mustahsil_tc']!, klavye: TextInputType.number),
            KAlan('Adres (ops.)', k['mustahsil_adres']!),
            KAlan('Ürün', k['urun_ad']!, ipucu: 'örn. domates', zorunlu: true),
            Row(children: [
              Expanded(child: KAlan('Miktar', k['miktar']!, klavye: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              Expanded(child: KAlan('Birim', k['birim']!, ipucu: 'kg')),
              const SizedBox(width: 8),
              Expanded(child: KAlan('Birim Fiyat (₺)', k['birim_fiyat']!, klavye: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            Row(children: [
              Expanded(child: KAlan('Stopaj %', so, klavye: const TextInputType.numberWithOptions(decimal: true))),
              const SizedBox(width: 8),
              Expanded(child: KAlan('Bağ-Kur %', bo, klavye: const TextInputType.numberWithOptions(decimal: true))),
            ]),
            TextButton(onPressed: () => ss(() {}), child: Text('Hesapla: brüt ${tl(brut)} → net ${tl(net)}', style: TextStyle(color: t.mor1, fontWeight: FontWeight.w700))),
            KButon('Kaydet', ikon: Icons.save_outlined, genis: true, onTap: () {
              if (k['mustahsil_ad']!.text.trim().isEmpty || k['urun_ad']!.text.trim().isEmpty) return kToast(c, 'Üretici adı ve ürün zorunlu.', hata: true);
              Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok != true || !mounted) return;
    await saGonder(context, '/mustahsil/ekle', {for (final e in k.entries) e.key: e.value.text.trim(), 'stopaj_oran': so.text.trim(), 'bagkur_oran': bo.text.trim(), 'tarih': tarih}, json: false);
    yenile();
  }
}

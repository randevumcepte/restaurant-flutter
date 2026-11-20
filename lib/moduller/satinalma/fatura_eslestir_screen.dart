import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /fatura-eslestir — 3'lü eşleştirme: sipariş ↔ irsaliye (mal kabul) ↔ fatura. Faturası girilmemiş mal kabuller listesi,
/// seçilen mal kabul için fatura kalemleri (miktar / fiyat / KDV) + fark uyarıları → alış faturası (finansal, stok yazmaz).
class FaturaEslestirScreen extends StatefulWidget {
  final String url;
  const FaturaEslestirScreen({super.key, this.url = '/fatura-eslestir'});
  @override
  State<FaturaEslestirScreen> createState() => _FaturaEslestirScreenState();
}

class _FeSatir {
  final Map<String, dynamic> k;
  final mik = TextEditingController();
  final fiyat = TextEditingController();
  final kdv = TextEditingController(text: '10');
  _FeSatir(this.k) {
    mik.text = sayiYaz(k['kabul_miktar']).replaceAll('.', '');
    fiyat.text = '${sayiOku(k['birim_fiyat'])}';
  }
}

class _FaturaEslestirScreenState extends State<FaturaEslestirScreen> {
  String? _mkId;
  List<_FeSatir>? _s;
  final _no = TextEditingController();
  final _isk = TextEditingController(text: '0');
  String _tarih = bugunStr();
  String _vade = '';
  bool _mesgul = false;

  @override
  void initState() {
    super.initState();
    _mkId = Uri.parse(widget.url).queryParameters['mal_kabul_id'];
  }

  void _sec(String? id) => setState(() {
        _mkId = id;
        _s = null;
        _no.clear();
        _isk.text = '0';
        _tarih = bugunStr();
        _vade = '';
      });

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: ValueKey(_mkId),
      yol: '/fatura-eslestir',
      q: _mkId == null ? null : {'mal_kabul_id': _mkId!},
      baslik: 'Fatura Eşleştir (3\'lü)',
      ikon: Icons.fact_check_outlined,
      govde: _govde,
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final bekleyen = liste(v['bekleyen']);
    final mk = harita(v['mk']);
    final ted = harita(v['tedarikci']);
    if (mk.isNotEmpty) _s ??= [for (final k in liste(v['kalemler'])) _FeSatir(k)];
    double ara = 0, kdv = 0;
    final uyari = <String>[];
    for (final r in _s ?? <_FeSatir>[]) {
      final m = sayiOku(r.mik.text), f = sayiOku(r.fiyat.text);
      ara += m * f;
      kdv += m * f * sayiOku(r.kdv.text) / 100;
      final kabul = sayiOku(r.k['kabul_miktar']), po = sayiOku(r.k['po_fiyat']);
      if (kabul > 0 && (kabul - m).abs() > 0.001) uyari.add('${r.k['malzeme']}: miktar farkı (irsaliye ${sayiYaz(kabul)} ≠ fatura ${sayiYaz(m)})');
      if (po > 0 && f > po + 0.0001) uyari.add('${r.k['malzeme']}: fiyat yüksek (sipariş ${tl(po)} → fatura ${tl(f)})');
    }
    final isk = sayiOku(_isk.text);
    return KGovde(yenile: yenile, children: [
      const SaBilgi('Mal kabul (irsaliye) stoğu yazdı; burada faturayı girip sipariş ve irsaliyeyle karşılaştırırsınız. Fark varsa uyarılır. Fatura yalnız finansal kayıttır.', ikon: Icons.info_outline),
      KBaslik('Faturası bekleyen mal kabuller', ikon: Icons.inventory_outlined, renk: t.amber, sag: KRozet('${bekleyen.length}', renk: t.amber)),
      if (bekleyen.isEmpty)
        const KBos(baslik: 'Faturası bekleyen mal kabul yok', aciklama: 'Mal Kabul ekranından gelen malı kaydettiğinizde, faturası girilene kadar burada listelenir.', ikon: Icons.check_circle_outline)
      else
        SaIzgara([
          for (final m in bekleyen)
            KKart(
              renk: '${m['id']}' == _mkId ? t.mor1 : t.amber,
              onTap: () => _sec('${m['id']}'),
              child: KSatir(
                cizgi: false,
                baslik: metinOku(m['tedarikci'], '—'),
                alt: 'İrsaliye ${metinOku(m['irsaliye_no'], '—')} · ${tarihYaz(m['tarih'], saat: false)}',
                sag: Text('${m['id']}' == _mkId ? 'Seçili' : 'Faturayı gir →', style: TextStyle(color: t.amber, fontWeight: FontWeight.w700)),
              ),
            ),
        ], minGenislik: 380),
      if (mk.isNotEmpty) ...[
        const SizedBox(height: 8),
        KBaslik('${metinOku(ted['ad'], 'Tedarikçi')} · İrsaliye ${metinOku(mk['irsaliye_no'], '—')}', ikon: Icons.receipt_long_outlined, renk: t.amber),
        Row(children: [
          Expanded(child: KAlan('Fatura No', _no)),
          const SizedBox(width: 8),
          Expanded(child: KAlan('Genel İskonto (₺)', _isk, klavye: const TextInputType.numberWithOptions(decimal: true))),
        ]),
        Row(children: [
          Expanded(child: KSatir(baslik: 'Fatura Tarihi', alt: tarihYaz(_tarih, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
            final s = await saTarihSec(context, ilk: _tarih);
            if (s != null) setState(() => _tarih = s);
          })),
          const SizedBox(width: 8),
          Expanded(child: KSatir(baslik: 'Vade Tarihi', alt: _vade.isEmpty ? 'Seçilmedi' : tarihYaz(_vade, saat: false), sag: const Icon(Icons.event_outlined), onTap: () async {
            final s = await saTarihSec(context, ilk: _vade);
            if (s != null) setState(() => _vade = s);
          })),
        ]),
        const SizedBox(height: 8),
        if ((_s ?? []).isEmpty) const KBos(baslik: 'Bu mal kabulde kabul edilen kalem yok'),
        for (final r in _s ?? <_FeSatir>[])
          KKart(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('${metinOku(r.k['malzeme'])} / ${metinOku(r.k['birim'])}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700))),
                Text('İrsaliye: ${sayiYaz(r.k['kabul_miktar'])} · Sipariş fiyatı: ${sayiOku(r.k['po_fiyat']) > 0 ? tl(r.k['po_fiyat']) : '—'}', style: TextStyle(color: t.sub, fontSize: 12.5)),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(child: Focus(onFocusChange: (_) => setState(() {}), child: KAlan('Fatura miktarı', r.mik, klavye: const TextInputType.numberWithOptions(decimal: true)))),
                const SizedBox(width: 8),
                Expanded(child: Focus(onFocusChange: (_) => setState(() {}), child: KAlan('Birim fiyat', r.fiyat, klavye: const TextInputType.numberWithOptions(decimal: true)))),
                const SizedBox(width: 8),
                Expanded(child: Focus(onFocusChange: (_) => setState(() {}), child: KAlan('KDV %', r.kdv, klavye: const TextInputType.numberWithOptions(decimal: true)))),
              ]),
            ]),
          ),
        KKart(
          child: Column(children: [
            SaDeger('Ara toplam', tl(ara)),
            SaDeger('İskonto', tl(isk)),
            SaDeger('KDV', tl(kdv)),
            SaDeger('Genel toplam', tl(ara - isk + kdv), kalin: true),
          ]),
        ),
        if (uyari.isNotEmpty) SaBilgi('FARK VAR: ${uyari.join(' · ')}', renk: t.kirmizi, ikon: Icons.warning_amber_outlined) else if ((_s ?? []).isNotEmpty) SaBilgi('Sipariş / irsaliye / fatura tutuyor.', renk: t.yesil, ikon: Icons.check_circle_outline),
        KButon('Faturayı Kaydet ve Eşleştir', ikon: Icons.fact_check_outlined, renk: t.amber, genis: true, yukleniyor: _mesgul, onTap: () => _kaydet(uyari, yenile)),
      ],
    ]);
  }

  Future<void> _kaydet(List<String> uyari, Future<void> Function() yenile) async {
    final kal = [
      for (final r in _s ?? <_FeSatir>[])
        {
          'malzeme_id': tamOku(r.k['malzeme_id']), 'alis_birim_id': tamOku(r.k['alis_birim_id']), 'miktar': sayiOku(r.mik.text), 'birim_fiyat': sayiOku(r.fiyat.text),
          'kdv_yuzde': sayiOku(r.kdv.text), 'kabul_miktar': sayiOku(r.k['kabul_miktar']), 'po_fiyat': sayiOku(r.k['po_fiyat']),
        },
    ];
    if (kal.isEmpty) return kToast(context, 'Kalem yok.', hata: true);
    setState(() => _mesgul = true);
    final mk = _mkId;
    final c = await saGonder(context, '/fatura-eslestir/kaydet', {
      'mal_kabul_id': mk, 'fatura_no': _no.text.trim(), 'tarih': _tarih, 'vade_tarihi': _vade, 'iskonto': sayiOku(_isk.text), 'kalemler': jsonEncode(kal),
    }, json: false, sessiz: true);
    if (!mounted) return;
    setState(() => _mesgul = false);
    if (c == null || !c.ok) return;
    // Sunucu sonucu flash ile verir; kayıt oldu mu → mal kabul artık "bekleyen" listesinde değilse kaydedildi
    final kontrol = await saAl(context, '/fatura-eslestir');
    if (!mounted) return;
    final hala = liste(kontrol?.veri['bekleyen']).any((m) => '${m['id']}' == mk);
    if (hala) {
      kToast(context, 'Fatura kaydedilemedi. Bu mal kabulün faturası zaten olabilir ya da kalem geçersiz.', hata: true);
    } else {
      kToast(context, uyari.isEmpty ? 'Fatura eşleşti — sipariş/irsaliye/fatura tutuyor.' : 'FARK VAR: ${uyari.take(4).join(' · ')}', hata: uyari.isNotEmpty);
      _sec(null);
    }
  }
}

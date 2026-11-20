import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// Web /tedarikci — tedarikçi listesi (toplam alış, fatura, anlaşmalı) + ekle/düzenle (zengin kart) + sil.
class TedarikciScreen extends StatefulWidget {
  const TedarikciScreen({super.key});

  @override
  State<TedarikciScreen> createState() => _TedarikciScreenState();
}

class _TedarikciScreenState extends State<TedarikciScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _ara = '';
  String _f = 'tumu';

  Future<void> _form(Map<String, dynamic>? x) async {
    final ok = await kAltSayfa<bool>(context, baslik: x == null ? 'Yeni Tedarikçi' : 'Tedarikçiyi Düzenle', icerik: (c) => _TedarikciForm(x: x));
    if (ok == true) _k.currentState?.yukle();
  }

  Future<void> _sil(Map<String, dynamic> x) async {
    if (tamOku(x['fatura_sayisi']) > 0) {
      kToast(context, 'Bu tedarikçinin faturaları var, silinemez.', hata: true);
      return;
    }
    if (!await kOnay(context, '"${x['ad']}" silinsin mi?', evet: 'Sil', tehlikeli: true)) return;
    if (!mounted) return;
    final r = await stGonder(context, '/tedarikci/sil', {'id': x['id']}, basari: 'Tedarikçi silindi.');
    if (r.ok) _k.currentState?.yukle();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/tedarikci',
      baslik: 'Tedarikçiler',
      ikon: Icons.local_shipping_outlined,
      araclar: (ctx, v, y) => [
        IconButton(tooltip: 'Tedarikçi karnesi', icon: const Icon(Icons.grading), onPressed: () => stAc(ctx, '/tedarikci-karne', 'Tedarikçi Karnesi')),
      ],
      fab: (ctx, v, y) => FloatingActionButton.extended(
        heroTag: 'tedFab',
        onPressed: () => _form(null),
        icon: const Icon(Icons.add),
        label: const Text('Tedarikçi', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      govde: (ctx, v, yenile) {
        final t = ctx.watch<TemaProvider>();
        final liste0 = liste(v['tedarikciler']);
        final q = _ara.toLowerCase();
        final gorunen = liste0.where((x) {
          if (_f == 'anlasmali' && tamOku(x['anlasmali']) != 1) return false;
          if (_f == 'alisli' && sayiOku(x['toplam_alis']) <= 0) return false;
          if (q.isNotEmpty && !'${x['ad']} ${x['telefon'] ?? ''} ${x['yetkili'] ?? ''} ${x['unvan'] ?? ''}'.toLowerCase().contains(q)) return false;
          return true;
        }).toList();
        final toplam = liste0.fold<double>(0, (s, x) => s + sayiOku(x['toplam_alis']));
        final genis = genisMi(ctx);
        return KGovde(yenile: yenile, children: [
          KKpiIzgara([
            KKpi(etiket: 'Tedarikçi', deger: '${liste0.length}', ikon: Icons.local_shipping_outlined, renk: t.mavi),
            KKpi(etiket: 'Anlaşmalı', deger: '${liste0.where((x) => tamOku(x['anlasmali']) == 1).length}', ikon: Icons.handshake_outlined, renk: t.amber),
            KKpi(etiket: 'Toplam alış', deger: tl(toplam, kisa: true), ikon: Icons.payments_outlined, renk: t.mor1),
          ]),
          const SizedBox(height: 8),
          KAra(ipucu: 'Ad, telefon, yetkili ara', onDegis: (s) => setState(() => _ara = s)),
          const SizedBox(height: 8),
          KCipler(secenekler: const [('tumu', 'Tümü'), ('anlasmali', 'Anlaşmalı'), ('alisli', 'Alış yapılan')], secili: _f, onSec: (s) => setState(() => _f = s)),
          const SizedBox(height: 8),
          if (liste0.isEmpty)
            KBos(
              baslik: 'Henüz tedarikçi yok',
              ikon: Icons.local_shipping_outlined,
              aciklama: 'Alış faturası, satın alma siparişi ve fiyat araştırması için önce tedarikçi ekleyin.',
              aksiyon: KButon('Tedarikçi Ekle', ikon: Icons.add, onTap: () => _form(null)),
            )
          else if (gorunen.isEmpty)
            const KBos(baslik: 'Bu filtrede tedarikçi yok', ikon: Icons.filter_alt_off_outlined)
          else if (genis)
            LayoutBuilder(builder: (c, s) {
              final w = (s.maxWidth - 12) / 2;
              return Wrap(spacing: 12, children: [for (final x in gorunen) SizedBox(width: w, child: _kart(ctx, x))]);
            })
          else
            for (final x in gorunen) _kart(ctx, x),
        ]);
      },
    );
  }

  Widget _kart(BuildContext context, Map<String, dynamic> x) {
    final t = context.read<TemaProvider>();
    final tel = metinOku(x['telefon']);
    return KKart(
      renk: tamOku(x['anlasmali']) == 1 ? t.amber : null,
      onTap: () => stAc(context, '/tedarikci-detay?id=${x['id']}', '${x['ad']}'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          KIkon(Icons.storefront_outlined, renk: t.mavi),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text('${x['ad']}', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))),
                if (tamOku(x['anlasmali']) == 1) ...[const SizedBox(width: 6), KRozet('⭐ anlaşmalı', renk: t.amber)],
              ]),
              Text([
                if (metinOku(x['yetkili']).isNotEmpty) '${x['yetkili']}',
                if (tel.isNotEmpty) tel,
                if (metinOku(x['odeme_vade_gun']).isNotEmpty) 'Vade ${x['odeme_vade_gun']} gün',
              ].join(' · ').ifEmpty('İletişim bilgisi yok'), style: TextStyle(color: t.sub, fontSize: 12.5)),
            ]),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: t.sub),
            onSelected: (s) {
              if (s == 'duzenle') _form(x);
              if (s == 'sil') _sil(x);
              if (s == 'ara' && tel.isNotEmpty) launchUrl(Uri.parse('tel:${tel.replaceAll(' ', '')}'));
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'duzenle', child: Text('Düzenle')),
              if (tel.isNotEmpty) const PopupMenuItem(value: 'ara', child: Text('Ara')),
              const PopupMenuItem(value: 'sil', child: Text('Sil')),
            ],
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 6, children: [
          KRozet('Alış ${tl(x['toplam_alis'], kisa: true)}', renk: t.mor1),
          KRozet('${tamOku(x['fatura_sayisi'])} fatura', renk: t.sub),
          if (metinOku(x['aciklama']).isNotEmpty) KRozet('${x['aciklama']}', renk: t.sub),
        ]),
      ]),
    );
  }
}

extension _BosIse on String {
  String ifEmpty(String y) => isEmpty ? y : this;
}

class _TedarikciForm extends StatefulWidget {
  final Map<String, dynamic>? x;
  const _TedarikciForm({required this.x});

  @override
  State<_TedarikciForm> createState() => _TedarikciFormState();
}

class _TedarikciFormState extends State<_TedarikciForm> {
  static const _alanlar = ['ad', 'telefon', 'email', 'aciklama', 'unvan', 'vkn_tckn', 'vergi_dairesi', 'yetkili', 'odeme_vade_gun', 'iban', 'adres'];
  late final Map<String, TextEditingController> _k = {for (final a in _alanlar) a: TextEditingController(text: metinOku(widget.x?[a]))};
  late bool _anlasmali = tamOku(widget.x?['anlasmali']) == 1;
  bool _gonder = false;

  @override
  void dispose() {
    for (final c in _k.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    Widget ikili(String a, String ea, String b, String eb, {TextInputType? ka, TextInputType? kb}) => Row(children: [
          Expanded(child: KAlan(ea, _k[a]!, klavye: ka)),
          const SizedBox(width: 10),
          Expanded(child: KAlan(eb, _k[b]!, klavye: kb)),
        ]);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KAlan('Ad', _k['ad']!, zorunlu: true, ipucu: 'Firma / Kişi adı'),
      ikili('telefon', 'Telefon', 'email', 'E-posta', ka: TextInputType.phone, kb: TextInputType.emailAddress),
      KAlan('Not', _k['aciklama']!, ipucu: 'İsteğe bağlı'),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _anlasmali,
        onChanged: (b) => setState(() => _anlasmali = b),
        title: Text('Anlaşmalı tedarikçi', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
        subtitle: Text('Fiyat araştırma ve sipariş önerisinde öne çıkar.', style: TextStyle(color: t.sub, fontSize: 12)),
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: widget.x != null && ['unvan', 'vkn_tckn', 'iban', 'adres'].any((a) => _k[a]!.text.isNotEmpty),
        title: Text('Resmî bilgiler (fatura / ödeme)', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
        children: [
          ikili('unvan', 'Unvan', 'vkn_tckn', 'VKN / TCKN', kb: TextInputType.number),
          ikili('vergi_dairesi', 'Vergi Dairesi', 'yetkili', 'Yetkili Kişi'),
          ikili('odeme_vade_gun', 'Ödeme Vadesi (gün)', 'iban', 'IBAN', ka: TextInputType.number),
          KAlan('Adres', _k['adres']!, satir: 2),
        ],
      ),
      const SizedBox(height: 8),
      KButon('Kaydet', ikon: Icons.check, genis: true, yukleniyor: _gonder, onTap: _gonder
          ? null
          : () async {
              if (_k['ad']!.text.trim().isEmpty) {
                kToast(context, 'Ad boş olamaz.', hata: true);
                return;
              }
              setState(() => _gonder = true);
              final r = await stGonder(context, '/tedarikci/kaydet', {
                'id': widget.x?['id'] ?? 0,
                for (final a in _alanlar) a: _k[a]!.text.trim(),
                if (_anlasmali) 'anlasmali': 1,
              }, basari: widget.x == null ? 'Tedarikçi eklendi.' : 'Tedarikçi güncellendi.');
              if (!context.mounted) return;
              setState(() => _gonder = false);
              if (r.ok) Navigator.pop(context, true);
            }),
    ]);
  }
}

/// Web /tedarikci-detay?id= — kart + cari (borç/ödeme/bakiye, ödeme gir) + fatura kataloğu (fiyat bandı/trend)
/// + sağlanan malzemeler (RFQ kataloğu: tek/toplu bağla, kaldır) + ekstre.
class TedarikciDetayScreen extends StatefulWidget {
  final String url;
  const TedarikciDetayScreen({super.key, required this.url});

  @override
  State<TedarikciDetayScreen> createState() => _TedarikciDetayScreenState();
}

class _TedarikciDetayScreenState extends State<TedarikciDetayScreen> {
  final _k = GlobalKey<KopruEkranState>();
  String _sekme = 'cari';
  late final String _id = Uri.parse(widget.url).queryParameters['id'] ?? '0';

  Future<void> _odeme(Map<String, dynamic> ted, double bakiye) async {
    final tutar = TextEditingController(text: bakiye > 0 ? bakiye.toStringAsFixed(2) : '');
    final not = TextEditingController();
    String sekil = 'nakit';
    final ok = await kAltSayfa<bool>(context, baslik: 'Ödeme Gir · ${ted['ad']}', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            KAlan('Tutar (₺)', tutar, klavye: const TextInputType.numberWithOptions(decimal: true), zorunlu: true),
            KSecim<String>('Ödeme şekli', deger: sekil, secenekler: const [('nakit', 'Nakit'), ('havale', 'Havale/EFT'), ('kart', 'Kart')], onSec: (s) => ss(() => sekil = s ?? 'nakit')),
            KAlan('Not', not, ipucu: 'İsteğe bağlı'),
            KButon('Ödemeyi Kaydet', ikon: Icons.check, genis: true, onTap: () async {
              final v = double.tryParse(tutar.text.trim().replaceAll(',', '.')) ?? 0;
              if (v <= 0) {
                kToast(c, 'Geçerli tutar girin.', hata: true);
                return;
              }
              final r = await stGonder(c, '/tedarikci-detay/odeme', {'tedarikci_id': ted['id'], 'tutar': v, 'odeme_sekli': sekil, 'not': not.text.trim()},
                  basari: 'Ödeme kaydedildi (${tl(v, kisa: true)}).');
              if (r.ok && c.mounted) Navigator.pop(c, true);
            }),
          ]);
        }));
    if (ok == true) _k.currentState?.yukle();
  }

  Future<void> _malzemeBagla(Map<String, dynamic> ted, List<Map<String, dynamic>> malzemeler, Set<int> bagli) async {
    final secili = <int>{};
    String ara = '';
    final ok = await kAltSayfa<bool>(context, baslik: 'Malzeme Bağla', icerik: (c) => StatefulBuilder(builder: (c, ss) {
          final t = c.read<TemaProvider>();
          final secilebilir = malzemeler.where((m) => !bagli.contains(tamOku(m['id']))).toList();
          final gor = secilebilir.where((m) => ara.isEmpty || '${m['ad']} ${m['kategori'] ?? ''}'.toLowerCase().contains(ara)).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Bu tedarikçinin sağladığı malzemeleri işaretleyin. "Fiyat Araştır" bu tedarikçiye de gider.', style: TextStyle(color: t.sub, fontSize: 13, height: 1.35)),
            const SizedBox(height: 8),
            KAra(ipucu: 'Malzeme ara', onDegis: (s) => ss(() => ara = s.toLowerCase())),
            const SizedBox(height: 6),
            if (secilebilir.isEmpty)
              const KBos(baslik: 'Bağlanacak malzeme kalmadı', aciklama: 'Tüm malzemeler bu tedarikçiye bağlı ya da hiç malzeme kartı yok.')
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 380),
                child: ListView(shrinkWrap: true, children: [
                  for (final m in gor)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: secili.contains(tamOku(m['id'])),
                      onChanged: (b) => ss(() => b == true ? secili.add(tamOku(m['id'])) : secili.remove(tamOku(m['id']))),
                      title: Text('${m['ad']}', style: TextStyle(color: t.ink, fontSize: 14)),
                      subtitle: metinOku(m['kategori']).isEmpty ? null : Text('${m['kategori']}', style: TextStyle(color: t.sub, fontSize: 12)),
                    ),
                ]),
              ),
            const SizedBox(height: 8),
            KButon('${secili.length} malzemeyi bağla', ikon: Icons.link, genis: true, onTap: secili.isEmpty
                ? null
                : () async {
                    final r = await stGonder(c, '/tedarikci-detay/malzeme-toplu-ekle', {'tedarikci_id': ted['id'], 'malzeme_ids': secili.toList()},
                        basari: '${secili.length} malzeme bağlandı.');
                    if (r.ok && c.mounted) Navigator.pop(c, true);
                  }),
          ]);
        }));
    if (ok == true) _k.currentState?.yukle();
  }

  Future<void> _fiyatGir(Map<String, dynamic> ted, Map<String, dynamic> s) async {
    final v = await stSayiSor(context, '${s['ad']} · güncel fiyat', etiket: 'Birim fiyat (₺/${s['birim']})', baslangic: sayiOku(s['guncel_fiyat']) > 0 ? '${s['guncel_fiyat']}' : '');
    if (v == null || !mounted) return;
    final r = await stGonder(context, '/tedarikci-detay/malzeme-ekle', {'tedarikci_id': ted['id'], 'malzeme_id': s['malzeme_id'], 'fiyat': v}, basari: 'Fiyat güncellendi.');
    if (r.ok) _k.currentState?.yukle();
  }

  Future<void> _baglantiSil(Map<String, dynamic> ted, Map<String, dynamic> s) async {
    if (!await kOnay(context, 'Bağlantı kaldırılsın mı?', aciklama: '${s['ad']}', evet: 'Kaldır', tehlikeli: true)) return;
    if (!mounted) return;
    final r = await stGonder(context, '/tedarikci-detay/malzeme-sil', {'tedarikci_id': ted['id'], 'id': s['id']}, basari: 'Malzeme bağlantısı kaldırıldı.');
    if (r.ok) _k.currentState?.yukle();
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/tedarikci-detay',
      q: {'id': _id},
      baslik: 'Tedarikçi',
      ikon: Icons.storefront_outlined,
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final ted = harita(v['ted']);
    if (ted.isEmpty) return const KBos(baslik: 'Tedarikçi bulunamadı', aciklama: 'Kayıt silinmiş ya da bu işletmeye ait değil.');
    final katalog = liste(v['katalog']);
    final ekstre = liste(v['ekstre']);
    final saglanan = liste(v['saglanan']);
    final malzemeler = liste(v['malzemeList']);
    final bakiye = sayiOku(v['bakiye']);
    final bilgi = <(IconData, String)>[
      if (metinOku(ted['yetkili']).isNotEmpty) (Icons.person_outline, '${ted['yetkili']}'),
      if (metinOku(ted['telefon']).isNotEmpty) (Icons.call_outlined, '${ted['telefon']}'),
      if (metinOku(ted['email']).isNotEmpty) (Icons.alternate_email, '${ted['email']}'),
      if (metinOku(ted['unvan']).isNotEmpty) (Icons.badge_outlined, '${ted['unvan']}'),
      if (metinOku(ted['vkn_tckn']).isNotEmpty) (Icons.numbers, 'VKN/TC ${ted['vkn_tckn']}${metinOku(ted['vergi_dairesi']).isNotEmpty ? ' · ${ted['vergi_dairesi']}' : ''}'),
      if (metinOku(ted['iban']).isNotEmpty) (Icons.account_balance_outlined, '${ted['iban']}'),
      if (metinOku(ted['odeme_vade_gun']).isNotEmpty) (Icons.event_repeat, 'Vade ${ted['odeme_vade_gun']} gün'),
      if (metinOku(ted['adres']).isNotEmpty) (Icons.place_outlined, '${ted['adres']}'),
    ];
    return KGovde(yenile: yenile, children: [
      KKart(
        renk: tamOku(ted['anlasmali']) == 1 ? t.amber : t.mavi,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${ted['ad']}', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold))),
            if (tamOku(ted['anlasmali']) == 1) KRozet('⭐ anlaşmalı', renk: t.amber),
          ]),
          const SizedBox(height: 6),
          if (bilgi.isEmpty)
            Text('İletişim/resmî bilgi girilmemiş — Tedarikçiler listesinden düzenleyin.', style: TextStyle(color: t.sub, fontSize: 12.5))
          else
            Wrap(spacing: 14, runSpacing: 6, children: [
              for (final b in bilgi)
                InkWell(
                  onTap: b.$1 == Icons.call_outlined ? () => launchUrl(Uri.parse('tel:${b.$2.replaceAll(' ', '')}')) : null,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(b.$1, size: 15, color: t.sub),
                    const SizedBox(width: 4),
                    Text(b.$2, style: TextStyle(color: t.sub2, fontSize: 13)),
                  ]),
                ),
            ]),
          if (metinOku(ted['aciklama']).isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${ted['aciklama']}', style: TextStyle(color: t.sub, fontSize: 12.5))),
        ]),
      ),
      KKpiIzgara([
        KKpi(etiket: 'Toplam borç (alış)', deger: tl(v['borc'], kisa: true), ikon: Icons.receipt_long_outlined, renk: t.mavi),
        KKpi(etiket: 'Ödenen', deger: tl(v['odeme'], kisa: true), ikon: Icons.payments_outlined, renk: t.yesil),
        KKpi(etiket: 'Bakiye', deger: tl(bakiye, kisa: true), ikon: Icons.account_balance_wallet_outlined, renk: bakiye > 0 ? t.kirmizi : t.yesil),
      ]),
      const SizedBox(height: 8),
      KButon('Ödeme Gir', ikon: Icons.add_card, genis: true, onTap: () => _odeme(ted, bakiye)),
      const SizedBox(height: 12),
      KCipler(
        secenekler: [('cari', 'Ekstre ${ekstre.length}'), ('katalog', 'Alış kataloğu ${katalog.length}'), ('saglanan', 'Sağlanan malzemeler ${saglanan.length}')],
        secili: _sekme,
        onSec: (s) => setState(() => _sekme = s),
      ),
      const SizedBox(height: 8),
      if (_sekme == 'cari') ...[
        if (ekstre.isEmpty)
          const KBos(baslik: 'Hareket yok', ikon: Icons.receipt_long_outlined, aciklama: 'Bu tedarikçiye alış faturası girilmemiş ve ödeme yapılmamış.')
        else
          for (final e in ekstre)
            KSatir(
              solIkon: Icon(e['tip'] == 'borc' ? Icons.receipt_long_outlined : Icons.payments_outlined, color: e['tip'] == 'borc' ? t.kirmizi : t.yesil),
              baslik: '${e['aciklama']}',
              alt: tarihYaz(e['tarih'], saat: false),
              sag: Text('${e['tip'] == 'borc' ? '+' : '−'}${tl(e['tutar'])}', style: TextStyle(color: e['tip'] == 'borc' ? t.kirmizi : t.yesil, fontSize: 14, fontWeight: FontWeight.w700)),
            ),
      ],
      if (_sekme == 'katalog') ...[
        if (katalog.isEmpty)
          const KBos(baslik: 'Alış geçmişi yok', ikon: Icons.inventory_outlined, aciklama: 'Katalog bu tedarikçinin alış faturalarındaki kalemlerden oluşur. Faturada tedarikçi seçip kalem girildikçe dolar.')
        else if (genisMi(context))
          KKart(
            padding: EdgeInsets.zero,
            child: KTablo(
              basliklar: const ['Malzeme', 'Alış', 'Son fiyat', 'Ortalama', 'En düşük', 'En yüksek', 'Trend', 'Son alış'],
              sagaYasla: const {1, 2, 3, 4, 5, 6},
              satirlar: [
                for (final k in katalog)
                  [
                    '${k['ad']}',
                    '${k['adet']}',
                    '${tl(k['son_fiyat'])}/${k['birim']}',
                    tl(k['ort_fiyat']),
                    tl(k['min_fiyat']),
                    tl(k['max_fiyat']),
                    '${sayiOku(k['trend']) > 0 ? '+' : ''}${yuzde(k['trend'])}',
                    tarihYaz(k['son_tarih'], saat: false),
                  ],
              ],
            ),
          )
        else
          for (final k in katalog)
            KKart(
              renk: sayiOku(k['trend']) > 5 ? t.kirmizi : (sayiOku(k['trend']) < -5 ? t.yesil : null),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text('${k['ad']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold))),
                  Text('${tl(k['son_fiyat'])}/${k['birim']}', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                ]),
                Text('${k['adet']} alış · ort ${tl(k['ort_fiyat'])} · ${tl(k['min_fiyat'])}–${tl(k['max_fiyat'])} · son ${tarihYaz(k['son_tarih'], saat: false)}',
                    style: TextStyle(color: t.sub, fontSize: 12)),
                if (sayiOku(k['trend']).abs() >= 0.1)
                  Text('Son fiyat ortalamadan ${sayiOku(k['trend']) > 0 ? '+' : ''}${yuzde(k['trend'])}',
                      style: TextStyle(color: sayiOku(k['trend']) > 0 ? t.kirmizi : t.yesil, fontSize: 12, fontWeight: FontWeight.w700)),
              ]),
            ),
      ],
      if (_sekme == 'saglanan') ...[
        KButon('Malzeme bağla', ikon: Icons.link, ikincil: true, genis: true,
            onTap: () => _malzemeBagla(ted, malzemeler, {for (final s in saglanan) tamOku(s['malzeme_id'])})),
        const SizedBox(height: 8),
        if (saglanan.isEmpty)
          const KBos(
            baslik: 'Bağlı malzeme yok',
            ikon: Icons.link_off,
            aciklama: 'Faturası olmayan yeni tedarikçiye "Fiyat Araştır" (RFQ) gidebilmesi için sağladığı malzemeleri bağlayın.',
          )
        else
          for (final s in saglanan)
            KSatir(
              solIkon: Icon(Icons.inventory_2_outlined, color: tamOku(s['aktif']) == 1 ? t.mavi : t.sub),
              baslik: '${s['ad']}',
              alt: sayiOku(s['guncel_fiyat']) > 0 ? '${tl(s['guncel_fiyat'])}/${s['birim']}' : 'Fiyat girilmemiş — dokunup girin',
              onTap: () => _fiyatGir(ted, s),
              sag: IconButton(tooltip: 'Bağlantıyı kaldır', onPressed: () => _baglantiSil(ted, s), icon: Icon(Icons.link_off, color: t.kirmizi)),
            ),
      ],
    ]);
  }
}

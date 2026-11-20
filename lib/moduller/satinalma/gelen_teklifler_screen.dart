import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../ui/kit.dart';
import 'ortak.dart';
import 'satinalma_talep_screen.dart';

const _renkler = [Color(0xFF7C3AED), Color(0xFFEA580C), Color(0xFF0891B2), Color(0xFFDB2777), Color(0xFF2563EB), Color(0xFFCA8A04), Color(0xFFDC2626), Color(0xFF0D9488)];
const _talepDurumAd = {
  'yeni': 'Yeni', 'departman_onay': 'Departman onayında', 'teklif': 'Teklif toplanıyor', 'onayda': 'Patron onayında', 'fiyat_onay': 'Fiyat onayında',
  'onaylandi': 'Onaylandı', 'siparis': 'Siparişe döndü', 'tamamlandi': 'Tamamlandı', 'reddedildi': 'Reddedildi',
};

String _kanalAd(dynamic k) {
  final s = metinOku(k);
  if (s.isEmpty) return 'iletilemedi (bağlantı elle gönderilmeli)';
  return s.split('+').map((x) => x == 'wa' ? 'WhatsApp' : (x == 'mail' ? 'E-posta' : x)).join(' + ');
}

Map<String, dynamic> _hucreler(Map<String, dynamic> g, dynamic mid) => harita(harita(g['hucre'])['$mid']);

double _tasarrufU(Map<String, dynamic> g, Map<String, dynamic> u) {
  final f = _hucreler(g, u['id']).values.map((c) => sayiOku(harita(c)['fiyat'])).where((x) => x > 0).toList();
  if (f.length < 2) return 0;
  f.sort();
  return (f.last - f.first) * sayiOku(u['miktar']);
}

double _tasarruf(Map<String, dynamic> g) => liste(g['urunler']).fold(0.0, (s, u) => s + _tasarrufU(g, u));

/// Web /gelen-teklifler — tedarikçi portalından / WhatsApp / e-postadan gelen RFQ teklifleri; karşılaştırma, AI tarama, hatırlatma, sipariş.
class GelenTekliflerScreen extends StatefulWidget {
  const GelenTekliflerScreen({super.key});
  @override
  State<GelenTekliflerScreen> createState() => _GelenTekliflerScreenState();
}

class _GelenTekliflerScreenState extends State<GelenTekliflerScreen> {
  String _sekme = 'aktif';
  String _ara = '';
  int _sonId = 0;
  bool _yeniVar = false;
  bool _taraniyor = false;

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/gelen-teklifler',
      baslik: 'Gelen Teklifler',
      ikon: Icons.mark_email_read_outlined,
      otomatik: const Duration(seconds: 30),
      govde: _govde,
      araclar: (ctx, v, yenile) => [
        IconButton(tooltip: 'Nasıl çalışır?', onPressed: _nasil, icon: const Icon(Icons.help_outline)),
        if (v['sahip'] == true)
          PopupMenuButton<String>(
            tooltip: 'Test araçları (yalnız yönetici)',
            icon: const Icon(Icons.science_outlined),
            onSelected: (s) => _test(s, yenile),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'kur', child: Text('Test kur (örnek malzeme + tedarikçi)')),
              PopupMenuItem(value: 'sifirla', child: Text('Test verilerini sil')),
              PopupMenuItem(value: 'arastir', child: Text('Talepsiz fiyat araştır (kritik stok)')),
            ],
          ),
      ],
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final gt = liste(v['gruplar']);
    final son = tamOku(v['sonId']);
    if (_sonId == 0 || son <= _sonId) {
      _sonId = son;
      _yeniVar = false;
    } else {
      _yeniVar = true;
      _sonId = son;
    }
    final akt = gt.where((g) => g['gecmis'] != true).toList();
    final gec = gt.where((g) => g['gecmis'] == true).toList();
    var bek = 0, fiyat = 0, ai = 0;
    var tas = 0.0;
    for (final g in akt) {
      for (final td in liste(g['tedarikciler'])) {
        if (td['durum'] != 'geldi') bek++;
        fiyat += tamOku(td['fiyat_say']);
      }
      for (final s in harita(g['hucre']).values) {
        for (final c in harita(s).values) {
          final k = metinOku(harita(c)['kaynak']);
          if (k.isNotEmpty && k != 'portal') ai++;
        }
      }
      tas += _tasarruf(g);
    }
    final kaynak = _sekme == 'aktif' ? akt : gec;
    final gorunen = kaynak.where((g) => saIcerir([
          g['baslik'], g['etkinlik'], g['talep_id'] != null ? '#${g['talep_id']}' : '',
          ...liste(g['tedarikciler']).map((x) => '${x['ad']} ${x['kod']}'),
          ...liste(g['urunler']).map((u) => u['ad']),
        ].join(' '), _ara)).toList();
    return KGovde(yenile: yenile, children: [
      if (_yeniVar) SaBilgi('Yeni teklif geldi — liste güncellendi.', renk: t.yesil, ikon: Icons.notifications_active_outlined),
      KKpiIzgara([
        KKpi(etiket: 'Açık talep', deger: '${akt.length}', ikon: Icons.pending_actions, renk: t.mor1),
        KKpi(etiket: 'Yanıt bekleyen', deger: '$bek', ikon: Icons.hourglass_top, renk: const Color(0xFFD97706)),
        KKpi(etiket: 'Gelen fiyat', deger: '$fiyat', ikon: Icons.sell_outlined, renk: const Color(0xFF2563EB)),
        KKpi(etiket: 'AI\'ın okuduğu', deger: '$ai', ikon: Icons.auto_awesome_outlined, renk: const Color(0xFFDB2777)),
        KKpi(etiket: 'En ucuzla kazanç', deger: tl(tas, kisa: true), ikon: Icons.price_check, renk: const Color(0xFF059669)),
      ]),
      Wrap(spacing: 8, runSpacing: 8, children: [
        KButon('Yazılı cevapları AI ile tara', ikon: Icons.auto_awesome_outlined, yukleniyor: _taraniyor, onTap: () => _aiTara(yenile)),
        KButon('Taleplere git', ikon: Icons.request_quote_outlined, ikincil: true, onTap: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SatinalmaTalepScreen()));
          yenile();
        }),
      ]),
      const SizedBox(height: 12),
      KCipler(secenekler: [('aktif', 'Aktif ${akt.length}'), ('gecmis', 'Geçmiş ${gec.length}')], secili: _sekme, onSec: (k) => setState(() => _sekme = k)),
      KAra(ipucu: 'Talep no, tedarikçi veya ürün…', onDegis: (s) => setState(() => _ara = s)),
      if (gorunen.isEmpty)
        KBos(
          baslik: _ara.isNotEmpty ? 'Aramaya uyan teklif yok' : (_sekme == 'aktif' ? 'Şu an açık bir fiyat isteği yok' : 'Geçmiş yok'),
          aciklama: 'Fiyat isteği Satın Alma Talepleri\'nde talebi açıp "Fiyat Araştır" ile gönderilir; tedarikçi bağlantıdan fiyat girince burada görünür.',
          ikon: Icons.mark_email_unread_outlined,
        )
      else
        SaIzgara([for (final g in gorunen) _grupKart(g, t, yenile)], minGenislik: 440),
    ]);
  }

  Widget _grupKart(Map<String, dynamic> g, TemaProvider t, Future<void> Function() yenile) {
    final ted = liste(g['tedarikciler']);
    final n = ted.length;
    final yan = tamOku(g['yanitlayan']);
    final renk = n == 0 ? t.sub : (yan >= n ? t.yesil : (yan > 0 ? const Color(0xFF0EA5E9) : t.amber));
    return KKart(
      renk: renk,
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => _GrupDetay(g: g)));
        yenile();
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(metinOku(g['baslik']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5)),
        const SizedBox(height: 3),
        Text('${liste(g['urunler']).length} ürün · $n tedarikçi${metinOku(g['talep_durum']).isNotEmpty ? ' · ${_talepDurumAd[g['talep_durum']] ?? g['talep_durum']}' : ''}',
            style: TextStyle(color: t.sub, fontSize: 12.5)),
        if (metinOku(g['etkinlik']).isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 4), child: KRozet('${g['etkinlik']}${metinOku(g['etkinlik_tarih']).isNotEmpty ? ' · ${tarihYaz(g['etkinlik_tarih'], saat: false)}' : ''}', renk: const Color(0xFFEC4899))),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: n == 0 ? 0 : yan / n, minHeight: 6, backgroundColor: t.line, color: renk),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: Text('$yan/$n yanıt${metinOku(g['son_yanit']).isNotEmpty ? ' · ${gecenZaman(g['son_yanit'])}' : ''}', style: TextStyle(color: t.sub, fontSize: 12.5))),
          if (sayiOku(g['en_iyi_toplam']) > 0) Text(tl(g['en_iyi_toplam'], kisa: true), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
        ]),
      ]),
    );
  }

  Future<void> _aiTara(Future<void> Function() yenile) async {
    setState(() => _taraniyor = true);
    await saGonder(context, '/gelen-teklifler/oku', {}, json: false);
    if (!mounted) return;
    setState(() => _taraniyor = false);
    yenile();
  }

  Future<void> _test(String s, Future<void> Function() yenile) async {
    if (s == 'arastir') {
      saAc(context, '/fiyat-arastir-sec', 'Talepsiz Fiyat Araştır');
      return;
    }
    final kur = s == 'kur';
    final ok = await kOnay(context, kur ? 'Test kurulsun mu?' : 'Test verileri silinsin mi?',
        aciklama: kur
            ? 'Test için örnek bir malzeme + tedarikçi oluşturulacak (sonra silebilirsiniz).'
            : 'TÜM test verileri silinecek (gelen teklifler, RFQ\'lar, tekliften oluşan siparişler, TEST tedarikçi/malzeme) — gerçek veriler etkilenmez.',
        tehlikeli: !kur,
        evet: kur ? 'Evet, kur' : 'Evet, sil');
    if (!ok || !mounted) return;
    await saGonder(context, kur ? '/rfq-test-kur' : '/rfq-test-sifirla', {}, json: false);
    yenile();
  }

  void _nasil() {
    kAltSayfa(context, baslik: 'Nasıl çalışır?', icerik: (c) {
      final t = c.watch<TemaProvider>();
      Widget a(String n, String b, String m) => KSatir(solIkon: CircleAvatar(radius: 14, backgroundColor: t.mor1, child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700))), baslik: b, alt: m);
      return Column(children: [
        a('1', 'Fiyat isteği gider.', 'Satın Alma Talepleri\'nde talebi açıp "Fiyat Araştır" → tedarikçilere WhatsApp + e-posta ile kişiye özel teklif bağlantısı gider.'),
        a('2', 'Tedarikçi formu doldurur.', 'Bağlantıdan birim fiyat, teslim tarihi ve vadeyi girer → fiyat anında buraya ve talebin içine düşer.'),
        a('AI', 'Yazıyla cevap verirse AI okur.', '"Tuz 30, peynir 280" gibi mesajdan ürün + fiyatı AI çıkarır ve hangi talebe ait olduğunu kendisi bulur.'),
        a('3', 'Karşılaştır, karar ver.', 'Yeşil = en ucuz. "Talepte aç" → teklifler orada hazır → onaya / siparişe gönderin.'),
      ]);
    });
  }
}

// ───────────────────────── Grup detayı (tedarikçiler + ürün ürün karşılaştırma) ─────────────────────────
class _GrupDetay extends StatefulWidget {
  final Map<String, dynamic> g;
  const _GrupDetay({required this.g});
  @override
  State<_GrupDetay> createState() => _GrupDetayState();
}

class _GrupDetayState extends State<_GrupDetay> {
  final Map<String, String> _secim = {}; // talepsiz grupta ürün → seçili tedarikçi
  bool _gonderiyor = false;

  Map<String, dynamic> get g => widget.g;

  @override
  void initState() {
    super.initState();
    if (g['talep_id'] == null) {
      harita(g['en_ucuz']).forEach((mid, tid) {
        if (tid != null && _hucreler(g, mid)['$tid'] != null) _secim[mid] = '$tid';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final ted = liste(g['tedarikciler']);
    final ur = liste(g['urunler']);
    final tas = _tasarruf(g);
    final talepId = g['talep_id'];
    final tamam = ted.where((x) => tamOku(x['fiyat_say']) >= ur.length && sayiOku(x['toplam']) > 0).toList();
    final enIyiT = ted.length > 1 && tamam.isNotEmpty ? tamam.reduce((a, b) => sayiOku(b['toplam']) < sayiOku(a['toplam']) ? b : a)['id'] : null;
    final eslesmeyen = liste(g['eslesmeyen']);
    return KSayfa(
      baslik: metinOku(g['baslik']),
      ikon: Icons.mark_email_read_outlined,
      govde: KGovde(maxGenislik: 1000, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          if (metinOku(g['etkinlik']).isNotEmpty) KRozet(metinOku(g['etkinlik']), renk: const Color(0xFFEC4899)),
          if (metinOku(g['talep_durum']).isNotEmpty) KRozet(_talepDurumAd[g['talep_durum']] ?? metinOku(g['talep_durum']), renk: t.mavi),
          if (ted.isNotEmpty)
            KRozet(tamOku(g['yanitlayan']) >= ted.length ? 'Herkes yanıt verdi' : (tamOku(g['yanitlayan']) > 0 ? '${g['yanitlayan']}/${ted.length} yanıt' : 'Yanıt bekleniyor'),
                renk: tamOku(g['yanitlayan']) >= ted.length ? t.yesil : t.amber),
        ]),
        const SizedBox(height: 6),
        Text('${ur.length} ürün · İstek: ${tarihYaz(g['gonderim'])}${metinOku(g['son_yanit']).isNotEmpty ? ' · Son yanıt: ${gecenZaman(g['son_yanit'])}' : ''}${metinOku(g['isteyen']).isNotEmpty ? ' · ${g['isteyen']}' : ''}',
            style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 10),
        KKpiIzgara([
          if (sayiOku(g['en_iyi_toplam']) > 0) KKpi(etiket: 'En ucuzlarla toplam', deger: tl(g['en_iyi_toplam']), renk: t.mor1),
          if (tas > 0) KKpi(etiket: 'En ucuzu seçince kazanç', deger: tl(tas), renk: t.yesil),
        ]),
        if (talepId != null)
          KButon('Talepte aç → onaya gönder', ikon: Icons.open_in_new, genis: true, onTap: () => _talepAc(talepId))
        else if (tamOku(g['yanitlayan']) > 0)
          KButon('Seçilenlerle sipariş ver', ikon: Icons.shopping_cart_checkout, renk: t.yesil, genis: true, yukleniyor: _gonderiyor, onTap: _siparis),
        const SizedBox(height: 14),
        if (ted.isEmpty || ur.isEmpty)
          const KBos(baslik: 'Bu istekte ürün/tedarikçi bilgisi yok', aciklama: 'Fiyat isteği gönderilirken ürün veya tedarikçi listesi boş kalmış.')
        else ...[
          KBaslik('Tedarikçiler (${ted.length})', ikon: Icons.storefront_outlined, alt: 'Dokunun → teklifin tüm detayı'),
          SaIzgara([
            for (var i = 0; i < ted.length; i++) _tedKart(ted[i], _renkler[i % _renkler.length], ur.length, ted[i]['id'] == enIyiT, t),
          ], minGenislik: 300),
          const SizedBox(height: 8),
          KBaslik('Ürün ürün fiyat karşılaştırma', ikon: Icons.bar_chart, alt: 'Çubuk = birim fiyat · yeşil = en ucuz${talepId == null ? ' · dokunun → o tedarikçiyi seçin' : ''}'),
          for (final u in ur) _urunKart(u, ted, t),
          if (eslesmeyen.isNotEmpty)
            SaBilgi('AI şu fiyatları okudu ama talepteki bir ürünle eşleştiremedi (elle kontrol edin): ${eslesmeyen.map((e) => '${e['ted']}: ${e['urun']} ${tl(e['fiyat'])}').join(' · ')}',
                renk: t.amber, ikon: Icons.warning_amber_outlined),
          if (talepId == null && tamOku(g['yanitlayan']) > 0)
            const SaBilgi('En ucuzlar hazır seçili. Başka tedarikçi isterseniz o satırdaki fiyata dokunun, sonra "Seçilenlerle sipariş ver".', ikon: Icons.lightbulb_outline),
        ],
      ]),
    );
  }

  Future<void> _talepAc(dynamic id) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SatinalmaTalepScreen(url: '/satinalma-talep?ac=$id')));
  }

  Widget _tedKart(Map<String, dynamic> td, Color renk, int urunSay, bool enIyi, TemaProvider t) {
    final geldi = td['durum'] == 'geldi';
    return KKart(
      renk: renk,
      onTap: () => _tedDetay(td),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (enIyi) Padding(padding: const EdgeInsets.only(bottom: 6), child: KRozet('EN İYİ TOPLAM', renk: t.yesil, ikon: Icons.star)),
        Text('${td['anlasmali'] == 1 ? '⭐ ' : ''}${metinOku(td['ad'], '—')}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5)),
        Text('${_kanalAd(td['kanal'])} ile gönderildi', style: TextStyle(color: t.sub, fontSize: 12)),
        const SizedBox(height: 6),
        if (geldi)
          Text('${tl(td['toplam'])}  ·  ${td['fiyat_say']}/$urunSay ürün', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 15))
        else
          Text('Yanıt bekleniyor · ${gecenZaman(td['gonderim'])}', style: TextStyle(color: t.amber, fontWeight: FontWeight.w700, fontSize: 13)),
        Text('Teslim: ${metinOku(td['teslim']).isEmpty ? '—' : tarihYaz(td['teslim'], saat: false)} · Vade: ${metinOku(td['vade'], '—')}', style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          KButon('Detay', ikon: Icons.visibility_outlined, ikincil: true, onTap: () => _tedDetay(td)),
          if (!geldi && td['tel'] == true) KButon('Hatırlat', ikon: Icons.notifications_active_outlined, ikincil: true, onTap: () => _hatirlat(td['rfq_id'])),
          if (metinOku(td['link']).isNotEmpty) KButon('Bağlantı', ikon: Icons.link, ikincil: true, onTap: () => saKopyala(context, metinOku(td['link']), 'Bağlantı kopyalandı — tedarikçiye iletebilirsiniz.')),
        ]),
      ]),
    );
  }

  Widget _urunKart(Map<String, dynamic> u, List<Map<String, dynamic>> ted, TemaProvider t) {
    final satir = _hucreler(g, u['id']);
    final fiyatlar = satir.values.map((c) => sayiOku(harita(c)['fiyat'])).where((x) => x > 0).toList();
    final hal = harita(u['hal']);
    final alis = harita(u['son_alis']);
    final maks = [...fiyatlar, 0.0].reduce((a, b) => a > b ? a : b);
    final cok = fiyatlar.length > 1;
    final tu = _tasarrufU(g, u);
    final enUcuz = '${harita(g['en_ucuz'])['${u['id']}']}';
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(metinOku(u['ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 14.5))),
          Text('İhtiyaç: ${sayiYaz(u['miktar'])} ${metinOku(u['birim'])}', style: TextStyle(color: t.sub, fontSize: 12.5)),
        ]),
        if (tu > 0) Padding(padding: const EdgeInsets.only(top: 4), child: KRozet('${tl(tu)} fark', renk: t.yesil, ikon: Icons.trending_down)),
        const SizedBox(height: 6),
        Text(
            hal.isNotEmpty
                ? 'Hal${tamOku(hal['cesit']) > 1 ? ' (${hal['cesit']} çeşit)' : ''}: ${tl(hal['ort'])}/${metinOku(hal['birim'])}${sayiOku(hal['min']) > 0 && sayiOku(hal['max']) > 0 ? ' (${tl(hal['min'], kisa: true)}–${tl(hal['max'], kisa: true)})' : ''} · ${tarihYaz(hal['tarih'], saat: false)}'
                : 'Hal fiyatı yok — hal yalnız sebze-meyve satar',
            style: TextStyle(color: t.sub2, fontSize: 12.5)),
        Text(
            alis.isNotEmpty
                ? 'Son alışımız: ${tl(alis['fiyat'])}${metinOku(alis['birim']).isNotEmpty ? '/${alis['birim']}' : ''} · ${alis['kaynak'] == 'fatura' ? 'faturadan' : 'siparişten'}${metinOku(alis['ted']).isNotEmpty ? ' · ${alis['ted']}' : ''}${metinOku(alis['tarih']).isNotEmpty ? ' · ${tarihYaz(alis['tarih'], saat: false)}' : ''}'
                : 'Bu ürünü daha önce almamışız (fatura/sipariş yok)',
            style: TextStyle(color: t.sub2, fontSize: 12.5)),
        const SizedBox(height: 8),
        for (var i = 0; i < ted.length; i++)
          Builder(builder: (_) {
            final td = ted[i];
            final c = harita(satir['${td['id']}']);
            final renk = _renkler[i % _renkler.length];
            if (c.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  SizedBox(width: 120, child: Text(metinOku(td['ad']), overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12.5))),
                  Expanded(child: Text(td['durum'] == 'geldi' ? 'fiyat vermedi' : 'bekleniyor', style: TextStyle(color: t.sub, fontSize: 12.5))),
                ]),
              );
            }
            final f = sayiOku(c['fiyat']);
            final ucuz = cok && enUcuz == '${td['id']}';
            final sec = g['talep_id'] == null && _secim['${u['id']}'] == '${td['id']}';
            return InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: g['talep_id'] != null ? () => _tedDetay(td) : () => setState(() => _secim['${u['id']}'] = '${td['id']}'),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: sec ? BoxDecoration(color: t.yesil.withValues(alpha: .08), borderRadius: BorderRadius.circular(8), border: Border.all(color: t.yesil)) : null,
                child: Row(children: [
                  SizedBox(width: 120, child: Text(metinOku(td['ad']), overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(value: maks > 0 ? (f / maks).clamp(.06, 1.0) : .06, minHeight: 10, backgroundColor: t.card2, color: ucuz ? t.yesil : renk),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${tl(f)}/${metinOku(u['birim'])}', style: TextStyle(color: ucuz ? t.yesil : t.ink, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  if (sec) Padding(padding: const EdgeInsets.only(left: 4), child: Icon(Icons.check_circle, size: 16, color: t.yesil)),
                ]),
              ),
            );
          }),
      ]),
    );
  }

  void _tedDetay(Map<String, dynamic> td) {
    final ur = liste(g['urunler']);
    kAltSayfa(context, baslik: '${td['anlasmali'] == 1 ? '⭐ ' : ''}${metinOku(td['ad'])}', icerik: (c) {
      final t = c.watch<TemaProvider>();
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${metinOku(g['baslik'])}${metinOku(g['etkinlik']).isNotEmpty ? ' · ${g['etkinlik']}' : ''}', style: TextStyle(color: t.sub, fontSize: 12.5)),
        const SizedBox(height: 8),
        SaDeger('Durum', td['durum'] == 'geldi' ? 'Teklif geldi${metinOku(td['yanit']).isNotEmpty ? ' · ${gecenZaman(td['yanit'])}' : ''}' : 'Yanıt bekleniyor'),
        SaDeger('İstek gönderildi', '${tarihYaz(td['gonderim'])} · ${_kanalAd(td['kanal'])}'),
        SaDeger('Teslim tarihi', metinOku(td['teslim']).isEmpty ? '—' : tarihYaz(td['teslim'], saat: false)),
        SaDeger('Vade / ödeme', metinOku(td['vade'], '—')),
        if (metinOku(td['not']).isNotEmpty) SaBilgi('Tedarikçinin notu: ${td['not']}'),
        const Divider(),
        for (final u in ur)
          Builder(builder: (_) {
            final hc = harita(_hucreler(g, u['id'])['${td['id']}']);
            if (hc.isEmpty) {
              return KSatir(baslik: metinOku(u['ad']), alt: '${sayiYaz(u['miktar'])} ${metinOku(u['birim'])}', sag: Text(td['durum'] == 'geldi' ? 'fiyat vermedi' : 'bekleniyor', style: TextStyle(color: t.sub, fontSize: 12.5)));
            }
            final k = metinOku(hc['kaynak']);
            final kAd = k == 'portal' ? 'Teklif formu' : ((k == 'wa' || k == 'whatsapp') ? 'WhatsApp · AI okudu' : 'E-posta · AI okudu');
            return KSatir(
              baslik: metinOku(u['ad']),
              alt: '${sayiYaz(u['miktar'])} ${metinOku(u['birim'])} · $kAd ${gecenZaman(hc['zaman'])}${metinOku(hc['metin']).isNotEmpty && k != 'portal' ? '\nTedarikçinin mesajı: ${hc['metin']}' : ''}',
              sag: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('${tl(hc['fiyat'])}/${metinOku(u['birim'])}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                Text(tl(sayiOku(hc['fiyat']) * sayiOku(u['miktar'])), style: TextStyle(color: t.sub, fontSize: 12)),
              ]),
            );
          }),
        const SizedBox(height: 8),
        Text('Toplam: ${tl(td['toplam'])} (${td['fiyat_say']}/${ur.length} ürün)', textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (metinOku(td['link']).isNotEmpty) KButon('Teklif bağlantısını kopyala', ikon: Icons.link, ikincil: true, onTap: () => saKopyala(c, metinOku(td['link']), 'Bağlantı kopyalandı.')),
          if (td['durum'] != 'geldi' && td['tel'] == true) KButon('WhatsApp\'tan hatırlat', ikon: Icons.notifications_active_outlined, ikincil: true, onTap: () => _hatirlat(td['rfq_id'])),
          if (g['talep_id'] != null) KButon('Talepte aç', ikon: Icons.open_in_new, onTap: () => _talepAc(g['talep_id'])),
        ]),
      ]);
    });
  }

  Future<void> _hatirlat(dynamic rfq) async {
    await saGonder(context, '/gelen-teklifler/hatirlat', {'rfq': rfq}, basari: 'Hatırlatma WhatsApp ile gönderildi.');
  }

  Future<void> _siparis() async {
    final ids = <dynamic>[];
    _secim.forEach((mid, tid) {
      final c = harita(_hucreler(g, mid)[tid]);
      if (c['id'] != null) ids.add(c['id']);
    });
    if (ids.isEmpty) return kToast(context, 'Önce en az bir fiyat seçin.', hata: true);
    final ok = await kOnay(context, 'Sipariş verilsin mi?', aciklama: '${ids.length} ürün, seçtiğiniz tedarikçilere göre siparişe dönüşecek ve tedarikçilere WhatsApp + e-posta ile gönderilecek.', evet: 'Evet, sipariş ver');
    if (!ok || !mounted) return;
    setState(() => _gonderiyor = true);
    final c = await saGonder(context, '/gelen-teklifler/siparis', {'teklif': ids}, json: false);
    if (!mounted) return;
    setState(() => _gonderiyor = false);
    if (c?.ok == true) Navigator.pop(context);
  }
}

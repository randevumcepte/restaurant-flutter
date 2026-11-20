import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// /patron-ai — Patron AI komuta merkezi (web patron_ai ile aynı veri). ?tip=sabah|aksam, ?gm=1 (Genel Müdür), ?force=1 (yeniden üret).
/// Bloklar: selam + kaynak rozeti + Sabah/Akşam, 5 KPI, bugün öncelikler (detay penceresi → onayla/reddet/fiyat sor/eylem),
/// AI önerisi + Patron AI sohbet + 4 hazır AI eylemi (onaylı), AI kullanım, departmanların durumu, detaylı AI analizi,
/// dünden devam (çözüldü), bugünkü gündem, iletişim (e-posta / WhatsApp), alt şerit.
class PatronAiScreen extends StatefulWidget {
  final String url;
  final String baslik;
  const PatronAiScreen({super.key, this.url = '/patron-ai', this.baslik = ''});
  @override
  State<PatronAiScreen> createState() => _PatronAiScreenState();
}

class _PatronAiScreenState extends State<PatronAiScreen> {
  final _k = GlobalKey<KopruEkranState>();
  late String _tip;
  late final bool _gm;
  bool _demo = false;
  final Set<String> _analizIstendi = {};
  bool _uretiliyor = false;
  final Set<int> _cozulen = {};
  final Set<String> _bitenIs = {};

  @override
  void initState() {
    super.initState();
    final q = Uri.parse(widget.url).queryParameters;
    _tip = q['tip'] == 'aksam' ? 'aksam' : 'sabah';
    _gm = q['gm'] == '1' || q['gm'] == 'true';
    _demo = q['demo'] == '1';
  }

  Map<String, String> get _q => {'tip': _tip, if (_gm) 'gm': '1', if (_demo) 'demo': '1'};

  Future<void> _tipSec(String tip) async {
    if (tip == _tip) return;
    setState(() => _tip = tip);
  }

  /// Yenile (web: ?force=1) — brifingi yeniden üretir, sonra normal adresle yükler
  Future<void> _uret() async {
    setState(() => _uretiliyor = true);
    await aiAl(context, '/patron-ai', q: {..._q, 'force': '1'});
    if (!mounted) return;
    setState(() => _uretiliyor = false);
    await _k.currentState?.yukle();
  }

  /// AI analizi önbellekte yoksa (aiSoguk) arka planda üret, hazır olunca sessizce tazele (web: ?frag=analiz)
  void _analizUret() {
    if (_analizIstendi.contains(_tip) || _demo) return;
    _analizIstendi.add(_tip);
    final tip = _tip;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final c = await aiAl(context, '/patron-ai', q: {'frag': 'analiz', 'tip': tip, if (_gm) 'gm': '1'});
      if (!mounted || tip != _tip) return;
      if (c.ok) _k.currentState?.yukle(sessiz: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/patron-ai',
      q: _q,
      baslik: widget.baslik.isNotEmpty ? widget.baslik : (_gm ? 'Genel Müdür Brifingi' : 'Patron AI'),
      ikon: Icons.auto_awesome_outlined,
      araclar: (c, v, y) => [
        IconButton(
          tooltip: 'Brifingi yeniden üret',
          onPressed: _uretiliyor ? null : _uret,
          icon: _uretiliyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_mode),
        ),
      ],
      govde: (c, v, yenile) {
        if (v['aiSoguk'] == true && v['brief'] != null) _analizUret();
        return _govde(c, v, yenile);
      },
    );
  }

  Widget _govde(BuildContext c, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = c.watch<TemaProvider>();
    final brief = harita(v['brief']);
    final b = harita(brief['veri']);
    final demo = v['demo'] == true;
    final aiVar = v['aiVar'] == true;
    final aiSoguk = v['aiSoguk'] == true;
    final ad = metinOku(v['ad']);
    final adK = ad.isEmpty ? '' : ad.split(' ').first;
    final genis = genisMi(c);

    final hero = Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      alignment: WrapAlignment.spaceBetween,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _tip == 'aksam' ? [const Color(0xFF4338CA), const Color(0xFF1E1B4B)] : [const Color(0xFFF6A623), const Color(0xFFF56A8B)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(_tip == 'aksam' ? '🌙' : '☀️', style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${selamMetni()}${adK.isEmpty ? '' : ' $adK'} 👋', style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.4)),
            const SizedBox(height: 4),
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text('${bugunMetni()} · ${_tip == 'aksam' ? 'akşam raporu' : 'sabah brifingi'}', style: TextStyle(color: t.sub, fontSize: 12.5)),
              KRozet(aiVar ? '✨ AI yazdı' : (aiSoguk ? '⏳ AI hazırlanıyor' : '⚙️ kural motoru'), renk: t.mor1),
            ]),
          ]),
        ]),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'sabah', label: Text('☀️ Sabah')),
            ButtonSegment(value: 'aksam', label: Text('🌙 Akşam')),
          ],
          selected: {_tip},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _tipSec(s.first),
        ),
      ],
    );

    if (brief.isEmpty) {
      return KGovde(yenile: yenile, children: [
        hero,
        const SizedBox(height: 16),
        KKart(
          child: KBos(
            ikon: Icons.auto_awesome_outlined,
            baslik: 'Bugün için henüz brifing üretilmedi',
            aciklama: 'Brifing satış, stok, personel ve onay verilerinden üretilir. Şimdi üretebilirsin.',
            aksiyon: KButon('Şimdi üret', ikon: Icons.auto_mode, yukleniyor: _uretiliyor, onTap: _uret),
          ),
        ),
      ]);
    }

    final kayip = harita(b['kayip']);
    final kayipTop = kayip.values.fold<double>(0, (s, x) => s + sayiOku(x));
    final ciroY = sayiOku(b['ciro_yuzde']);
    final krit = tamOku(b['kritik_sayi']);
    final acik = tamOku(v['acikAdisyon']);
    final onayOp = tamOku(v['onayOp']);
    final onaySa = tamOku(v['onaySa']);
    final kritikAd = dizi(b['kritik']).take(3).map((e) => metinOku(e)).join(', ');
    final ciroR = metinOku(b['kiyas_etiket']).isNotEmpty ? (ciroY >= 5 ? t.yesil : (ciroY <= -10 ? t.kirmizi : (ciroY < 0 ? t.amber : const Color(0xFF5B8DEF)))) : const Color(0xFF5B8DEF);
    final isler = liste(harita(v['isler'])['isler']).where((i) => !_bitenIs.contains(_isAnahtar(i))).toList();
    final bitenler = dizi(harita(v['isler'])['bitenler']);
    final analiz = liste(v['analiz']);
    final verdict = metinOku(v['aiOzet']).isNotEmpty ? metinOku(v['aiOzet']) : metinOku(brief['metin'], aiSoguk ? 'AI değerlendirmen hazırlanıyor…' : 'Bugün için özet bulunmuyor.');

    final islerKart = _islerKart(c, isler, bitenler);
    final aiPanel = _aiPanel(c, verdict, v['devirSa'] == true);

    return KGovde(yenile: yenile, children: [
      hero,
      const SizedBox(height: 12),
      if (demo)
        KKart(
          renk: t.amber,
          child: Row(children: [
            Icon(Icons.theater_comedy_outlined, color: t.amber),
            const SizedBox(width: 10),
            Expanded(child: Text('DEMO VERİ — gerçek değil; AI\'ın veri olunca nasıl yorumladığını gösterir.', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600))),
            TextButton(
                onPressed: () {
                  setState(() => _demo = false);
                },
                child: const Text('Gerçek veriye dön')),
          ]),
        ),
      KKpiIzgara([
        KKpi(
          etiket: _tip == 'aksam' ? 'Bugünkü ciro' : 'Dünkü ciro',
          deger: tl(b['dun_ciro'], kisa: true),
          alt: sayiOku(b['dun_ciro']) == 0
              ? 'veri kontrolü gerekli'
              : [
                  if (metinOku(b['kiyas_etiket']).isNotEmpty && ciroY != 0) '${ciroY > 0 ? '▲ +' : '▼ '}${yuzde(ciroY.abs())} ${metinOku(b['kiyas_etiket'])}',
                  if (sayiOku(b['kisi_basi']) > 0) 'kişi başı ${tl(b['kisi_basi'], kisa: true)}',
                ].join(' · '),
          ikon: Icons.payments_outlined,
          renk: sayiOku(b['dun_ciro']) == 0 ? t.kirmizi : ciroR,
          onTap: () => aiGit(c, '/dashboard', baslik: 'Özet'),
        ),
        KKpi(
          etiket: 'Kayıp / Zayiat',
          deger: tl(kayipTop, kisa: true),
          alt: '${_tip == 'aksam' ? '(bugün)' : '(dün)'} iskonto ${tl(kayip['iskonto'], kisa: true)} · ikram ${tl(kayip['ikram'], kisa: true)}',
          ikon: Icons.delete_outline,
          renk: kayipTop > 0 ? t.amber : t.yesil,
        ),
        KKpi(
          etiket: 'Kritik stok',
          deger: '$krit ürün',
          alt: krit > 0 ? kritikAd : 'sorun yok 👍',
          ikon: Icons.inventory_2_outlined,
          renk: krit > 0 ? t.kirmizi : t.yesil,
          onTap: krit > 0 ? () => _isDetay(c, 'kritik_stok', 'Kritik Stok') : null,
        ),
        KKpi(
          etiket: 'Açık adisyon',
          deger: '$acik',
          alt: acik > 0 ? 'incelenmesi gerekiyor' : 'hepsi kapalı',
          ikon: Icons.receipt_long_outlined,
          renk: const Color(0xFF5B8DEF),
          onTap: acik > 0 ? () => _isDetay(c, 'acik_adisyon', 'Dünden Açık Adisyonlar') : null,
        ),
        KKpi(
          etiket: 'Onay bekleyen',
          deger: '${onayOp + onaySa} işlem',
          alt: '$onayOp operasyon + $onaySa satın alma',
          ikon: Icons.fact_check_outlined,
          renk: const Color(0xFF5B8DEF),
          onTap: onayOp > 0
              ? () => _isDetay(c, 'islem_onay', 'Bekleyen İşlem Onayları')
              : (onaySa > 0 ? () => _isDetay(c, 'satinalma_onay', 'Onay Bekleyen Satın Alma') : null),
        ),
      ]),
      if (genis)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 17, child: islerKart),
          const SizedBox(width: 12),
          Expanded(flex: 10, child: aiPanel),
        ])
      else ...[
        islerKart,
        aiPanel,
      ],
      _tuketim(c, harita(v['tuketim'])),
      ..._departmanlar(c, liste(v['denetim'])),
      AiBolum('Detaylı AI analizi', ikon: Icons.insights,
          sag: aiSoguk && !aiVar ? Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: t.mor1)),
            const SizedBox(width: 6),
            Text('AI hazırlanıyor', style: TextStyle(color: t.sub, fontSize: 12)),
          ]) : null),
      if (analiz.isEmpty)
        KKart(child: KBos(ikon: Icons.insights, baslik: 'Analiz verisi yok', aciklama: 'Satış, stok ve kayıp verisi oluştukça AI burada her alanı yorumlar.'))
      else
        AiIzgara(minGenislik: 330, cocuklar: [for (final a in analiz) _analizKart(c, a)]),
      const SizedBox(height: 12),
      _surekli(c, harita(v['sureklilik'])),
      _gundem(c, liste(b['takvim'])),
      _iletisim(c, liste(b['eposta']), harita(v['whatsapp'])),
      KKart(
        child: Wrap(spacing: 7, runSpacing: 7, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _mini(t, '💰 Ciro ${tl(b['dun_ciro'], kisa: true)}'),
          _mini(t, '🍽 FC ${yuzde(b['food_cost_yuzde'])}'),
          _mini(t, '📉 Kayıp ${tl(kayipTop, kisa: true)}'),
          _mini(t, '👥 ${sayiYaz(b['misafir'])} misafir'),
          _mini(t, '⚠️ $krit kritik stok'),
          TextButton(onPressed: () => aiGit(c, '/dashboard', baslik: 'Özet'), child: const Text('Detaylı özet →')),
        ]),
      ),
    ]);
  }

  String _isAnahtar(Map<String, dynamic> i) => '${metinOku(i['baslik'])}|${metinOku(harita(i['aksiyon'])['id'])}';

  Widget _mini(TemaProvider t, String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.line)),
        child: Text(s, style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  // ───────── Öncelikler ─────────
  Widget _islerKart(BuildContext c, List<Map<String, dynamic>> isler, List<dynamic> bitenler) {
    final t = c.watch<TemaProvider>();
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.track_changes, size: 20, color: t.mor1),
          const SizedBox(width: 8),
          Expanded(child: Text('Bugün önceliklerin', style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.w800))),
          if (isler.isNotEmpty) KRozet('${isler.length}', renk: t.mor1),
          if (isler.length > 6) TextButton(onPressed: () => _tumIsler(c, isler), child: const Text('Tümünü gör →')),
        ]),
        const SizedBox(height: 10),
        if (isler.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('✅ Bekleyen iş yok — her şey yolunda 👍', style: TextStyle(color: t.sub, fontSize: 13.5))))
        else
          AiIzgara(minGenislik: 300, ara: 8, cocuklar: [for (final i in isler.take(6)) _isSatir(c, i)]),
        if (bitenler.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text('BUGÜN ÇÖZÜLENLER:', style: TextStyle(color: t.sub, fontSize: 11.5, fontWeight: FontWeight.w700)),
            for (final x in bitenler) KRozet('✓ ${metinOku(x)}', renk: t.yesil),
          ]),
        ],
      ]),
    );
  }

  void _tumIsler(BuildContext c, List<Map<String, dynamic>> isler) {
    kAltSayfa(c, baslik: 'Bugün önceliklerin (${isler.length})', icerik: (s) => Column(children: [
          for (final i in isler) Padding(padding: const EdgeInsets.only(bottom: 8), child: _isSatir(s, i, pencereden: true)),
        ]));
  }

  Widget _isSatir(BuildContext c, Map<String, dynamic> i, {bool pencereden = false}) {
    final t = c.watch<TemaProvider>();
    final r = cssRenk(c, i['renk']);
    final ak = harita(i['aksiyon']);
    final tip = metinOku(ak['tip'], 'info');
    VoidCallback? islem;
    String lbl = metinOku(ak['lbl'], 'Aç');
    if (tip == 'pop') {
      islem = () => _isDetay(c, metinOku(i['pop']), metinOku(i['baslik']));
    } else if (tip == 'eylem') {
      lbl = metinOku(ak['lbl'], 'Yap');
      islem = () => _eylemOner(c, metinOku(ak['intent']));
    } else if (tip == 'link') {
      islem = () => aiGit(c, metinOku(ak['url']), baslik: metinOku(i['baslik']));
    } else if (tip == 'ajanda') {
      lbl = metinOku(ak['lbl'], 'Bitti');
      islem = () async {
        final cv = await aiPost(c, '/ajanda/durum', {'id': ak['id'], 'durum': 'tamam'});
        if (!mounted) return;
        if (cv.ok) {
          setState(() => _bitenIs.add(_isAnahtar(i)));
          if (pencereden && c.mounted) Navigator.of(c).maybePop();
          if (c.mounted) kToast(c, 'Harika, tamamlandı! 🎉');
        } else if (c.mounted) {
          kToast(c, cevapMesaj(cv), hata: true);
        }
      };
    }
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Row(children: [
        KIkon(ikonAdi(metinOku(i['ikon']), Icons.task_alt), renk: r, boyut: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (metinOku(i['grup']).isNotEmpty)
              Text(metinOku(i['grup']).toUpperCase(), style: TextStyle(color: r, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .3)),
            Text(metinOku(i['baslik']), style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
            if (metinOku(i['aciklama']).isNotEmpty)
              Text(metinOku(i['aciklama']), maxLines: pencereden ? null : 2, overflow: pencereden ? null : TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12)),
          ]),
        ),
        if (islem != null) ...[
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tip == 'ajanda' ? t.card : t.mor1,
              foregroundColor: tip == 'ajanda' ? t.yesil : Colors.white,
              side: tip == 'ajanda' ? BorderSide(color: t.yesil.withValues(alpha: .5)) : null,
              minimumSize: const Size(56, 40),
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            onPressed: islem,
            child: Text(lbl, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }

  // ───────── AI paneli ─────────
  Widget _aiPanel(BuildContext c, String verdict, bool devirSa) {
    final t = c.watch<TemaProvider>();
    Widget eylemBtn(IconData ik, String lbl, String intent) => Material(
          color: t.card,
          borderRadius: BorderRadius.circular(11),
          child: InkWell(
            borderRadius: BorderRadius.circular(11),
            onTap: () => _eylemOner(c, intent),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: t.line)),
              child: Row(children: [
                KIkon(ik, renk: t.mor1, boyut: 30),
                const SizedBox(width: 8),
                Expanded(child: Text(lbl, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1.3))),
              ]),
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color.alphaBlend(t.mor1.withValues(alpha: .07), t.card), t.card]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color.alphaBlend(t.mor1.withValues(alpha: .2), t.line)),
        boxShadow: t.golge,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(gradient: LinearGradient(colors: [t.mor1, t.mavi]), borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('${_gm ? 'Genel Müdür' : 'Patron'} AI ne öneriyor?', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 10),
        ZenginMetin(verdict, stil: TextStyle(color: t.sub2, fontSize: 13.5, height: 1.5)),
        const SizedBox(height: 12),
        Material(
          borderRadius: BorderRadius.circular(13),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [t.mor1, t.mavi])),
            child: InkWell(
              onTap: () => aiGit(c, '/patron-ai-sohbet', baslik: 'Patron AI'),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                child: Row(children: [
                  Icon(Icons.forum_outlined, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Benimle konuşmak ister misin?', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('Ciro, stok, onaylar… yaz sor — işini bitireyim', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ]),
                  ),
                  Icon(Icons.arrow_forward, color: Colors.white),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Icon(Icons.auto_awesome, size: 16, color: t.mor1),
          const SizedBox(width: 6),
          Expanded(child: Text('Senin için şunları yapabilirim', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700))),
          KRozet('AI', renk: t.mor1),
        ]),
        const SizedBox(height: 8),
        AiIzgara(minGenislik: 170, ara: 7, cocuklar: [
          eylemBtn(Icons.inventory_2_outlined, devirSa ? 'Kritik stok → satın almaya sipariş talebi gönder' : 'Kritik stok için sipariş taslağı hazırla', 'kritik_siparis_olustur'),
          eylemBtn(Icons.local_shipping_outlined, 'Tedarikçiye hatırlatma gönder', 'tedarikci_hatirlat'),
          eylemBtn(Icons.badge_outlined, 'Eksik özlük bilgisini iste', 'eksik_bilgi_iste'),
          eylemBtn(Icons.cake_outlined, 'Doğum günü kutlaması gönder', 'dogum_gunu_kutla'),
        ]),
      ]),
    );
  }

  /// Hazır AI eylemi: öneri kaydı (eylem-oner) → onay penceresi → yürüt (ai-eylem/onayla)
  Future<void> _eylemOner(BuildContext c, String intent) async {
    final cv = await aiPost(c, '/api/patron-ai/eylem-oner', {'intent': intent});
    if (!c.mounted) return;
    final logId = tamOku(cv.j['log_id']);
    if (!cv.ok || logId == 0) {
      kToast(c, metinOku(cv.j['hata'], 'Önerilemedi.'), hata: true);
      return;
    }
    await kAltSayfa(c, baslik: 'AI eylem onayı', icerik: (s) => _EylemOnay(ozet: metinOku(cv.j['ozet']), logId: logId));
  }

  void _isDetay(BuildContext c, String pop, String baslik) {
    if (pop.isEmpty) return;
    kAltSayfa(c, baslik: baslik.isEmpty ? 'Detay' : baslik, icerik: (s) => _IsDetay(pop: pop)).then((_) {
      if (mounted) _k.currentState?.yukle(sessiz: true);
    });
  }

  // ───────── AI kullanım ─────────
  Widget _tuketim(BuildContext c, Map<String, dynamic> tk) {
    if (tk.isEmpty) return const SizedBox.shrink();
    final t = c.watch<TemaProvider>();
    final yz = sayiOku(tk['yuzde']).clamp(0, 100).toDouble();
    final br = yz >= 90 ? t.kirmizi : (yz >= 70 ? t.amber : t.yesil);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Row(children: [
        Icon(Icons.auto_awesome, size: 15, color: t.mor1),
        const SizedBox(width: 6),
        Text('Bu ay dahil AI', style: TextStyle(color: t.sub, fontSize: 12)),
        const SizedBox(width: 10),
        SizedBox(
          width: 180,
          child: ClipRRect(borderRadius: BorderRadius.circular(5), child: LinearProgressIndicator(value: yz / 100, minHeight: 7, backgroundColor: t.card2, color: br)),
        ),
        const SizedBox(width: 10),
        Text('${sayiYaz(tk['kullanim'])}/${sayiYaz(tk['hak'])}', style: TextStyle(color: t.sub2, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }

  // ───────── Departmanların durumu ─────────
  List<Widget> _departmanlar(BuildContext c, List<Map<String, dynamic>> den) {
    if (den.isEmpty) return const [];
    final t = c.watch<TemaProvider>();
    const oran = {'iyi': .9, 'notr': .6, 'dikkat': .42, 'risk': .24};
    return [
      AiBolum('Departmanların durumu', ikon: Icons.apartment,
          sag: TextButton(onPressed: () => aiGit(c, '/departman-rapor', baslik: 'Departman Raporları'), child: const Text('Tüm departmanlar →'))),
      AiIzgara(minGenislik: 240, cocuklar: [
        for (final d in den)
          Builder(builder: (c2) {
            final (et, dr) = durumRenk(metinOku(d['durum']));
            final dic = cssRenk(c2, d['renk'], const Color(0xFF5B8DEF));
            return KKart(
              margin: EdgeInsets.zero,
              padding: const EdgeInsets.all(12),
              onTap: metinOku(d['kod']).isEmpty ? null : () => aiGit(c2, '/departman-brief?dep=${metinOku(d['kod'])}', baslik: '${metinOku(d['ad'])} Brifingi'),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  KIkon(ikonAdi(metinOku(d['ikon']), Icons.badge_outlined), renk: dic, boyut: 34),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(metinOku(d['ad']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Wrap(spacing: 4, children: [
                        KRozet(et, renk: dr),
                        if (tamOku(d['uyari_say']) > 0) KRozet('${tamOku(d['uyari_say'])} ⚠', renk: t.amber),
                      ]),
                    ]),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(metinOku(d['ozet']), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12.5)),
                const SizedBox(height: 8),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: oran[metinOku(d['durum'])] ?? .6, minHeight: 5, color: dr, backgroundColor: t.card2)),
                const SizedBox(height: 4),
                Row(children: [
                  if (metinOku(d['kod']).isNotEmpty)
                    TextButton(onPressed: () => aiGit(c2, '/departman-brief?dep=${metinOku(d['kod'])}', baslik: '${metinOku(d['ad'])} Brifingi'), child: const Text('Brifing →')),
                  TextButton(
                    onPressed: () => aiGit(c2, '/departman-rapor?id=${metinOku(d['id'])}', baslik: '${metinOku(d['ad'])} Raporu'),
                    child: Text('Rapor →', style: TextStyle(color: t.sub2)),
                  ),
                ]),
              ]),
            );
          }),
      ]),
      const SizedBox(height: 12),
    ];
  }

  Widget _analizKart(BuildContext c, Map<String, dynamic> a) {
    final t = c.watch<TemaProvider>();
    final (et, dr) = durumRenk(metinOku(a['durum']));
    return KKart(
      renk: dr,
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          KIkon(ikonAdi(metinOku(a['ikon']), Icons.insights), renk: dr),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(a['baslik']), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
              if (metinOku(a['deger']).isNotEmpty) Text(metinOku(a['deger']), style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: dr, borderRadius: BorderRadius.circular(20)),
            child: Text(et, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 9),
        ZenginMetin(metinOku(a['yorum']), stil: TextStyle(color: t.ink, fontSize: 13.5, height: 1.5)),
        if (metinOku(a['risk']).isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: t.kirmizi.withValues(alpha: .09), borderRadius: BorderRadius.circular(10)),
            child: Text('🔴 Risk: ${metinOku(a['risk'])}', style: TextStyle(color: t.kirmizi, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        if (metinOku(a['oneri']).isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              const Text('✅ '),
              Expanded(child: ZenginMetin('**Öneri:** ${metinOku(a['oneri'])}', stil: TextStyle(color: t.sub2, fontSize: 12.5, height: 1.45))),
              if (metinOku(a['link']).isNotEmpty)
                TextButton(onPressed: () => aiGit(c, metinOku(a['link']), baslik: metinOku(a['lbl'])), child: Text('${metinOku(a['lbl'], 'Aç')} →')),
            ]),
          ),
      ]),
    );
  }

  // ───────── Dünden devam ─────────
  Widget _surekli(BuildContext c, Map<String, dynamic> sk) {
    final t = c.watch<TemaProvider>();
    final acik = liste(sk['acik']).where((a) => !_cozulen.contains(tamOku(a['id']))).toList();
    final kapanan = liste(sk['kapanan']);
    if (acik.isEmpty && kapanan.isEmpty) return const SizedBox.shrink();
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.history, size: 18, color: Color(0xFF5B8DEF)),
          const SizedBox(width: 8),
          Text('DÜNDEN DEVAM', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: .4)),
        ]),
        const SizedBox(height: 6),
        for (final k in kapanan)
          KSatir(
            solIkon: Icon(Icons.check_circle, color: t.yesil, size: 20),
            baslik: metinOku(k['konu']),
            sag: Text(metinOku(k['durum']) == 'devredildi' ? 'devredildi' : 'çözüldü', style: TextStyle(color: t.sub, fontSize: 12)),
          ),
        for (final a in acik)
          KSatir(
            solIkon: Container(width: 10, height: 10, decoration: BoxDecoration(color: t.amber, shape: BoxShape.circle)),
            baslik: metinOku(a['konu']),
            alt: tamOku(a['gun']) > 0 ? '${tamOku(a['gun'])} gündür açık' : 'bugün',
            sag: OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: t.yesil, minimumSize: const Size(44, 40)),
              onPressed: () async {
                final cv = await aiPost(c, '/api/patron-ai/takip-durum', {'id': a['id'], 'durum': 'cozuldu'});
                if (!mounted) return;
                if (cv.ok) {
                  setState(() => _cozulen.add(tamOku(a['id'])));
                } else if (c.mounted) {
                  kToast(c, cevapMesaj(cv), hata: true);
                }
              },
              child: const Text('Çözüldü', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
      ]),
    );
  }

  Widget _gundem(BuildContext c, List<Map<String, dynamic>> takvim) {
    if (takvim.isEmpty) return const SizedBox.shrink();
    final t = c.watch<TemaProvider>();
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.event_outlined, size: 18, color: t.mor1),
          const SizedBox(width: 8),
          Text('BUGÜNKÜ GÜNDEM', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: .4)),
        ]),
        const SizedBox(height: 6),
        for (final e in takvim)
          KSatir(
            solIkon: SizedBox(width: 46, child: Text(metinOku(e['saat']), style: const TextStyle(color: Color(0xFF5B8DEF), fontWeight: FontWeight.w800, fontSize: 13.5))),
            baslik: metinOku(e['baslik']),
            alt: metinOku(e['not']).isEmpty ? null : '📝 ${metinOku(e['not'])}',
          ),
      ]),
    );
  }

  Widget _iletisim(BuildContext c, List<Map<String, dynamic>> eposta, Map<String, dynamic> wa) {
    final gelen = liste(wa['gelen']);
    final giden = tamOku(wa['giden']);
    if (eposta.isEmpty && gelen.isEmpty && giden == 0) return const SizedBox.shrink();
    final t = c.watch<TemaProvider>();
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.forum_outlined, size: 18, color: t.yesil),
          const SizedBox(width: 8),
          Text('İLETİŞİM', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: .4)),
        ]),
        if (eposta.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('📨 Yanıt bekleyen e-posta (${eposta.length})', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
          for (final e in eposta)
            KSatir(
              solIkon: Icon(Icons.mail_outline, color: t.amber, size: 19),
              baslik: metinOku(e['subject'], '(konusuz)'),
              alt: metinOku(e['from']),
              sag: metinOku(e['link']).isEmpty ? null : const Icon(Icons.open_in_new, size: 18),
              onTap: metinOku(e['link']).isEmpty ? null : () => aiGit(c, metinOku(e['link'])),
            ),
        ],
        if (giden > 0 || gelen.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('💬 WhatsApp', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Bugün sistemden $giden mesaj gönderildi.', style: TextStyle(color: t.sub, fontSize: 12.5)),
          for (final g in gelen)
            KSatir(
              solIkon: const Icon(Icons.chat_outlined, color: Color(0xFF25D366), size: 19),
              baslik: metinOku(g['mesaj']),
              alt: '${metinOku(g['telefon'])} · ${metinOku(g['saat'])}',
              sag: Text('Yanıtla →', style: TextStyle(color: t.mor1, fontSize: 12.5, fontWeight: FontWeight.w700)),
              onTap: () => aiGit(c, '/whatsapp', baslik: 'WhatsApp'),
            ),
        ],
      ]),
    );
  }
}

/// Hazır AI eylemi onay penceresi: özet + "İşlemi Yap" → /api/ai-eylem/onayla {log_id}
class _EylemOnay extends StatefulWidget {
  final String ozet;
  final int logId;
  const _EylemOnay({required this.ozet, required this.logId});
  @override
  State<_EylemOnay> createState() => _EylemOnayState();
}

class _EylemOnayState extends State<_EylemOnay> {
  bool _calisiyor = false;
  bool? _ok;
  String _sonuc = '';

  Future<void> _yap() async {
    setState(() => _calisiyor = true);
    final cv = await aiPost(context, '/api/ai-eylem/onayla', {'log_id': widget.logId});
    if (!mounted) return;
    final s = harita(cv.j['sonuc']);
    setState(() {
      _calisiyor = false;
      if (s.isEmpty) {
        _ok = false;
        _sonuc = metinOku(cv.j['hata'], 'Yürütme sonucu alınamadı.');
      } else {
        _ok = s['ok'] == true || s['ok'] == 1;
        _sonuc = metinOku(s['mesaj'], _ok! ? 'İşlem yapıldı.' : 'Hata oluştu.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
        child: ZenginMetin(widget.ozet, stil: TextStyle(color: t.ink, fontSize: 14, height: 1.5)),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Icon(Icons.lock_outline, size: 14, color: t.yesil),
        const SizedBox(width: 5),
        Expanded(child: Text('Onaylamadan hiçbir şey değişmez. Onay kaydedilir.', style: TextStyle(color: t.sub, fontSize: 12))),
      ]),
      if (_ok != null)
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: (_ok! ? t.yesil : t.kirmizi).withValues(alpha: .1),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: _ok! ? t.yesil : t.kirmizi, width: 3)),
          ),
          child: Text(_sonuc, style: TextStyle(color: _ok! ? t.yesil : t.kirmizi, fontSize: 13.5, fontWeight: FontWeight.w600)),
        ),
      const SizedBox(height: 14),
      Wrap(alignment: WrapAlignment.end, spacing: 9, runSpacing: 8, children: [
        KButon('Kapat', ikincil: true, renk: t.sub2, onTap: () => Navigator.of(context).maybePop()),
        if (_ok != true) KButon('İşlemi Yap', ikon: Icons.check, renk: t.yesil, yukleniyor: _calisiyor, onTap: _yap),
      ]),
    ]);
  }
}

/// Öncelik detayı (web paiIsAc): GET /api/patron-ai/is-detay?pop=… → açıklama + satırlar (onayla/reddet/fiyat sor) + tek tık aksiyonlar
class _IsDetay extends StatefulWidget {
  final String pop;
  const _IsDetay({required this.pop});
  @override
  State<_IsDetay> createState() => _IsDetayState();
}

class _IsDetayState extends State<_IsDetay> {
  Map<String, dynamic>? _d;
  String? _hata;
  bool? _sonOk;
  String _son = '';
  final Set<String> _mesgul = {};
  final Set<int> _kalkan = {};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final c = await aiAl(context, '/api/patron-ai/is-detay', q: {'pop': widget.pop});
    if (!mounted) return;
    setState(() {
      if (c.ok) {
        _d = c.j;
        _hata = null;
      } else {
        _hata = metinOku(c.j['hata'], 'Detay alınamadı.');
      }
    });
  }

  void _sonuc(bool ok, String m) => setState(() {
        _sonOk = ok;
        _son = m;
      });

  Future<void> _sor(String soru, String anahtar, Future<void> Function() isFn) async {
    if (!await kOnay(context, soru)) return;
    setState(() => _mesgul.add(anahtar));
    try {
      await isFn();
    } finally {
      if (mounted) setState(() => _mesgul.remove(anahtar));
    }
  }

  Future<void> _eylem(String intent) async {
    final c1 = await aiPost(context, '/api/patron-ai/eylem-oner', {'intent': intent});
    if (!mounted) return;
    final logId = tamOku(c1.j['log_id']);
    if (!c1.ok || logId == 0) return _sonuc(false, metinOku(c1.j['hata'], 'Olmadı'));
    final c2 = await aiPost(context, '/api/ai-eylem/onayla', {'log_id': logId});
    if (!mounted) return;
    final s = harita(c2.j['sonuc']);
    final ok = s['ok'] == true || s['ok'] == 1;
    _sonuc(ok, metinOku(s['mesaj'], ok ? 'İşlem yapıldı.' : metinOku(c2.j['hata'], 'Hata oluştu.')));
  }

  Future<void> _post(String url) async {
    final c = await aiPost(context, url, {});
    if (!mounted) return;
    final s = c.j['sonuc'] is Map ? harita(c.j['sonuc']) : c.j;
    final ok = c.ok && s['ok'] != false && s['ok'] != 0;
    _sonuc(ok, metinOku(s['mesaj'], ok ? 'İşlem yapıldı.' : metinOku(c.j['hata'], 'İşlem yapılamadı.')));
  }

  Future<void> _satirIslem(String tur, int id) async {
    _Sonuc r;
    if (tur == 'onay' || tur == 'red') {
      final c = await aiPost(context, '/api/patron/onay-cevap', {'istek_id': id, 'cevap': tur});
      r = _Sonuc(c.ok, '${tur == 'onay' ? 'Onaylandı' : 'Reddedildi'}${metinOku(c.j['mesaj']).isEmpty ? '' : ' · ${metinOku(c.j['mesaj'])}'}', metinOku(c.j['hata'], 'Olmadı'));
    } else if (tur == 'sa') {
      final c = await aiPost(context, '/satinalma-talep/onayla', {'id': id});
      r = _Sonuc(c.ok, 'Talep onaylandı — sipariş oluşturmaya hazır.', metinOku(c.j['mesaj'], metinOku(c.j['hata'], 'Olmadı')));
    } else {
      final c = await aiPost(context, '/api/patron-ai/talep-fiyat-sor', {'talep': id});
      r = _Sonuc(c.ok, metinOku(c.j['mesaj'], 'Fiyat isteği gönderildi.'), metinOku(c.j['mesaj'], metinOku(c.j['hata'], 'Gönderilemedi.')));
    }
    if (!mounted) return;
    if (r.ok) setState(() => _kalkan.add(id));
    _sonuc(r.ok, r.ok ? r.basari : r.hata);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    if (_d == null && _hata == null) return const Padding(padding: EdgeInsets.all(30), child: KYukleniyor(metin: 'Yükleniyor…'));
    if (_d == null) return KBos(ikon: Icons.cloud_off_outlined, baslik: 'Detay alınamadı', aciklama: _hata, aksiyon: KButon('Tekrar dene', onTap: _yukle));
    final d = _d!;
    final satirAk = metinOku(d['satir_aksiyon']);
    final satirlar = liste(d['satirlar']).where((s) => !_kalkan.contains(tamOku(s['id']))).toList();
    final aks = liste(d['aksiyonlar']);
    Widget kucukBtn(String m, Color r, String anahtar, VoidCallback f, {bool ikincil = false}) => Padding(
          padding: const EdgeInsets.only(left: 6),
          child: _mesgul.contains(anahtar)
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
              : (ikincil
                  ? OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: r, minimumSize: const Size(44, 40)), onPressed: f, child: Text(m, style: const TextStyle(fontWeight: FontWeight.w700)))
                  : FilledButton(style: FilledButton.styleFrom(backgroundColor: r, minimumSize: const Size(44, 40)), onPressed: f, child: Text(m, style: const TextStyle(fontWeight: FontWeight.w700)))),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (metinOku(d['aciklama']).isNotEmpty)
        Container(
          padding: const EdgeInsets.all(11),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(11)),
          child: Text(metinOku(d['aciklama']), style: TextStyle(color: t.sub2, fontSize: 13, height: 1.5)),
        ),
      if (satirlar.isNotEmpty)
        for (final s in satirlar)
          Container(
            margin: const EdgeInsets.only(bottom: 7),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: t.line)),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(metinOku(s['ad']), style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  if (metinOku(s['alt']).isNotEmpty) Text(metinOku(s['alt']), style: TextStyle(color: t.sub, fontSize: 12)),
                ]),
              ),
              if (satirAk == 'onay') ...[
                kucukBtn('Reddet', t.kirmizi, 'r${s['id']}', () => _sor('Bu işlem reddedilsin mi?', 'r${s['id']}', () => _satirIslem('red', tamOku(s['id']))), ikincil: true),
                kucukBtn('Onayla', t.mor1, 'o${s['id']}', () => _sor('Bu işlemi onaylayıp yürüteyim mi?', 'o${s['id']}', () => _satirIslem('onay', tamOku(s['id'])))),
              ] else if (satirAk == 'satinalma_onayla')
                kucukBtn('Onayla', t.mor1, 's${s['id']}', () => _sor('Bu talebi onaylayayım mı?', 's${s['id']}', () => _satirIslem('sa', tamOku(s['id']))))
              else if (satirAk == 'fiyat_arastir')
                kucukBtn('Fiyat sor', t.mor1, 'f${s['id']}', () => _sor('Tedarikçilere fiyat isteği (RFQ) göndereyim mi?', 'f${s['id']}', () => _satirIslem('fiyat', tamOku(s['id']))))
              else if (metinOku(s['sag']).isNotEmpty)
                Text(metinOku(s['sag']), style: TextStyle(color: s['renk'] == null ? t.sub : cssRenk(context, s['renk']), fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
          )
      else if (aks.isEmpty)
        Padding(padding: const EdgeInsets.all(16), child: Text(metinOku(d['bos'], 'Kayıt yok.'), textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 13))),
      if (aks.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color.alphaBlend(t.mor1.withValues(alpha: .07), t.card),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: Color.alphaBlend(t.mor1.withValues(alpha: .2), t.line)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(Icons.auto_awesome, size: 16, color: t.mor1),
              const SizedBox(width: 6),
              Text('İstersen tek tıkla yapayım', style: TextStyle(color: t.mor1, fontSize: 12.5, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 9),
            for (var i = 0; i < aks.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: KButon(
                  metinOku(aks[i]['lbl']),
                  genis: true,
                  yukleniyor: _mesgul.contains('a$i'),
                  onTap: () => _sor('Bu işlemi yapayım mı?', 'a$i', () => metinOku(aks[i]['tip']) == 'eylem' ? _eylem(metinOku(aks[i]['intent'])) : _post(metinOku(aks[i]['url']))),
                ),
              ),
          ]),
        ),
      if (_sonOk != null)
        Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: (_sonOk! ? t.yesil : t.kirmizi).withValues(alpha: .1),
            borderRadius: BorderRadius.circular(11),
            border: Border(left: BorderSide(color: _sonOk! ? t.yesil : t.kirmizi, width: 3)),
          ),
          child: Text(_son, style: TextStyle(color: _sonOk! ? t.yesil : t.kirmizi, fontSize: 13, fontWeight: FontWeight.w600)),
        ),
    ]);
  }
}

class _Sonuc {
  final bool ok;
  final String basari;
  final String hata;
  _Sonuc(this.ok, this.basari, this.hata);
}

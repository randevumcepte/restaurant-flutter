import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';
import 'ortak.dart';

/// /departman-brief[?dep=kod] — Departman sabah brifingi (web departman_brief ile aynı veri):
/// selam + rozetler, KPI kartları (dokununca ilgili ekran), santral & rezervasyon akışı (rezervasyon satış),
/// bugün öncelikler (aksiyon düğmeli), "AI ne diyor" + AI asistana geçiş + hızlı erişim, detaylı AI analizi, dün yapılanlar.
class DepartmanBriefScreen extends StatefulWidget {
  final String url;
  final String baslik;
  const DepartmanBriefScreen({super.key, required this.url, this.baslik = ''});
  @override
  State<DepartmanBriefScreen> createState() => _DepartmanBriefScreenState();
}

const _tintHex = {
  't-rose': Color(0xFFF56A8B),
  't-green': Color(0xFF2FBE94),
  't-amber': Color(0xFFF6A623),
  't-blue': Color(0xFF5B8DEF),
  't-red': Color(0xFFF5576C),
  't-mor': Color(0xFF7C3AED),
};

class _DepartmanBriefScreenState extends State<DepartmanBriefScreen> {
  final _k = GlobalKey<KopruEkranState>();
  final Set<String> _onaylanan = {};

  Map<String, String> get _q {
    final u = Uri.parse(widget.url);
    return Map<String, String>.from(u.queryParameters);
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: _k,
      yol: '/departman-brief',
      q: _q,
      baslik: widget.baslik.isEmpty ? 'Departman Brifingi' : widget.baslik,
      ikon: Icons.wb_sunny_outlined,
      araclar: (c, v, yenile) => [
        if (v['demo'] == true)
          TextButton(onPressed: () => _k.currentState?.sorgu({'demo': '0'}), child: const Text('Gerçek veri'))
        else
          IconButton(
            tooltip: 'Demo veriyle göster (sayfanın dolu halini görmek için)',
            onPressed: () => _k.currentState?.sorgu({'demo': '1'}),
            icon: const Icon(Icons.theater_comedy_outlined),
          ),
      ],
      govde: (c, v, yenile) => _govde(c, v, yenile),
    );
  }

  Widget _govde(BuildContext c, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = c.watch<TemaProvider>();
    final deptAd = metinOku(v['deptAd'], 'Departman');
    final deptRenk = cssRenk(c, v['deptRenk']);
    final ad = metinOku(v['ad']);
    final adK = ad.isEmpty ? '' : ad.split(' ').first;
    final kpis = liste(v['kpis']);
    final isler = liste(v['isler']);
    final analiz = liste(v['analiz']);
    final hizli = liste(v['hizli']);
    final dun = liste(v['dunYapilanlar']);
    final rozetler = liste(v['rozetler']);
    final aiLink = harita(v['aiLink']);
    final crm = harita(v['crmRez']);
    final onayN = tamOku(v['onayBekleyenTalep']);
    final altDep = liste(v['altDepartmanlar']);
    final genis = genisMi(c);

    final aiPanel = _aiPanel(c, deptAd, v, aiLink, hizli);
    final islerKart = _islerKart(c, isler);

    return KGovde(yenile: yenile, children: [
      // ── Departman sorumlusunun onayını bekleyen satın alma talepleri
      if (onayN > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => aiGit(c, '/talep-onaylarim', baslik: 'Talep Onaylarım'),
              child: Ink(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: .28), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Row(children: [
                  const Icon(Icons.fact_check_outlined, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(child: Text('$onayN satın alma talebi senin onayını bekliyor', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700))),
                  const Icon(Icons.chevron_right, color: Colors.white),
                ]),
              ),
            ),
          ),
        ),
      // ── HERO
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [deptRenk, Color.lerp(deptRenk, Colors.black, .32)!]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: deptRenk.withValues(alpha: .3), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Icon(ikonAdi(metinOku(v['deptIkon']), Icons.badge_outlined), color: Colors.white, size: 25),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${selamMetni()}${adK.isEmpty ? '' : ' $adK'} 👋', style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -.4)),
            const SizedBox(height: 3),
            Text('${bugunMetni()} · $deptAd sabah brifingi', style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w500)),
          ]),
        ),
      ]),
      if (rozetler.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(spacing: 7, runSpacing: 7, children: [
            for (final r in rozetler)
              KRozet(metinOku(r['metin']), renk: r['renk'] == null ? t.sub2 : cssRenk(c, r['renk']), ikon: ikonAdi(metinOku(r['ikon']), Icons.info_outline)),
          ]),
        ),
      // ── Mutfak (BOH) alt departman sekmeleri: istasyon çalışanı yalnız kendininkini görür (sunucu süzer)
      if (altDep.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final a in altDep)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Builder(builder: (_) {
                    final aktif = a['aktif'] == true;
                    final r = cssRenk(c, a['renk']);
                    return ChoiceChip(
                      selected: aktif,
                      showCheckmark: false,
                      selectedColor: r,
                      backgroundColor: t.card,
                      side: BorderSide(color: aktif ? r : t.line),
                      avatar: Icon(ikonAdi(metinOku(a['ikon']), Icons.restaurant), size: 18, color: aktif ? Colors.white : r),
                      label: Text(metinOku(a['ad']), style: TextStyle(color: aktif ? Colors.white : t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
                      onSelected: aktif ? null : (_) => _k.currentState?.sorgu({'dep': metinOku(a['kod'])}),
                    );
                  }),
                ),
            ]),
          ),
        ),
      const SizedBox(height: 12),
      if (v['demo'] == true)
        KKart(
          renk: t.amber,
          child: Row(children: [
            Icon(Icons.theater_comedy_outlined, color: t.amber),
            const SizedBox(width: 10),
            Expanded(child: Text('DEMO VERİ — gerçek değil; sayfanın dolu halini gösterir.', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600))),
            TextButton(onPressed: () => _k.currentState?.sorgu({'demo': '0'}), child: const Text('Gerçek veriye dön')),
          ]),
        ),
      // ── KPI
      if (kpis.isNotEmpty)
        KKpiIzgara([
          for (final k in kpis)
            KKpi(
              etiket: metinOku(k['label']),
              deger: duzMetin(k['deger']),
              alt: metinOku(k['alt']).isEmpty ? null : metinOku(k['alt']),
              ikon: ikonAdi(metinOku(k['ikon']), Icons.insights),
              renk: _tintHex[metinOku(k['tint'])] ?? t.mor1,
              onTap: metinOku(k['link']).isEmpty ? null : () => aiGit(c, metinOku(k['link']), baslik: metinOku(k['label'])),
            ),
        ]),
      // ── Santral & rezervasyon (yalnız rezervasyon satış)
      if (crm.isNotEmpty) ..._crmBolum(c, crm),
      // ── Öncelikler + AI
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
      // ── Detaylı AI analizi
      if (analiz.isNotEmpty) ...[
        const AiBolum('Detaylı AI analizi', ikon: Icons.analytics_outlined),
        AiIzgara(minGenislik: 300, cocuklar: [for (final a in analiz) _analizKart(c, a)]),
        const SizedBox(height: 12),
      ],
      // ── Dün yapılanlar
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.done_all, size: 18, color: t.yesil),
            const SizedBox(width: 8),
            Text('DÜN YAPILANLAR', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: .4)),
          ]),
          const SizedBox(height: 8),
          if (dun.isEmpty)
            Text('Dün bu departmanda kayıtlı hareket yok. Görev tamamlama, kayıt ve onaylar yapıldıkça burada listelenir.', style: TextStyle(color: t.sub, fontSize: 13))
          else
            for (final y in dun)
              KSatir(
                baslik: metinOku(y['mtn']),
                solIkon: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: t.yesil.withValues(alpha: .15), shape: BoxShape.circle),
                  child: Icon(Icons.check, size: 15, color: t.yesil),
                ),
                sag: metinOku(y['link']).isEmpty ? null : Text('Aç →', style: TextStyle(color: t.mor1, fontSize: 12.5, fontWeight: FontWeight.w700)),
                onTap: metinOku(y['link']).isEmpty ? null : () => aiGit(c, metinOku(y['link'])),
              ),
        ]),
      ),
    ]);
  }

  Widget _islerKart(BuildContext c, List<Map<String, dynamic>> isler) {
    final t = c.watch<TemaProvider>();
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.track_changes, size: 20, color: t.mor1),
          const SizedBox(width: 8),
          Expanded(child: Text('Bugün önceliklerin', style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.w800))),
          if (isler.isNotEmpty) KRozet('${isler.length}', renk: t.mor1),
        ]),
        const SizedBox(height: 10),
        if (isler.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('✅ Bekleyen iş yok — her şey yolunda 👍', style: TextStyle(color: t.sub, fontSize: 13.5))),
          )
        else
          AiIzgara(minGenislik: 300, ara: 8, cocuklar: [for (final i in isler) _isSatir(c, i)]),
      ]),
    );
  }

  Widget _isSatir(BuildContext c, Map<String, dynamic> i) {
    final t = c.watch<TemaProvider>();
    final r = cssRenk(c, i['renk']);
    final ak = harita(i['aksiyon']);
    final url = metinOku(ak['url']);
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
              Text(metinOku(i['aciklama']), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12)),
          ]),
        ),
        if (url.isNotEmpty) ...[
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: t.mor1, minimumSize: const Size(56, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
            onPressed: () => aiGit(c, url, baslik: metinOku(i['baslik'])),
            child: Text(metinOku(ak['lbl'], 'Aç'), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }

  Widget _aiPanel(BuildContext c, String deptAd, Map<String, dynamic> v, Map<String, dynamic> aiLink, List<Map<String, dynamic>> hizli) {
    final t = c.watch<TemaProvider>();
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
          Expanded(child: Text('$deptAd AI ne diyor?', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w800))),
        ]),
        const SizedBox(height: 10),
        ZenginMetin(metinOku(v['aiOzet'], 'Bugün için değerlendirme yok.'), stil: TextStyle(color: t.sub2, fontSize: 13.5, height: 1.5)),
        if (aiLink.isNotEmpty) ...[
          const SizedBox(height: 12),
          Material(
            borderRadius: BorderRadius.circular(13),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [t.mor1, t.mavi])),
              child: InkWell(
                onTap: () => aiGit(c, metinOku(aiLink['url']), baslik: metinOku(aiLink['lbl'])),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
                  child: Row(children: [
                    const Icon(Icons.forum_outlined, color: Colors.white),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(metinOku(aiLink['lbl'], 'AI ile konuş'), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        const Text('Departmanınla ilgili sor — yardımcı olayım', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ]),
                    ),
                    const Icon(Icons.arrow_forward, color: Colors.white),
                  ]),
                ),
              ),
            ),
          ),
        ],
        if (hizli.isNotEmpty) ...[
          const SizedBox(height: 14),
          Row(children: [
            Icon(Icons.bolt, size: 16, color: t.mor1),
            const SizedBox(width: 6),
            Text('Hızlı erişim', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          AiIzgara(minGenislik: 160, ara: 7, cocuklar: [
            for (final h in hizli)
              Material(
                color: t.card,
                borderRadius: BorderRadius.circular(11),
                child: InkWell(
                  borderRadius: BorderRadius.circular(11),
                  onTap: () => aiGit(c, metinOku(h['url']), baslik: metinOku(h['lbl'])),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 46),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), border: Border.all(color: t.line)),
                    child: Row(children: [
                      KIkon(ikonAdi(metinOku(h['ikon']), Icons.open_in_new), renk: t.mor1, boyut: 30),
                      const SizedBox(width: 8),
                      Expanded(child: Text(metinOku(h['lbl']), style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ),
              ),
          ]),
        ],
      ]),
    );
  }

  Widget _analizKart(BuildContext c, Map<String, dynamic> a) {
    final t = c.watch<TemaProvider>();
    final (et, dr) = durumRenk(metinOku(a['durum']));
    final r = cssRenk(c, a['renk']);
    return KKart(
      renk: dr,
      margin: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          KIkon(ikonAdi(metinOku(a['ikon']), Icons.insights), renk: r),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(metinOku(a['baslik']), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
              if (metinOku(a['alt']).isNotEmpty) Text(metinOku(a['alt']), style: TextStyle(color: t.sub, fontSize: 12)),
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
      ]),
    );
  }

  // ───────── Santral & rezervasyon akışı ─────────
  List<Widget> _crmBolum(BuildContext c, Map<String, dynamic> cz) {
    final t = c.watch<TemaProvider>();
    final santral = liste(cz['santral']).where((s) => !_onaylanan.contains(metinOku(s['id']))).toList();
    final kacan = liste(cz['kacan']);
    final bugun = liste(cz['bugun']);
    const durR = {'bekliyor': Color(0xFFF59E0B), 'onaylandi': Color(0xFF2FBE94), 'geldi': Color(0xFF5B8DEF), 'gelmedi': Color(0xFFF43F5E), 'iptal': Color(0xFF94A3B8)};
    const durA = {'bekliyor': 'Bekliyor', 'onaylandi': 'Onaylı', 'geldi': 'Geldi', 'gelmedi': 'Gelmedi', 'iptal': 'İptal'};
    const kanR = {'Santral': Color(0xFF7C3AED), 'Panel': Color(0xFF64748B), 'Telefon': Color(0xFF0EA5E9), 'Uygulama': Color(0xFF10B981), 'WhatsApp': Color(0xFF22C55E)};

    Widget kart(String baslik, IconData ikon, Color r, String sayi, List<Widget> satirlar, String bos, {Widget? sag}) => KKart(
          margin: EdgeInsets.zero,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(ikon, size: 19, color: r),
              const SizedBox(width: 8),
              Expanded(child: Text(baslik, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w800))),
              KRozet(sayi, renk: r),
              ?sag,
            ]),
            const SizedBox(height: 6),
            if (satirlar.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(bos, style: TextStyle(color: t.sub, fontSize: 12.5))) else ...satirlar,
          ]),
        );

    return [
      const AiBolum('Santral & Rezervasyon Akışı', ikon: Icons.call_outlined),
      AiIzgara(minGenislik: 340, cocuklar: [
        kart('Santraldan gelen', Icons.call_outlined, const Color(0xFF7C3AED), '${santral.length} onay bekliyor', [
          for (final s in santral)
            KSatir(
              baslik: '${metinOku(s['ad'])} · ${metinOku(s['kisi'])} kişi',
              alt: '${s['bugun'] == true ? 'Bugün' : tarihYaz(s['tarih'], saat: false)} · ${metinOku(s['saat'])}${metinOku(s['telefon']).isEmpty ? '' : ' · ${metinOku(s['telefon'])}'}',
              sag: Row(mainAxisSize: MainAxisSize.min, children: [
                if (metinOku(s['ses']).isNotEmpty)
                  IconButton(tooltip: 'Kaydı dinle', onPressed: () => aiGit(c, tamAdres(metinOku(s['ses']))), icon: Icon(Icons.play_circle_outline, color: t.mor1)),
                if (metinOku(s['id']).isNotEmpty)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2FBE94), minimumSize: const Size(44, 40)),
                    onPressed: () => _rezOnayla(c, s),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Onayla', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
        ], 'Santraldan onay bekleyen rezervasyon yok. 👍'),
        kart('Kaçan çağrı — geri ara', Icons.phone_missed_outlined, const Color(0xFFF43F5E), '${kacan.length}', [
          for (final k in kacan)
            KSatir(
              baslik: metinOku(k['telefon']),
              alt: '${metinOku(k['sonuc']) == 'bilgi' ? 'bilgi aldı' : 'kaçan'} · ${metinOku(k['zaman'])} · rezervasyona dönmedi',
              sag: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF5B8DEF), minimumSize: const Size(44, 40)),
                onPressed: () => aiGit(c, 'tel:${metinOku(k['telefon'])}'),
                icon: const Icon(Icons.call, size: 16),
                label: const Text('Ara', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
        ], 'Son 3 günde sonuçsuz/kaçan çağrı yok. 👍'),
        kart('Bugünün rezervasyonları', Icons.event_available_outlined, const Color(0xFFA855F7), '${bugun.length}', [
          for (final b in bugun)
            KSatir(
              solIkon: SizedBox(width: 44, child: Text(metinOku(b['saat']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13))),
              baslik: '${metinOku(b['ad'])} · ${metinOku(b['kisi'])} kişi',
              sag: Wrap(spacing: 4, children: [
                KRozet('${b['santral'] == true ? '📞 ' : ''}${metinOku(b['kanal'])}', renk: kanR[metinOku(b['kanal'])] ?? const Color(0xFF64748B)),
                KRozet(durA[metinOku(b['durum'])] ?? metinOku(b['durum']), renk: durR[metinOku(b['durum'])] ?? const Color(0xFF64748B)),
              ]),
            ),
        ], 'Bugün rezervasyon yok. Boş günü doldurma kampanyası düşünebilirsin.',
            sag: TextButton(onPressed: () => aiGit(c, '/rezervasyon', baslik: 'Rezervasyon'), child: const Text('Tümü →'))),
      ]),
      const SizedBox(height: 12),
    ];
  }

  Future<void> _rezOnayla(BuildContext c, Map<String, dynamic> s) async {
    if (!await kOnay(c, 'Rezervasyon onaylansın mı?', aciklama: '${metinOku(s['ad'])} · ${metinOku(s['kisi'])} kişi · ${metinOku(s['saat'])}')) return;
    if (!c.mounted) return;
    final ok = await kopruGonder(c, '/rezervasyon/durum', {'id': s['id'], 'durum': 'onaylandi', 'tarih': s['tarih']}, basariMesaji: 'Rezervasyon onaylandı.');
    if (ok) {
      setState(() => _onaylanan.add(metinOku(s['id'])));
      _k.currentState?.yukle(sessiz: true);
    }
  }
}

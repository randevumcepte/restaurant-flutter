import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../ui/kit.dart';
import 'kopru_api.dart';
import 'kopru_ekran.dart';

/// Web'deki rapor çatıları (satın alma / mutfak / departman raporları). Hepsi aynı yapıda:
///   {taban}/{kategori}          → katalog + kategoriler + dönem + "kullanılan veri"
///   {taban}/indir?rapor=X&format=html → rapor sayfaları (pano KPI + bloklar + tablolar)
///   POST {taban}/ai             → AI özet / soru-cevap
const List<String> kRaporOnekleri = [
  '/satinalma-raporlar/', '/mutfak-raporlar/', '/ik-raporlar/', '/finans-raporlar/', '/crm-raporlar/', '/it-raporlar/',
  '/kalite-raporlar/', '/pazarlama-raporlar/', '/santral-raporlar/', '/rezervasyon-raporlar/',
];

const List<(String, String)> kDonemler = [
  ('bugun', 'Bugün'), ('dun', 'Dün'), ('bu_hafta', 'Bu hafta'), ('gecen_hafta', 'Geçen hafta'), ('bu_ay', 'Bu ay'),
  ('gecen_ay', 'Geçen ay'), ('son30', 'Son 30 gün'), ('son90', 'Son 90 gün'), ('bu_yil', 'Bu yıl'),
];

class RaporMerkeziScreen extends StatefulWidget {
  final String url;
  final String baslik;
  const RaporMerkeziScreen({super.key, required this.url, required this.baslik});

  @override
  State<RaporMerkeziScreen> createState() => _RaporMerkeziScreenState();
}

class _RaporMerkeziScreenState extends State<RaporMerkeziScreen> {
  late String _taban;
  late String _kat;
  String? _donem;

  @override
  void initState() {
    super.initState();
    final yol = widget.url.split('?').first;
    final i = yol.lastIndexOf('/');
    _taban = yol.substring(0, i);
    _kat = yol.substring(i + 1);
  }

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      key: ValueKey('$_kat|$_donem'),
      yol: '$_taban/$_kat',
      q: _donem == null ? null : {'donem': _donem!},
      baslik: widget.baslik,
      ikon: Icons.insights,
      govde: (ctx, v, yenile) => _govde(ctx, v, yenile),
    );
  }

  Widget _govde(BuildContext context, Map<String, dynamic> v, Future<void> Function() yenile) {
    final t = context.watch<TemaProvider>();
    final dn = harita(v['dn']);
    final kategoriler = harita(v['kategoriler']);
    final katalog = harita(v['katalog']);
    final durum = harita(v['durum']);
    final aktifDonem = metinOku(dn['tip'], 'bu_ay');
    final raporlar = <MapEntry<String, List<dynamic>>>[
      for (final e in katalog.entries)
        if (e.value is List && (e.value as List).isNotEmpty && '${(e.value as List)[0]}' == _kat) MapEntry(e.key, e.value as List),
    ];
    return KGovde(yenile: yenile, children: [
      // kategori sekmeleri
      if (kategoriler.length > 1)
        KCipler(
          secenekler: [for (final e in kategoriler.entries) (e.key, e.value is List && (e.value as List).isNotEmpty ? '${(e.value as List)[0]}' : e.key)],
          secili: _kat,
          onSec: (k) => setState(() => _kat = k),
        ),
      KCipler(secenekler: kDonemler, secili: aktifDonem, onSec: (d) => setState(() => _donem = d)),
      Padding(
        padding: const EdgeInsets.only(bottom: 10, left: 2),
        child: Text('${metinOku(dn['ad'])} · ${metinOku(dn['etiket'])}', style: TextStyle(color: t.sub, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
      if (_kat == 'ai')
        _AiBolum(taban: _taban, donem: aktifDonem, ai: harita(v['ai']), nabiz: harita(v['aiNabiz']))
      else if (raporlar.isEmpty)
        const KBos(baslik: 'Bu kategoride rapor yok', ikon: Icons.insights)
      else
        for (final r in raporlar) _raporKart(context, r.key, r.value, aktifDonem),
      if (durum.isNotEmpty) ...[
        const SizedBox(height: 8),
        KBaslik('Kullanılan veri', ikon: Icons.dataset_outlined, alt: '0 görünen kayıt türü, o raporlarda boş kalmasının nedenidir'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final e in durum.entries)
            KRozet('${e.key}: ${sayiYaz(e.value)}', renk: sayiOku(e.value) > 0 ? t.yesil : t.sub),
        ]),
      ],
    ]);
  }

  Widget _raporKart(BuildContext context, String anahtar, List<dynamic> r, String donem) {
    final t = context.read<TemaProvider>();
    final ad = r.length > 1 ? '${r[1]}' : anahtar;
    final acik = r.length > 2 ? '${r[2]}' : '';
    final renk = r.length > 4 ? renkOku(r[4]) : t.mor1;
    return KKart(
      renk: renk,
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => RaporDetayScreen(taban: _taban, rapor: anahtar, baslik: ad, donem: donem))),
      child: Row(children: [
        KIkon(ikonAdi(r.length > 3 ? '${r[3]}' : '', Icons.insights), renk: renk),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ad, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
            if (acik.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 3), child: Text(acik, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.35))),
          ]),
        ),
        Icon(Icons.chevron_right, color: t.sub),
      ]),
    );
  }
}

/// Tek rapor: sayfalar (pano KPI + bloklar, tablolar). Web'deki önizleme ile aynı veri.
class RaporDetayScreen extends StatelessWidget {
  final String taban, rapor, baslik, donem;
  const RaporDetayScreen({super.key, required this.taban, required this.rapor, required this.baslik, required this.donem});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '$taban/indir',
      q: {'rapor': rapor, 'format': 'html', 'donem': donem},
      baslik: baslik,
      ikon: Icons.insights,
      govde: (ctx, v, yenile) {
        final sayfalar = liste(v['sayfalar']);
        final alt = metinOku(v['alt']);
        return KGovde(yenile: yenile, children: [
          if (alt.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(alt, style: TextStyle(color: ctx.watch<TemaProvider>().sub, fontSize: 12.5))),
          if (sayfalar.isEmpty) const KBos(baslik: 'Bu dönemde rapor verisi yok', aciklama: 'Dönemi değiştirin ya da "Kullanılan veri" bölümünde eksik kayıt türüne bakın.'),
          for (final s in sayfalar) RaporSayfaGorunum(sayfa: s),
        ]);
      },
    );
  }
}

/// Rapor sayfası çizimi (pano: KPI + bloklar; tablo: kolon + satır). Diğer ekranlar da kullanabilir.
class RaporSayfaGorunum extends StatelessWidget {
  final Map<String, dynamic> sayfa;
  const RaporSayfaGorunum({super.key, required this.sayfa});

  static String bicim(dynamic v, String tip) {
    if (v == null || (v is String && v.isEmpty)) return '—';
    if (v is String && double.tryParse(v.replaceAll(',', '.')) == null) return v;
    switch (tip) {
      case 'tl':
        return tl(v);
      case 'y':
        return yuzde(v);
      case 's':
      case 'sayi':
      case 'n':
        return sayiYaz(v);
      default:
        return v is num ? sayiYaz(v) : '$v';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final ad = metinOku(sayfa['ad']);
    final not = metinOku(sayfa['not']);
    final bos = metinOku(sayfa['bos']);
    final kpi = dizi(sayfa['kpi']);
    final bloklar = liste(sayfa['bloklar']);
    final kol = dizi(sayfa['kol']);
    final sat = dizi(sayfa['sat']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KBaslik(ad, ikon: sayfa['tip'] == 'pano' ? Icons.space_dashboard_outlined : Icons.table_chart_outlined, alt: not.isEmpty ? not : null),
      if (kpi.isNotEmpty)
        KKpiIzgara([
          for (final k in kpi)
            if (k is List && k.length >= 2) KKpi(etiket: '${k[0]}', deger: bicim(k[1], k.length > 2 ? '${k[2]}' : 'm'), renk: k.length > 3 ? renkOku(k[3]) : t.mor1),
        ]),
      for (final b in bloklar) _Blok(blok: b),
      if (kol.isNotEmpty && sat.isNotEmpty)
        KKart(
          padding: const EdgeInsets.all(6),
          child: KTablo(
            basliklar: [for (final c in kol) c is List && c.isNotEmpty ? '${c[0]}' : '$c'],
            satirlar: [
              for (final r in sat)
                if (r is List) [for (var i = 0; i < kol.length; i++) i < r.length ? bicim(r[i], kol[i] is List && (kol[i] as List).length > 1 ? '${(kol[i] as List)[1]}' : 'm') : ''],
            ],
            sagaYasla: {for (var i = 0; i < kol.length; i++) if (kol[i] is List && (kol[i] as List).length > 1 && const ['tl', 'y', 's', 'sayi', 'n'].contains('${(kol[i] as List)[1]}')) i},
          ),
        )
      else if (kpi.isEmpty && bloklar.isEmpty)
        KKart(child: Text(bos.isNotEmpty ? bos : 'Bu bölüm için dönemde kayıt yok.', style: TextStyle(color: t.sub, fontSize: 13.5, height: 1.4))),
      if (bos.isNotEmpty && (kpi.isNotEmpty || sat.isNotEmpty))
        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(bos, style: TextStyle(color: t.sub, fontSize: 12.5))),
      const SizedBox(height: 6),
    ]);
  }
}

/// Pano bloğu: ilk sayısal kolona göre yatay çubuklar + değer
class _Blok extends StatelessWidget {
  final Map<String, dynamic> blok;
  const _Blok({required this.blok});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final kol = dizi(blok['kol']);
    final sat = dizi(blok['sat']).whereType<List>().toList();
    final renk = renkOku(blok['renk'], t.mor1);
    int sayiKol = 1;
    for (var i = 1; i < kol.length; i++) {
      final tip = kol[i] is List && (kol[i] as List).length > 1 ? '${(kol[i] as List)[1]}' : 'm';
      if (tip != 'm') { sayiKol = i; break; }
    }
    final tip = kol.length > sayiKol && kol[sayiKol] is List && (kol[sayiKol] as List).length > 1 ? '${(kol[sayiKol] as List)[1]}' : 'sayi';
    double mx = 0;
    for (final r in sat) { if (r.length > sayiKol) mx = mx < sayiOku(r[sayiKol]).abs() ? sayiOku(r[sayiKol]).abs() : mx; }
    return KKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(metinOku(blok['baslik']), style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        if (sat.isEmpty) Text('Veri yok', style: TextStyle(color: t.sub, fontSize: 13)),
        for (final r in sat.take(14))
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text(r.isNotEmpty ? '${r[0]}' : '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 13))),
                const SizedBox(width: 8),
                Text(r.length > sayiKol ? RaporSayfaGorunum.bicim(r[sayiKol], tip) : '', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
              ]),
              if (r.length > 2 && sayiKol != 2 && '${r[2]}'.isNotEmpty)
                Text(RaporSayfaGorunum.bicim(r[2], kol.length > 2 && kol[2] is List && (kol[2] as List).length > 1 ? '${(kol[2] as List)[1]}' : 'm'), style: TextStyle(color: t.sub, fontSize: 11.5)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: mx <= 0 || r.length <= sayiKol ? 0 : (sayiOku(r[sayiKol]).abs() / mx).clamp(0, 1).toDouble(),
                  minHeight: 7,
                  backgroundColor: t.card2,
                  color: renk,
                ),
              ),
            ]),
          ),
      ]),
    );
  }
}

/// AI analiz bölümü: son özet + "Özet hazırla" + soru sor
class _AiBolum extends StatefulWidget {
  final String taban, donem;
  final Map<String, dynamic> ai;
  final Map<String, dynamic> nabiz;
  const _AiBolum({required this.taban, required this.donem, required this.ai, required this.nabiz});

  @override
  State<_AiBolum> createState() => _AiBolumState();
}

class _AiBolumState extends State<_AiBolum> {
  Map<String, dynamic>? _ai;
  bool _calisiyor = false;
  final _soru = TextEditingController();
  String? _cevap;

  @override
  void initState() {
    super.initState();
    _ai = widget.ai.isEmpty ? null : widget.ai;
  }

  Future<void> _hazirla({bool yenile = false}) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    setState(() => _calisiyor = true);
    final c = await KopruApi.gonder(tok, '${widget.taban}/ai', {'donem': widget.donem, if (yenile) 'yenile': '1'});
    if (!mounted) return;
    setState(() => _calisiyor = false);
    if (c.ok && c.j['analiz'] is Map) {
      setState(() => _ai = Map<String, dynamic>.from(c.j['analiz'] as Map));
    } else {
      kToast(context, c.hata ?? 'AI özeti hazırlanamadı.', hata: true);
    }
  }

  Future<void> _sor() async {
    final s = _soru.text.trim();
    if (s.isEmpty) return;
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    setState(() { _calisiyor = true; _cevap = null; });
    final c = await KopruApi.gonder(tok, '${widget.taban}/ai', {'donem': widget.donem, 'soru': s});
    if (!mounted) return;
    setState(() { _calisiyor = false; _cevap = c.ok ? metinOku(c.j['cevap']) : null; });
    if (!c.ok) kToast(context, c.hata ?? 'Cevap alınamadı.', hata: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final ai = _ai;
    final kalan = widget.nabiz['kalan'];
    Widget liste(String baslik, String anahtar, Color renk, IconData ikon) {
      final l = ai == null ? const [] : dizi(ai[anahtar]);
      if (l.isEmpty) return const SizedBox.shrink();
      return KKart(
        renk: renk,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Icon(ikon, color: renk, size: 19), const SizedBox(width: 8), Text(baslik, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold))]),
          const SizedBox(height: 8),
          for (final x in l)
            if (x is Map)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${x['baslik'] ?? ''}', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                  Text('${x['detay'] ?? ''}', style: TextStyle(color: t.sub2, fontSize: 13.5, height: 1.4)),
                ]),
              ),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.auto_awesome, color: t.mor1),
            const SizedBox(width: 8),
            Expanded(child: Text('Yapay zekâ özeti', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold))),
            if (kalan != null) KRozet('Bugün kalan: $kalan', renk: t.mavi),
          ]),
          const SizedBox(height: 8),
          Text(ai == null ? 'Seçili dönem için henüz özet yok. Hazırlatın; rakamlar bu dönemin raporlarından alınır.' : metinOku(ai['ozet']),
              style: TextStyle(color: t.sub2, fontSize: 14, height: 1.45)),
          if (ai != null && metinOku(ai['_zaman']).isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text('Hazırlandı: ${ai['_zaman']} · ${ai['_donem'] ?? ''}', style: TextStyle(color: t.sub, fontSize: 12))),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, children: [
            KButon(ai == null ? 'Özet hazırla' : 'Yeniden hazırla', ikon: Icons.auto_awesome, yukleniyor: _calisiyor, onTap: () => _hazirla(yenile: ai != null)),
          ]),
        ]),
      ),
      liste('Öne çıkanlar', 'one_cikanlar', t.yesil, Icons.trending_up),
      liste('Riskler', 'riskler', t.kirmizi, Icons.warning_amber_outlined),
      liste('Öneriler', 'oneriler', t.mavi, Icons.lightbulb_outline),
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Rapora soru sorun', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          KAlan('Sorunuz', _soru, ipucu: 'ör. Geçen aya göre en çok ne arttı?', satir: 2),
          KButon('Sor', ikon: Icons.send, yukleniyor: _calisiyor, onTap: _sor),
          if (_cevap != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_cevap!, style: TextStyle(color: t.ink, fontSize: 14, height: 1.5))),
        ]),
      ),
    ]);
  }
}

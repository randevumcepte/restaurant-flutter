import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Fiyat Radarı v2 — satın alma rapor merkezi. Web /fiyat-radari ile aynı veri (/api/patron/fiyat-radari-v2):
/// kimden / ne zaman / kaça + neye göre kıyaslandığı, alış geçmişi, Excel/PDF rapor (imzalı link → tarayıcı), AI analiz.
class FiyatRadariScreen extends StatefulWidget {
  const FiyatRadariScreen({super.key});
  @override
  State<FiyatRadariScreen> createState() => _FiyatRadariScreenState();
}

const _kirmizi = Color(0xFFF43F5E);
const _amber = Color(0xFFF59E0B);
const _yesil = Color(0xFF10B981);
const _pembe = Color(0xFFEC4899);
const _mor = Color(0xFF7C3AED);
const _mavi = Color(0xFF4F46E5);
const _cyan = Color(0xFF0EA5E9);
const _gri = Color(0xFF64748B);
const _aiMor = Color(0xFF9333EA);

final _fmtP = NumberFormat('#,##0.00', 'tr');
final _fmt0 = NumberFormat('#,##0', 'tr');
final _fmtM = NumberFormat('#,##0.###', 'tr');
final _fmtY = NumberFormat('#,##0.#', 'tr');
num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
String _p(dynamic v) => '${_fmtP.format(_n(v))} ₺';
String _p0(dynamic v) => '${_fmt0.format(_n(v).round())} ₺';
String _y(dynamic v) => '%${_fmtY.format(_n(v))}';
String _tar(dynamic t) {
  final s = t?.toString() ?? '';
  return s.length >= 10 ? '${s.substring(8, 10)}.${s.substring(5, 7)}.${s.substring(0, 4)}' : '—';
}
String _s(dynamic v) => v?.toString() ?? '';
String _norm(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

const _sekmeler = [
  ('genel', Icons.dashboard_outlined, 'Genel Bakış'),
  ('zam', Icons.trending_up, 'Gizli Zamlar'),
  ('malzeme', Icons.inventory_2_outlined, 'Malzeme Fiyatları'),
  ('tedarikci', Icons.compare_arrows, 'Tedarikçi Karşılaştırma'),
  ('karne', Icons.workspace_premium_outlined, 'Tedarikçi Karnesi'),
  ('hal', Icons.storefront_outlined, 'Hal Kıyası'),
  ('dokum', Icons.receipt_long_outlined, 'Alış Dökümü'),
  ('ai', Icons.auto_awesome, 'AI Analiz'),
  ('rapor', Icons.download_outlined, 'Raporlar'),
];

const _raporIkon = <String, IconData>{
  'summarize': Icons.summarize_outlined,
  'trending_up': Icons.trending_up,
  'inventory_2': Icons.inventory_2_outlined,
  'compare_arrows': Icons.compare_arrows,
  'workspace_premium': Icons.workspace_premium_outlined,
  'storefront': Icons.storefront_outlined,
  'receipt_long': Icons.receipt_long_outlined,
  'bar_chart': Icons.bar_chart,
  'auto_awesome': Icons.auto_awesome,
};

Color _hex(String h) => Color(int.tryParse('FF${h.replaceAll('#', '')}', radix: 16) ?? 0xFF7C3AED);

class _FiyatRadariScreenState extends State<FiyatRadariScreen> {
  bool loading = true;
  String? hata;
  Map<String, dynamic> v = {};
  int gun = 120, ted = 0;
  num esik = 8;
  String sekme = 'genel';
  String ara = '';
  // AI
  bool aiYukleniyor = false;
  Map<String, dynamic>? ai;
  String? aiHata;
  final soruCtl = TextEditingController();
  bool soruYukleniyor = false;
  String? soruCevap, soruMetin;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    soruCtl.dispose();
    super.dispose();
  }

  List _l(String k) => (v[k] as List?) ?? const [];
  Map _m(String k) => (v[k] as Map?) ?? const {};
  List get _halSat => (_m('hal')['satirlar'] as List?) ?? const [];

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      loading = true;
      hata = null;
    });
    try {
      final res = await Api.fiyatRadariV2(auth.token!, gun: gun, ted: ted, esik: esik);
      if (!mounted) return;
      setState(() {
        if (res['ok'] == 1) {
          v = res;
          if (res['ai'] is Map) ai = Map<String, dynamic>.from(res['ai']);
        } else {
          hata = _s(res['hata']).isEmpty ? 'Veri alınamadı.' : _s(res['hata']);
        }
        loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          hata = 'Bağlantı hatası. Tekrar dene.';
        });
      }
    }
  }

  void _sekme(String k) => setState(() {
        sekme = k;
        ara = '';
      });

  // Rapor: sunucudan 15 dk geçerli imzalı link al → tarayıcıda aç (Excel iner, PDF yazdır görünümü açılır)
  Future<void> _rapor(String rapor, String format) async {
    final auth = context.read<AuthProvider>();
    final mesaj = ScaffoldMessenger.of(context);
    mesaj.showSnackBar(SnackBar(content: Text(format == 'pdf' ? 'PDF hazırlanıyor…' : 'Excel hazırlanıyor…'), duration: const Duration(seconds: 2)));
    try {
      final res = await Api.fiyatRadariRaporLink(auth.token!, rapor, format, gun: gun, ted: ted, esik: esik);
      final url = _s(res['url']);
      if (res['ok'] != 1 || url.isEmpty) {
        mesaj.showSnackBar(SnackBar(content: Text(_s(res['hata']).isEmpty ? 'Rapor linki alınamadı.' : _s(res['hata']))));
        return;
      }
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok) mesaj.showSnackBar(const SnackBar(content: Text('Tarayıcı açılamadı.')));
    } catch (_) {
      mesaj.showSnackBar(const SnackBar(content: Text('Rapor alınamadı. Bağlantını kontrol et.')));
    }
  }

  Future<void> _aiAnaliz(bool yenile) async {
    if (aiYukleniyor) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      aiYukleniyor = true;
      aiHata = null;
    });
    final res = await Api.fiyatRadariAi(auth.token!, yenile: yenile, gun: gun, ted: ted, esik: esik);
    if (!mounted) return;
    setState(() {
      aiYukleniyor = false;
      if (res['ok'] == 1 && res['analiz'] is Map) {
        ai = Map<String, dynamic>.from(res['analiz']);
      } else {
        aiHata = _s(res['hata']).isEmpty ? 'Analiz yapılamadı.' : _s(res['hata']);
      }
    });
  }

  Future<void> _sor() async {
    final q = soruCtl.text.trim();
    if (q.isEmpty || soruYukleniyor) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      soruYukleniyor = true;
      soruMetin = q;
      soruCevap = null;
    });
    final res = await Api.fiyatRadariAi(auth.token!, soru: q, gun: gun, ted: ted, esik: esik);
    if (!mounted) return;
    setState(() {
      soruYukleniyor = false;
      soruCevap = res['ok'] == 1 ? _s(res['cevap']) : (_s(res['hata']).isEmpty ? 'Cevap alınamadı.' : _s(res['hata']));
    });
  }

  // Bir malzemenin alış geçmişi (kimden, hangi fatura, kaça, önceki alışa göre)
  void _gecmis(dynamic mid, String ad) {
    final g = (_m('gecmis')[mid.toString()] as List?) ?? const [];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final t = Provider.of<TemaProvider>(ctx, listen: false);
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          expand: false,
          builder: (_, sc) => Container(
            decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
            child: ListView(controller: sc, padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 12),
              Text(ad, style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.w900)),
              Text('Alış geçmişi · en yeni ${g.length} alış', style: TextStyle(color: t.sub, fontSize: 12)),
              const SizedBox(height: 12),
              if (g.isEmpty) Text('Kayıt yok.', style: TextStyle(color: t.sub)),
              for (final r in g)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(_s(r['tedarikci']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 13.5)),
                        const SizedBox(height: 2),
                        Text('${_tar(r['tarih'])} · fatura ${_s(r['fatura_no'])} · ${_fmtM.format(_n(r['miktar']))} ${_s(r['birim'])}',
                            style: TextStyle(color: t.sub, fontSize: 11.5)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(_p(r['birim_fiyat']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 3),
                      _degisim(r['degisim'], t),
                    ]),
                  ]),
                ),
            ]),
          ),
        );
      },
    );
  }

  Widget _degisim(dynamic d, TemaProvider t) {
    if (d == null) return Text('ilk alış', style: TextStyle(color: t.sub, fontSize: 11));
    final n = _n(d);
    if (n == 0) return Text('aynı', style: TextStyle(color: t.sub, fontSize: 11));
    return MRozet('${n > 0 ? '▲ +' : '▼ '}${_fmtY.format(n.abs())}%', n > 0 ? _kirmizi : _yesil);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final genis = MediaQuery.sizeOf(context).width >= 1000;
    return MasaustuSayfa(
      baslik: 'Fiyat Radarı',
      ikon: Icons.radar,
      geri: true,
      altBaslik: 'Satın alma rapor merkezi · kimden, kaça, neye göre',
      araclar: [
        if (genis) ...[
          MButon('Tam Rapor (Excel)', _yesil, () => _rapor('tam', 'xlsx'), ikon: Icons.table_view),
          const SizedBox(width: 6),
          MButon('PDF', _kirmizi, () => _rapor('tam', 'pdf'), dolu: false, ikon: Icons.picture_as_pdf_outlined),
          const SizedBox(width: 6),
        ],
        IconButton(onPressed: _yukle, tooltip: 'Yenile', icon: Icon(Icons.refresh, color: t.sub2)),
      ],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: EdgeInsets.all(genis ? 20 : 12),
                children: [
                  _hero(t, genis),
                  const SizedBox(height: 14),
                  if (hata != null) ...[_bos(t, hata!, Icons.error_outline, _kirmizi), const SizedBox(height: 14)],
                  _kpiler(t),
                  const SizedBox(height: 14),
                  _sekmeCubugu(t),
                  const SizedBox(height: 14),
                  ..._icerik(t, genis),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // ---------- ÜST: başlık + filtre ----------
  Widget _secim<T>(String etiket, T deger, List<(T, String)> ops, ValueChanged<T> deg, {double genislik = 160}) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(etiket, style: const TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: .5)),
          const SizedBox(height: 4),
          Container(
            width: genislik, // sabit genişlik + isExpanded: uzun tedarikçi adı taşmaz, "…" ile kısalır
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: .14), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white30)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: ops.any((o) => o.$1 == deger) ? deger : ops.first.$1,
                isExpanded: true,
                dropdownColor: const Color(0xFF4338CA),
                iconEnabledColor: Colors.white,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                items: [for (final o in ops) DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis))],
                onChanged: (x) {
                  if (x != null) deg(x);
                },
              ),
            ),
          ),
        ],
      );

  Widget _hero(TemaProvider t, bool genis) {
    final kpi = _m('kpi');
    final tedler = _l('tedarikciler');
    return Container(
      padding: EdgeInsets.all(genis ? 22 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9), Color(0xFF4338CA), Color(0xFF1E1B4B)]),
        boxShadow: [BoxShadow(color: const Color(0xFF4C1D95).withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('📡 Satın Alma Rapor Merkezi', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        const Text('Her malzemeyi kimden, ne zaman, kaça aldığını ve neye göre pahalı/ucuz sayıldığını gösterir. Karta dokun → alış geçmişi.',
            style: TextStyle(color: Colors.white70, fontSize: 12.5)),
        const SizedBox(height: 14),
        Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: [
          _secim<int>('DÖNEM', gun, const [(30, 'Son 30 gün'), (60, 'Son 60 gün'), (90, 'Son 3 ay'), (120, 'Son 4 ay'), (180, 'Son 6 ay'), (365, 'Son 1 yıl')], (x) {
            gun = x;
            _yukle();
          }),
          _secim<int>('TEDARİKÇİ', ted, [(0, 'Tüm tedarikçiler'), for (final x in tedler) (_n(x['id']).toInt(), _s(x['ad']))], (x) {
            ted = x;
            _yukle();
          }, genislik: 220),
          _secim<num>('ZAM EŞİĞİ', esik, const [(3, '%3 ve üstü'), (5, '%5 ve üstü'), (8, '%8 ve üstü'), (10, '%10 ve üstü'), (15, '%15 ve üstü'), (20, '%20 ve üstü'), (30, '%30 ve üstü')], (x) {
            esik = x;
            _yukle();
          }),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('${_tar(kpi['baslangic'])} – ${_tar(kpi['bitis'])} · ${_n(kpi['fatura'])} fatura · ${_n(kpi['kalem'])} alış satırı',
                style: const TextStyle(color: Colors.white70, fontSize: 11.5)),
          ),
        ]),
        if (!genis) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _heroBtn('Tam Rapor Excel', Icons.table_view, () => _rapor('tam', 'xlsx'), dolu: true)),
            const SizedBox(width: 8),
            Expanded(child: _heroBtn('PDF', Icons.picture_as_pdf_outlined, () => _rapor('tam', 'pdf'))),
          ]),
        ],
      ]),
    );
  }

  Widget _heroBtn(String e, IconData ik, VoidCallback f, {bool dolu = false}) => Material(
        color: dolu ? Colors.white : Colors.white.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: f,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(ik, size: 17, color: dolu ? const Color(0xFF5B21B6) : Colors.white),
              const SizedBox(width: 6),
              Flexible(child: Text(e, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dolu ? const Color(0xFF5B21B6) : Colors.white, fontWeight: FontWeight.w800, fontSize: 13))),
            ]),
          ),
        ),
      );

  // ---------- KPI ----------
  Widget _kpiler(TemaProvider t) {
    final k = _m('kpi');
    final kartlar = [
      (Icons.payments_outlined, _mavi, 'Toplam alış', _p0(k['toplam']), '${_n(k['tedarikci'])} tedarikçi · ${_n(k['malzeme'])} malzeme'),
      (Icons.trending_up, _kirmizi, 'Gizli zam yıllık etkisi', '~${_p0(k['zam_etki'])}', '${_n(k['zam_say'])} malzemede %$esik+ artış'),
      (Icons.compare_arrows, _cyan, 'En ucuzdan alsaydın (yıllık)', '~${_p0(k['ted_kayip'])}', '${_l('karsilastirma').length} malzemede tedarikçi farkı'),
      (Icons.storefront_outlined, _yesil, 'Hal üstü fazla (yıllık)', '~${_p0(k['hal_fazla'])}', '${_halSat.length} malzeme halde eşleşti'),
      (Icons.price_check, _amber, 'Toplam tasarruf potansiyeli', '~${_p0(_n(k['zam_etki']) + _n(k['ted_kayip']) + _n(k['hal_fazla']))}', 'zam + tedarikçi + hal (kesişebilir)'),
    ];
    return LayoutBuilder(builder: (_, c) {
      final sutun = c.maxWidth >= 1100 ? 5 : (c.maxWidth >= 640 ? 3 : 2);
      final w = (c.maxWidth - (sutun - 1) * 10) / sutun;
      return Wrap(spacing: 10, runSpacing: 10, children: [
        for (final x in kartlar)
          SizedBox(
            width: w,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line), boxShadow: t.golge),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(width: 32, height: 32, decoration: BoxDecoration(color: x.$2.withValues(alpha: .14), borderRadius: BorderRadius.circular(9)), child: Icon(x.$1, color: x.$2, size: 18)),
                const SizedBox(height: 8),
                Text(x.$3, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 11.5, fontWeight: FontWeight.w600)),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(x.$4, style: TextStyle(color: x.$2 == _mavi ? t.ink : x.$2, fontSize: 20, fontWeight: FontWeight.w900))),
                Text(x.$5, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 10.5)),
              ]),
            ),
          ),
      ]);
    });
  }

  // ---------- SEKMELER ----------
  int _sayi(String k) {
    switch (k) {
      case 'zam':
        return _l('zamlar').length;
      case 'malzeme':
        return _l('malzemeler').length;
      case 'tedarikci':
        return _l('karsilastirma').length;
      case 'karne':
        return _l('karne').length;
      case 'hal':
        return _halSat.length;
      case 'dokum':
        return _n(v['dokum_toplam']).toInt();
      case 'rapor':
        return _l('raporlar').length;
    }
    return -1;
  }

  Widget _sekmeCubugu(TemaProvider t) => Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (final s in _sekmeler)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _sekme(s.$1),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: sekme == s.$1 ? const LinearGradient(colors: [_mor, _mavi]) : null,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(s.$2, size: 17, color: sekme == s.$1 ? Colors.white : t.sub2),
                        const SizedBox(width: 6),
                        Text(s.$3, style: TextStyle(color: sekme == s.$1 ? Colors.white : t.sub2, fontWeight: FontWeight.w700, fontSize: 13)),
                        if (_sayi(s.$1) >= 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                            decoration: BoxDecoration(color: (sekme == s.$1 ? Colors.white : t.sub2).withValues(alpha: .18), borderRadius: BorderRadius.circular(99)),
                            child: Text('${_sayi(s.$1)}', style: TextStyle(color: sekme == s.$1 ? Colors.white : t.sub2, fontSize: 10.5, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ]),
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );

  List<Widget> _icerik(TemaProvider t, bool genis) {
    switch (sekme) {
      case 'zam':
        return _zamlar(t);
      case 'malzeme':
        return _malzemeler(t);
      case 'tedarikci':
        return _tedarikci(t);
      case 'karne':
        return _karne(t);
      case 'hal':
        return _hal(t);
      case 'dokum':
        return _dokum(t);
      case 'ai':
        return _ai(t);
      case 'rapor':
        return _raporlar(t);
    }
    return _genel(t, genis);
  }

  // ---------- ortak parçalar ----------
  Widget _baslik(TemaProvider t, String metin, IconData ik, Color renk, {String? rapor, bool araKutusu = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, alignment: WrapAlignment.spaceBetween, children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(ik, color: renk, size: 20),
            const SizedBox(width: 8),
            Flexible(child: Text(metin, style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.w900))),
          ]),
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (araKutusu)
              SizedBox(
                width: 190,
                height: 38,
                child: TextField(
                  onChanged: (x) => setState(() => ara = x),
                  style: TextStyle(color: t.ink, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Ara…',
                    hintStyle: TextStyle(color: t.sub, fontSize: 12.5),
                    isDense: true,
                    prefixIcon: Icon(Icons.search, size: 18, color: t.sub),
                    filled: true,
                    fillColor: t.card,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: BorderSide(color: t.line)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9), borderSide: const BorderSide(color: _mor)),
                  ),
                ),
              ),
            if (rapor != null) ...[
              _indirBtn('Excel', Icons.table_view, const Color(0xFF16A34A), () => _rapor(rapor, 'xlsx')),
              _indirBtn('PDF', Icons.picture_as_pdf_outlined, const Color(0xFFE11D48), () => _rapor(rapor, 'pdf')),
            ],
          ]),
        ]),
      );

  Widget _indirBtn(String e, IconData ik, Color c, VoidCallback f) => Material(
        color: c.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(9),
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: f,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(9), border: Border.all(color: c.withValues(alpha: .4))),
            child: Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(ik, size: 16, color: c),
              const SizedBox(width: 5),
              Text(e, style: TextStyle(color: c, fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
        ),
      );

  Widget _nasil(TemaProvider t, String metin) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _mavi.withValues(alpha: .07), borderRadius: BorderRadius.circular(12), border: Border.all(color: _mavi.withValues(alpha: .3))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.info_outline, size: 18, color: _mavi),
          const SizedBox(width: 8),
          Expanded(child: Text(metin, style: TextStyle(color: t.sub2, fontSize: 12, height: 1.4))),
        ]),
      );

  Widget _bos(TemaProvider t, String metin, IconData ik, Color c) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Column(children: [
          Icon(ik, size: 38, color: c),
          const SizedBox(height: 8),
          Text(metin, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 13)),
        ]),
      );

  // Telefonda 1, tablette 2, geniş masaüstünde 3 sütun kart ızgarası
  Widget _izgara(List<Widget> kartlar) => LayoutBuilder(builder: (_, c) {
        final sutun = c.maxWidth >= 1500 ? 3 : (c.maxWidth >= 820 ? 2 : 1);
        final w = (c.maxWidth - (sutun - 1) * 12) / sutun;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final k in kartlar) SizedBox(width: w, child: k)]);
      });

  Widget _kart(TemaProvider t, {required Widget child, VoidCallback? onTap, Color? vurgu}) => Material(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: vurgu?.withValues(alpha: .4) ?? t.line),
            ),
            child: child,
          ),
        ),
      );

  Widget _kartBas(TemaProvider t, String ad, String birim, Widget? sag, {String? alt}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: ad, style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w900)),
              if (birim.isNotEmpty) TextSpan(text: '  / $birim', style: TextStyle(color: t.sub, fontSize: 11)),
            ])),
            if (alt != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(alt, style: TextStyle(color: t.sub, fontSize: 11))),
          ]),
        ),
        if (sag != null) ...[
          const SizedBox(width: 8),
          ConstrainedBox(constraints: const BoxConstraints(maxWidth: 150), child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.topRight, child: sag)),
        ],
      ]);

  // etiket · değer · alt (kimden/tarih) satırı
  Widget _satir(TemaProvider t, String etiket, String deger, {String? alt, Color? renk, bool kalin = false}) => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 118, child: Text(etiket, style: TextStyle(color: t.sub, fontSize: 12))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(deger, style: TextStyle(color: renk ?? t.ink, fontSize: 13, fontWeight: kalin ? FontWeight.w900 : FontWeight.w700)),
              if (alt != null && alt.isNotEmpty) Text(alt, style: TextStyle(color: t.sub, fontSize: 11)),
            ]),
          ),
        ]),
      );

  bool _eslesir(List<dynamic> alanlar) => ara.trim().isEmpty || _norm(alanlar.map(_s).join(' ')).contains(_norm(ara.trim()));

  // ---------- GENEL BAKIŞ ----------
  Widget _kutu(TemaProvider t, String b, IconData ik, Color c, Widget ic) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line), boxShadow: t.golge),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(ik, size: 18, color: c), const SizedBox(width: 7), Expanded(child: Text(b, style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w900)))]),
          const SizedBox(height: 12),
          ic,
        ]),
      );

  Widget _yatay(TemaProvider t, String ad, String sag, double oran, Gradient g, {String? alt}) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Row(children: [
          Expanded(
            flex: 4,
            child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: ad, style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 12.5)),
                  if (alt != null) TextSpan(text: ' · $alt', style: TextStyle(color: t.sub, fontSize: 10.5)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Container(
                height: 9,
                color: t.card2,
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(widthFactor: oran.clamp(0.02, 1.0), child: Container(decoration: BoxDecoration(gradient: g))),
              ),
            ),
          ),
          SizedBox(width: 92, child: Text(sag, textAlign: TextAlign.right, style: TextStyle(color: t.sub2, fontWeight: FontWeight.w800, fontSize: 12))),
        ]),
      );

  Widget _madde(TemaProvider t, IconData ik, Color c, String sekmeK, InlineSpan metin) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: t.card2,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _sekme(sekmeK),
            child: Padding(
              padding: const EdgeInsets.all(11),
              child: Row(children: [Icon(ik, size: 18, color: c), const SizedBox(width: 10), Expanded(child: Text.rich(metin, style: TextStyle(color: t.ink, fontSize: 12.5)))]),
            ),
          ),
        ),
      );

  List<Widget> _genel(TemaProvider t, bool genis) {
    final aylik = _l('aylik');
    final kat = _l('kategori');
    final malz = _l('malzemeler').take(8).toList();
    final maxAy = aylik.fold<num>(1, (a, x) => _n(x['tutar']) > a ? _n(x['tutar']) : a);
    final maxH = malz.fold<num>(1, (a, x) => _n(x['harcama']) > a ? _n(x['harcama']) : a);
    final halAcil = _halSat.where((h) => h['fark'] != null && _n(h['fark']) > 30).take(3).toList();
    final aylikKutu = _kutu(
        t,
        'Aylık alış',
        Icons.bar_chart,
        _pembe,
        aylik.isEmpty
            ? Text('Bu dönemde alış yok.', style: TextStyle(color: t.sub, fontSize: 12))
            : SizedBox(
                height: 170,
                child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  for (final a in aylik)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                          FittedBox(child: Text('${_fmtY.format(_n(a['tutar']) / 1000)}k', style: TextStyle(color: t.sub2, fontSize: 10, fontWeight: FontWeight.w800))),
                          const SizedBox(height: 4),
                          Container(
                            height: (_n(a['tutar']) / maxAy * 120).toDouble().clamp(3.0, 120.0),
                            constraints: const BoxConstraints(maxWidth: 46),
                            decoration: const BoxDecoration(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(3)),
                                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [_pembe, _mor])),
                          ),
                          const SizedBox(height: 5),
                          FittedBox(child: Text(_ayAd(_s(a['ay'])), style: TextStyle(color: t.sub, fontSize: 10.5, fontWeight: FontWeight.w700))),
                        ]),
                      ),
                    ),
                ]),
              ));
    final katKutu = _kutu(
        t,
        'Kategori dağılımı',
        Icons.donut_small_outlined,
        _mavi,
        kat.isEmpty
            ? Text('Veri yok.', style: TextStyle(color: t.sub, fontSize: 12))
            : Column(children: [for (final k in kat.take(7)) _yatay(t, _s(k['ad']), _y(k['pay']), (_n(k['pay']) / 100).toDouble(), const LinearGradient(colors: [_mavi, _cyan]))]));
    final topKutu = _kutu(
        t,
        'En çok para giden malzemeler',
        Icons.leaderboard_outlined,
        _mor,
        malz.isEmpty
            ? Text('Veri yok.', style: TextStyle(color: t.sub, fontSize: 12))
            : Column(children: [
                for (final m in malz) _yatay(t, _s(m['ad']), _p0(m['harcama']), (_n(m['harcama']) / maxH).toDouble(), const LinearGradient(colors: [_mor, _pembe]), alt: _s(m['son_ted']))
              ]));
    final zam = _l('zamlar').take(3).toList();
    final kars = _l('karsilastirma').take(3).toList();
    final acilKutu = _kutu(
        t,
        'Hemen bakılacaklar',
        Icons.priority_high,
        _kirmizi,
        Column(children: [
          for (final z in zam)
            _madde(t, Icons.trending_up, _kirmizi, 'zam', TextSpan(children: [
              TextSpan(text: _s(z['ad']), style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' ${_y(z['yuzde'])} zamlandı '),
              TextSpan(text: '(${_s(z['ilk_ted'])} ${_p(z['ilk'])} → ${_s(z['son_ted'])} ${_p(z['son'])})', style: TextStyle(color: t.sub, fontSize: 11)),
            ])),
          for (final k in kars)
            _madde(t, Icons.compare_arrows, _cyan, 'tedarikci', TextSpan(children: [
              TextSpan(text: '${_s(k['ad'])}: ', style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: '${_s(k['en_ucuz_ted'])} ${_p(k['en_ucuz'])}, ${_s(k['en_pahali_ted'])} ${_p(k['en_pahali'])} '),
              TextSpan(text: '(${_y(k['fark'])} fark)', style: TextStyle(color: t.sub, fontSize: 11)),
            ])),
          for (final h in halAcil)
            _madde(t, Icons.storefront_outlined, _yesil, 'hal', TextSpan(children: [
              TextSpan(text: _s(h['ad']), style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' halin %${_s(h['fark'])} üstünde '),
              TextSpan(text: '(${_s(h['tedarikci'])})', style: TextStyle(color: t.sub, fontSize: 11)),
            ])),
          if (zam.isEmpty && kars.isEmpty && halAcil.isEmpty) Text('Şu an acil bir şey görünmüyor 👍', style: TextStyle(color: t.sub, fontSize: 12.5)),
        ]));
    if (!genis) return [aylikKutu, const SizedBox(height: 12), acilKutu, const SizedBox(height: 12), topKutu, const SizedBox(height: 12), katKutu];
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: aylikKutu), const SizedBox(width: 12), Expanded(flex: 5, child: katKutu)]),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 7, child: topKutu), const SizedBox(width: 12), Expanded(flex: 5, child: acilKutu)]),
    ];
  }

  String _ayAd(String ay) {
    const adlar = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    final p = ay.split('-');
    if (p.length < 2 || p[0].length < 4) return ay;
    final i = (int.tryParse(p[1]) ?? 1) - 1;
    return '${adlar[i.clamp(0, 11)]} ${p[0].substring(2)}';
  }

  // ---------- GİZLİ ZAMLAR ----------
  List<Widget> _zamlar(TemaProvider t) {
    final l = _l('zamlar').where((z) => _eslesir([z['ad'], z['ilk_ted'], z['son_ted']])).toList();
    return [
      _baslik(t, 'Gizli Zam Dedektörü', Icons.trending_up, _kirmizi, rapor: 'zam', araKutusu: true),
      _nasil(t,
          'Neye göre? Seçili dönemdeki İLK alış ile SON alış karşılaştırılır (hangi tedarikçiden, hangi faturadan olduğu yazılı). Tedarikçi değiştiyse ayrıca aynı tedarikçinin kendi zammı gösterilir; böylece "zam mı yaptı, yoksa pahalı tedarikçiye mi geçtik" ayrılır. Yıllık etki = (son − ilk) × dönemdeki alım miktarı, yıla oranlanmış.'),
      if (_l('zamlar').isEmpty)
        _bos(t, '%$esik üstü zam yok 👍\n(En az 2 alışı olan malzemeler kıyaslanır.)', Icons.verified_outlined, _yesil)
      else
        _izgara([
          for (final z in l)
            _kart(t,
                vurgu: _n(z['yuzde']) >= 15 ? _kirmizi : _amber,
                onTap: () => _gecmis(z['id'], _s(z['ad'])),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kartBas(t, _s(z['ad']), _s(z['birim']), MRozet('▲ ${_y(z['yuzde'])}', _n(z['yuzde']) >= 15 ? _kirmizi : _amber),
                      alt: '${_n(z['adet'])} alış${z['ted_degisti'] == true ? ' · tedarikçi değişti' : ''} · dokun: geçmiş'),
                  _satir(t, 'İlk alış', _p(z['ilk']), alt: '${_s(z['ilk_ted'])} · ${_tar(z['ilk_tarih'])} · fatura ${_s(z['ilk_fatura'])}'),
                  _satir(t, 'Son alış', _p(z['son']), kalin: true, alt: '${_s(z['son_ted'])} · ${_tar(z['son_tarih'])} · fatura ${_s(z['son_fatura'])}'),
                  _satir(t, 'Aynı tedarikçide', z['ayni_ted_yuzde'] == null ? 'tek alış (kıyas yok)' : _y(z['ayni_ted_yuzde']),
                      renk: z['ayni_ted_yuzde'] == null ? t.sub : (_n(z['ayni_ted_yuzde']) >= esik ? _kirmizi : _yesil)),
                  _satir(t, 'Dönemin en ucuzu', _p(z['en_dusuk']), alt: _s(z['en_dusuk_ted']), renk: _yesil),
                  _satir(t, 'Yıllık etki', '~${_p0(z['yillik_etki'])}', renk: _kirmizi, kalin: true),
                ])),
        ]),
    ];
  }

  // ---------- MALZEME FİYATLARI ----------
  List<Widget> _malzemeler(TemaProvider t) {
    final l = _l('malzemeler').where((m) => _eslesir([m['ad'], m['kategori'], m['min_ted'], m['max_ted'], m['son_ted']])).toList();
    return [
      _baslik(t, 'Malzeme Fiyat Analizi', Icons.inventory_2_outlined, _mavi, rapor: 'malzeme', araKutusu: true),
      _nasil(t,
          'Neye göre? Ortalama fiyat miktar ağırlıklıdır (toplam tutar ÷ toplam miktar). En düşük / en yüksek / son fiyatın yanında hangi tedarikçiden alındığı yazılı. Oynaklık = (en yüksek − en düşük) ÷ en düşük. Tasarruf payı = hep en düşük fiyattan alsaydın kazancın.'),
      if (_l('malzemeler').isEmpty)
        _bos(t, 'Bu dönemde alış yok.', Icons.inbox_outlined, _gri)
      else
        _izgara([
          for (final m in l)
            _kart(t,
                onTap: () => _gecmis(m['id'], _s(m['ad'])),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kartBas(t, _s(m['ad']), _s(m['birim']),
                      MRozet('oynaklık ${_y(_n(m['oynaklik']).round())}', _n(m['oynaklik']) >= 25 ? _kirmizi : (_n(m['oynaklik']) >= 10 ? _amber : _yesil)),
                      alt:
                          '${_s(m['kategori']).isEmpty ? 'Kategorisiz' : _s(m['kategori'])} · ${_n(m['alis_say'])} alış · ${_n(m['ted_say'])} tedarikçi · ${_fmtM.format(_n(m['miktar']))} ${_s(m['birim'])}'),
                  _satir(t, 'Harcama', _p0(m['harcama']), kalin: true),
                  _satir(t, 'Ortalama', _p(m['ort'])),
                  _satir(t, 'En düşük', _p(m['min']), alt: '${_s(m['min_ted'])} · ${_tar(m['min_tarih'])}', renk: _yesil),
                  _satir(t, 'En yüksek', _p(m['max']), alt: '${_s(m['max_ted'])} · ${_tar(m['max_tarih'])}', renk: _kirmizi),
                  _satir(t, 'Son', _p(m['son']), alt: '${_s(m['son_ted'])} · ${_tar(m['son_tarih'])}'),
                  if (_n(m['tasarruf']) > 0) _satir(t, 'Tasarruf payı', _p0(m['tasarruf']), renk: const Color(0xFFD97706), kalin: true),
                ])),
        ]),
    ];
  }

  // ---------- TEDARİKÇİ KARŞILAŞTIRMA ----------
  List<Widget> _tedarikci(TemaProvider t) {
    final l = _l('karsilastirma').where((k) => _eslesir([k['ad'], ...((k['tedler'] as List?) ?? const []).map((x) => x['ted'])])).toList();
    final katalog = _l('katalog');
    return [
      _baslik(t, 'Tedarikçi Karşılaştırma', Icons.compare_arrows, _cyan, rapor: 'tedarikci', araKutusu: true),
      _nasil(t,
          'Neye göre? Aynı malzemeyi dönem içinde gerçekten farklı tedarikçilerden aldığın faturalar karşılaştırılır (miktar ağırlıklı ortalama). Kayıp = her tedarikçiden aldığın miktarı en ucuz tedarikçinin fiyatından alsaydın ödeyeceğin fark.'),
      if (_l('karsilastirma').isEmpty)
        _bos(t, 'Kıyas için bir malzemeyi bu dönemde en az 2 farklı tedarikçiden almış olman gerekir.', Icons.compare_arrows, _cyan)
      else
        _izgara([
          for (final k in l)
            Builder(builder: (_) {
              final enUcuzda = _s(k['son_ted']) == _s(k['en_ucuz_ted']);
              final tedler = (k['tedler'] as List?) ?? const [];
              return _kart(t,
                  onTap: () => _gecmis(k['id'], _s(k['ad'])),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _kartBas(t, _s(k['ad']), _s(k['birim']), MRozet('${_y(k['fark'])} fark', _n(k['fark']) >= 15 ? _kirmizi : _amber)),
                    const SizedBox(height: 6),
                    for (int i = 0; i < tedler.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Row(children: [
                          SizedBox(width: 104, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: MRozet(_p(tedler[i]['ort']), i == 0 ? _yesil : _gri))),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(_s(tedler[i]['ted']), style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: i == 0 ? FontWeight.w900 : FontWeight.w600)),
                              Text('${_n(tedler[i]['alis_say'])} alış · son ${_p(tedler[i]['son'])} (${_tar(tedler[i]['son_tarih'])})', style: TextStyle(color: t.sub, fontSize: 10.5)),
                            ]),
                          ),
                        ]),
                      ),
                    const SizedBox(height: 4),
                    _satir(t, 'Şu an kimden', enUcuzda ? '✓ ${_s(k['son_ted'])} (en ucuz)' : _s(k['son_ted']),
                        alt: enUcuzda ? null : 'en ucuz: ${_s(k['en_ucuz_ted'])}', renk: enUcuzda ? _yesil : _kirmizi),
                    _satir(t, 'Dönem kaybı', _n(k['kayip']) > 0 ? _p0(k['kayip']) : '—'),
                    _satir(t, 'Yıllık', _n(k['yillik_kayip']) > 0 ? '~${_p0(k['yillik_kayip'])}' : '—', renk: const Color(0xFF0284C7), kalin: true),
                  ]));
            }),
        ]),
      if (katalog.isNotEmpty) ...[
        const SizedBox(height: 20),
        _baslik(t, 'Katalog fırsatları (tedarikçi liste fiyatları)', Icons.menu_book_outlined, _yesil),
        _izgara([
          for (final k in katalog)
            _kart(t,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _kartBas(t, _s(k['ad']), '', MRozet('${_y(_n(k['tasarruf']).round())} ucuz', _yesil), alt: '${_n(k['ted_say'])} tedarikçi'),
                  _satir(t, 'En ucuz', _p(k['en_ucuz']), alt: _s(k['en_ucuz_ted']), renk: _yesil),
                  _satir(t, 'En pahalı', _p(k['en_pahali']), alt: _s(k['en_pahali_ted'])),
                ])),
        ]),
      ],
    ];
  }

  // ---------- TEDARİKÇİ KARNESİ ----------
  List<Widget> _karne(TemaProvider t) => [
        _baslik(t, 'Tedarikçi Karnesi', Icons.workspace_premium_outlined, _amber, rapor: 'karne'),
        _nasil(t, 'Zamlı kalem = o tedarikçinin kendi fiyatını %$esik+ artırdığı malzeme. Pahalı kaldığı = aynı malzemeyi başka tedarikçiden %5+ ucuza aldığın durum.'),
        if (_l('karne').isEmpty)
          _bos(t, 'Bu dönemde alış yok.', Icons.inbox_outlined, _gri)
        else
          _izgara([
            for (final k in _l('karne'))
              _kart(t,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _kartBas(t, _s(k['ted']), '', MRozet('pay ${_y(k['pay'])}', _amber), alt: 'son alış ${_tar(k['son_alis'])}'),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                          value: (_n(k['pay']) / 100).toDouble().clamp(0.0, 1.0), minHeight: 8, backgroundColor: t.card2, valueColor: const AlwaysStoppedAnimation(_amber)),
                    ),
                    _satir(t, 'Harcama', _p0(k['harcama']), kalin: true),
                    _satir(t, 'Fatura · malzeme', '${_n(k['fatura'])} · ${_n(k['malzeme'])}'),
                    _satir(t, 'Zamlı kalem', '${_n(k['zamli'])}${_n(k['ort_zam']) > 0 ? ' (ort. ${_y(k['ort_zam'])})' : ''}', renk: _n(k['zamli']) > 0 ? _kirmizi : _yesil),
                    _satir(t, 'Pahalı kaldığı', _n(k['pahali']) > 0 ? '${_n(k['pahali'])} malzeme' : '—', renk: _n(k['pahali']) > 0 ? _amber : t.sub),
                  ])),
          ]),
      ];

  // ---------- HAL ----------
  List<Widget> _hal(TemaProvider t) {
    final hal = _m('hal');
    final l = _halSat;
    return [
      _baslik(t, 'Hal Kıyası', Icons.storefront_outlined, _yesil, rapor: 'hal'),
      _nasil(t,
          'Neye göre? Son alış fiyatın, İzmir Büyükşehir hal bülteni${hal['bulten'] != null ? ' (${_tar(hal['bulten'])})' : ''} ile karşılaştırılır. Hal toptan fiyattır; tedarikçinin %10–20 üstü normaldir. Fark yalnız birimler aynıysa (kg↔kg) hesaplanır.'),
      if (l.isEmpty)
        _bos(t, hal['bulten'] == null ? 'Hal bülteni henüz gelmedi.' : 'Alışlardaki sebze-meyve malzemelerin halde eşleşince burada çıkar.', Icons.storefront_outlined, _yesil)
      else
        _izgara([
          for (final h in l)
            Builder(builder: (_) {
              final fk = h['fark'];
              final c = fk == null ? _gri : (_n(fk) > 30 ? _kirmizi : (_n(fk) > 15 ? _amber : _yesil));
              final uyumlu = h['uyumlu'] == true;
              return _kart(t,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _kartBas(t, _s(h['ad']), _s(h['birim']),
                        fk == null ? MRozet('birim farklı', _gri) : MRozet('${_n(fk) > 0 ? '▲ +' : (_n(fk) < 0 ? '▼ ' : '')}${_s(fk)}%', c),
                        alt: 'son alış ${_tar(h['son_tarih'])} · ${_s(h['tedarikci'])}'),
                    _satir(t, 'Haldeki karşılığı', _s(h['hal_ad'])),
                    _satir(t, 'Hal asgari–azami', _n(h['hal_min']) > 0 ? '${_p(h['hal_min'])} – ${_p(h['hal_max'])}' : '—'),
                    _satir(t, 'Hal ortalama', '${_p(h['hal_ort'])} / ${_s(h['hal_birim'])}', kalin: true),
                    _satir(t, 'Senin son alış', '${_p(uyumlu ? h['fiyat_hal_birim'] : h['son_fiyat'])} / ${uyumlu ? _s(h['hal_birim']) : _s(h['birim'])}', kalin: true),
                    if (_n(h['yillik']) > 0 && fk != null && _n(fk) > 15) _satir(t, 'Yıllık fazla', '~${_p0(h['yillik'])}', renk: _kirmizi, kalin: true),
                  ]));
            }),
        ]),
    ];
  }

  // ---------- ALIŞ DÖKÜMÜ ----------
  List<Widget> _dokum(TemaProvider t) {
    final l = _l('dokum').where((d) => _eslesir([d['malzeme'], d['tedarikci'], d['fatura_no']])).toList();
    final toplam = _n(v['dokum_toplam']).toInt();
    return [
      _baslik(t, 'Detaylı Alış Dökümü', Icons.receipt_long_outlined, _gri, rapor: 'dokum', araKutusu: true),
      if (toplam > _l('dokum').length) _nasil(t, 'Ekranda son ${_l('dokum').length} satır gösteriliyor; tamamı ($toplam satır) Excel raporunda.'),
      if (_l('dokum').isEmpty)
        _bos(t, 'Bu dönemde alış yok.', Icons.inbox_outlined, _gri)
      else
        Container(
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
          child: Column(children: [
            for (int i = 0; i < l.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: t.line))),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_s(l[i]['malzeme']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 13)),
                      Text('${_tar(l[i]['tarih'])} · ${_s(l[i]['tedarikci'])} · fatura ${_s(l[i]['fatura_no'])}', style: TextStyle(color: t.sub, fontSize: 11)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_p(l[i]['birim_fiyat']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 13)),
                    Text('${_fmtM.format(_n(l[i]['miktar']))} ${_s(l[i]['birim'])} · ${_p(l[i]['tutar'])}', style: TextStyle(color: t.sub, fontSize: 10.5)),
                  ]),
                  const SizedBox(width: 10),
                  SizedBox(width: 78, child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerRight, child: _degisim(l[i]['degisim'], t))),
                ]),
              ),
          ]),
        ),
    ];
  }

  // ---------- AI ----------
  Widget? _aiBolum(TemaProvider t, String anahtar, String baslik, IconData ik, Color c, Widget Function(Map) satir) {
    final l = (ai?[anahtar] as List?) ?? const [];
    if (l.isEmpty) return null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: .35))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(ik, size: 18, color: c), const SizedBox(width: 6), Text(baslik, style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 13.5))]),
        const SizedBox(height: 6),
        for (int i = 0; i < l.length; i++)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: t.line))),
            child: satir(l[i] is Map ? l[i] as Map : const {}),
          ),
      ]),
    );
  }

  List<Widget> _ai(TemaProvider t) {
    final a = ai;
    Widget md(Map x) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_s(x['baslik'])}${x['tutar'] != null && _n(x['tutar']) > 0 ? ' · ~${_p0(x['tutar'])}' : ''}', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 12.5)),
          const SizedBox(height: 2),
          Text(_s(x['detay']), style: TextStyle(color: t.sub2, fontSize: 12, height: 1.4)),
        ]);
    final skor = a == null ? 0 : _n(a['skor']).clamp(0, 100).toInt();
    final sr = skor >= 70 ? _yesil : (skor >= 45 ? _amber : _kirmizi);
    final bolumler = <Widget?>[
      _aiBolum(t, 'kritik', 'Kritik bulgular', Icons.report_outlined, _kirmizi, md),
      _aiBolum(t, 'gecmis_hatalar', 'Geçmiş hatalar', Icons.history, _amber, md),
      _aiBolum(t, 'firsatlar', 'Tasarruf fırsatları', Icons.price_check, _yesil, md),
      _aiBolum(t, 'gelecek', 'Gelecek önerileri', Icons.insights, _mavi, md),
      _aiBolum(t, 'pazarlik', 'Pazarlık argümanları', Icons.handshake_outlined, _cyan, (x) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s(x['tedarikci']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 12.5)),
            const SizedBox(height: 2),
            Text(_s(x['arguman']), style: TextStyle(color: t.sub2, fontSize: 12, height: 1.4)),
          ])),
      _aiBolum(t, 'aksiyonlar', 'Yapılacaklar', Icons.checklist, _aiMor, (x) {
        final o = _s(x['oncelik']);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          MRozet(o.toUpperCase(), o == 'yuksek' ? _kirmizi : (o == 'orta' ? _amber : _gri)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_s(x['is']), style: TextStyle(color: t.ink, fontSize: 12.5)),
              Text(_s(x['sorumlu']), style: TextStyle(color: t.sub, fontSize: 11)),
            ]),
          ),
        ]);
      }),
    ].whereType<Widget>().toList();
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(colors: [_aiMor.withValues(alpha: .14), _pembe.withValues(alpha: .10)]),
          border: Border.all(color: _aiMor.withValues(alpha: .3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('✨ AI Satın Alma Analisti', style: TextStyle(color: t.ink, fontSize: 16.5, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Seçili dönemin verisini inceler: geçmiş hataları, tasarruf fırsatlarını, gelecek önerilerini, pazarlık argümanlarını ve yapılacaklar listesini çıkarır.',
              style: TextStyle(color: t.sub2, fontSize: 12.5)),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            ElevatedButton.icon(
              onPressed: aiYukleniyor ? null : () => _aiAnaliz(false),
              icon: aiYukleniyor
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, size: 18),
              label: Text(aiYukleniyor ? 'Analiz ediliyor… (~10 sn)' : 'Analiz Et'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _aiMor,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _aiMor.withValues(alpha: .6),
                  disabledForegroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900)),
            ),
            OutlinedButton.icon(
              onPressed: aiYukleniyor ? null : () => _aiAnaliz(true),
              icon: const Icon(Icons.refresh, size: 17),
              label: const Text('Yeniden'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: t.sub2,
                  side: BorderSide(color: t.line),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: soruCtl,
                onSubmitted: (_) => _sor(),
                style: TextStyle(color: t.ink, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Soru sor: "Soğanı kimden almalıyım?"',
                  hintStyle: TextStyle(color: t.sub, fontSize: 12.5),
                  filled: true,
                  fillColor: t.card,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide(color: t.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _aiMor)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: soruYukleniyor ? null : _sor,
              style: IconButton.styleFrom(backgroundColor: _aiMor, foregroundColor: Colors.white),
              icon: soruYukleniyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.send),
            ),
          ]),
          if (soruMetin != null)
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('❓ $soruMetin', style: TextStyle(color: t.sub, fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 6),
                SelectableText(soruCevap ?? 'Düşünüyor…', style: TextStyle(color: t.ink, fontSize: 13, height: 1.5)),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 14),
      if (aiHata != null) ...[_bos(t, aiHata!, Icons.error_outline, _kirmizi), const SizedBox(height: 12)],
      if (a == null && aiHata == null) _bos(t, 'Henüz analiz yok. "Analiz Et"e bas — yaklaşık 10 saniye sürer.', Icons.auto_awesome, _aiMor),
      if (a != null) ...[
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line), boxShadow: t.golge),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 78,
              height: 78,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(child: CircularProgressIndicator(value: skor / 100, strokeWidth: 8, backgroundColor: t.card2, valueColor: AlwaysStoppedAnimation(sr))),
                Text('$skor', style: TextStyle(color: t.ink, fontSize: 22, fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('SATIN ALMA DİSİPLİNİ PUANI · ${_s(a['_zaman'])}', style: TextStyle(color: t.sub, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: .4)),
                const SizedBox(height: 4),
                SelectableText(_s(a['ozet']), style: TextStyle(color: t.ink, fontSize: 13.5, height: 1.5)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        _izgara(bolumler),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _indirBtn('AI raporu Excel', Icons.table_view, const Color(0xFF16A34A), () => _rapor('ai', 'xlsx')),
          _indirBtn('AI raporu PDF', Icons.picture_as_pdf_outlined, const Color(0xFFE11D48), () => _rapor('ai', 'pdf')),
        ]),
      ],
    ];
  }

  // ---------- RAPORLAR ----------
  List<Widget> _raporlar(TemaProvider t) => [
        _baslik(t, 'Rapor Merkezi', Icons.download_outlined, _mor),
        _nasil(t,
            'Tüm raporlar üstteki filtreye göre (son $gun gün${ted > 0 ? ', seçili tedarikçi' : ''}, zam eşiği %$esik) hazırlanır. Rapor tarayıcıda açılır: Excel dosyası iner; PDF yazdırma görünümünde açılır → "PDF olarak kaydet".'),
        _izgara([
          for (final r in _l('raporlar'))
            _kart(t,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: _hex(_s(r['renk'])), borderRadius: BorderRadius.circular(12)),
                    child: Icon(_raporIkon[_s(r['ikon'])] ?? Icons.description_outlined, color: Colors.white, size: 21),
                  ),
                  const SizedBox(height: 10),
                  Text(_s(r['ad']), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 3),
                  Text(_s(r['aciklama']), style: TextStyle(color: t.sub, fontSize: 12, height: 1.35)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _indirBtn('Excel', Icons.table_view, const Color(0xFF16A34A), () => _rapor(_s(r['anahtar']), 'xlsx'))),
                    const SizedBox(width: 8),
                    Expanded(child: _indirBtn('PDF', Icons.picture_as_pdf_outlined, const Color(0xFFE11D48), () => _rapor(_s(r['anahtar']), 'pdf'))),
                  ]),
                ])),
        ]),
      ];
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';
import '../responsive.dart';

/// Şubeler Arası Transfer — web /sube-transfer ile aynı akış ve veri (/api/sube-transfer/*).
/// İste / öner → onay (kısmi) → yola çıkar (FEFO, stok düşer) → teslim al (eksik = transfer firesi).
class SubeTransferScreen extends StatefulWidget {
  const SubeTransferScreen({super.key});
  @override
  State<SubeTransferScreen> createState() => _SubeTransferScreenState();
}

// ---------------- ortak sabitler / yardımcılar ----------------
const _trfYesil = Color(0xFF059669);
const _trfKirmizi = Color(0xFFDC2626);
const _trfAmber = Color(0xFFD97706);
const _trfMavi = Color(0xFF2563EB);
const _trfCyan = Color(0xFF0891B2);
const _trfMor = Color(0xFF7C3AED);
const _trfGri = Color(0xFF64748B);
const _trfPembe = Color(0xFFF43F5E);

const _trfTurRenk = <String, Color>{
  'ic': Color(0xFF0891B2),
  'firmalar_arasi': Color(0xFF7C3AED),
  'franchise': Color(0xFFDB2777),
  'vkn_eksik': Color(0xFFDC2626),
};
const _trfTurAd = <String, String>{
  'ic': 'İç transfer',
  'firmalar_arasi': 'Firmalar arası satış',
  'franchise': 'Franchise tedarik',
  'vkn_eksik': 'Vergi no eksik',
};
const _trfDurumRenk = <String, Color>{
  'istendi': Color(0xFFD97706),
  'oneri': Color(0xFFD97706),
  'hazirlaniyor': Color(0xFF2563EB),
  'yolda': Color(0xFF0891B2),
  'teslim': Color(0xFF059669),
  'reddedildi': Color(0xFFDC2626),
  'iptal': Color(0xFF64748B),
};

final _trfFmtM = NumberFormat('#,##0.###', 'tr');
final _trfFmtP = NumberFormat('#,##0.00', 'tr');
num _trfN(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
String _trfS(dynamic v) => v?.toString() ?? '';
String _trfSayi(dynamic v) => _trfFmtM.format(_trfN(v));
String _trfTl(dynamic v) => '${_trfFmtP.format(_trfN(v))} ₺';
bool _trfOk(Map r) => r['ok'] == true || r['ok'] == 1;
String _trfMesaj(Map r, String yedek) {
  final m = _trfS(r['mesaj']).isNotEmpty ? _trfS(r['mesaj']) : _trfS(r['hata']);
  return m.isEmpty ? yedek : m;
}
String _trfNorm(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
num? _trfParse(String s) => num.tryParse(s.trim().replaceAll(',', '.'));
String _trfZaman(dynamic z) {
  final s = _trfS(z).replaceAll('T', ' ');
  return s.length > 16 ? s.substring(0, 16) : s;
}

void _trfBildir(BuildContext context, String mesaj, {bool hata = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(mesaj),
    backgroundColor: hata ? _trfKirmizi : _trfYesil,
    behavior: SnackBarBehavior.floating,
  ));
}

/// Evet/hayır onayı. Tema dialog içinde listen:false okunur (debug çökmesini önler).
Future<bool> _trfOnayIste(BuildContext context, String baslik, String metin, String buton, Color renk) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final t = Provider.of<TemaProvider>(ctx, listen: false);
      return AlertDialog(
        backgroundColor: t.card,
        title: Text(baslik, style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
        content: Text(metin, style: TextStyle(color: t.sub2, fontSize: 13.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: renk), onPressed: () => Navigator.pop(ctx, true), child: Text(buton)),
        ],
      );
    },
  );
  return r == true;
}

/// Sebep / açıklama sor. Vazgeçilirse null döner.
Future<String?> _trfSebepSor(BuildContext context, String baslik, {bool zorunlu = true}) async {
  final ctl = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) {
      final t = Provider.of<TemaProvider>(ctx, listen: false);
      return StatefulBuilder(builder: (ctx, setS) {
        final gecerli = !zorunlu || ctl.text.trim().length >= 3;
        return AlertDialog(
          backgroundColor: t.card,
          title: Text(baslik, style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 16)),
          content: TextField(
            controller: ctl,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setS(() {}),
            style: TextStyle(color: t.ink),
            decoration: InputDecoration(
              hintText: zorunlu ? 'En az 3 karakter' : 'İsteğe bağlı',
              hintStyle: TextStyle(color: t.sub),
              filled: true,
              fillColor: t.card2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _trfKirmizi),
              onPressed: gecerli ? () => Navigator.pop(ctx, ctl.text.trim()) : null,
              child: const Text('Gönder'),
            ),
          ],
        );
      });
    },
  );
  ctl.dispose();
  return r;
}

Widget _trfRozet(String metin, Color renk) => MRozet(metin, renk);

// Yeni transfer formundaki satır
class _TrfSatir {
  int? mid;
  final TextEditingController ctl;
  _TrfSatir({this.mid, String miktar = ''}) : ctl = TextEditingController(text: miktar);
}

class _SubeTransferScreenState extends State<SubeTransferScreen> {
  bool loading = true;
  String? hata;
  bool yetkisiz = false;
  Map<String, dynamic> v = {};
  String sekme = 'is';

  // öneriler (sekme açılınca yüklenir)
  bool oneriYukleniyor = false;
  bool oneriYuklendi = false;
  String? oneriHata;
  List oneriAl = const [], oneriVer = const [];

  // yeni transfer formu
  String mod = 'iste'; // iste | oner
  int? ortakId;
  final List<_TrfSatir> satirlar = [];
  final notCtl = TextEditingController();
  String kaynak = 'elle';
  bool gonderiliyor = false;
  Map stokBen = const {}, stokOrtak = const {};
  Timer? _stokZ;

  // liste filtresi
  String lYon = '';
  String lDurum = '';
  String lAra = '';

  @override
  void initState() {
    super.initState();
    satirlar.add(_TrfSatir());
    _yukle();
  }

  @override
  void dispose() {
    _stokZ?.cancel();
    notCtl.dispose();
    for (final s in satirlar) {
      s.ctl.dispose();
    }
    super.dispose();
  }

  List get _liste => (v['liste'] as List?) ?? const [];
  List get _ortaklar => (v['ortaklar'] as List?) ?? const [];
  List get _malzemeler => (v['malzemeler'] as List?) ?? const [];
  Map? _malzeme(int? id) {
    if (id == null) return null;
    for (final m in _malzemeler) {
      if (_trfN(m['id']).toInt() == id) return m as Map;
    }
    return null;
  }

  List get _uygunOrtaklar => _ortaklar
      .where((o) => mod == 'iste' ? ['iki', 'gelir'].contains(o['yon']) : ['iki', 'gider'].contains(o['yon']))
      .toList();
  Map? get _seciliOrtak {
    for (final o in _uygunOrtaklar) {
      if (_trfN(o['id']).toInt() == ortakId) return o as Map;
    }
    return null;
  }

  List get _isler => _liste
      .where((t) =>
          (t['yon'] == 'giden' && ['istendi', 'hazirlaniyor'].contains(t['durum'])) ||
          (t['yon'] == 'gelen' && ['oneri', 'yolda'].contains(t['durum'])))
      .toList();

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      loading = true;
      hata = null;
    });
    try {
      final res = await Api.trfListe(auth.token!);
      if (!mounted) return;
      setState(() {
        if (_trfOk(res)) {
          v = res;
          yetkisiz = false;
          final u = _uygunOrtaklar;
          if (ortakId == null || !u.any((o) => _trfN(o['id']).toInt() == ortakId)) {
            ortakId = u.isEmpty ? null : _trfN(u.first['id']).toInt();
          }
        } else {
          hata = _trfMesaj(res, 'Transfer verisi alınamadı.');
          yetkisiz = _trfS(res['mesaj']).toLowerCase().contains('yetki');
        }
        loading = false;
      });
      if (sekme == 'oneri' && !oneriYuklendi) _onerileriYukle();
    } catch (e) {
      if (e is ApiYetkiHatasi) {
        if (mounted) context.read<AuthProvider>().cikis();
        return;
      }
      if (mounted) {
        setState(() {
          loading = false;
          hata = 'Bağlantı hatası. Tekrar deneyin.';
        });
      }
    }
  }

  Future<void> _onerileriYukle({bool zorla = false}) async {
    if (oneriYukleniyor || (oneriYuklendi && !zorla)) return;
    final auth = context.read<AuthProvider>();
    setState(() {
      oneriYukleniyor = true;
      oneriHata = null;
    });
    try {
      final res = await Api.trfOneriler(auth.token!);
      if (!mounted) return;
      setState(() {
        oneriYukleniyor = false;
        if (_trfOk(res)) {
          oneriYuklendi = true;
          oneriAl = (res['al'] as List?) ?? const [];
          oneriVer = (res['ver'] as List?) ?? const [];
        } else {
          oneriHata = _trfMesaj(res, 'Öneriler yüklenemedi.');
        }
      });
    } catch (e) {
      if (e is ApiYetkiHatasi) {
        if (mounted) context.read<AuthProvider>().cikis();
        return;
      }
      if (mounted) {
        setState(() {
          oneriYukleniyor = false;
          oneriHata = 'Bağlantı hatası.';
        });
      }
    }
  }

  void _sekmeAc(String s) {
    setState(() => sekme = s);
    if (s == 'oneri') _onerileriYukle();
  }

  // ---------------- yeni transfer ----------------
  void _stokYenile() {
    _stokZ?.cancel();
    _stokZ = Timer(const Duration(milliseconds: 300), () async {
      final mids = satirlar.map((s) => s.mid).whereType<int>().toSet().toList();
      if (mids.isEmpty || !mounted) return;
      final auth = context.read<AuthProvider>();
      try {
        final res = await Api.trfStok(auth.token!, mids);
        if (!mounted || !_trfOk(res)) return;
        setState(() {
          stokBen = (res['ben'] as Map?) ?? const {};
          stokOrtak = (res['ortak'] as Map?) ?? const {};
        });
      } catch (_) {}
    });
  }

  void _formuSifirla() {
    for (final s in satirlar) {
      s.ctl.dispose();
    }
    satirlar
      ..clear()
      ..add(_TrfSatir());
    notCtl.clear();
    kaynak = 'elle';
    stokBen = const {};
    stokOrtak = const {};
  }

  void _modDegis(String m) {
    setState(() {
      mod = m;
      final u = _uygunOrtaklar;
      if (!u.any((o) => _trfN(o['id']).toInt() == ortakId)) ortakId = u.isEmpty ? null : _trfN(u.first['id']).toInt();
    });
    _stokYenile();
  }

  // Öneriler sekmesinden hızlı doldurma
  void _hizli(String m, int sube, int mid, num miktar, String kyn) {
    setState(() {
      mod = m;
      ortakId = sube;
      for (final s in satirlar) {
        s.ctl.dispose();
      }
      satirlar
        ..clear()
        ..add(_TrfSatir(mid: mid, miktar: miktar > 0 ? _trfS(double.parse(miktar.toStringAsFixed(3))).replaceAll(RegExp(r'\.0$'), '') : ''));
      kaynak = kyn;
      sekme = 'yeni';
    });
    _stokYenile();
  }

  Future<void> _malzemeSec(_TrfSatir satir) async {
    final secilen = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MalzemeSecici(malzemeler: _malzemeler),
    );
    if (secilen == null || !mounted) return;
    setState(() => satir.mid = secilen);
    _stokYenile();
  }

  Future<void> _gonder() async {
    if (gonderiliyor) return;
    final o = _seciliOrtak;
    if (o == null) {
      _trfBildir(context, 'Önce şube seçin.', hata: true);
      return;
    }
    if (o['tur'] == 'vkn_eksik') {
      _trfBildir(context, 'Vergi numarası eksik: iki şubenin de Yasal Bilgiler sayfasında vergi no girilmeli.', hata: true);
      return;
    }
    final kalemler = <Map<String, num>>[];
    for (final s in satirlar) {
      final m = _trfParse(s.ctl.text);
      if (s.mid != null && m != null && m > 0) kalemler.add({'malzeme_id': s.mid!, 'miktar': m});
    }
    if (kalemler.isEmpty) {
      _trfBildir(context, 'En az bir ürün ve miktar girin.', hata: true);
      return;
    }
    final auth = context.read<AuthProvider>();
    setState(() => gonderiliyor = true);
    try {
      final oid = _trfN(o['id']).toInt();
      final res = mod == 'iste'
          ? await Api.trfIste(auth.token!, gonderenSubeId: oid, kalemler: kalemler, not: notCtl.text.trim(), kaynak: kaynak)
          : await Api.trfOner(auth.token!, alanSubeId: oid, kalemler: kalemler, not: notCtl.text.trim(), kaynak: kaynak == 'elle' ? 'oneri' : kaynak);
      if (!mounted) return;
      setState(() => gonderiliyor = false);
      if (_trfOk(res)) {
        _trfBildir(context, _trfMesaj(res, 'Transfer oluşturuldu.'));
        setState(() {
          _formuSifirla();
          sekme = 'liste';
        });
        await _yukle();
        final yeniId = _trfN(res['id']).toInt();
        if (yeniId > 0 && mounted) _detayAc(yeniId);
      } else {
        _trfBildir(context, _trfMesaj(res, 'Transfer oluşturulamadı.'), hata: true);
      }
    } catch (e) {
      if (e is ApiYetkiHatasi) {
        if (mounted) context.read<AuthProvider>().cikis();
        return;
      }
      if (mounted) {
        setState(() => gonderiliyor = false);
        _trfBildir(context, 'Bağlantı hatası.', hata: true);
      }
    }
  }

  // ---------------- detay ----------------
  Future<void> _detayAc(int id) async {
    bool? degisti;
    if (genisMi(context)) {
      degisti = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 820),
            child: _TransferDetay(id: id, dialog: true),
          ),
        ),
      );
    } else {
      degisti = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.97,
          minChildSize: 0.5,
          expand: false,
          builder: (_, sc) => _TransferDetay(id: id, dialog: false, scroll: sc),
        ),
      );
    }
    if (degisti == true && mounted) {
      oneriYuklendi = false;
      await _yukle();
    }
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final genis = genisMi(context);
    final subeAd = _trfS(v['sube_ad']);
    return MasaustuSayfa(
      baslik: 'Şubeler Arası Transfer',
      ikon: Icons.swap_horiz,
      geri: true,
      altBaslik: subeAd.isEmpty ? 'Kardeş şubelerle stok paylaşımı' : '$subeAd · kardeş şubelerle stok paylaşımı',
      araclar: [IconButton(onPressed: _yukle, tooltip: 'Yenile', icon: Icon(Icons.refresh, color: t.sub2))],
      govde: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                if (sekme == 'oneri') oneriYuklendi = false;
                await _yukle();
              },
              child: ListView(
                padding: EdgeInsets.all(genis ? 20 : 12),
                children: _govde(t, genis),
              ),
            ),
    );
  }

  List<Widget> _govde(TemaProvider t, bool genis) {
    if (hata != null) {
      return [
        _bosKutu(t, yetkisiz ? Icons.lock_outline : Icons.error_outline, yetkisiz ? _trfAmber : _trfKirmizi, hata!,
            alt: yetkisiz ? 'Şubeler arası transfer yetkisini patron veya müdür verebilir.' : null),
      ];
    }
    if (_ortaklar.isEmpty) {
      return [
        _bosKutu(t, Icons.hub_outlined, _trfMor, 'Bu şube henüz bir şube grubuna bağlı değil.',
            alt: 'Şubeler arası transfer için şubenizin bir işletme grubuna (aynı firma, kardeş firma ya da franchise) bağlanması gerekir. '
                'Grup tanımı sistem yönetiminden yapılır; bağlandıktan sonra kardeş şubelerle ürün isteyip gönderebilirsiniz.'),
      ];
    }
    return [
      _kpiler(t, genis),
      const SizedBox(height: 14),
      _sekmeCubugu(t),
      const SizedBox(height: 14),
      ..._icerik(t, genis),
      const SizedBox(height: 30),
    ];
  }

  Widget _bosKutu(TemaProvider t, IconData ikon, Color renk, String baslik, {String? alt}) => MKart(
        padding: const EdgeInsets.all(22),
        child: Column(children: [
          Icon(ikon, color: renk, size: 40),
          const SizedBox(height: 10),
          Text(baslik, textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 15)),
          if (alt != null) ...[
            const SizedBox(height: 6),
            Text(alt, textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 12.5)),
          ],
        ]),
      );

  // ---------- KPI ----------
  Widget _kpiler(TemaProvider t, bool genis) {
    final simdi = DateTime.now();
    final buAy = _liste.where((x) {
      final p = _trfS(x['tarih']).split(' ').first.split('.');
      return x['durum'] == 'teslim' && p.length == 3 && int.tryParse(p[1]) == simdi.month && int.tryParse(p[2]) == simdi.year;
    }).toList();
    final isler = _isler.length;
    final yolda = _liste.where((x) => x['yon'] == 'gelen' && x['durum'] == 'yolda').length;
    final kartlar = [
      _kpi(t, Icons.pending_actions, 'Sizi bekleyen', '$isler', isler > 0 ? 'onay / yola çıkar / teslim al' : 'bekleyen iş yok', _trfPembe, 'is'),
      _kpi(t, Icons.local_shipping_outlined, 'Yolda (size gelen)', '$yolda', 'gelince teslim alın', _trfCyan, 'is'),
      _kpi(t, Icons.task_alt, 'Bu ay tamamlanan', '${buAy.length}',
          '${buAy.where((x) => x['yon'] == 'gelen').length} gelen · ${buAy.where((x) => x['yon'] == 'giden').length} giden', _trfYesil, 'liste'),
      _kpi(t, Icons.hub_outlined, 'Transfer ortağı', '${_ortaklar.length}', _ortaklar.take(3).map((o) => _trfS(o['ad'])).join(', '), _trfMor, 'yeni'),
    ];
    if (genis) {
      return Row(children: [
        for (var i = 0; i < kartlar.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: kartlar[i])],
      ]);
    }
    return Column(children: [
      Row(children: [Expanded(child: kartlar[0]), const SizedBox(width: 10), Expanded(child: kartlar[1])]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: kartlar[2]), const SizedBox(width: 10), Expanded(child: kartlar[3])]),
    ]);
  }

  Widget _kpi(TemaProvider t, IconData ikon, String etiket, String deger, String alt, Color renk, String hedef) => MKart(
        padding: const EdgeInsets.all(14),
        kenar: renk.withValues(alpha: 0.35),
        onTap: () => _sekmeAc(hedef),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(ikon, color: renk, size: 17),
            const SizedBox(width: 6),
            Expanded(child: Text(etiket, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Text(deger, style: TextStyle(color: renk, fontSize: 24, fontWeight: FontWeight.w900)),
          Text(alt, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
      );

  // ---------- sekmeler ----------
  Widget _sekmeCubugu(TemaProvider t) {
    final n = _isler.length;
    final sekmeler = [
      ('is', Icons.pending_actions, 'Bekleyen İşler', n),
      ('oneri', Icons.auto_awesome, 'Öneriler', 0),
      ('yeni', Icons.add_circle_outline, 'Yeni Transfer', 0),
      ('liste', Icons.list_alt, 'Tüm Transferler', 0),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final s in sekmeler)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: sekme == s.$1 ? _trfMor : t.card,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _sekmeAc(s.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: sekme == s.$1 ? _trfMor : t.line)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.$2, size: 16, color: sekme == s.$1 ? Colors.white : t.sub2),
                    const SizedBox(width: 6),
                    Text(s.$3, style: TextStyle(color: sekme == s.$1 ? Colors.white : t.sub2, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (s.$4 > 0) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(color: _trfPembe, borderRadius: BorderRadius.circular(10)),
                        child: Text('${s.$4}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  List<Widget> _icerik(TemaProvider t, bool genis) {
    switch (sekme) {
      case 'oneri':
        return _oneriler(t, genis);
      case 'yeni':
        return _yeni(t, genis);
      case 'liste':
        return _tumListe(t, genis);
      default:
        return _bekleyen(t, genis);
    }
  }

  // ---------- transfer kartı ----------
  Widget _transferKart(TemaProvider t, Map x, {Widget? aksiyon}) {
    final giden = x['yon'] == 'giden';
    final karsi = giden ? _trfS(x['alan']) : _trfS(x['gonderen']);
    final durumRenk = _trfDurumRenk[x['durum']] ?? _trfGri;
    final kalem = _trfN(x['kalem']).toInt();
    final id = _trfN(x['id']).toInt();
    return MKart(
      padding: const EdgeInsets.all(14),
      kenar: durumRenk.withValues(alpha: 0.45),
      onTap: () => _detayAc(id),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(_trfS(x['no']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 14))),
          Text(_trfS(x['tarih']), style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _trfRozet(giden ? '→ $karsi' : '← $karsi', _trfCyan),
          _trfRozet(_trfTurAd[x['tur']] ?? _trfS(x['tur_ad']), _trfTurRenk[x['tur']] ?? _trfGri),
          _trfRozet(_trfS(x['durum_ad']), durumRenk),
          if (_trfN(x['talep_id']) > 0) _trfRozet('Talepten', _trfMor),
        ]),
        const SizedBox(height: 8),
        Text('📦 ${_trfS(x['ozet'])}${kalem > 4 ? ' +${kalem - 4}' : ''}${_trfS(x['isteyen']).isNotEmpty ? ' · ${_trfS(x['isteyen'])}' : ''}',
            maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 12.5)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ?aksiyon,
          MButon('Detay', _trfGri, () => _detayAc(id), dolu: false, ikon: Icons.visibility_outlined),
        ]),
      ]),
    );
  }

  Widget _izgara(bool genis, List<Widget> ogeler) {
    if (!genis) {
      return Column(children: [
        for (final o in ogeler) Padding(padding: const EdgeInsets.only(bottom: 10), child: o),
      ]);
    }
    final rows = <Widget>[];
    for (var i = 0; i < ogeler.length; i += 2) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: ogeler[i]),
            const SizedBox(width: 12),
            Expanded(child: i + 1 < ogeler.length ? ogeler[i + 1] : const SizedBox()),
          ]),
        ),
      ));
    }
    return Column(children: rows);
  }

  // ---------- Bekleyen İşler ----------
  List<Widget> _bekleyen(TemaProvider t, bool genis) {
    final isler = _isler;
    if (isler.isEmpty) {
      return [
        _bosKutu(t, Icons.task_alt, _trfYesil, 'Sizi bekleyen transfer işi yok.',
            alt: 'Öneriler sekmesinden eksik ürünleri kardeş şubelerden isteyebilirsiniz.'),
      ];
    }
    return [
      MBolumBaslik('Sizi bekleyen işler', renk: _trfPembe, sayi: isler.length),
      _izgara(genis, [
        for (final x in isler) _transferKart(t, x as Map, aksiyon: _isAksiyon(x)),
      ]),
    ];
  }

  Widget? _isAksiyon(Map x) {
    final id = _trfN(x['id']).toInt();
    final yon = x['yon'], d = x['durum'];
    if (yon == 'giden' && d == 'istendi') return MButon('İncele ve onayla', _trfYesil, () => _detayAc(id), ikon: Icons.fact_check_outlined);
    if (yon == 'giden' && d == 'hazirlaniyor') return MButon('Yola çıkar', _trfMavi, () => _detayAc(id), ikon: Icons.local_shipping_outlined);
    if (yon == 'gelen' && d == 'yolda') return MButon('Teslim al', _trfYesil, () => _detayAc(id), ikon: Icons.inventory_outlined);
    if (yon == 'gelen' && d == 'oneri') return MButon('Öneriyi incele', _trfYesil, () => _detayAc(id), ikon: Icons.thumb_up_outlined);
    return null;
  }

  // ---------- Öneriler ----------
  List<Widget> _oneriler(TemaProvider t, bool genis) {
    if (oneriYukleniyor && !oneriYuklendi) {
      return [const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))];
    }
    if (oneriHata != null) {
      return [
        _bosKutu(t, Icons.error_outline, _trfKirmizi, oneriHata!),
        const SizedBox(height: 10),
        Center(child: MButon('Tekrar dene', _trfMor, () => _onerileriYukle(zorla: true), ikon: Icons.refresh)),
      ];
    }
    final al = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MBolumBaslik('Bende eksik — kardeş şubede var', renk: _trfMor, sayi: oneriAl.length),
      if (oneriAl.isEmpty)
        _bosKutu(t, Icons.check_circle_outline, _trfYesil, 'Eksik ürününüz kardeş şubelerde yok ya da eksik ürün yok.')
      else
        for (final o in oneriAl) Padding(padding: const EdgeInsets.only(bottom: 10), child: _alKart(t, o as Map)),
    ]);
    final ver = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MBolumBaslik('SKT riski — başka şube kullansın', renk: _trfAmber, sayi: oneriVer.length),
      if (oneriVer.isEmpty)
        _bosKutu(t, Icons.check_circle_outline, _trfYesil, 'SKT riski olan ürün yok.')
      else
        for (final o in oneriVer) Padding(padding: const EdgeInsets.only(bottom: 10), child: _verKart(t, o as Map)),
    ]);
    if (genis) {
      return [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: al), const SizedBox(width: 16), Expanded(child: ver)]),
      ];
    }
    return [al, const SizedBox(height: 12), ver];
  }

  Widget _alKart(TemaProvider t, Map o) {
    final birim = _trfS(o['birim']);
    final kaynaklar = (o['kaynaklar'] as List?) ?? const [];
    final ihtiyac = _trfN(o['ihtiyac']);
    return MKart(
      padding: const EdgeInsets.all(14),
      kenar: _trfMor.withValues(alpha: 0.4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_trfS(o['ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _trfRozet('Sizde ${_trfSayi(o['mevcut'])} $birim', _trfKirmizi),
          _trfRozet('Kritik ${_trfSayi(o['kritik'])}', _trfGri),
          if (ihtiyac > 0) _trfRozet('İhtiyaç ${_trfSayi(ihtiyac)} $birim', _trfAmber),
        ]),
        const SizedBox(height: 8),
        for (final k in kaynaklar)
          Container(
            margin: const EdgeInsets.only(top: 6),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.storefront_outlined, size: 18, color: _trfMor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_trfS(k['sube_ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 13)),
                  Text('${_trfSayi(k['verilebilir'])} $birim verebilir', style: TextStyle(color: t.sub2, fontSize: 12)),
                  if (_trfN(k['skt_risk']) > 0)
                    Text('⚠️ ${_trfSayi(k['skt_risk'])} SKT riski (${_trfS(k['en_yakin_skt'])})', style: const TextStyle(color: _trfAmber, fontSize: 11.5)),
                ]),
              ),
              MButon('İste', _trfMor, () {
                final ver = _trfN(k['verilebilir']);
                final mik = ihtiyac > 0 ? (ihtiyac < ver ? ihtiyac : ver) : ver;
                _hizli('iste', _trfN(k['sube_id']).toInt(), _trfN(o['malzeme_id']).toInt(), mik, 'oneri');
              }, ikon: Icons.south_west),
            ]),
          ),
      ]),
    );
  }

  Widget _verKart(TemaProvider t, Map o) {
    final birim = _trfS(o['birim']);
    final alicilar = (o['alicilar'] as List?) ?? const [];
    return MKart(
      padding: const EdgeInsets.all(14),
      kenar: _trfAmber.withValues(alpha: 0.45),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_trfS(o['ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 14)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _trfRozet('${_trfSayi(o['skt_risk'])} $birim bozulabilir', _trfAmber),
          if (_trfS(o['en_yakin_skt']).isNotEmpty) _trfRozet('SKT ${_trfS(o['en_yakin_skt'])}', _trfKirmizi),
          if (_trfN(o['maliyet']) > 0) _trfRozet('≈ ${_trfTl(o['maliyet'])}', _trfGri),
        ]),
        const SizedBox(height: 8),
        if (alicilar.isEmpty)
          Text('Bu ürünü kullanan kardeş şube yok — menüde öne çıkarmayı düşünün.', style: TextStyle(color: t.sub, fontSize: 12))
        else
          for (final a in alicilar)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.storefront_outlined, size: 18, color: _trfAmber),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_trfS(a['sube_ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 13)),
                    Text('Günde ${_trfSayi(a['gunluk'])} $birim kullanıyor', style: TextStyle(color: t.sub2, fontSize: 12)),
                  ]),
                ),
                MButon('Gönder', _trfAmber,
                    () => _hizli('oner', _trfN(a['sube_id']).toInt(), _trfN(o['malzeme_id']).toInt(), _trfN(o['skt_risk']), 'skt'),
                    ikon: Icons.north_east),
              ]),
            ),
      ]),
    );
  }

  // ---------- Yeni Transfer ----------
  List<Widget> _yeni(TemaProvider t, bool genis) {
    final uygun = _uygunOrtaklar;
    final o = _seciliOrtak;
    final form = MKart(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Ne yapmak istiyorsunuz?', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'iste', icon: Icon(Icons.south_west, size: 16), label: Text('İSTE')),
            ButtonSegment(value: 'oner', icon: Icon(Icons.north_east, size: 16), label: Text('GÖNDER')),
          ],
          selected: {mod},
          onSelectionChanged: (s) => _modDegis(s.first),
        ),
        const SizedBox(height: 4),
        Text(mod == 'iste' ? 'Kardeş şubeden ürün isteyin; onlar onaylayıp yola çıkarır.' : 'Kendi stoğunuzdan kardeş şubeye ürün önerin; onlar kabul ederse yola çıkarırsınız.',
            style: TextStyle(color: t.sub, fontSize: 11.5)),
        const SizedBox(height: 14),
        Text(mod == 'iste' ? 'Hangi şubeden?' : 'Hangi şubeye?', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: o == null ? null : _trfN(o['id']).toInt(),
              isExpanded: true,
              dropdownColor: t.card,
              hint: Text('Uygun şube yok', style: TextStyle(color: t.sub)),
              style: TextStyle(color: t.ink, fontWeight: FontWeight.w600, fontSize: 13.5),
              items: [
                for (final x in uygun)
                  DropdownMenuItem(
                    value: _trfN(x['id']).toInt(),
                    child: Text('${_trfS(x['ad'])} · ${_trfTurAd[x['tur']] ?? _trfS(x['tur'])}', overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (x) {
                setState(() => ortakId = x);
                _stokYenile();
              },
            ),
          ),
        ),
        if (o != null) ...[const SizedBox(height: 10), _turNot(t, o)],
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Text('Ürünler', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w800))),
          MButon('Ürün ekle', _trfMor, () {
            setState(() => satirlar.add(_TrfSatir()));
          }, dolu: false, ikon: Icons.add),
        ]),
        const SizedBox(height: 8),
        for (final s in satirlar) _satirWidget(t, s),
        const SizedBox(height: 12),
        TextField(
          controller: notCtl,
          minLines: 2,
          maxLines: 4,
          style: TextStyle(color: t.ink, fontSize: 13.5),
          decoration: InputDecoration(
            hintText: 'Not (isteğe bağlı)',
            hintStyle: TextStyle(color: t.sub),
            filled: true,
            fillColor: t.card2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          ),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerRight,
          child: gonderiliyor
              ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5)))
              : MButon(mod == 'iste' ? 'Transfer iste' : 'Gönderme öner', o?['tur'] == 'vkn_eksik' ? _trfGri : _trfYesil, _gonder, ikon: Icons.send),
        ),
      ]),
    );
    if (!genis) return [form];
    // Geniş: sol form, sağ ortak listesi + akış özeti
    final yan = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      MKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Transfer ortaklarınız', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          for (final x in _ortaklar)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.storefront_outlined, size: 17, color: _trfTurRenk[x['tur']] ?? _trfGri),
                const SizedBox(width: 8),
                Expanded(child: Text(_trfS(x['ad']), style: TextStyle(color: t.sub2, fontSize: 13))),
                _trfRozet(_trfTurAd[x['tur']] ?? _trfS(x['tur']), _trfTurRenk[x['tur']] ?? _trfGri),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      MKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Akış', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(height: 8),
          for (final s in const [
            '1. İstek / öneri gönderilir',
            '2. Karşı şube onaylar (kısmi onay olabilir)',
            '3. Gönderen yola çıkarır — stok SKT\'si en yakın lottan düşer',
            '4. Alan teslim alır — eksik gelen kısım transfer firesi olur',
          ])
            Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(s, style: TextStyle(color: t.sub2, fontSize: 12.5))),
        ]),
      ),
    ]);
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 3, child: form), const SizedBox(width: 16), Expanded(flex: 2, child: yan)]),
    ];
  }

  Widget _turNot(TemaProvider t, Map o) {
    final tur = _trfS(o['tur']);
    final carpan = _trfN(o['carpan']) > 0 ? _trfSayi(o['carpan']) : '1';
    final metin = <String, (String, String)>{
      'ic': ('İç transfer', 'Aynı vergi no. Maliyet bedeliyle sevk irsaliyesi; finansa kayıt düşmez, yalnız stok yer değiştirir.'),
      'firmalar_arasi': ('Firmalar arası satış', 'Farklı vergi no. Teslim alınınca alan firmaya otomatik alış faturası, gönderen firmaya cari alacak yazılır.'),
      'franchise': ('Franchise tedarik', 'Fatura + cari; fiyat, merkezin belirlediği çarpanla (maliyet × $carpan).'),
      'vkn_eksik': ('Vergi numarası eksik', 'İki şubenin de Yasal Bilgiler sayfasında vergi no girilmeden transfer yapılamaz (iç mi, firmalar arası mı belirlenemiyor).'),
    }[tur];
    if (metin == null) return const SizedBox();
    final renk = tur == 'ic' ? _trfCyan : (tur == 'vkn_eksik' ? _trfKirmizi : _trfAmber);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: renk.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: renk.withValues(alpha: 0.4))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(tur == 'vkn_eksik' ? Icons.block : (tur == 'ic' ? Icons.info_outline : Icons.receipt_long_outlined), size: 18, color: renk),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: '${metin.$1} — ', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 12.5)),
            TextSpan(text: metin.$2, style: TextStyle(color: t.sub2, fontSize: 12.5)),
          ])),
        ),
      ]),
    );
  }

  Widget _satirWidget(TemaProvider t, _TrfSatir s) {
    final m = _malzeme(s.mid);
    final birim = m == null ? '' : _trfS(m['birim']);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _malzemeSec(s),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
                child: Row(children: [
                  Icon(Icons.inventory_2_outlined, size: 16, color: t.sub),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(m == null ? 'Malzeme seçin…' : '${_trfS(m['ad'])}${birim.isNotEmpty ? ' ($birim)' : ''}',
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: m == null ? t.sub : t.ink, fontSize: 13.5, fontWeight: FontWeight.w600)),
                  ),
                  Icon(Icons.arrow_drop_down, color: t.sub),
                ]),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 96,
            child: TextField(
              controller: s.ctl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: TextStyle(color: t.ink, fontSize: 13.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Miktar',
                hintStyle: TextStyle(color: t.sub),
                suffixText: birim,
                suffixStyle: TextStyle(color: t.sub, fontSize: 11),
                filled: true,
                fillColor: t.card,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Satırı kaldır',
            onPressed: () => setState(() {
              satirlar.remove(s);
              s.ctl.dispose();
              if (satirlar.isEmpty) satirlar.add(_TrfSatir());
            }),
            icon: const Icon(Icons.close, color: _trfKirmizi, size: 20),
          ),
        ]),
        if (s.mid != null) ...[const SizedBox(height: 6), _stokIpucu(t, s.mid!, birim)],
      ]),
    );
  }

  Widget _stokIpucu(TemaProvider t, int mid, String birim) {
    final ben = stokBen['$mid'] as Map?;
    if (mod == 'iste') {
      Map? k;
      for (final x in ((stokOrtak['$mid'] as List?) ?? const [])) {
        if (_trfN(x['sube_id']).toInt() == ortakId) k = x as Map;
      }
      return Text.rich(TextSpan(children: [
        if (ben != null) TextSpan(text: 'Sizde ${_trfSayi(ben['mevcut'])} $birim · ', style: TextStyle(color: t.sub2)),
        if (k != null) ...[
          TextSpan(text: 'Karşı şube ${_trfSayi(k['verilebilir'])} $birim verebilir', style: const TextStyle(color: _trfYesil, fontWeight: FontWeight.w800)),
          if (_trfN(k['skt_risk']) > 0) TextSpan(text: ' · ⚠️ SKT ${_trfS(k['en_yakin_skt'])}', style: const TextStyle(color: _trfAmber)),
        ] else if (stokBen.isNotEmpty || stokOrtak.isNotEmpty)
          const TextSpan(text: 'Karşı şubede fazla görünmüyor (yine de isteyebilirsiniz; onlar kendi stoklarına göre karar verir)', style: TextStyle(color: _trfAmber)),
      ]), style: const TextStyle(fontSize: 11.5));
    }
    if (ben == null) return const SizedBox();
    return Text.rich(TextSpan(children: [
      TextSpan(text: 'Sizde ${_trfSayi(ben['mevcut'])} $birim', style: TextStyle(color: t.sub2)),
      if (_trfN(ben['skt_risk']) > 0) TextSpan(text: ' · ${_trfSayi(ben['skt_risk'])} SKT riski', style: const TextStyle(color: _trfAmber, fontWeight: FontWeight.w800)),
      TextSpan(text: ' · fazla ${_trfSayi(ben['fazla'])}', style: TextStyle(color: t.sub2)),
    ]), style: const TextStyle(fontSize: 11.5));
  }

  // ---------- Tüm Transferler ----------
  List<Widget> _tumListe(TemaProvider t, bool genis) {
    final q = _trfNorm(lAra);
    final l = _liste.where((x) {
      if (lYon.isNotEmpty && x['yon'] != lYon) return false;
      final d = x['durum'];
      if (lDurum == 'acik' && !['oneri', 'istendi', 'hazirlaniyor', 'yolda'].contains(d)) return false;
      if (lDurum == 'teslim' && d != 'teslim') return false;
      if (lDurum == 'kapali' && !['reddedildi', 'iptal'].contains(d)) return false;
      if (q.isNotEmpty && !_trfNorm([x['no'], x['gonderen'], x['alan'], x['ozet']].map(_trfS).join(' ')).contains(q)) return false;
      return true;
    }).toList();

    Widget chip(String deger, String etiket, String secili, ValueChanged<String> deg) => ChoiceChip(
          label: Text(etiket),
          selected: secili == deger,
          onSelected: (_) => deg(deger),
          selectedColor: _trfMor.withValues(alpha: 0.2),
          labelStyle: TextStyle(color: secili == deger ? _trfMor : t.sub2, fontWeight: FontWeight.w700, fontSize: 12.5),
          backgroundColor: t.card,
          side: BorderSide(color: secili == deger ? _trfMor : t.line),
        );

    final filtre = Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      chip('', 'Tümü', lYon, (x) => setState(() => lYon = x)),
      chip('gelen', '⬅ Gelen', lYon, (x) => setState(() => lYon = x)),
      chip('giden', 'Giden ➡', lYon, (x) => setState(() => lYon = x)),
      const SizedBox(width: 8),
      chip('', 'Her durum', lDurum, (x) => setState(() => lDurum = x)),
      chip('acik', 'Açık', lDurum, (x) => setState(() => lDurum = x)),
      chip('teslim', 'Teslim', lDurum, (x) => setState(() => lDurum = x)),
      chip('kapali', 'Red / iptal', lDurum, (x) => setState(() => lDurum = x)),
    ]);
    final ara = TextField(
      onChanged: (x) => setState(() => lAra = x),
      style: TextStyle(color: t.ink, fontSize: 13.5),
      decoration: InputDecoration(
        isDense: true,
        prefixIcon: Icon(Icons.search, color: t.sub),
        hintText: 'Ara: no, şube, ürün…',
        hintStyle: TextStyle(color: t.sub),
        filled: true,
        fillColor: t.card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
      ),
    );

    final ust = genis
        ? Row(children: [Expanded(child: filtre), const SizedBox(width: 12), SizedBox(width: 300, child: ara)])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [ara, const SizedBox(height: 10), filtre]);

    if (l.isEmpty) return [ust, const SizedBox(height: 14), _bosKutu(t, Icons.inbox_outlined, _trfGri, 'Kayıt yok.')];

    if (genis) {
      return [
        ust,
        const SizedBox(height: 14),
        MTablo(
          sutunlar: const [
            MSutun('No', flex: 12),
            MSutun('Tarih', flex: 11),
            MSutun('Yön', flex: 7),
            MSutun('Karşı şube', flex: 13),
            MSutun('Ürünler', flex: 22),
            MSutun('Tür', flex: 13),
            MSutun('Durum', flex: 16),
          ],
          satirlar: [
            for (final x in l)
              [
                InkWell(onTap: () => _detayAc(_trfN(x['id']).toInt()), child: Text(_trfS(x['no']), style: const TextStyle(color: _trfMor, fontWeight: FontWeight.w800, fontSize: 12.5))),
                Text(_trfS(x['tarih']), style: TextStyle(color: t.sub2, fontSize: 12)),
                Text(x['yon'] == 'gelen' ? '⬅ Gelen' : 'Giden ➡', style: TextStyle(color: t.sub2, fontSize: 12)),
                Text(x['yon'] == 'gelen' ? _trfS(x['gonderen']) : _trfS(x['alan']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 12.5)),
                Text(_trfS(x['ozet']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 12)),
                _trfRozet(_trfTurAd[x['tur']] ?? _trfS(x['tur_ad']), _trfTurRenk[x['tur']] ?? _trfGri),
                InkWell(onTap: () => _detayAc(_trfN(x['id']).toInt()), child: _trfRozet(_trfS(x['durum_ad']), _trfDurumRenk[x['durum']] ?? _trfGri)),
              ],
          ],
        ),
      ];
    }
    return [
      ust,
      const SizedBox(height: 14),
      for (final x in l) Padding(padding: const EdgeInsets.only(bottom: 10), child: _transferKart(t, x as Map)),
    ];
  }
}

// ================= Malzeme seçici (aramalı) =================
class _MalzemeSecici extends StatefulWidget {
  final List malzemeler;
  const _MalzemeSecici({required this.malzemeler});
  @override
  State<_MalzemeSecici> createState() => _MalzemeSeciciState();
}

class _MalzemeSeciciState extends State<_MalzemeSecici> {
  String q = '';
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final n = _trfNorm(q);
    final l = n.isEmpty ? widget.malzemeler : widget.malzemeler.where((m) => _trfNorm(_trfS(m['ad'])).contains(n)).toList();
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(color: t.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(4))),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: TextField(
              autofocus: true,
              onChanged: (x) => setState(() => q = x),
              style: TextStyle(color: t.ink),
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, color: t.sub),
                hintText: 'Malzeme ara…',
                hintStyle: TextStyle(color: t.sub),
                filled: true,
                fillColor: t.card,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
              ),
            ),
          ),
          Expanded(
            child: l.isEmpty
                ? Center(child: Text('Eşleşen malzeme yok.', style: TextStyle(color: t.sub)))
                : ListView.builder(
                    controller: sc,
                    itemCount: l.length,
                    itemBuilder: (_, i) {
                      final m = l[i];
                      return ListTile(
                        dense: true,
                        title: Text(_trfS(m['ad']), style: TextStyle(color: t.ink, fontSize: 14)),
                        trailing: Text(_trfS(m['birim']), style: TextStyle(color: t.sub, fontSize: 12)),
                        onTap: () => Navigator.pop(context, _trfN(m['id']).toInt()),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}

// ================= Transfer detayı (telefon: alt sayfa, masaüstü: dialog) =================
class _TransferDetay extends StatefulWidget {
  final int id;
  final bool dialog;
  final ScrollController? scroll;
  const _TransferDetay({required this.id, required this.dialog, this.scroll});
  @override
  State<_TransferDetay> createState() => _TransferDetayState();
}

class _TransferDetayState extends State<_TransferDetay> {
  bool loading = true;
  bool islemde = false;
  String? hata;
  Map tr = const {};
  final Map<int, TextEditingController> miktarCtl = {};
  final Map<int, TextEditingController> farkCtl = {};
  final notCtl = TextEditingController();
  num kdv = 10;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    for (final c in [...miktarCtl.values, ...farkCtl.values]) {
      c.dispose();
    }
    notCtl.dispose();
    super.dispose();
  }

  List get _kalemler => (tr['kalemler'] as List?) ?? const [];
  bool get _yetkili => tr['yetkili'] == true || tr['yetkili'] == 1;
  String get _durum => _trfS(tr['durum']);
  String get _ben => _trfS(tr['ben']);
  bool get _onayModu => _ben == 'gonderen' && _durum == 'istendi' && _yetkili;
  bool get _teslimModu => _ben == 'alan' && _durum == 'yolda' && _yetkili;

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      loading = true;
      hata = null;
    });
    try {
      final res = await Api.trfDetay(auth.token!, widget.id);
      if (!mounted) return;
      setState(() {
        loading = false;
        if (_trfOk(res) && res['transfer'] is Map) {
          tr = res['transfer'] as Map;
          final k = _trfN(tr['kdv_orani']);
          kdv = const [1, 10, 20, 0].contains(k) ? k : 10;
          for (final c in [...miktarCtl.values, ...farkCtl.values]) {
            c.dispose();
          }
          miktarCtl.clear();
          farkCtl.clear();
          for (final x in _kalemler) {
            final id = _trfN(x['id']).toInt();
            if (_onayModu) miktarCtl[id] = TextEditingController(text: _trfSayiDuz(x['istenen']));
            if (_teslimModu) {
              miktarCtl[id] = TextEditingController(text: _trfSayiDuz(x['gonderilen']));
              farkCtl[id] = TextEditingController();
            }
          }
        } else {
          hata = _trfMesaj(res, 'Transfer bulunamadı.');
        }
      });
    } catch (e) {
      if (e is ApiYetkiHatasi) {
        if (mounted) context.read<AuthProvider>().cikis();
        return;
      }
      if (mounted) {
        setState(() {
          loading = false;
          hata = 'Bağlantı hatası.';
        });
      }
    }
  }

  String _trfSayiDuz(dynamic v) {
    final n = _trfN(v);
    return n == n.roundToDouble() ? n.toInt().toString() : double.parse(n.toStringAsFixed(3)).toString();
  }

  Map<int, num> _miktarlar() {
    final m = <int, num>{};
    miktarCtl.forEach((id, c) {
      final x = _trfParse(c.text);
      m[id] = x == null || x < 0 ? 0 : x;
    });
    return m;
  }

  Future<void> _sonuc(Future<Map<String, dynamic>> Function(String token) islem) async {
    final auth = context.read<AuthProvider>();
    setState(() => islemde = true);
    try {
      final res = await islem(auth.token!);
      if (!mounted) return;
      setState(() => islemde = false);
      if (_trfOk(res)) {
        _trfBildir(context, _trfMesaj(res, 'Tamam.'));
        Navigator.of(context).pop(true);
      } else {
        _trfBildir(context, _trfMesaj(res, 'İşlem yapılamadı.'), hata: true);
      }
    } catch (e) {
      if (e is ApiYetkiHatasi) {
        if (mounted) context.read<AuthProvider>().cikis();
        return;
      }
      if (mounted) {
        setState(() => islemde = false);
        _trfBildir(context, 'Bağlantı hatası.', hata: true);
      }
    }
  }

  Future<void> _onayla() async {
    final mik = _miktarlar();
    if (!mik.values.any((x) => x > 0)) {
      _trfBildir(context, 'Hiç miktar onaylamadınız; vermeyecekseniz reddedin.', hata: true);
      return;
    }
    final ic = _trfS(tr['tur']) == 'ic';
    await _sonuc((tk) => Api.trfKarar(tk, widget.id, 'onay', miktar: mik, kdvOrani: ic ? null : kdv, not: notCtl.text.trim()));
  }

  Future<void> _reddet() async {
    final s = await _trfSebepSor(context, 'Neden reddediyorsunuz? (isteyen şube görecek)');
    if (s == null || !mounted) return;
    await _sonuc((tk) => Api.trfKarar(tk, widget.id, 'red', sebep: s));
  }

  Future<void> _sevk() async {
    final ok = await _trfOnayIste(context, 'Yola çıkar',
        'Ürünler yola çıksın mı? Onaylanan miktarlar şimdi stoğunuzdan düşecek (SKT\'si en yakın lot önce gider).', 'Yola çıkar', _trfMavi);
    if (!ok || !mounted) return;
    await _sonuc((tk) => Api.trfSevk(tk, widget.id));
  }

  Future<void> _teslim() async {
    final ok = await _trfOnayIste(context, 'Teslim al',
        'Girdiğiniz miktarlar stoğunuza girecek. Eksik gelen kısım "transfer firesi" olarak kaydedilir ve gönderen şubeye bildirilir.', 'Teslim al', _trfYesil);
    if (!ok || !mounted) return;
    final mik = _miktarlar();
    final notlar = {for (final e in farkCtl.entries) e.key: e.value.text};
    await _sonuc((tk) => Api.trfTeslim(tk, widget.id, miktar: mik, farkNot: notlar));
  }

  Future<void> _kabul(bool kabul) async {
    if (kabul) {
      await _sonuc((tk) => Api.trfKabul(tk, widget.id, 'kabul'));
      return;
    }
    final s = await _trfSebepSor(context, 'Neden reddediyorsunuz?');
    if (s == null || !mounted) return;
    await _sonuc((tk) => Api.trfKabul(tk, widget.id, 'red', sebep: s));
  }

  Future<void> _iptal() async {
    final s = await _trfSebepSor(context, 'İptal sebebi?', zorunlu: false);
    if (s == null || !mounted) return;
    await _sonuc((tk) => Api.trfIptal(tk, widget.id, s));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final radius = widget.dialog ? BorderRadius.circular(18) : const BorderRadius.vertical(top: Radius.circular(20));
    Widget icerik;
    if (loading) {
      icerik = const Padding(padding: EdgeInsets.all(50), child: Center(child: CircularProgressIndicator()));
    } else if (hata != null) {
      icerik = Padding(
        padding: const EdgeInsets.all(30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _trfKirmizi, size: 36),
          const SizedBox(height: 8),
          Text(hata!, textAlign: TextAlign.center, style: TextStyle(color: t.ink)),
        ]),
      );
    } else {
      icerik = Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: _govde(t));
    }
    return Material(
      color: t.bg,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: widget.dialog ? MainAxisSize.min : MainAxisSize.max, children: [
        if (!widget.dialog) ...[
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(4))),
        ],
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 6, 0),
          child: Row(children: [
            Expanded(
              child: Text(loading ? 'Yükleniyor…' : _trfS(tr['transfer_no']).isEmpty ? 'Transfer' : _trfS(tr['transfer_no']),
                  style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            IconButton(onPressed: () => Navigator.of(context).pop(), icon: Icon(Icons.close, color: t.sub2), tooltip: 'Kapat'),
          ]),
        ),
        Flexible(
          child: SingleChildScrollView(
            controller: widget.scroll,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: icerik,
          ),
        ),
      ]),
    );
  }

  List<Widget> _govde(TemaProvider t) {
    final tur = _trfS(tr['tur']);
    final ic = tur == 'ic';
    final kapali = ['reddedildi', 'iptal'].contains(_durum);
    final sira = ['istendi', 'hazirlaniyor', 'yolda', 'teslim'];
    final idx = _durum == 'oneri' ? 0 : sira.indexOf(_durum);
    final adimlar = ['İstek / öneri', 'Onay', 'Yolda', 'Teslim'];
    final genis = widget.dialog;

    Widget kim(String etiket, dynamic ad, dynamic z) {
      if (_trfS(ad).isEmpty) return const SizedBox.shrink();
      return Text('$etiket: ${_trfS(ad)}${_trfS(z).isNotEmpty ? ' · ${_trfZaman(z)}' : ''}', style: TextStyle(color: t.sub, fontSize: 11.5));
    }

    final oneriMi = _durum == 'oneri' || _trfS(tr['kaynak']) == 'skt';
    final taraflar = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: MKart(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Gönderen', style: TextStyle(color: t.sub, fontSize: 11.5)),
            Text(_trfS(tr['gonderen_ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 14)),
            kim('Onay', tr['onaylayan_ad'], tr['onay_at']),
            kim('Sevk', tr['sevk_eden_ad'], tr['sevk_at']),
          ]),
        ),
      ),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 18), child: Icon(Icons.arrow_forward, color: _trfCyan, size: 26)),
      Expanded(
        child: MKart(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Alan', style: TextStyle(color: t.sub, fontSize: 11.5)),
            Text(_trfS(tr['alan_ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 14)),
            kim(oneriMi ? 'Öneren' : 'İsteyen', tr['isteyen_ad'], tr['created_at']),
            kim('Teslim', tr['teslim_alan_ad'], tr['teslim_at']),
          ]),
        ),
      ),
    ]);

    Widget not(IconData ikon, String metin, {Color renk = _trfGri, String? baslik}) => Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: renk.withValues(alpha: 0.35))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ikon, size: 17, color: renk),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(TextSpan(children: [
                if (baslik != null) TextSpan(text: '$baslik: ', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800)),
                TextSpan(text: metin, style: TextStyle(color: t.sub2)),
              ]), style: const TextStyle(fontSize: 12.5)),
            ),
          ]),
        );

    final butonlar = <Widget>[];
    if (_onayModu) {
      butonlar.add(MButon('Onayla', _trfYesil, _onayla, ikon: Icons.check));
      butonlar.add(MButon('Reddet', _trfKirmizi, _reddet, ikon: Icons.close));
    }
    if (_ben == 'gonderen' && _durum == 'hazirlaniyor' && _yetkili) {
      butonlar.add(MButon('Yola çıkar (stoktan düş)', _trfMavi, _sevk, ikon: Icons.local_shipping_outlined));
    }
    if (_teslimModu) butonlar.add(MButon('Teslim al (stoğa gir)', _trfYesil, _teslim, ikon: Icons.inventory_outlined));
    if (_ben == 'alan' && _durum == 'oneri' && _yetkili) {
      butonlar.add(MButon('Kabul et', _trfYesil, () => _kabul(true), ikon: Icons.thumb_up_outlined));
      butonlar.add(MButon('Reddet', _trfKirmizi, () => _kabul(false), ikon: Icons.thumb_down_outlined));
    }
    if (['oneri', 'istendi', 'hazirlaniyor'].contains(_durum) && _yetkili) {
      butonlar.add(MButon('İptal et', _trfKirmizi, _iptal, dolu: false, ikon: Icons.cancel_outlined));
    }

    return [
      Wrap(spacing: 6, runSpacing: 6, children: [
        _trfRozet(_trfS(tr['tur_ad']).isNotEmpty ? _trfS(tr['tur_ad']) : (_trfTurAd[tur] ?? tur), _trfTurRenk[tur] ?? _trfGri),
        _trfRozet(_trfS(tr['durum_ad']), _trfDurumRenk[_durum] ?? _trfGri),
        if (_trfN(tr['talep_id']) > 0) _trfRozet('Talepten · #${_trfS(tr['talep_id'])}', _trfMor),
      ]),
      const SizedBox(height: 14),
      // adım göstergesi
      Row(children: [
        for (var i = 0; i < adimlar.length; i++) ...[
          if (i > 0) Expanded(child: Container(height: 2, color: (!kapali && (i <= idx || _durum == 'teslim')) ? _trfYesil : t.line)),
          _adim(t, i + 1, adimlar[i], kapali ? 0 : ((i < idx || _durum == 'teslim') ? 2 : (i == idx ? 1 : 0))),
        ],
      ]),
      const SizedBox(height: 14),
      taraflar,
      if (kapali && _trfS(tr['red_sebep']).isNotEmpty)
        not(Icons.block, _trfS(tr['red_sebep']), renk: _trfKirmizi, baslik: _durum == 'iptal' ? 'İptal' : 'Red sebebi'),
      if (_trfS(tr['not']).isNotEmpty) not(Icons.sticky_note_2_outlined, _trfS(tr['not'])),
      if (_trfS(tr['gonderen_not']).isNotEmpty) not(Icons.reply, _trfS(tr['gonderen_not']), baslik: 'Gönderen notu'),
      const SizedBox(height: 14),
      MBolumBaslik('Kalemler', renk: _trfCyan, sayi: _kalemler.length),
      if (genis) _kalemTablo(t, ic) else for (final k in _kalemler) _kalemKart(t, k as Map, ic),
      if (_trfN(tr['maliyet_toplam']) > 0 || _trfN(tr['net_toplam']) > 0)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Wrap(spacing: 18, runSpacing: 6, children: [
            if (_trfN(tr['maliyet_toplam']) > 0) Text('Maliyet toplamı: ${_trfTl(tr['maliyet_toplam'])}', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
            if (_trfN(tr['net_toplam']) > 0)
              Text('Fatura: ${_trfTl(tr['net_toplam'])} + KDV %${_trfSayi(tr['kdv_orani'])} = ${_trfTl(_trfN(tr['net_toplam']) + _trfN(tr['kdv_toplam']))}',
                  style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      if (_onayModu) ...[
        if (!ic) ...[
          const SizedBox(height: 12),
          Row(children: [
            Text('Fatura KDV oranı:', style: TextStyle(color: t.ink, fontSize: 13)),
            const SizedBox(width: 10),
            DropdownButton<num>(
              value: kdv,
              dropdownColor: t.card,
              style: TextStyle(color: t.ink, fontWeight: FontWeight.w700),
              items: [for (final x in const [1, 10, 20, 0]) DropdownMenuItem(value: x, child: Text('%$x'))],
              onChanged: (x) => setState(() => kdv = x ?? kdv),
            ),
          ]),
        ],
        const SizedBox(height: 10),
        TextField(
          controller: notCtl,
          minLines: 2,
          maxLines: 3,
          style: TextStyle(color: t.ink, fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Karşı şubeye not (isteğe bağlı)',
            hintStyle: TextStyle(color: t.sub),
            filled: true,
            fillColor: t.card,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          ),
        ),
      ],
      if (_teslimModu)
        not(Icons.info_outline, 'Gelen miktarı girin. Eksik gelen kısım transfer firesi olarak kaydedilir; eksik varsa nedenini not edin.', renk: _trfCyan),
      if (_onayModu)
        not(Icons.info_outline, 'İstenenden az onaylayabilirsiniz (kısmi onay). Vermeyecekseniz reddedin.', renk: _trfCyan),
      const SizedBox(height: 16),
      if (islemde)
        const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
      else if (butonlar.isNotEmpty)
        Wrap(spacing: 8, runSpacing: 8, children: butonlar)
      else if (!_yetkili && ['oneri', 'istendi', 'hazirlaniyor', 'yolda'].contains(_durum))
        Text('Bu transferde işlem yapma yetkiniz yok.', style: TextStyle(color: t.sub, fontSize: 12.5)),
    ];
  }

  Widget _adim(TemaProvider t, int no, String etiket, int hal) {
    // hal: 0 bekliyor, 1 şu an, 2 tamam
    final renk = hal == 2 ? _trfYesil : (hal == 1 ? _trfMavi : t.sub);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hal == 0 ? t.card : renk,
          shape: BoxShape.circle,
          border: Border.all(color: hal == 0 ? t.line : renk, width: 2),
        ),
        child: hal == 2
            ? const Icon(Icons.check, size: 15, color: Colors.white)
            : Text('$no', style: TextStyle(color: hal == 1 ? Colors.white : t.sub, fontSize: 12, fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 4),
      Text(etiket, style: TextStyle(color: hal == 0 ? t.sub : renk, fontSize: 10.5, fontWeight: FontWeight.w700)),
    ]);
  }

  String _mik(dynamic v) => v == null ? '—' : _trfSayi(v);

  Widget _lotlar(TemaProvider t, Map k) {
    final lot = (k['lotlar'] as List?) ?? const [];
    final satir = <Widget>[];
    if (lot.isNotEmpty) {
      final s = lot.map((l) {
        final ln = _trfS(l['lot_no']);
        final skt = _trfS(l['skt']);
        return '${ln.isNotEmpty ? 'Lot $ln' : 'Lotsuz'}${skt.isNotEmpty ? ' · SKT $skt' : ''} · ${_trfSayi(l['miktar'])}';
      }).join(' | ');
      satir.add(Text('🏷️ $s', style: TextStyle(color: t.sub, fontSize: 11)));
    }
    if (_trfS(k['fark_not']).isNotEmpty) satir.add(Text('⚠️ ${_trfS(k['fark_not'])}', style: const TextStyle(color: _trfKirmizi, fontSize: 11)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: satir);
  }

  Widget _girdi(TemaProvider t, TextEditingController c, {String? ipucu, double genislik = 90, bool sayi = true}) => SizedBox(
        width: genislik,
        child: TextField(
          controller: c,
          keyboardType: sayi ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: TextStyle(color: t.ink, fontSize: 13, fontWeight: sayi ? FontWeight.w700 : FontWeight.normal),
          decoration: InputDecoration(
            isDense: true,
            hintText: ipucu,
            hintStyle: TextStyle(color: t.sub, fontSize: 11.5),
            filled: true,
            fillColor: t.card2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: _trfMor.withValues(alpha: 0.5))),
          ),
        ),
      );

  String _fiyat(Map k) => _trfN(k['birim_fiyat']) > 0 ? _trfTl(k['birim_fiyat']) : (_trfN(k['birim_maliyet']) > 0 ? _trfTl(k['birim_maliyet']) : '—');

  Widget _kalemTablo(TemaProvider t, bool ic) {
    final yz = TextStyle(color: t.ink, fontSize: 12.5);
    return MTablo(
      sutunlar: [
        const MSutun('Ürün', flex: 26),
        const MSutun('İstenen', flex: 10, hiza: TextAlign.right),
        const MSutun('Onaylanan', flex: 11, hiza: TextAlign.right),
        const MSutun('Gönderilen', flex: 11, hiza: TextAlign.right),
        MSutun('Teslim', flex: _teslimModu ? 16 : 10, hiza: TextAlign.right),
        MSutun(ic ? 'Birim maliyet' : 'Birim fiyat', flex: 11, hiza: TextAlign.right),
      ],
      satirlar: [
        for (final k0 in _kalemler)
          () {
            final k = k0 as Map;
            final id = _trfN(k['id']).toInt();
            final birim = _trfS(k['birim']);
            return <Widget>[
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(_trfS(k['ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 13)),
                _lotlar(t, k),
              ]),
              Text('${_mik(k['istenen'])} $birim', style: yz),
              _onayModu && miktarCtl[id] != null ? _girdi(t, miktarCtl[id]!) : Text(_mik(k['onaylanan']), style: yz),
              Text(_mik(k['gonderilen']), style: yz),
              _teslimModu && miktarCtl[id] != null
                  ? Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
                      _girdi(t, miktarCtl[id]!),
                      const SizedBox(height: 4),
                      _girdi(t, farkCtl[id]!, ipucu: 'Eksikse not', genislik: 140, sayi: false),
                    ])
                  : Text(_mik(k['teslim_alinan']), style: yz),
              Text(_fiyat(k), style: yz),
            ];
          }(),
      ],
    );
  }

  Widget _kalemKart(TemaProvider t, Map k, bool ic) {
    final id = _trfN(k['id']).toInt();
    final birim = _trfS(k['birim']);
    Widget hucre(String etiket, Widget deger) => Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(etiket, style: TextStyle(color: t.sub, fontSize: 10.5)),
            const SizedBox(height: 2),
            deger,
          ]),
        );
    final yz = TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MKart(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(_trfS(k['ad']), style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 14))),
            Text('${ic ? 'Maliyet' : 'Fiyat'} ${_fiyat(k)}', style: TextStyle(color: t.sub, fontSize: 11.5)),
          ]),
          _lotlar(t, k),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            hucre('İstenen', Text('${_mik(k['istenen'])} $birim', style: yz)),
            hucre('Onaylanan', _onayModu && miktarCtl[id] != null ? _girdi(t, miktarCtl[id]!, genislik: 80) : Text(_mik(k['onaylanan']), style: yz)),
            hucre('Gönderilen', Text(_mik(k['gonderilen']), style: yz)),
            hucre('Teslim', _teslimModu && miktarCtl[id] != null ? _girdi(t, miktarCtl[id]!, genislik: 80) : Text(_mik(k['teslim_alinan']), style: yz)),
          ]),
          if (_teslimModu && farkCtl[id] != null) ...[
            const SizedBox(height: 8),
            _girdi(t, farkCtl[id]!, ipucu: 'Eksik geldiyse not', genislik: double.infinity, sayi: false),
          ],
        ]),
      ),
    );
  }
}

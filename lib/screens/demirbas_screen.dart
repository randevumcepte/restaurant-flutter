import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../responsive.dart';
import '../services/api.dart';
import '../services/etiket_yazici.dart';
import '../ui/masaustu_kit.dart';
import 'barkod_tarayici.dart';

/// DEMİRBAŞ & ETİKET — web /demirbas ile aynı veri ve akış (/api/demirbas/*, /api/etiket/*).
/// Demirbaş kartı + otomatik barkod + etiket basımı (ZPL/TSPL ağ yazıcısı ya da fiş yazıcısı)
/// + okut-bul + zimmet/konum/durum/bakım + demirbaş sayımı. Telefon ve masaüstü aynı içerik.
class DemirbasScreen extends StatefulWidget {
  const DemirbasScreen({super.key});
  @override
  State<DemirbasScreen> createState() => _DemirbasScreenState();
}

// ---------------- ortak sabitler / yardımcılar ----------------
const _dmYesil = Color(0xFF059669);
const _dmKirmizi = Color(0xFFDC2626);
const _dmAmber = Color(0xFFD97706);
const _dmMavi = Color(0xFF2563EB);
const _dmMor = Color(0xFF7C3AED);
const _dmGri = Color(0xFF64748B);
const _dmTuruncu = Color(0xFFEA580C);

const _dmDurumRenk = <String, Color>{
  'aktif': _dmYesil,
  'bakimda': _dmAmber,
  'arizali': _dmTuruncu,
  'kayip': _dmKirmizi,
  'hurda': _dmGri,
};
const _dmVarsayilanDurumlar = <String, String>{
  'aktif': 'Kullanımda',
  'bakimda': 'Bakımda',
  'arizali': 'Arızalı',
  'kayip': 'Kayıp',
  'hurda': 'Hurda',
};

final _dmFmtP = NumberFormat('#,##0.00', 'tr');
num _dmN(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '') ?? 0);
String _dmS(dynamic v) => v?.toString() ?? '';
String _dmTl(dynamic v) => '${_dmFmtP.format(_dmN(v))} ₺';
bool _dmOk(Map r) => r['ok'] == true || r['ok'] == 1;
String _dmMesaj(Map r, String yedek) {
  final m = _dmS(r['mesaj']).isNotEmpty ? _dmS(r['mesaj']) : _dmS(r['hata']);
  return m.isEmpty ? yedek : m;
}
String _dmNorm(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
String _dmTarih(dynamic z) {
  final s = _dmS(z).replaceAll('T', ' ');
  if (s.isEmpty) return '';
  final d = DateTime.tryParse(s);
  if (d == null) return s.length > 16 ? s.substring(0, 16) : s;
  return s.length > 10 ? DateFormat('dd.MM.yyyy HH:mm').format(d) : DateFormat('dd.MM.yyyy').format(d);
}
Map<String, String> _dmMapStr(dynamic m) {
  if (m is Map && m.isNotEmpty) return m.map((k, v) => MapEntry(k.toString(), v.toString()));
  return Map<String, String>.from(_dmVarsayilanDurumlar);
}

void _dmBildir(BuildContext context, String mesaj, {bool hata = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(mesaj),
    backgroundColor: hata ? _dmKirmizi : _dmYesil,
    behavior: SnackBarBehavior.floating,
  ));
}

/// API çağrısı sarmalayıcı: 401 → çıkış; bağlantı hatası → bildirim; null döner.
Future<Map<String, dynamic>?> _dmCagir(BuildContext context, Future<Map<String, dynamic>> Function(String token) f) async {
  final auth = context.read<AuthProvider>();
  try {
    return await f(auth.token ?? '');
  } on ApiYetkiHatasi {
    if (context.mounted) context.read<AuthProvider>().cikis();
    return null;
  } catch (_) {
    if (context.mounted) _dmBildir(context, 'Bağlantı hatası. Tekrar deneyin.', hata: true);
    return null;
  }
}

/// Evet/hayır onayı. Tema dialog içinde listen:false okunur (debug çökmesini önler).
Future<bool> _dmOnayIste(BuildContext context, String baslik, String metin, String buton, Color renk) async {
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

InputDecoration _dmDekor(TemaProvider t, String etiket, {String? ipucu, Widget? onEk, Widget? sonEk}) => InputDecoration(
      labelText: etiket,
      hintText: ipucu,
      isDense: true,
      prefixIcon: onEk,
      suffixIcon: sonEk,
      labelStyle: TextStyle(color: t.sub),
      hintStyle: TextStyle(color: t.sub, fontSize: 12.5),
      filled: true,
      fillColor: t.card2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
    );

/// Etiket bas: adet sorar → /api/etiket/komut → ZPL/TSPL ağ yazıcısı ya da fiş yazıcısı.
Future<void> _dmEtiketBas(BuildContext context, List<int> ids) async {
  if (ids.isEmpty) return;
  final adetC = TextEditingController(text: '1');
  final adet = await showDialog<int>(
    context: context,
    builder: (ctx) {
      final t = Provider.of<TemaProvider>(ctx, listen: false);
      return AlertDialog(
        backgroundColor: t.card,
        title: Text(ids.length == 1 ? 'Etiket bas' : 'Etiket bas (${ids.length} demirbaş)', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: adetC,
            autofocus: true,
            keyboardType: TextInputType.number,
            style: TextStyle(color: t.ink),
            decoration: _dmDekor(t, 'Her demirbaştan kaç adet?'),
          ),
          const SizedBox(height: 8),
          Text('Etiket yazıcısı ayarı (ZPL/TSPL) varsa oraya, yoksa fiş yazıcısına basılır.', style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _dmMor),
            onPressed: () => Navigator.pop(ctx, (int.tryParse(adetC.text.trim()) ?? 1).clamp(1, 500)),
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Yazdır'),
          ),
        ],
      );
    },
  );
  adetC.dispose();
  if (adet == null || !context.mounted) return;
  final token = context.read<AuthProvider>().token ?? '';
  String sonuc;
  try {
    sonuc = await EtiketYazici.yazdir(token, tur: 'demirbas', ids: ids, adet: adet);
  } on ApiYetkiHatasi {
    if (context.mounted) context.read<AuthProvider>().cikis();
    return;
  } catch (_) {
    sonuc = 'Bağlantı hatası. Tekrar deneyin.';
  }
  if (!context.mounted) return;
  _dmBildir(context, sonuc == 'ok' ? 'Etiket yazıcıya gönderildi ✓' : sonuc, hata: sonuc != 'ok');
}

/// Etiket ayarları dialogu (yalnız düzenleme yetkisi olana gösterilir).
Future<void> _dmEtiketAyarAc(BuildContext context) async {
  final r = await _dmCagir(context, (tok) => Api.etiketAyar(tok));
  if (r == null || !context.mounted) return;
  if (!_dmOk(r)) {
    _dmBildir(context, _dmMesaj(r, 'Etiket ayarı alınamadı.'), hata: true);
    return;
  }
  final ayar = (r['ayar'] as Map?) ?? const {};
  final boyutlar = _dmMapStr(r['boyutlar'] is Map ? r['boyutlar'] : {'50x30': '50 × 30 mm'});
  final diller = _dmMapStr(r['diller'] is Map ? r['diller'] : {'tarayici': 'Bilgisayardan yazdır'});
  String dil = diller.containsKey(_dmS(ayar['dil'])) ? _dmS(ayar['dil']) : diller.keys.first;
  String boyut = boyutlar.containsKey(_dmS(ayar['boyut'])) ? _dmS(ayar['boyut']) : boyutlar.keys.first;
  int dpi = _dmN(ayar['dpi']).toInt() == 300 ? 300 : 203;
  final ipC = TextEditingController(text: _dmS(ayar['ip']));
  final portC = TextEditingController(text: _dmN(ayar['port']) > 0 ? '${_dmN(ayar['port']).toInt()}' : '9100');
  bool islemde = false;
  await showDialog<void>(
    context: context,
    builder: (ctx) {
      final t = Provider.of<TemaProvider>(ctx, listen: false);
      return StatefulBuilder(builder: (ctx, setS) {
        final agYazici = dil == 'zpl' || dil == 'tspl';
        Future<void> test() async {
          setS(() => islemde = true);
          final s = await EtiketYazici.testBas(dil: dil, ip: ipC.text, port: int.tryParse(portC.text.trim()) ?? 9100);
          if (!ctx.mounted) return;
          setS(() => islemde = false);
          _dmBildir(ctx, s == 'ok' ? 'Test etiketi gönderildi ✓' : s, hata: s != 'ok');
        }

        Future<void> kaydet() async {
          setS(() => islemde = true);
          final res = await _dmCagir(ctx, (tok) => Api.etiketAyarKaydet(tok, {
                'dil': dil,
                'boyut': boyut,
                'dpi': '$dpi',
                'ip': ipC.text.trim(),
                'port': portC.text.trim().isEmpty ? '9100' : portC.text.trim(),
              }));
          if (!ctx.mounted) return;
          setS(() => islemde = false);
          if (res == null) return;
          if (_dmOk(res)) {
            Navigator.pop(ctx);
            if (context.mounted) _dmBildir(context,_dmMesaj(res, 'Etiket ayarları kaydedildi.'));
          } else {
            _dmBildir(ctx, _dmMesaj(res, 'Kaydedilemedi.'), hata: true);
          }
        }

        return AlertDialog(
          backgroundColor: t.card,
          title: Row(children: [
            Icon(Icons.settings, color: _dmMor, size: 20),
            const SizedBox(width: 8),
            Text('Etiket ayarları', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
          ]),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                DropdownButtonFormField<String>(
                  initialValue: dil,
                  isExpanded: true,
                  dropdownColor: t.card,
                  style: TextStyle(color: t.ink, fontSize: 13.5),
                  decoration: _dmDekor(t, 'Yazıcı dili'),
                  items: [for (final e in diller.entries) DropdownMenuItem(value: e.key, child: Text(e.value, maxLines: 2, overflow: TextOverflow.ellipsis))],
                  onChanged: (x) => setS(() => dil = x ?? dil),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: boyut,
                  isExpanded: true,
                  dropdownColor: t.card,
                  style: TextStyle(color: t.ink, fontSize: 13.5),
                  decoration: _dmDekor(t, 'Etiket boyutu'),
                  items: [for (final e in boyutlar.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (x) => setS(() => boyut = x ?? boyut),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: dpi,
                  dropdownColor: t.card,
                  style: TextStyle(color: t.ink, fontSize: 13.5),
                  decoration: _dmDekor(t, 'Çözünürlük (DPI)'),
                  items: const [
                    DropdownMenuItem(value: 203, child: Text('203 dpi (çoğu yazıcı)')),
                    DropdownMenuItem(value: 300, child: Text('300 dpi')),
                  ],
                  onChanged: (x) => setS(() => dpi = x ?? dpi),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextField(controller: ipC, style: TextStyle(color: t.ink), decoration: _dmDekor(t, 'Yazıcı IP', ipucu: 'ör. 192.168.1.50')),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(controller: portC, keyboardType: TextInputType.number, style: TextStyle(color: t.ink), decoration: _dmDekor(t, 'Port')),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  agYazici
                      ? 'Uygulama etiketi bu IP:port adresine doğrudan gönderir (Zebra/TSC genelde 9100).'
                      : 'Bu dilde uygulama, Yazıcı Ayarları\'ndaki fiş yazıcısına basar. IP/port yalnız ZPL/TSPL için kullanılır.',
                  style: TextStyle(color: t.sub, fontSize: 12),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: islemde ? null : () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
            OutlinedButton.icon(onPressed: islemde ? null : test, icon: const Icon(Icons.print_outlined, size: 18), label: const Text('Test etiketi')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: _dmMor), onPressed: islemde ? null : kaydet, child: const Text('Kaydet')),
          ],
        );
      });
    },
  );
  ipC.dispose();
  portC.dispose();
}

// =====================================================================================
// ANA EKRAN
// =====================================================================================
class _DemirbasScreenState extends State<DemirbasScreen> {
  bool loading = true;
  String? hata;
  bool yetkisiz = false;
  Map<String, dynamic> v = {};
  String sekme = 'liste'; // liste | sayim

  // liste filtreleri
  final araC = TextEditingController();
  String ara = '';
  String durumF = '';
  String lokF = '';
  bool secimModu = false;
  final Set<int> secili = {};

  // sayım
  bool sayimYukleniyor = false;
  Map<String, dynamic> sayimV = {};
  String sayimLok = '';
  final kodC = TextEditingController();
  Map<String, dynamic>? sonOkut;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    araC.dispose();
    kodC.dispose();
    super.dispose();
  }

  bool get duzenler => v['duzenler'] == true || v['duzenler'] == 1;
  List get _liste => (v['liste'] as List?) ?? const [];
  Map get _ozet => (v['ozet'] as Map?) ?? const {};
  Map<String, String> get _durumlar => _dmMapStr(v['durumlar']);
  List<String> get _lokasyonlar => ((v['lokasyonlar'] as List?) ?? const []).map((e) => e.toString()).toList();
  Map? get _aktifSayim => v['aktif_sayim'] is Map ? v['aktif_sayim'] as Map : null;

  List get _filtreli {
    final n = _dmNorm(ara.trim());
    return _liste.where((d) {
      if (durumF.isNotEmpty && d['durum'] != durumF) return false;
      if (lokF.isNotEmpty && _dmS(d['lokasyon']) != lokF) return false;
      if (n.isEmpty) return true;
      final metin = _dmNorm([d['ad'], d['barkod'], d['kod'], d['kategori'], d['lokasyon'], d['zimmet_ad'], d['marka'], d['model'], d['seri_no']].map(_dmS).join(' '));
      return metin.contains(n);
    }).toList();
  }

  Future<void> _yukle() async {
    setState(() {
      loading = true;
      hata = null;
    });
    final res = await _dmCagir(context, (tok) => Api.demirbasListe(tok));
    if (!mounted) return;
    setState(() {
      loading = false;
      if (res == null) {
        if (v.isEmpty) hata = 'Bağlantı hatası. Tekrar deneyin.';
        return;
      }
      if (_dmOk(res)) {
        v = res;
        yetkisiz = false;
        final ids = _liste.map((d) => _dmN(d['id']).toInt()).toSet();
        secili.removeWhere((x) => !ids.contains(x));
        if (lokF.isNotEmpty && !_lokasyonlar.contains(lokF)) lokF = '';
      } else {
        hata = _dmMesaj(res, 'Demirbaş listesi alınamadı.');
        yetkisiz = hata!.toLowerCase().contains('yetki');
      }
    });
    if (sekme == 'sayim' && hata == null) _sayimYukle();
  }

  Future<void> _sayimYukle() async {
    setState(() => sayimYukleniyor = true);
    final res = await _dmCagir(context, (tok) => Api.demirbasSayim(tok));
    if (!mounted) return;
    setState(() {
      sayimYukleniyor = false;
      if (res != null && _dmOk(res)) sayimV = res;
    });
  }

  void _sekmeAc(String s) {
    setState(() => sekme = s);
    if (s == 'sayim') _sayimYukle();
  }

  // ---------- detay / form ----------
  Future<void> _detayAc({int? id, String? kod}) async {
    final genis = genisMi(context);
    final meta = _DmMeta(
      durumlar: _durumlar,
      lokasyonlar: _lokasyonlar,
      kategoriler: ((v['kategoriler'] as List?) ?? const []).map((e) => e.toString()).toList(),
      personeller: ((v['personeller'] as List?) ?? const []).whereType<Map>().toList(),
    );
    bool? degisti;
    if (genis) {
      degisti = await showDialog<bool>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900, maxHeight: 840),
            child: _DemirbasDetay(id: id, kod: kod, meta: meta, dialog: true),
          ),
        ),
      );
    } else {
      degisti = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          maxChildSize: 0.97,
          minChildSize: 0.5,
          expand: false,
          builder: (_, sc) => _DemirbasDetay(id: id, kod: kod, meta: meta, dialog: false, scroll: sc),
        ),
      );
    }
    // Kapat (X) = false → değişiklik yoksa yenileme yok; kaydırarak kapatma (null) → güvenli tarafta yenile
    if (degisti != false && mounted) await _yukle();
  }

  Future<void> _okut() async {
    final kod = await BarkodTarayici.oku(context, baslik: 'Demirbaş okut');
    if (kod == null || !mounted) return;
    await _koddanAc(kod);
  }

  Future<void> _koddanAc(String kod) async {
    final res = await _dmCagir(context, (tok) => Api.demirbasDetay(tok, kod: kod));
    if (res == null || !mounted) return;
    if (_dmOk(res) && (res['bulundu'] == 1 || res['bulundu'] == true)) {
      final id = _dmN((res['demirbas'] as Map?)?['id']).toInt();
      await _detayAc(id: id);
    } else {
      _dmBildir(context, 'Bu barkodla kayıtlı demirbaş yok: $kod', hata: true);
    }
  }

  Future<void> _yeni() async {
    final sonuc = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(
      builder: (_) => _DemirbasForm(
        meta: _DmMeta(
          durumlar: _durumlar,
          lokasyonlar: _lokasyonlar,
          kategoriler: ((v['kategoriler'] as List?) ?? const []).map((e) => e.toString()).toList(),
          personeller: ((v['personeller'] as List?) ?? const []).whereType<Map>().toList(),
        ),
      ),
    ));
    if (sonuc == null || !mounted) return;
    await _yukle();
    if (!mounted) return;
    final id = _dmN(sonuc['id']).toInt();
    if (id <= 0) return;
    final bas = await _dmOnayIste(context, 'Demirbaş kaydedildi', 'Barkod: ${_dmS(sonuc['barkod'])}\nEtiketini şimdi basmak ister misin?', 'Etiketini bas', _dmMor);
    if (bas && mounted) await _dmEtiketBas(context, [id]);
  }

  // ---------------- build ----------------
  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final genis = genisMi(context);
    return MasaustuSayfa(
      baslik: 'Demirbaş & Etiket',
      ikon: Icons.qr_code_2,
      geri: true,
      altBaslik: 'Ekipman kartı · barkod etiketi · zimmet · sayım',
      araclar: [
        if (duzenler) IconButton(onPressed: () => _dmEtiketAyarAc(context), tooltip: 'Etiket ayarları', icon: Icon(Icons.settings_outlined, color: t.sub2)),
        IconButton(onPressed: _yukle, tooltip: 'Yenile', icon: Icon(Icons.refresh, color: t.sub2)),
      ],
      govde: loading && v.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _yukle,
                  child: ListView(
                    padding: EdgeInsets.all(genis ? 20 : 12),
                    children: _govde(t, genis),
                  ),
                ),
              ),
              if (sekme == 'liste' && secimModu && hata == null) _secimCubugu(t),
            ]),
    );
  }

  List<Widget> _govde(TemaProvider t, bool genis) {
    if (hata != null) {
      return [
        _bosKutu(t, yetkisiz ? Icons.lock_outline : Icons.error_outline, yetkisiz ? _dmAmber : _dmKirmizi,
            yetkisiz ? 'Demirbaş ekranını görme yetkin yok.' : hata!,
            alt: yetkisiz ? 'Patron veya müdür, Personel Yetkileri ekranından "Demirbaş" yetkisini açabilir.' : null),
      ];
    }
    return [
      _kpiler(t, genis),
      const SizedBox(height: 14),
      _sekmeCubugu(t),
      const SizedBox(height: 14),
      if (sekme == 'sayim') ..._sayimIcerik(t, genis) else ..._listeIcerik(t, genis),
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
    final o = _ozet;
    final kartlar = [
      _kpi(t, Icons.inventory_2_outlined, 'Kayıtlı demirbaş', '${_dmN(o['adet']).toInt()}', 'Toplam değer ${_dmTl(o['deger'])}', _dmMor, () => setState(() => durumF = '')),
      _kpi(t, Icons.badge_outlined, 'Zimmetli', '${_dmN(o['zimmetli']).toInt()}', 'personel üzerinde', _dmMavi, null),
      _kpi(t, Icons.build_circle_outlined, 'Bakımda / arızalı / kayıp', '${_dmN(o['sorunlu']).toInt()}', 'ilgilenilmesi gereken', _dmTuruncu, null),
      _kpi(t, Icons.verified_outlined, 'Garantisi bitiyor', '${_dmN(o['garanti']).toInt()}', '30 gün içinde', _dmAmber, null),
      _kpi(t, Icons.fact_check_outlined, 'Sayılmamış', '${_dmN(o['sayilmamis']).toInt()}', '90 gündür okutulmadı', _dmKirmizi, () => _sekmeAc('sayim')),
    ];
    if (genis) {
      return Row(children: [
        for (var i = 0; i < kartlar.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: kartlar[i])],
      ]);
    }
    return Column(children: [
      kartlar[0],
      const SizedBox(height: 10),
      Row(children: [Expanded(child: kartlar[1]), const SizedBox(width: 10), Expanded(child: kartlar[2])]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: kartlar[3]), const SizedBox(width: 10), Expanded(child: kartlar[4])]),
    ]);
  }

  Widget _kpi(TemaProvider t, IconData ikon, String etiket, String deger, String alt, Color renk, VoidCallback? onTap) => MKart(
        padding: const EdgeInsets.all(14),
        kenar: renk.withValues(alpha: 0.35),
        onTap: onTap,
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
    final sayimVar = _aktifSayim != null;
    final sekmeler = [
      ('liste', Icons.list_alt, 'Demirbaşlar', _liste.length, false),
      ('sayim', Icons.fact_check_outlined, sayimVar ? 'Sayım (açık)' : 'Sayım', 0, sayimVar),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (final s in sekmeler)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Material(
              color: sekme == s.$1 ? _dmMor : t.card,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _sekmeAc(s.$1),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: sekme == s.$1 ? _dmMor : t.line)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(s.$2, size: 16, color: sekme == s.$1 ? Colors.white : t.sub2),
                    const SizedBox(width: 6),
                    Text(s.$3, style: TextStyle(color: sekme == s.$1 ? Colors.white : t.sub2, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (s.$4 > 0) ...[
                      const SizedBox(width: 6),
                      Text('${s.$4}', style: TextStyle(color: sekme == s.$1 ? Colors.white70 : t.sub, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                    if (s.$5) ...[
                      const SizedBox(width: 6),
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: _dmAmber, shape: BoxShape.circle)),
                    ],
                  ]),
                ),
              ),
            ),
          ),
      ]),
    );
  }

  // =================== LİSTE ===================
  List<Widget> _listeIcerik(TemaProvider t, bool genis) {
    final l = _filtreli;
    final araAlani = TextField(
      controller: araC,
      onChanged: (x) => setState(() => ara = x),
      onSubmitted: (x) {
        final k = x.trim();
        if (k.isEmpty) return;
        // El tipi USB okuyucu / elle tam kod: birebir eşleşen barkod varsa doğrudan aç
        final esit = _liste.where((d) => _dmS(d['barkod']) == k || _dmS(d['kod']) == k || _dmS(d['seri_no']) == k).toList();
        if (esit.length == 1) {
          _detayAc(id: _dmN(esit.first['id']).toInt());
        } else if (l.isEmpty) {
          _koddanAc(k);
        }
      },
      style: TextStyle(color: t.ink),
      decoration: _dmDekor(t, 'Ara', ipucu: 'Ad, barkod, seri no, konum, zimmet…', onEk: Icon(Icons.search, color: t.sub),
          sonEk: ara.isEmpty
              ? null
              : IconButton(
                  icon: Icon(Icons.close, color: t.sub, size: 18),
                  onPressed: () => setState(() {
                    araC.clear();
                    ara = '';
                  }),
                )),
    );
    final okutBtn = SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _okut,
        style: ElevatedButton.styleFrom(backgroundColor: _dmMor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Okut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );
    final yeniBtn = SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _yeni,
        style: OutlinedButton.styleFrom(foregroundColor: _dmMor, side: const BorderSide(color: _dmMor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        icon: const Icon(Icons.add),
        label: const Text('Yeni demirbaş', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
    final secBtn = SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () => setState(() {
          secimModu = !secimModu;
          if (!secimModu) secili.clear();
        }),
        style: OutlinedButton.styleFrom(
          foregroundColor: secimModu ? Colors.white : t.sub2,
          backgroundColor: secimModu ? _dmMavi : null,
          side: BorderSide(color: secimModu ? _dmMavi : t.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(secimModu ? Icons.check_box : Icons.check_box_outlined),
        label: Text(secimModu ? 'Seçimi kapat' : 'Seç → etiket', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );

    final ust = genis
        ? Row(children: [
            Expanded(child: araAlani),
            const SizedBox(width: 10),
            SizedBox(width: 150, child: okutBtn),
            const SizedBox(width: 10),
            secBtn,
            if (duzenler) ...[const SizedBox(width: 10), yeniBtn],
          ])
        : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            okutBtn,
            const SizedBox(height: 10),
            araAlani,
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: secBtn),
              if (duzenler) ...[const SizedBox(width: 10), Expanded(child: yeniBtn)],
            ]),
          ]);

    return [
      ust,
      const SizedBox(height: 12),
      _filtreler(t),
      const SizedBox(height: 12),
      if (_liste.isEmpty)
        _bosKutu(t, Icons.inventory_2_outlined, _dmMor, 'Henüz demirbaş kaydı yok.',
            alt: duzenler
                ? '"Yeni demirbaş" ile ekipmanlarını (fırın, POS cihazı, tablet, masa…) kaydet; sistem her birine barkod verir, etiketini basıp yapıştırırsın.'
                : 'Demirbaşlar, düzenleme yetkisi olan biri (patron/müdür) tarafından eklenir.')
      else if (l.isEmpty)
        _bosKutu(t, Icons.filter_alt_off_outlined, _dmGri, 'Filtreye uyan demirbaş yok.', alt: 'Arama ya da durum/konum filtresini değiştir.')
      else if (genis)
        _tablo(t, l)
      else
        for (final d in l) Padding(padding: const EdgeInsets.only(bottom: 10), child: _kart(t, d as Map)),
    ];
  }

  Widget _filtreler(TemaProvider t) {
    final sayac = <String, int>{};
    for (final d in _liste) {
      sayac[_dmS(d['durum'])] = (sayac[_dmS(d['durum'])] ?? 0) + 1;
    }
    Widget chip(String key, String ad, Color renk, int n) {
      final sec = durumF == key;
      return Padding(
        padding: const EdgeInsets.only(right: 6, bottom: 6),
        child: ChoiceChip(
          label: Text(n > 0 || key.isEmpty ? '$ad ($n)' : ad),
          selected: sec,
          onSelected: (_) => setState(() => durumF = key),
          selectedColor: renk,
          backgroundColor: t.card,
          side: BorderSide(color: sec ? renk : t.line),
          labelStyle: TextStyle(color: sec ? Colors.white : t.sub2, fontWeight: FontWeight.w700, fontSize: 12.5),
          showCheckmark: false,
        ),
      );
    }

    final lok = _lokasyonlar;
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      chip('', 'Tümü', _dmMor, _liste.length),
      for (final e in _durumlar.entries) chip(e.key, e.value, _dmDurumRenk[e.key] ?? _dmGri, sayac[e.key] ?? 0),
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: lokF.isEmpty ? t.line : _dmMavi)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: lokF,
              dropdownColor: t.card,
              isDense: true,
              icon: Icon(Icons.place_outlined, color: t.sub, size: 18),
              style: TextStyle(color: t.ink, fontSize: 13),
              items: [
                const DropdownMenuItem(value: '', child: Text('Tüm konumlar')),
                for (final x in lok) DropdownMenuItem(value: x, child: Text(x)),
              ],
              onChanged: (x) => setState(() => lokF = x ?? ''),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _durumRozet(Map d) {
    final k = _dmS(d['durum']);
    return MRozet(_dmS(d['durum_ad']).isNotEmpty ? _dmS(d['durum_ad']) : (_durumlar[k] ?? k), _dmDurumRenk[k] ?? _dmGri);
  }

  void _secToggle(int id) => setState(() => secili.contains(id) ? secili.remove(id) : secili.add(id));

  Widget _kart(TemaProvider t, Map d) {
    final id = _dmN(d['id']).toInt();
    final sec = secili.contains(id);
    final renk = _dmDurumRenk[_dmS(d['durum'])] ?? _dmGri;
    return MKart(
      padding: const EdgeInsets.all(14),
      kenar: sec ? _dmMavi : renk.withValues(alpha: 0.35),
      onTap: () => secimModu ? _secToggle(id) : _detayAc(id: id),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (secimModu)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Icon(sec ? Icons.check_box : Icons.check_box_outline_blank, color: sec ? _dmMavi : t.sub),
          ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(_dmS(d['ad']), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 14.5))),
              const SizedBox(width: 6),
              _durumRozet(d),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.qr_code_2, size: 15, color: t.sub),
              const SizedBox(width: 4),
              Text(_dmS(d['barkod']), style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 4),
            Wrap(spacing: 12, runSpacing: 4, children: [
              _ikonMetin(t, Icons.place_outlined, _dmS(d['lokasyon']).isEmpty ? 'Konum yok' : _dmS(d['lokasyon'])),
              _ikonMetin(t, Icons.person_outline, _dmS(d['zimmet_ad']).isEmpty ? 'Zimmet yok' : _dmS(d['zimmet_ad'])),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _ikonMetin(TemaProvider t, IconData i, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(i, size: 14, color: t.sub),
        const SizedBox(width: 3),
        Text(s, style: TextStyle(color: t.sub, fontSize: 12)),
      ]);

  Widget _tablo(TemaProvider t, List l) {
    final sutunlar = [
      if (secimModu) const MSutun('', flex: 3),
      const MSutun('Demirbaş', flex: 26),
      const MSutun('Barkod', flex: 14),
      const MSutun('Konum', flex: 14),
      const MSutun('Zimmet', flex: 14),
      const MSutun('Durum', flex: 11),
      const MSutun('', flex: 9, hiza: TextAlign.right),
    ];
    final satirlar = <List<Widget>>[];
    for (final x in l) {
      final d = x as Map;
      final id = _dmN(d['id']).toInt();
      final sec = secili.contains(id);
      satirlar.add([
        if (secimModu)
          InkWell(onTap: () => _secToggle(id), child: Icon(sec ? Icons.check_box : Icons.check_box_outline_blank, color: sec ? _dmMavi : t.sub, size: 20)),
        InkWell(
          onTap: () => secimModu ? _secToggle(id) : _detayAc(id: id),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(_dmS(d['ad']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontWeight: FontWeight.w700, fontSize: 13.5)),
            if ([d['kategori'], d['marka'], d['model']].any((e) => _dmS(e).isNotEmpty))
              Text([d['kategori'], d['marka'], d['model']].map(_dmS).where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 11.5)),
          ]),
        ),
        Text(_dmS(d['barkod']), style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        Text(_dmS(d['lokasyon']).isEmpty ? '—' : _dmS(d['lokasyon']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 12.5)),
        Text(_dmS(d['zimmet_ad']).isEmpty ? '—' : _dmS(d['zimmet_ad']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub2, fontSize: 12.5)),
        _durumRozet(d),
        Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Etiket bas', visualDensity: VisualDensity.compact, onPressed: () => _dmEtiketBas(context, [id]), icon: const Icon(Icons.print_outlined, color: _dmMor, size: 19)),
          IconButton(tooltip: 'Detay', visualDensity: VisualDensity.compact, onPressed: () => _detayAc(id: id), icon: Icon(Icons.chevron_right, color: t.sub2, size: 20)),
        ]),
      ]);
    }
    return MTablo(sutunlar: sutunlar, satirlar: satirlar);
  }

  Widget _secimCubugu(TemaProvider t) {
    final l = _filtreli;
    final hepsi = l.isNotEmpty && l.every((d) => secili.contains(_dmN(d['id']).toInt()));
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          TextButton.icon(
            onPressed: () => setState(() {
              if (hepsi) {
                for (final d in l) {
                  secili.remove(_dmN(d['id']).toInt());
                }
              } else {
                for (final d in l) {
                  secili.add(_dmN(d['id']).toInt());
                }
              }
            }),
            icon: Icon(hepsi ? Icons.deselect : Icons.select_all, color: t.sub2),
            label: Text(hepsi ? 'Seçimi temizle' : 'Görünenleri seç', style: TextStyle(color: t.sub2)),
          ),
          const Spacer(),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: _dmMor, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
            onPressed: secili.isEmpty ? null : () => _dmEtiketBas(context, secili.toList()),
            icon: const Icon(Icons.print, size: 18),
            label: Text('Etiket bas (${secili.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

  // =================== SAYIM ===================
  Map? get _sayimAktif => sayimV['aktif'] is Map ? sayimV['aktif'] as Map : null;
  Map get _rapor => (sayimV['rapor'] as Map?) ?? const {};
  List _rl(String k) => (_rapor[k] as List?) ?? const [];

  Future<void> _sayimBaslat() async {
    final res = await _dmCagir(context, (tok) => Api.demirbasSayimBaslat(tok, lokasyon: sayimLok));
    if (res == null || !mounted) return;
    _dmBildir(context, _dmMesaj(res, _dmOk(res) ? 'Sayım başladı' : 'Başlatılamadı'), hata: !_dmOk(res));
    sonOkut = null;
    await _yukle();
  }

  Future<Map<String, dynamic>?> _sayimOkut(String kod) async {
    final res = await _dmCagir(context, (tok) => Api.demirbasSayimOkut(tok, kod));
    if (res == null || !mounted) return null;
    if (!_dmOk(res)) {
      _dmBildir(context, _dmMesaj(res, 'Okutulamadı'), hata: true);
      return null;
    }
    setState(() => sonOkut = res);
    return res;
  }

  Future<void> _sayimElleOkut() async {
    final k = kodC.text.trim();
    if (k.isEmpty) return;
    kodC.clear();
    final r = await _sayimOkut(k);
    if (r != null) await _sayimYukle();
  }

  Future<void> _sayimKamera() async {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _SayimTarayici(okut: _sayimOkut),
    ));
    if (mounted) await _sayimYukle();
  }

  Future<void> _sayimBitir() async {
    bool konum = true, kayip = false;
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Provider.of<TemaProvider>(ctx, listen: false);
        return StatefulBuilder(builder: (ctx, setS) => AlertDialog(
              backgroundColor: t.card,
              title: Text('Sayımı bitir', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
              content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${_rl('bulundu').length} yerinde · ${_rl('yanlis_yer').length} yanlış yerde · ${_rl('eksik').length} bulunamadı · ${_rl('bilinmeyen').length} tanımsız barkod',
                    style: TextStyle(color: t.sub2, fontSize: 13)),
                const SizedBox(height: 8),
                if (duzenler) ...[
                  CheckboxListTile(
                    value: konum,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: _dmMor,
                    onChanged: (x) => setS(() => konum = x ?? false),
                    title: Text('Yanlış yerde bulunanların konumunu güncelle', style: TextStyle(color: t.ink, fontSize: 13.5)),
                  ),
                  CheckboxListTile(
                    value: kayip,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: _dmKirmizi,
                    onChanged: (x) => setS(() => kayip = x ?? false),
                    title: Text('Bulunamayanları Kayıp işaretle', style: TextStyle(color: t.ink, fontSize: 13.5)),
                  ),
                ] else
                  Text('Konum güncelleme ve kayıp işaretleme yalnız düzenleme yetkisiyle yapılır; sayım yalnız kapatılır.', style: TextStyle(color: t.sub, fontSize: 12)),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: _dmYesil), onPressed: () => Navigator.pop(ctx, true), child: const Text('Bitir')),
              ],
            ));
      },
    );
    if (tamam != true || !mounted) return;
    final res = await _dmCagir(context, (tok) => Api.demirbasSayimBitir(tok, konumGuncelle: konum, eksikKayip: kayip));
    if (res == null || !mounted) return;
    if (_dmOk(res)) {
      final o = (res['ozet'] as Map?) ?? const {};
      _dmBildir(context,
          'Sayım bitti: ${_dmN(o['bulundu']).toInt()} yerinde, ${_dmN(o['yanlis_yer']).toInt()} yanlış yerde, ${_dmN(o['eksik']).toInt()} bulunamadı, ${_dmN(o['bilinmeyen']).toInt()} tanımsız barkod.');
      sonOkut = null;
      await _yukle();
    } else {
      _dmBildir(context, _dmMesaj(res, 'Bitirilemedi'), hata: true);
    }
  }

  Future<void> _sayimIptal() async {
    final ok = await _dmOnayIste(context, 'Sayımı iptal et', 'Bu sayımda okutulan tüm kayıtlar silinir, demirbaşlara dokunulmaz. Emin misin?', 'İptal et', _dmKirmizi);
    if (!ok || !mounted) return;
    final res = await _dmCagir(context, (tok) => Api.demirbasSayimBitir(tok, iptal: true));
    if (res == null || !mounted) return;
    _dmBildir(context, _dmMesaj(res, 'Sayım iptal edildi'), hata: !_dmOk(res));
    sonOkut = null;
    await _yukle();
  }

  List<Widget> _sayimIcerik(TemaProvider t, bool genis) {
    if (sayimYukleniyor && sayimV.isEmpty) return [const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator()))];
    final aktif = _sayimAktif;
    if (aktif == null) {
      final lok = _lokasyonlar;
      return [
        MKart(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            MBolumBaslik('Demirbaş sayımı başlat', renk: _dmMor),
            Text(
              'Etiketleri tek tek okutursun; sistem yerinde olanı, yanlış yerde bulunanı, hiç bulunamayanı ve tanımsız barkodları ayırır. '
              'Belirli bir konumu sayacaksan seç; boş bırakırsan bütün şube sayılır.',
              style: TextStyle(color: t.sub2, fontSize: 13),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: lok.contains(sayimLok) ? sayimLok : '',
                    dropdownColor: t.card,
                    style: TextStyle(color: t.ink, fontSize: 13.5),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Tüm şube')),
                      for (final x in lok) DropdownMenuItem(value: x, child: Text(x)),
                    ],
                    onChanged: (x) => setState(() => sayimLok = x ?? ''),
                  ),
                ),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _dmMor, padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14)),
                onPressed: _sayimBaslat,
                icon: const Icon(Icons.play_arrow),
                label: const Text('Sayımı başlat', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
        ),
      ];
    }

    final sayac = sonOkut?['sayac'] is Map ? sonOkut!['sayac'] as Map : null;
    final nBul = sayac != null ? _dmN(sayac['bulundu']).toInt() : _rl('bulundu').length;
    final nYan = sayac != null ? _dmN(sayac['yanlis_yer']).toInt() : _rl('yanlis_yer').length;
    final nEks = sayac != null ? _dmN(sayac['eksik']).toInt() : _rl('eksik').length;
    final nBil = sayac != null ? _dmN(sayac['bilinmeyen']).toInt() : _rl('bilinmeyen').length;
    final kapsam = sayac != null ? _dmN(sayac['kapsam']).toInt() : _dmN(_rapor['kapsam']).toInt();

    final sayaclar = [
      _sayacKutu(t, 'Yerinde', nBul, _dmYesil),
      _sayacKutu(t, 'Yanlış yer', nYan, _dmAmber),
      _sayacKutu(t, 'Eksik', nEks, _dmKirmizi),
      _sayacKutu(t, 'Tanımsız', nBil, _dmGri),
    ];

    final elle = Row(children: [
      Expanded(
        child: TextField(
          controller: kodC,
          onSubmitted: (_) => _sayimElleOkut(),
          style: TextStyle(color: t.ink),
          decoration: _dmDekor(t, 'Barkod (el okuyucu ya da elle)', onEk: Icon(Icons.keyboard_outlined, color: t.sub)),
        ),
      ),
      const SizedBox(width: 8),
      IconButton.filled(onPressed: _sayimElleOkut, style: IconButton.styleFrom(backgroundColor: _dmMor), icon: const Icon(Icons.check, color: Colors.white)),
    ]);

    final listeler = [
      _sayimListe(t, 'Bulunamayan (eksik)', _dmKirmizi, _rl('eksik'), (e) => '${_dmS(e['ad'])}${_dmS(e['lokasyon']).isNotEmpty ? ' · ${_dmS(e['lokasyon'])}' : ''}', (e) => _dmS(e['barkod'])),
      _sayimListe(t, 'Yanlış yerde', _dmAmber, _rl('yanlis_yer'), (e) => _dmS(e['ad']),
          (e) => 'Kayıtta: ${_dmS(e['kayitli']).isEmpty ? '—' : _dmS(e['kayitli'])} → Bulunan: ${_dmS(e['lokasyon']).isEmpty ? '—' : _dmS(e['lokasyon'])}'),
      _sayimListe(t, 'Tanımsız barkod', _dmGri, _rl('bilinmeyen'), (e) => _dmS(e['kod']), (e) => _dmS(e['lokasyon'])),
    ];

    return [
      MKart(
        padding: const EdgeInsets.all(16),
        kenar: _dmAmber.withValues(alpha: 0.5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.fact_check, color: _dmAmber),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Açık sayım · ${_dmS(aktif['lokasyon']).isEmpty ? 'Tüm şube' : _dmS(aktif['lokasyon'])}',
                    style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Başlangıç: ${_dmTarih(aktif['baslangic'])} · kapsam $kapsam demirbaş', style: TextStyle(color: t.sub, fontSize: 12)),
              ]),
            ),
            if (sayimYukleniyor) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          const SizedBox(height: 12),
          if (genis)
            Row(children: [for (var i = 0; i < sayaclar.length; i++) ...[if (i > 0) const SizedBox(width: 10), Expanded(child: sayaclar[i])]])
          else ...[
            Row(children: [Expanded(child: sayaclar[0]), const SizedBox(width: 8), Expanded(child: sayaclar[1])]),
            const SizedBox(height: 8),
            Row(children: [Expanded(child: sayaclar[2]), const SizedBox(width: 8), Expanded(child: sayaclar[3])]),
          ],
          if (sonOkut != null) ...[const SizedBox(height: 12), _sonucBant(sonOkut!)],
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _sayimKamera,
              style: ElevatedButton.styleFrom(backgroundColor: _dmMor, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Kamerayla sürekli okut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
          const SizedBox(height: 10),
          elle,
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.end, children: [
            OutlinedButton.icon(
              onPressed: _sayimIptal,
              style: OutlinedButton.styleFrom(foregroundColor: _dmKirmizi, side: const BorderSide(color: _dmKirmizi)),
              icon: const Icon(Icons.close),
              label: const Text('İptal'),
            ),
            FilledButton.icon(
              onPressed: _sayimBitir,
              style: FilledButton.styleFrom(backgroundColor: _dmYesil),
              icon: const Icon(Icons.flag),
              label: const Text('Bitir', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
      ),
      const SizedBox(height: 14),
      if (genis)
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < listeler.length; i++) ...[if (i > 0) const SizedBox(width: 12), Expanded(child: listeler[i])],
        ])
      else
        for (final w in listeler) Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
    ];
  }

  Widget _sayacKutu(TemaProvider t, String etiket, int n, Color renk) => Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: renk.withValues(alpha: 0.4))),
        child: Column(children: [
          Text('$n', style: TextStyle(color: renk, fontSize: 22, fontWeight: FontWeight.w900)),
          Text(etiket, style: TextStyle(color: t.sub2, fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      );

  Widget _sayimListe(TemaProvider t, String baslik, Color renk, List l, String Function(Map) ust, String Function(Map) alt) => MKart(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          MBolumBaslik(baslik, renk: renk, sayi: l.length),
          if (l.isEmpty)
            Text('Kayıt yok.', style: TextStyle(color: t.sub, fontSize: 12.5))
          else
            for (final x in l.take(200))
              if (x is Map)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 6, height: 6, margin: const EdgeInsets.only(top: 6, right: 8), decoration: BoxDecoration(color: renk, shape: BoxShape.circle)),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(ust(x), style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                        if (alt(x).isNotEmpty) Text(alt(x), style: TextStyle(color: t.sub, fontSize: 11.5)),
                      ]),
                    ),
                  ]),
                ),
          if (l.length > 200) Text('… ve ${l.length - 200} kayıt daha', style: TextStyle(color: t.sub, fontSize: 12)),
        ]),
      );
}

/// Sayım okutma sonucu rengi + ikonu.
(Color, IconData, String) _dmSonucStil(String sonuc) {
  switch (sonuc) {
    case 'bulundu':
      return (_dmYesil, Icons.check_circle, 'Yerinde');
    case 'yanlis_yer':
      return (_dmAmber, Icons.swap_horiz, 'Yanlış yerde');
    case 'tekrar':
      return (_dmGri, Icons.replay, 'Zaten sayıldı');
    default:
      return (_dmKirmizi, Icons.help_outline, 'Tanımsız barkod');
  }
}

Widget _sonucBant(Map r) {
  final (renk, ikon, ad) = _dmSonucStil(_dmS(r['sonuc']));
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(ikon, color: Colors.white, size: 28),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ad, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
          Text(_dmS(r['mesaj']), style: const TextStyle(color: Colors.white, fontSize: 13)),
        ]),
      ),
    ]),
  );
}

// =====================================================================================
// SAYIM — SÜREKLİ KAMERA OKUTMA
// =====================================================================================
class _SayimTarayici extends StatefulWidget {
  final Future<Map<String, dynamic>?> Function(String kod) okut;
  const _SayimTarayici({required this.okut});
  @override
  State<_SayimTarayici> createState() => _SayimTarayiciState();
}

class _SayimTarayiciState extends State<_SayimTarayici> {
  final MobileScannerController _ctrl = MobileScannerController(detectionSpeed: DetectionSpeed.normal);
  bool _mesgul = false;
  String _sonKod = '';
  DateTime _sonZaman = DateTime.fromMillisecondsSinceEpoch(0);
  Map<String, dynamic>? _sonuc;
  Map _sayac = const {};

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _yakala(String kod) async {
    final simdi = DateTime.now();
    // Aynı etiket kamerada dururken tekrar tekrar gönderilmesin
    if (_mesgul || (kod == _sonKod && simdi.difference(_sonZaman).inMilliseconds < 2500)) return;
    _mesgul = true;
    _sonKod = kod;
    _sonZaman = simdi;
    final r = await widget.okut(kod);
    if (!mounted) return;
    if (r != null) {
      final s = _dmS(r['sonuc']);
      if (s == 'bulundu') {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.heavyImpact();
      }
      setState(() {
        _sonuc = r;
        if (r['sayac'] is Map) _sayac = r['sayac'] as Map;
      });
    }
    _sonZaman = DateTime.now();
    _mesgul = false;
  }

  Widget _sayacYazi(String etiket, dynamic n, Color renk) => Column(children: [
        Text('${_dmN(n).toInt()}', style: TextStyle(color: renk, fontSize: 20, fontWeight: FontWeight.w900)),
        Text(etiket, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]);

  @override
  Widget build(BuildContext context) {
    final sonuc = _sonuc;
    final cerceve = sonuc != null ? _dmSonucStil(_dmS(sonuc['sonuc'])).$1 : const Color(0xFF7C3AED);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Sayım — sürekli okut'),
        actions: [IconButton(onPressed: () => _ctrl.toggleTorch(), icon: const Icon(Icons.flash_on), tooltip: 'Fener')],
      ),
      body: Stack(children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: (cap) {
            final b = cap.barcodes.isNotEmpty ? cap.barcodes.first : null;
            final v = b?.rawValue;
            if (v != null && v.trim().isNotEmpty) _yakala(v.trim());
          },
        ),
        Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 260,
            height: 150,
            decoration: BoxDecoration(border: Border.all(color: cerceve, width: 4), borderRadius: BorderRadius.circular(14)),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 24,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (sonuc != null) _sonucBant(sonuc) else
              const Text('Etiketleri sırayla çerçeveye getir', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _sayacYazi('Yerinde', _sayac['bulundu'], const Color(0xFF34D399)),
                _sayacYazi('Yanlış yer', _sayac['yanlis_yer'], const Color(0xFFFBBF24)),
                _sayacYazi('Eksik', _sayac['eksik'], const Color(0xFFF87171)),
                _sayacYazi('Tanımsız', _sayac['bilinmeyen'], const Color(0xFFCBD5E1)),
              ]),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tamam — listeye dön', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

// =====================================================================================
// DETAY (telefon: alt sayfa, masaüstü: dialog)
// =====================================================================================
class _DmMeta {
  final Map<String, String> durumlar;
  final List<String> lokasyonlar;
  final List<String> kategoriler;
  final List<Map> personeller;
  const _DmMeta({required this.durumlar, required this.lokasyonlar, required this.kategoriler, required this.personeller});
}

class _DemirbasDetay extends StatefulWidget {
  final int? id;
  final String? kod;
  final _DmMeta meta;
  final bool dialog;
  final ScrollController? scroll;
  const _DemirbasDetay({this.id, this.kod, required this.meta, required this.dialog, this.scroll});
  @override
  State<_DemirbasDetay> createState() => _DemirbasDetayState();
}

class _DemirbasDetayState extends State<_DemirbasDetay> {
  bool loading = true;
  bool islemde = false;
  bool degisti = false;
  String? hata;
  Map d = const {};
  List bakimlar = const [];
  List hareketler = const [];
  bool duzenler = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  int get _id => _dmN(d['id']).toInt() > 0 ? _dmN(d['id']).toInt() : (widget.id ?? 0);

  Future<void> _yukle() async {
    setState(() => loading = true);
    final res = await _dmCagir(context, (tok) => _dmN(d['id']) > 0 || widget.kod == null
        ? Api.demirbasDetay(tok, id: _id)
        : Api.demirbasDetay(tok, kod: widget.kod));
    if (!mounted) return;
    setState(() {
      loading = false;
      if (res == null) {
        hata ??= 'Bağlantı hatası.';
        return;
      }
      if (_dmOk(res) && res['demirbas'] is Map) {
        hata = null;
        d = res['demirbas'] as Map;
        bakimlar = (res['bakimlar'] as List?) ?? const [];
        hareketler = (res['hareketler'] as List?) ?? const [];
        duzenler = res['duzenler'] == true || res['duzenler'] == 1;
      } else {
        hata = _dmMesaj(res, 'Demirbaş bulunamadı.');
      }
    });
  }

  void _kapat() => Navigator.of(context).pop(degisti);

  Future<void> _islem(String islem, [Map<String, String> ek = const {}]) async {
    setState(() => islemde = true);
    final res = await _dmCagir(context, (tok) => Api.demirbasIslem(tok, _id, islem, ek));
    if (!mounted) return;
    setState(() => islemde = false);
    if (res == null) return;
    _dmBildir(context, _dmMesaj(res, _dmOk(res) ? 'Kaydedildi.' : 'İşlem yapılamadı.'), hata: !_dmOk(res));
    if (_dmOk(res)) {
      degisti = true;
      if (islem == 'sil') {
        _kapat();
        return;
      }
      await _yukle();
    }
  }

  // ---- işlem dialogları ----
  Future<void> _zimmet() async {
    final simdiki = _dmN(d['zimmet_personel_id']).toInt();
    final secim = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final t = Provider.of<TemaProvider>(ctx, listen: false);
        String q = '';
        return StatefulBuilder(builder: (ctx, setS) {
          final l = widget.meta.personeller.where((p) => q.isEmpty || _dmNorm(_dmS(p['ad'])).contains(_dmNorm(q))).toList();
          return AlertDialog(
            backgroundColor: t.card,
            title: Text('Zimmet değiştir', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
            content: SizedBox(
              width: 420,
              height: 420,
              child: Column(children: [
                TextField(onChanged: (x) => setS(() => q = x), style: TextStyle(color: t.ink), decoration: _dmDekor(t, 'Personel ara', onEk: Icon(Icons.search, color: t.sub))),
                const SizedBox(height: 8),
                ListTile(
                  dense: true,
                  leading: Icon(simdiki == 0 ? Icons.radio_button_checked : Icons.radio_button_off, color: _dmGri),
                  title: Text('Zimmet yok (depoda / ortak kullanım)', style: TextStyle(color: t.ink)),
                  onTap: () => Navigator.pop(ctx, 0),
                ),
                Divider(height: 1, color: t.line),
                Expanded(
                  child: ListView(children: [
                    for (final p in l)
                      ListTile(
                        dense: true,
                        leading: Icon(_dmN(p['id']).toInt() == simdiki ? Icons.radio_button_checked : Icons.radio_button_off, color: _dmMor),
                        title: Text(_dmS(p['ad']), style: TextStyle(color: t.ink)),
                        onTap: () => Navigator.pop(ctx, _dmN(p['id']).toInt()),
                      ),
                  ]),
                ),
              ]),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub)))],
          );
        });
      },
    );
    if (secim == null || secim == simdiki) return;
    await _islem('zimmet', {'zimmet_personel_id': secim == 0 ? '' : '$secim'});
  }

  Future<void> _konum() async {
    final c = TextEditingController(text: _dmS(d['lokasyon']));
    final yeni = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final t = Provider.of<TemaProvider>(ctx, listen: false);
        return StatefulBuilder(builder: (ctx, setS) => AlertDialog(
              backgroundColor: t.card,
              title: Text('Konum değiştir', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
              content: SizedBox(
                width: 420,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(controller: c, autofocus: true, style: TextStyle(color: t.ink), decoration: _dmDekor(t, 'Konum', ipucu: 'ör. Mutfak, Bar, Depo, Salon 2')),
                  if (widget.meta.lokasyonlar.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      for (final l in widget.meta.lokasyonlar)
                        ActionChip(
                          label: Text(l, style: TextStyle(color: t.sub2, fontSize: 12)),
                          backgroundColor: t.card2,
                          side: BorderSide(color: t.line),
                          onPressed: () => setS(() => c.text = l),
                        ),
                    ]),
                  ],
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: _dmMor), onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Kaydet')),
              ],
            ));
      },
    );
    c.dispose();
    if (yeni == null || yeni == _dmS(d['lokasyon'])) return;
    await _islem('lokasyon', {'lokasyon': yeni});
  }

  Future<void> _durum() async {
    final simdiki = _dmS(d['durum']);
    final yeni = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final t = Provider.of<TemaProvider>(ctx, listen: false);
        return AlertDialog(
          backgroundColor: t.card,
          title: Text('Durum değiştir', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            for (final e in widget.meta.durumlar.entries)
              ListTile(
                dense: true,
                leading: Icon(e.key == simdiki ? Icons.radio_button_checked : Icons.radio_button_off, color: _dmDurumRenk[e.key] ?? _dmGri),
                title: Text(e.value, style: TextStyle(color: t.ink, fontWeight: e.key == simdiki ? FontWeight.w800 : FontWeight.w500)),
                onTap: () => Navigator.pop(ctx, e.key),
              ),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub)))],
        );
      },
    );
    if (yeni == null || yeni == simdiki) return;
    await _islem('durum', {'durum': yeni});
  }

  Future<void> _bakim() async {
    String tip = 'bakim';
    DateTime tarih = DateTime.now();
    final acikC = TextEditingController();
    final maliyetC = TextEditingController();
    final tamam = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = Provider.of<TemaProvider>(ctx, listen: false);
        return StatefulBuilder(builder: (ctx, setS) => AlertDialog(
              backgroundColor: t.card,
              title: Text('Bakım / Arıza ekle', style: TextStyle(color: t.ink, fontWeight: FontWeight.w800, fontSize: 17)),
              content: SizedBox(
                width: 420,
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    for (final x in const [('bakim', 'Bakım', Icons.build_outlined), ('ariza', 'Arıza', Icons.report_problem_outlined)])
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            avatar: Icon(x.$3, size: 16, color: tip == x.$1 ? Colors.white : t.sub2),
                            label: Text(x.$2),
                            selected: tip == x.$1,
                            showCheckmark: false,
                            selectedColor: x.$1 == 'ariza' ? _dmTuruncu : _dmAmber,
                            backgroundColor: t.card2,
                            labelStyle: TextStyle(color: tip == x.$1 ? Colors.white : t.sub2, fontWeight: FontWeight.w700),
                            onSelected: (_) => setS(() => tip = x.$1),
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final s = await showDatePicker(context: ctx, initialDate: tarih, firstDate: DateTime(2015), lastDate: DateTime(2100));
                      if (s != null) setS(() => tarih = s);
                    },
                    child: InputDecorator(
                      decoration: _dmDekor(t, 'Tarih', onEk: Icon(Icons.event, color: t.sub)),
                      child: Text(DateFormat('dd.MM.yyyy').format(tarih), style: TextStyle(color: t.ink)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: acikC, minLines: 2, maxLines: 4, style: TextStyle(color: t.ink), decoration: _dmDekor(t, 'Açıklama', ipucu: 'Ne yapıldı / ne arızalandı?')),
                  const SizedBox(height: 10),
                  TextField(controller: maliyetC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: TextStyle(color: t.ink), decoration: _dmDekor(t, 'Maliyet (₺)', ipucu: 'Boş = 0')),
                ]),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
                FilledButton(style: FilledButton.styleFrom(backgroundColor: _dmMor), onPressed: () => Navigator.pop(ctx, true), child: const Text('Kaydet')),
              ],
            ));
      },
    );
    final aciklama = acikC.text.trim();
    final maliyet = maliyetC.text.trim().replaceAll(',', '.');
    acikC.dispose();
    maliyetC.dispose();
    if (tamam != true) return;
    await _islem('bakim', {'tip': tip, 'tarih': DateFormat('yyyy-MM-dd').format(tarih), 'aciklama': aciklama, 'maliyet': maliyet.isEmpty ? '0' : maliyet});
  }

  Future<void> _duzenle() async {
    final sonuc = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(builder: (_) => _DemirbasForm(meta: widget.meta, mevcut: d)));
    if (sonuc == null || !mounted) return;
    degisti = true;
    await _yukle();
  }

  Future<void> _sil() async {
    final ok = await _dmOnayIste(context, 'Demirbaşı sil', '"${_dmS(d['ad'])}" kalıcı olarak silinecek; bakım ve hareket geçmişi de silinir. Emin misin?', 'Sil', _dmKirmizi);
    if (ok) await _islem('sil');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final ic = loading && d.isEmpty
        ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
        : (hata != null && d.isEmpty)
            ? Padding(
                padding: const EdgeInsets.all(30),
                child: Column(children: [
                  const Icon(Icons.search_off, color: _dmAmber, size: 40),
                  const SizedBox(height: 10),
                  Text(hata!, textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)),
                ]),
              )
            : _icerik(t);
    return Container(
      decoration: BoxDecoration(
        color: t.bg,
        borderRadius: widget.dialog ? BorderRadius.circular(18) : const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
          if (!widget.dialog) ...[
            const SizedBox(height: 10),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(4))),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 6, 6),
            child: Row(children: [
              const Icon(Icons.qr_code_2, color: _dmMor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(d.isEmpty ? 'Demirbaş' : _dmS(d['ad']),
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontWeight: FontWeight.w900, fontSize: 17)),
              ),
              if (islemde || (loading && d.isNotEmpty)) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              IconButton(onPressed: _kapat, icon: Icon(Icons.close, color: t.sub2), tooltip: 'Kapat'),
            ]),
          ),
          Divider(height: 1, color: t.line),
          Expanded(
            child: ListView(controller: widget.scroll, padding: const EdgeInsets.all(14), children: [ic]),
          ),
        ]),
    );
  }

  Widget _alan(TemaProvider t, String etiket, String deger) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 120, child: Text(etiket, style: TextStyle(color: t.sub, fontSize: 12.5))),
          Expanded(child: Text(deger.isEmpty ? '—' : deger, style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600))),
        ]),
      );

  Widget _icerik(TemaProvider t) {
    final genis = widget.dialog;
    final durumK = _dmS(d['durum']);
    final durumRenk = _dmDurumRenk[durumK] ?? _dmGri;
    final adet = _dmN(d['adet']).toInt();
    final garanti = _dmS(d['garanti_bitis']);
    final garantiTarih = DateTime.tryParse(garanti);
    final garantiNot = garantiTarih == null
        ? ''
        : (garantiTarih.isBefore(DateTime.now()) ? ' (bitti)' : (garantiTarih.difference(DateTime.now()).inDays <= 30 ? ' (30 gün içinde bitiyor)' : ''));

    final barkodKutu = MKart(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        const Icon(Icons.qr_code_2, color: _dmMor, size: 34),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Barkod', style: TextStyle(color: t.sub, fontSize: 11.5)),
            SelectableText(_dmS(d['barkod']), style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontFamily: 'monospace')),
          ]),
        ),
        MRozet(_dmS(d['durum_ad']).isNotEmpty ? _dmS(d['durum_ad']) : (widget.meta.durumlar[durumK] ?? durumK), durumRenk),
      ]),
    );

    final bilgiler = MKart(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const MBolumBaslik('Kart bilgileri', renk: _dmMor),
        _alan(t, 'Ad', _dmS(d['ad'])),
        _alan(t, 'Demirbaş kodu', _dmS(d['kod'])),
        _alan(t, 'Kategori', _dmS(d['kategori'])),
        _alan(t, 'Konum', _dmS(d['lokasyon'])),
        _alan(t, 'Zimmet', _dmS(d['zimmet_ad'])),
        _alan(t, 'Marka / model', [d['marka'], d['model']].map(_dmS).where((e) => e.isNotEmpty).join(' / ')),
        _alan(t, 'Seri no', _dmS(d['seri_no'])),
        _alan(t, 'Tedarikçi', _dmS(d['tedarikci'])),
        _alan(t, 'Alış tarihi', _dmTarih(d['alis_tarih'])),
        _alan(t, 'Alış bedeli', _dmN(d['alis_bedel']) > 0 ? '${_dmTl(d['alis_bedel'])}${adet > 1 ? ' × $adet adet' : ''}' : ''),
        _alan(t, 'Adet', '$adet'),
        _alan(t, 'Garanti bitişi', garanti.isEmpty ? '' : '${_dmTarih(garanti)}$garantiNot'),
        _alan(t, 'Son sayım', _dmS(d['son_sayim']).isEmpty ? 'Hiç sayılmadı' : _dmTarih(d['son_sayim'])),
        _alan(t, 'Not', _dmS(d['not'])),
      ]),
    );

    final aksiyonlar = Wrap(spacing: 8, runSpacing: 8, children: [
      MButon('Etiket bas', _dmMor, () => _dmEtiketBas(context, [_id]), ikon: Icons.print),
      if (duzenler) ...[
        MButon('Zimmet değiştir', _dmMavi, _zimmet, dolu: false, ikon: Icons.badge_outlined),
        MButon('Konum değiştir', _dmMavi, _konum, dolu: false, ikon: Icons.place_outlined),
        MButon('Durum değiştir', _dmMavi, _durum, dolu: false, ikon: Icons.swap_vert),
        MButon('Bakım / Arıza ekle', _dmAmber, _bakim, dolu: false, ikon: Icons.build_outlined),
        MButon('Düzenle', _dmMavi, _duzenle, dolu: false, ikon: Icons.edit_outlined),
        MButon('Sil', _dmKirmizi, _sil, dolu: false, ikon: Icons.delete_outline),
      ],
    ]);

    final bakimKart = MKart(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MBolumBaslik('Bakım / arıza kayıtları', renk: _dmAmber, sayi: bakimlar.length),
        if (bakimlar.isEmpty)
          Text('Bakım ya da arıza kaydı yok.', style: TextStyle(color: t.sub, fontSize: 12.5))
        else
          for (final b in bakimlar)
            if (b is Map)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(b['tip'] == 'ariza' ? Icons.report_problem_outlined : Icons.build_outlined, size: 18, color: b['tip'] == 'ariza' ? _dmTuruncu : _dmAmber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${b['tip'] == 'ariza' ? 'Arıza' : 'Bakım'} · ${_dmTarih(b['tarih'])}', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
                      if (_dmS(b['aciklama']).isNotEmpty) Text(_dmS(b['aciklama']), style: TextStyle(color: t.sub2, fontSize: 12.5)),
                    ]),
                  ),
                  if (_dmN(b['maliyet']) > 0) Text(_dmTl(b['maliyet']), style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
              ),
      ]),
    );

    String hareketMetin(Map h) {
      const tipAd = {'olustur': 'Kayıt açıldı', 'zimmet': 'Zimmet', 'lokasyon': 'Konum', 'durum': 'Durum', 'bakim': 'Bakım/arıza', 'sayim': 'Sayım', 'duzenle': 'Düzenlendi'};
      final tip = tipAd[_dmS(h['tip'])] ?? _dmS(h['tip']);
      final eski = _dmS(h['eski']), yeni = _dmS(h['yeni']);
      final degisim = (eski.isNotEmpty || yeni.isNotEmpty) ? ': ${eski.isEmpty ? '—' : eski} → ${yeni.isEmpty ? '—' : yeni}' : '';
      return '$tip$degisim';
    }

    final hareketKart = MKart(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MBolumBaslik('Hareket geçmişi', renk: _dmMavi, sayi: hareketler.length),
        if (hareketler.isEmpty)
          Text('Hareket kaydı yok.', style: TextStyle(color: t.sub, fontSize: 12.5))
        else
          for (final h in hareketler)
            if (h is Map)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(width: 7, height: 7, margin: const EdgeInsets.only(top: 6, right: 8), decoration: const BoxDecoration(color: _dmMavi, shape: BoxShape.circle)),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(hareketMetin(h), style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text(
                        [_dmTarih(h['tarih']), _dmS(h['kim']), _dmS(h['aciklama'])].where((e) => e.isNotEmpty).join(' · '),
                        style: TextStyle(color: t.sub, fontSize: 11.5),
                      ),
                    ]),
                  ),
                ]),
              ),
      ]),
    );

    if (genis) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        barkodKutu,
        const SizedBox(height: 12),
        aksiyonlar,
        const SizedBox(height: 12),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: bilgiler),
          const SizedBox(width: 12),
          Expanded(child: Column(children: [hareketKart, const SizedBox(height: 12), bakimKart])),
        ]),
      ]);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      barkodKutu,
      const SizedBox(height: 12),
      aksiyonlar,
      const SizedBox(height: 12),
      bilgiler,
      const SizedBox(height: 12),
      hareketKart,
      const SizedBox(height: 12),
      bakimKart,
      const SizedBox(height: 20),
    ]);
  }
}

// =====================================================================================
// EKLE / DÜZENLE FORMU (telefon ve masaüstü: sayfa; masaüstünde ortalanmış 2 sütun)
// =====================================================================================
class _DemirbasForm extends StatefulWidget {
  final _DmMeta meta;
  final Map? mevcut;
  const _DemirbasForm({required this.meta, this.mevcut});
  @override
  State<_DemirbasForm> createState() => _DemirbasFormState();
}

class _DemirbasFormState extends State<_DemirbasForm> {
  late final Map<String, TextEditingController> c;
  String durum = 'aktif';
  int zimmet = 0;
  bool kaydediliyor = false;

  bool get yeni => widget.mevcut == null;

  static const _alanlar = ['ad', 'barkod', 'kod', 'kategori', 'lokasyon', 'marka', 'model', 'seri_no', 'tedarikci', 'alis_tarih', 'alis_bedel', 'adet', 'garanti_bitis', 'not'];

  @override
  void initState() {
    super.initState();
    final m = widget.mevcut ?? const {};
    c = {for (final k in _alanlar) k: TextEditingController(text: _dmS(m[k]))};
    if (yeni) c['adet']!.text = '1';
    final bedel = _dmN(m['alis_bedel']);
    if (!yeni) c['alis_bedel']!.text = bedel > 0 ? bedel.toString() : '';
    for (final k in ['alis_tarih', 'garanti_bitis']) {
      final s = c[k]!.text;
      if (s.length > 10) c[k]!.text = s.substring(0, 10);
    }
    durum = widget.meta.durumlar.containsKey(_dmS(m['durum'])) ? _dmS(m['durum']) : 'aktif';
    zimmet = _dmN(m['zimmet_personel_id']).toInt();
    if (!widget.meta.personeller.any((p) => _dmN(p['id']).toInt() == zimmet)) zimmet = 0;
  }

  @override
  void dispose() {
    for (final x in c.values) {
      x.dispose();
    }
    super.dispose();
  }

  Future<void> _barkodOkut() async {
    final kod = await BarkodTarayici.oku(context, baslik: 'Hazır barkodu okut');
    if (kod != null && mounted) setState(() => c['barkod']!.text = kod);
  }

  Future<void> _tarihSec(String k) async {
    final s = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(c[k]!.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (s != null && mounted) setState(() => c[k]!.text = DateFormat('yyyy-MM-dd').format(s));
  }

  Future<void> _kaydet() async {
    if (c['ad']!.text.trim().isEmpty) {
      _dmBildir(context, 'Ad zorunlu.', hata: true);
      return;
    }
    final barkod = c['barkod']!.text.trim();
    if (barkod.isNotEmpty && !RegExp(r'^[\x21-\x7E]{1,64}$').hasMatch(barkod)) {
      _dmBildir(context, 'Barkod yalnız harf, rakam ve işaret içerebilir (Türkçe karakter ve boşluk olmaz).', hata: true);
      return;
    }
    setState(() => kaydediliyor = true);
    final body = <String, String>{
      if (!yeni) 'id': '${_dmN(widget.mevcut!['id']).toInt()}',
      for (final k in _alanlar) k: c[k]!.text.trim(),
      'alis_bedel': c['alis_bedel']!.text.trim().replaceAll(',', '.'),
      'durum': durum,
      'zimmet_personel_id': zimmet > 0 ? '$zimmet' : '',
    };
    final res = await _dmCagir(context, (tok) => Api.demirbasKaydet(tok, body));
    if (!mounted) return;
    setState(() => kaydediliyor = false);
    if (res == null) return;
    if (_dmOk(res)) {
      _dmBildir(context, _dmMesaj(res, 'Kaydedildi.'));
      Navigator.of(context).pop(<String, dynamic>{'id': res['id'], 'barkod': res['barkod']});
    } else {
      _dmBildir(context, _dmMesaj(res, 'Kaydedilemedi.'), hata: true);
    }
  }

  Widget _tf(TemaProvider t, String k, String etiket, {String? ipucu, TextInputType? klavye, Widget? sonEk, int satir = 1, VoidCallback? onTap, List<String> oneriler = const []}) {
    final alan = TextField(
      controller: c[k],
      keyboardType: klavye,
      minLines: satir,
      maxLines: satir == 1 ? 1 : satir + 2,
      readOnly: onTap != null,
      onTap: onTap,
      style: TextStyle(color: t.ink),
      decoration: _dmDekor(t, etiket, ipucu: ipucu, sonEk: sonEk),
    );
    if (oneriler.isEmpty) return alan;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      alan,
      const SizedBox(height: 6),
      Wrap(spacing: 6, runSpacing: 6, children: [
        for (final o in oneriler.take(12))
          ActionChip(
            visualDensity: VisualDensity.compact,
            label: Text(o, style: TextStyle(color: t.sub2, fontSize: 11.5)),
            backgroundColor: t.card2,
            side: BorderSide(color: t.line),
            onPressed: () => setState(() => c[k]!.text = o),
          ),
      ]),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final genis = genisMi(context);

    Widget tarihAlan(String k, String etiket) => _tf(t, k, etiket,
        ipucu: 'Seçmek için dokun',
        onTap: () => _tarihSec(k),
        sonEk: c[k]!.text.isEmpty
            ? Icon(Icons.event, color: t.sub)
            : IconButton(icon: Icon(Icons.close, color: t.sub, size: 18), onPressed: () => setState(() => c[k]!.clear())));

    final temel = [
      _tf(t, 'ad', 'Ad *', ipucu: 'ör. Konveksiyonel fırın, POS tableti'),
      _tf(t, 'barkod', 'Barkod', ipucu: 'Boş bırakırsan sistem verir (DM000123)',
          sonEk: IconButton(tooltip: 'Hazır barkodu okut', icon: Icon(Icons.qr_code_scanner, color: _dmMor), onPressed: _barkodOkut)),
      _tf(t, 'kod', 'Demirbaş kodu', ipucu: 'Muhasebe/iç kod (isteğe bağlı)'),
      _tf(t, 'kategori', 'Kategori', ipucu: 'ör. Mutfak ekipmanı, Elektronik', oneriler: widget.meta.kategoriler),
      _tf(t, 'lokasyon', 'Konum', ipucu: 'ör. Mutfak, Bar, Depo', oneriler: widget.meta.lokasyonlar),
      DropdownButtonFormField<int>(
        initialValue: zimmet,
        isExpanded: true,
        dropdownColor: t.card,
        style: TextStyle(color: t.ink, fontSize: 14),
        decoration: _dmDekor(t, 'Zimmet'),
        items: [
          const DropdownMenuItem(value: 0, child: Text('Zimmet yok')),
          for (final p in widget.meta.personeller) DropdownMenuItem(value: _dmN(p['id']).toInt(), child: Text(_dmS(p['ad']))),
        ],
        onChanged: (x) => setState(() => zimmet = x ?? 0),
      ),
      DropdownButtonFormField<String>(
        initialValue: durum,
        dropdownColor: t.card,
        style: TextStyle(color: t.ink, fontSize: 14),
        decoration: _dmDekor(t, 'Durum'),
        items: [for (final e in widget.meta.durumlar.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (x) => setState(() => durum = x ?? durum),
      ),
    ];
    final ek = [
      Row(children: [Expanded(child: _tf(t, 'marka', 'Marka')), const SizedBox(width: 10), Expanded(child: _tf(t, 'model', 'Model'))]),
      _tf(t, 'seri_no', 'Seri no'),
      _tf(t, 'tedarikci', 'Tedarikçi'),
      Row(children: [
        Expanded(child: tarihAlan('alis_tarih', 'Alış tarihi')),
        const SizedBox(width: 10),
        Expanded(child: _tf(t, 'alis_bedel', 'Alış bedeli (₺)', klavye: const TextInputType.numberWithOptions(decimal: true))),
      ]),
      Row(children: [
        Expanded(child: _tf(t, 'adet', 'Adet', klavye: TextInputType.number)),
        const SizedBox(width: 10),
        Expanded(child: tarihAlan('garanti_bitis', 'Garanti bitişi')),
      ]),
      _tf(t, 'not', 'Not', satir: 3),
    ];

    Widget sutun(List<Widget> l) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (final w in l) Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
        ]);

    final kaydetBtn = SizedBox(
      height: 50,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: _dmMor),
        onPressed: kaydediliyor ? null : _kaydet,
        icon: kaydediliyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save),
        label: Text(yeni ? 'Kaydet ve barkod ver' : 'Değişiklikleri kaydet', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      ),
    );

    return MasaustuSayfa(
      baslik: yeni ? 'Yeni demirbaş' : 'Demirbaşı düzenle',
      ikon: Icons.qr_code_2,
      geri: true,
      altBaslik: yeni ? 'Barkodu boş bırakırsan sistem verir' : _dmS(widget.mevcut?['ad']),
      govde: ListView(
        padding: EdgeInsets.all(genis ? 20 : 12),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 980),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (genis)
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: MKart(child: sutun([const MBolumBaslik('Temel bilgiler', renk: _dmMor), ...temel]))),
                    const SizedBox(width: 14),
                    Expanded(child: MKart(child: sutun([const MBolumBaslik('Alış · garanti · not', renk: _dmMavi), ...ek]))),
                  ])
                else ...[
                  MKart(child: sutun([const MBolumBaslik('Temel bilgiler', renk: _dmMor), ...temel])),
                  const SizedBox(height: 12),
                  MKart(child: sutun([const MBolumBaslik('Alış · garanti · not', renk: _dmMavi), ...ek])),
                ],
                const SizedBox(height: 14),
                kaydetBtn,
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

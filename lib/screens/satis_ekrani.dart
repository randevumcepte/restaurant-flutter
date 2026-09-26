import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../services/yazici_servisi.dart';
import '../responsive.dart';
import 'cari_hesaplar_screen.dart';
import 'barkod_tarayici.dart';
import 'fis.dart';

/// SATIŞ EKRANI (POS) — masaya tıklayınca: SOLDA resimli ürün ızgarası (kategori sekmeli),
/// SAĞDA o masanın adisyonu + toplam + hızlı ödeme. Kerzz/Adisyo tarzı tek-ekran POS.
class SatisEkrani extends StatefulWidget {
  final int adisyonId;
  final String masaAd;
  const SatisEkrani({super.key, required this.adisyonId, required this.masaAd});
  @override
  State<SatisEkrani> createState() => _SatisEkraniState();
}

class _SatisEkraniState extends State<SatisEkrani> {
  final _f = NumberFormat.decimalPattern('tr');
  List kategoriler = [];
  List urunler = [];
  final Map<int, Map> _urunById = {};
  final Map<int, int> _pending = {}; // yeni eklenecek: urunId -> adet
  List _kalemler = []; // KAYITLI kalemler (id + odeme_durum)
  final Set<int> _secili = {}; // kalem-bazlı böl: seçili kalem id'leri
  double _toplamHepsi = 0;
  double _kayitliToplam = 0; // ödenmemiş (kalan) toplam
  int? _kat;
  String _ara = '';
  bool loading = true;
  bool _mesgul = false;
  Map? _fis; // fiş basımı için

  static const _mor = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);
  static const _turuncu = Color(0xFFF59E0B);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tl(num v) {
    final d = v.toDouble();
    return d == d.roundToDouble() ? '${_f.format(d.round())} TL' : '${_f.format(d)} TL';
  }

  double get _pendingTutar {
    double t = 0;
    _pending.forEach((id, adet) => t += _n(_urunById[id]?['fiyat']).toDouble() * adet);
    return t;
  }

  double get _genelToplam => _kayitliToplam + _pendingTutar;
  int get _pendingAdet => _pending.values.fold(0, (a, b) => a + b);

  double get _seciliTutar {
    double t = 0;
    for (final k in _kalemler) {
      final m = k as Map;
      if (_secili.contains(_n(m['id']).toInt()) && m['odeme_durum'] != 'odendi') t += _n(m['tutar']).toDouble();
    }
    return t;
  }
  double get _odenecek => _secili.isEmpty ? _kayitliToplam : _seciliTutar;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final menu = await Api.menu(auth.token!);
      final fis = await Api.fis(auth.token!, widget.adisyonId);
      final kl = await Api.adisyonKalemleri(auth.token!, widget.adisyonId);
      if (!mounted) return;
      kategoriler = (menu['kategoriler'] as List?) ?? [];
      urunler = (menu['urunler'] as List?) ?? [];
      _urunById.clear();
      for (final u in urunler) {
        _urunById[_n((u as Map)['id']).toInt()] = u;
      }
      _kat ??= kategoriler.isNotEmpty ? _n((kategoriler.first as Map)['id']).toInt() : null;
      if (fis['ok'] == 1) _fis = fis;
      if (kl['ok'] == 1) {
        _kalemler = (kl['kalemler'] as List?) ?? [];
        _toplamHepsi = _n(kl['toplam']).toDouble();
        _kayitliToplam = _n(kl['kalan']).toDouble();
      }
      _secili.removeWhere((id) => !_kalemler.any((k) => _n((k as Map)['id']).toInt() == id && k['odeme_durum'] != 'odendi'));
      setState(() => loading = false);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String m, Color c) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: c, duration: const Duration(seconds: 2)));
  }

  void _ekle(int id) => setState(() => _pending[id] = (_pending[id] ?? 0) + 1);
  void _azalt(int id) => setState(() {
        final a = (_pending[id] ?? 0) - 1;
        if (a <= 0) { _pending.remove(id); } else { _pending[id] = a; }
      });

  // Bekleyen yeni ürünleri adisyona kaydet (yoksa true döner).
  Future<bool> _kaydet() async {
    if (_pending.isEmpty) return true;
    if (_mesgul) return false;
    setState(() => _mesgul = true);
    final auth = context.read<AuthProvider>();
    final kalemler = _pending.entries.map((e) => {'urun_id': e.key, 'adet': e.value}).toList();
    try {
      final res = await Api.adisyonUrunEkle(auth.token!, widget.adisyonId, kalemler);
      if (!mounted) return false;
      if (res['ok'] == 1) {
        _pending.clear();
        await _yukle();
        setState(() => _mesgul = false);
        return true;
      }
      setState(() => _mesgul = false);
      _snack(res['hata']?.toString() ?? 'Kaydedilemedi', _kirmizi);
      return false;
    } catch (_) {
      if (mounted) { setState(() => _mesgul = false); _snack('Bağlantı hatası', _kirmizi); }
      return false;
    }
  }

  Future<void> _barkodOkut() async {
    final kod = await BarkodTarayici.oku(context, baslik: 'Ürün Barkodu Okut');
    if (kod == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final r = await Api.barkodCoz(auth.token!, kod);
      if (!mounted) return;
      if (r['ok'] == 1 && r['tur'] == 'urun') {
        _ekle(_n(r['id']).toInt());
        _snack('${r['ad']} eklendi', _yesil);
      } else {
        _snack(r['hata']?.toString() ?? 'Barkod tanımlı değil', _turuncu);
      }
    } catch (_) {}
  }

  // ---- ÖDEME ----
  Future<void> _ode(String tip) async {
    if (_mesgul) return;
    final secimVar = _secili.isNotEmpty;
    if (!secimVar && _genelToplam <= 0) { _snack('Adisyon boş', _turuncu); return; }
    // Seçim yoksa bekleyen ürünleri önce kaydet (tümünü öde). Seçim varsa sadece seçilenleri öde.
    if (!secimVar && _pending.isNotEmpty) {
      final ok = await _kaydet();
      if (!ok) return;
    }
    if (tip == 'acik_hesap') { await _acikHesap(); return; }
    final onay = await _odeOnay(tip);
    if (onay != true || !mounted) return;
    setState(() => _mesgul = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.adisyonIslem(auth.token!, islem: 'ode', adisyonId: widget.adisyonId, odemeTip: tip,
          tutar: secimVar ? 0 : _kayitliToplam, kalemIdler: secimVar ? _secili.join(',') : null);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() { _mesgul = false; _secili.clear(); });
        if (res['kapandi'] == true) { await _bitir(); } else { await _yukle(); _snack(res['mesaj']?.toString() ?? 'Ödeme alındı', _yesil); }
      } else {
        setState(() => _mesgul = false);
        _snack(res['hata']?.toString() ?? 'Ödeme alınamadı', _kirmizi);
      }
    } catch (_) {
      if (mounted) { setState(() => _mesgul = false); _snack('Bağlantı hatası', _kirmizi); }
    }
  }

  Future<bool?> _odeOnay(String tip) {
    final ad = {'nakit': 'Nakit', 'kredi': 'Kredi Kartı', 'yemek_karti': 'Yemek Kartı'}[tip] ?? tip;
    final renk = {'nakit': _yesil, 'kredi': _mavi, 'yemek_karti': _turuncu}[tip] ?? _mor;
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = ctx.read<TemaProvider>();
        return AlertDialog(
          backgroundColor: t.card,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('$ad ile Öde', style: TextStyle(color: t.ink, fontSize: 16)),
          content: Text(_secili.isEmpty
              ? '${_tl(_odenecek)} tahsil edilip masa kapatılsın mı?'
              : 'Seçili ${_secili.length} kalem için ${_tl(_odenecek)} tahsil edilsin mi?', style: TextStyle(color: t.sub, fontSize: 14)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: renk), child: const Text('Onayla')),
          ],
        );
      },
    );
  }

  Future<void> _acikHesap() async {
    final cari = await Navigator.of(context).push<Map>(MaterialPageRoute(builder: (_) => const CariHesaplarScreen(secmeMod: true)));
    if (cari == null || !mounted) return;
    setState(() => _mesgul = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.adisyonIslem(auth.token!, islem: 'kapat', adisyonId: widget.adisyonId, odemeTip: 'acik_hesap', cariId: _n(cari['id']).toInt());
      if (!mounted) return;
      setState(() => _mesgul = false);
      if (res['ok'] == 1) { await _bitir(); } else { _snack(res['hata']?.toString() ?? 'İşlem başarısız', _kirmizi); }
    } catch (_) {
      if (mounted) { setState(() => _mesgul = false); _snack('Bağlantı hatası', _kirmizi); }
    }
  }

  Future<void> _bitir() async {
    try {
      final y = YaziciServisi();
      await y.yukle();
      if (y.ayarli && _fis != null) await y.hesapFisi(_fis!);
    } catch (_) {}
    if (!mounted) return;
    _snack('Ödeme tamamlandı, masa kapatıldı', _yesil);
    Navigator.of(context).pop(true);
  }

  // ---- İKİNCİL İŞLEMLER (iskonto/ikram/iptal) ----
  Future<void> _islemUygula(String islem, {double? oran, double? tutar, String? onayPin}) async {
    setState(() => _mesgul = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.adisyonIslem(auth.token!, islem: islem, adisyonId: widget.adisyonId, oran: oran, tutar: tutar, onayPin: onayPin);
      if (!mounted) return;
      setState(() => _mesgul = false);
      if (res['ok'] == 1) {
        _snack(res['mesaj']?.toString() ?? 'Tamamlandı', _yesil);
        if (islem == 'iptal') { Navigator.of(context).pop(true); } else { await _yukle(); }
      } else if (res['onay_gerek'] == true) {
        final pin = await _pinSor(res['hata']?.toString() ?? 'Yetkili PIN onayı gerekli');
        if (pin != null && pin.trim().isNotEmpty) await _islemUygula(islem, oran: oran, tutar: tutar, onayPin: pin.trim());
      } else {
        _snack(res['hata']?.toString() ?? 'İşlem başarısız', _kirmizi);
      }
    } catch (_) {
      if (mounted) { setState(() => _mesgul = false); _snack('Bağlantı hatası', _kirmizi); }
    }
  }

  Future<void> _iskonto() async {
    final oran = await _sayiDialog('İskonto Uygula', 'Yüzde (%)', '%');
    if (oran == null || oran <= 0) return;
    await _islemUygula('iskonto', oran: oran);
  }

  Future<void> _ikram() async {
    final tutar = await _sayiDialog('İkram Uygula', 'Tutar (TL)', 'TL');
    if (tutar == null || tutar <= 0) return;
    await _islemUygula('ikram', tutar: tutar);
  }

  Future<void> _iptal() async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final t = ctx.read<TemaProvider>();
        return AlertDialog(
          backgroundColor: t.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Adisyonu İptal Et', style: TextStyle(color: t.ink, fontSize: 16)),
          content: Text('${widget.masaAd} adisyonu iptal edilsin mi? Bu işlem geri alınamaz.', style: TextStyle(color: t.sub, fontSize: 14)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: _kirmizi), child: const Text('İptal Et')),
          ],
        );
      },
    );
    if (onay == true) await _islemUygula('iptal');
  }

  Future<void> _fisBas() async {
    if (_pending.isNotEmpty) { final ok = await _kaydet(); if (!ok) return; }
    if (_fis == null) return;
    final y = YaziciServisi();
    await y.yukle();
    if (y.ayarli) {
      final s = await y.hesapFisi(_fis!);
      _snack(s == 'ok' ? '✓ Fiş yazıcıya gönderildi' : s, s == 'ok' ? _yesil : _kirmizi);
    } else if (mounted) {
      await fisYazdir(context, _fis!); // yazıcı yoksa PDF önizleme
    }
  }

  Future<String?> _pinSor(String mesaj) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final t = ctx.read<TemaProvider>();
        return AlertDialog(
          backgroundColor: t.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('🔒 Yetkili Onayı', style: TextStyle(color: t.ink, fontSize: 16)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(mesaj, style: TextStyle(color: t.sub, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(controller: c, keyboardType: TextInputType.number, obscureText: true, autofocus: true,
                style: TextStyle(color: t.ink, letterSpacing: 6), textAlign: TextAlign.center,
                decoration: InputDecoration(hintText: 'Müdür/Sahip PIN', filled: true, fillColor: t.card2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text), style: FilledButton.styleFrom(backgroundColor: _mor), child: const Text('Onayla')),
          ],
        );
      },
    );
  }

  Future<double?> _sayiDialog(String baslik, String ipuc, String suffix) {
    final c = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (ctx) {
        final t = ctx.read<TemaProvider>();
        return AlertDialog(
          backgroundColor: t.card, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(baslik, style: TextStyle(color: t.ink, fontSize: 16)),
          content: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true,
              style: TextStyle(color: t.ink, fontSize: 18),
              decoration: InputDecoration(hintText: ipuc, suffixText: suffix, filled: true, fillColor: t.card2, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none))),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
            FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(c.text.replaceAll(',', '.'))), style: FilledButton.styleFrom(backgroundColor: _mor), child: const Text('Uygula')),
          ],
        );
      },
    );
  }

  // ---- KISMI / BÖL / PARA ÜSTÜ (numpad sheet) ----
  Future<void> _kismiSheet() async {
    if (_pending.isNotEmpty) { final ok = await _kaydet(); if (!ok) return; }
    if (!mounted || _kayitliToplam <= 0) return;
    String giris = '';
    await showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) {
        final t = ctx.read<TemaProvider>();
        return StatefulBuilder(builder: (ctx, setSt) {
          final kalan = _kayitliToplam;
          final girilen = double.tryParse(giris) ?? 0;
          final paraUstu = girilen > kalan ? girilen - kalan : 0.0;
          void bas(String d) => setSt(() { if (d == '.' && giris.contains('.')) return; if (giris.length < 9) giris += d; });
          Future<void> al(String tip) async {
            final istenen = giris.isEmpty ? kalan : girilen;
            if (istenen <= 0) return;
            final uygulanan = istenen > kalan ? kalan : istenen;
            Navigator.pop(ctx);
            setState(() => _mesgul = true);
            final auth = context.read<AuthProvider>();
            try {
              final res = await Api.adisyonIslem(auth.token!, islem: 'ode', adisyonId: widget.adisyonId, odemeTip: tip, tutar: uygulanan);
              if (!mounted) return;
              setState(() => _mesgul = false);
              if (res['ok'] == 1) {
                if (tip == 'nakit' && paraUstu > 0) _snack('Para üstü: ${_tl(paraUstu)}', _turuncu);
                if (res['kapandi'] == true) { await _bitir(); } else { await _yukle(); }
              } else {
                _snack(res['hata']?.toString() ?? 'Ödeme alınamadı', _kirmizi);
              }
            } catch (_) {
              if (mounted) { setState(() => _mesgul = false); _snack('Bağlantı hatası', _kirmizi); }
            }
          }
          Widget tus(String d, {IconData? ikon, VoidCallback? onTap}) => Expanded(child: Padding(padding: const EdgeInsets.all(4), child: Material(
            color: t.card2, borderRadius: BorderRadius.circular(12),
            child: InkWell(borderRadius: BorderRadius.circular(12), onTap: onTap ?? () => bas(d), child: Container(height: 46, alignment: Alignment.center, child: ikon != null ? Icon(ikon, color: t.ink) : Text(d, style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.bold)))),
          )));
          Widget odeK(String tip, String ad, Color renk) => Expanded(child: Padding(padding: const EdgeInsets.all(4), child: Material(
            color: renk, borderRadius: BorderRadius.circular(12),
            child: InkWell(borderRadius: BorderRadius.circular(12), onTap: () => al(tip), child: Container(height: 46, alignment: Alignment.center, child: Text(ad, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)))),
          )));
          return Container(
            padding: EdgeInsets.only(left: 14, right: 14, top: 14, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
            decoration: BoxDecoration(color: t.card, borderRadius: const BorderRadius.vertical(top: Radius.circular(22))),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(2))),
              Row(children: [
                Text('Kalan', style: TextStyle(color: t.sub, fontSize: 13)),
                const Spacer(),
                Text(_tl(kalan), style: TextStyle(color: t.mor1, fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Text('Alınan', style: TextStyle(color: t.sub, fontSize: 13)),
                  const Spacer(),
                  Text(giris.isEmpty ? '—' : '${_f.format(girilen)} TL', style: TextStyle(color: t.ink, fontSize: 22, fontWeight: FontWeight.bold)),
                ]),
              ),
              if (paraUstu > 0) Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [
                Text('Para Üstü', style: TextStyle(color: _turuncu, fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text(_tl(paraUstu), style: const TextStyle(color: _turuncu, fontSize: 18, fontWeight: FontWeight.bold)),
              ])),
              const SizedBox(height: 6),
              Row(children: [tus('1'), tus('2'), tus('3')]),
              Row(children: [tus('4'), tus('5'), tus('6')]),
              Row(children: [tus('7'), tus('8'), tus('9')]),
              Row(children: [tus('.'), tus('0'), tus('', ikon: Icons.backspace_outlined, onTap: () => setSt(() { if (giris.isNotEmpty) giris = giris.substring(0, giris.length - 1); }))]),
              const SizedBox(height: 6),
              Row(children: [odeK('nakit', 'Nakit', _yesil), odeK('kredi', 'Kart', _mavi), odeK('yemek_karti', 'Yemek K.', _turuncu)]),
            ]),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final genis = genisMi(context);
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
        title: Text(widget.masaAd, style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [IconButton(tooltip: 'Barkod okut', onPressed: _barkodOkut, icon: Icon(Icons.qr_code_scanner, color: t.mor1))],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : genis
              ? Row(children: [
                  Expanded(child: _urunPaneli(t)),
                  Container(width: 380, decoration: BoxDecoration(color: t.card, border: Border(left: BorderSide(color: t.line))), child: _adisyonPaneli(t)),
                ])
              : Column(children: [
                  Expanded(child: _urunPaneli(t)),
                  _altSepetBar(t),
                ]),
    );
  }

  // ---------- SOL: ürün paneli ----------
  Widget _urunPaneli(TemaProvider t) {
    final aranan = _ara.trim().toLowerCase();
    final liste = aranan.isNotEmpty
        ? urunler.where((u) => (u as Map)['ad'].toString().toLowerCase().contains(aranan)).toList()
        : urunler.where((u) => _n((u as Map)['kategori_id']).toInt() == (_kat ?? 0)).toList();
    return Column(children: [
      // Arama
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: TextField(
          onChanged: (v) => setState(() => _ara = v),
          style: TextStyle(color: t.ink, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Ürün ara…', hintStyle: TextStyle(color: t.sub), isDense: true,
            prefixIcon: Icon(Icons.search, color: t.sub, size: 20), filled: true, fillColor: t.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: t.mor1)),
          ),
        ),
      ),
      // Kategori sekmeleri
      if (aranan.isEmpty)
        SizedBox(
          height: 42,
          child: ListView.separated(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            itemCount: kategoriler.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final k = kategoriler[i] as Map;
              final id = _n(k['id']).toInt();
              final secili = id == _kat;
              return GestureDetector(
                onTap: () => setState(() => _kat = id),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), alignment: Alignment.center,
                  decoration: BoxDecoration(gradient: secili ? const LinearGradient(colors: [_mor, _mavi]) : null, color: secili ? null : t.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: secili ? Colors.transparent : t.line)),
                  child: Text(k['ad'].toString(), style: TextStyle(color: secili ? Colors.white : t.sub2, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ),
      Expanded(
        child: liste.isEmpty
            ? Center(child: Text('Ürün yok.', style: TextStyle(color: t.sub)))
            : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 190, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.82),
                itemCount: liste.length,
                itemBuilder: (ctx, i) => _urunKart(t, liste[i] as Map),
              ),
      ),
    ]);
  }

  Widget _urunKart(TemaProvider t, Map u) {
    final id = _n(u['id']).toInt();
    final adet = _pending[id] ?? 0;
    final tukendi = u['tukendi'] == true;
    final gorsel = u['gorsel']?.toString();
    return GestureDetector(
      onTap: tukendi ? null : () => _ekle(id),
      onLongPress: adet > 0 ? () => _azalt(id) : null,
      child: Opacity(
        opacity: tukendi ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: adet > 0 ? _mor : t.line, width: adet > 0 ? 1.8 : 1)),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(
              child: Stack(fit: StackFit.expand, children: [
                gorsel != null
                    ? Image.network(gorsel, fit: BoxFit.cover, errorBuilder: (_, _, _) => _fotoYer(t, u['ad'].toString()))
                    : _fotoYer(t, u['ad'].toString()),
                if (adet > 0)
                  Positioned(top: 6, right: 6, child: Container(
                    width: 26, height: 26, alignment: Alignment.center,
                    decoration: const BoxDecoration(color: _mor, shape: BoxShape.circle),
                    child: Text('$adet', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  )),
                if (tukendi)
                  Positioned(bottom: 6, left: 6, child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: _kirmizi, borderRadius: BorderRadius.circular(6)),
                    child: const Text('Tükendi', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  )),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u['ad'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_tl(_n(u['fiyat'])), style: const TextStyle(color: _yesil, fontSize: 13.5, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _fotoYer(TemaProvider t, String ad) => Container(
        color: t.card2,
        alignment: Alignment.center,
        child: Icon(Icons.restaurant_menu, color: t.sub.withValues(alpha: 0.5), size: 32),
      );

  // ---------- SAĞ: adisyon + ödeme ----------
  Widget _adisyonPaneli(TemaProvider t) {
    final araToplam = _n(_fis?['ara_toplam']).toDouble();
    final iskonto = _n(_fis?['indirim']).toDouble();
    final ikram = _n(_fis?['ikram']).toDouble();
    final kalemSayi = _kalemler.fold<int>(0, (a, k) => a + _n((k as Map)['adet']).toInt()) + _pendingAdet;
    return Column(children: [
      // Başlık şeridi (gradient)
      Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [_mor, _mavi])),
        child: Row(children: [
          const Icon(Icons.table_restaurant, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.masaAd, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Adisyon${_fis?['adisyon_no'] != null ? ' #${_fis!['adisyon_no']}' : ''} · $kalemSayi ürün', style: const TextStyle(color: Color(0xFFE9D5FF), fontSize: 11.5)),
          ])),
        ]),
      ),
      // Kalemler
      Expanded(
        child: (_kalemler.isEmpty && _pending.isEmpty)
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.receipt_long_outlined, color: t.sub.withValues(alpha: 0.4), size: 40),
                const SizedBox(height: 8),
                Text('Soldan ürün ekleyin', style: TextStyle(color: t.sub, fontSize: 14)),
              ]))
            : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 6), children: [
                for (final k in _kalemler) _kalemSatir(t, k as Map),
                if (_pending.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: _turuncu, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text('YENİ · kaydedilmedi', style: TextStyle(color: _turuncu, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                  ]),
                  const SizedBox(height: 4),
                  for (final e in _pending.entries) _pendingSatir(t, e.key, e.value),
                ],
              ]),
      ),
      // Alt panel: döküm + aksiyon + ödeme
      Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: BoxDecoration(
          color: t.card,
          border: Border(top: BorderSide(color: t.line)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -3))],
        ),
        child: Column(children: [
          // Döküm
          if (iskonto > 0 || ikram > 0) ...[
            _dokum(t, 'Ara Toplam', _tl(araToplam), t.sub),
            if (iskonto > 0) _dokum(t, 'İskonto', '-${_tl(iskonto)}', _yesil),
            if (ikram > 0) _dokum(t, 'İkram', '-${_tl(ikram)}', _turuncu),
            const SizedBox(height: 4),
          ],
          if (_toplamHepsi > _kayitliToplam + 0.5)
            Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
              Text('Toplam ${_tl(_toplamHepsi)}', style: TextStyle(color: t.sub, fontSize: 11.5)),
              const Spacer(),
              Text('Ödenen ${_tl(_toplamHepsi - _kayitliToplam)}', style: const TextStyle(color: _yesil, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ])),
          Row(children: [
            Text(_secili.isEmpty ? 'Genel Toplam' : 'Seçili ${_secili.length} kalem', style: TextStyle(color: _secili.isEmpty ? t.ink : t.mor1, fontSize: 14, fontWeight: FontWeight.w700)),
            const Spacer(),
            Text(_tl(_secili.isEmpty ? _genelToplam : _seciliTutar), style: TextStyle(color: t.mor1, fontSize: 26, fontWeight: FontWeight.bold)),
          ]),
          if (_secili.isNotEmpty)
            Align(alignment: Alignment.centerRight, child: GestureDetector(
              onTap: () => setState(() => _secili.clear()),
              child: Padding(padding: const EdgeInsets.only(top: 2), child: Text('Seçimi temizle', style: TextStyle(color: t.sub, fontSize: 11.5, decoration: TextDecoration.underline))),
            )),
          const SizedBox(height: 10),
          // İkincil aksiyonlar
          Row(children: [
            _ikincil(t, Icons.local_offer_outlined, 'İskonto', _yesil, _iskonto),
            const SizedBox(width: 7),
            _ikincil(t, Icons.card_giftcard, 'İkram', _turuncu, _ikram),
            const SizedBox(width: 7),
            _ikincil(t, Icons.print_outlined, 'Fiş', _mavi, _fisBas),
            const SizedBox(width: 7),
            _ikincil(t, Icons.cancel_outlined, 'İptal', _kirmizi, _iptal),
          ]),
          const SizedBox(height: 10),
          if (_pending.isNotEmpty) ...[
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _mesgul ? null : () => _kaydet(),
              icon: const Icon(Icons.save_outlined, size: 19),
              label: Text('Siparişi Kaydet ($_pendingAdet)', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(backgroundColor: _mor, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
            )),
            const SizedBox(height: 10),
          ],
          // Ödeme yöntemleri
          Row(children: [
            _odeBtn(t, 'nakit', 'Nakit', Icons.payments_outlined, _yesil),
            const SizedBox(width: 9),
            _odeBtn(t, 'kredi', 'Kart', Icons.credit_card, _mavi),
          ]),
          const SizedBox(height: 9),
          Row(children: [
            _odeBtn(t, 'yemek_karti', 'Yemek K.', Icons.restaurant, _turuncu),
            const SizedBox(width: 9),
            _odeBtn(t, 'acik_hesap', 'Açık Hesap', Icons.account_balance_wallet_outlined, _mor),
          ]),
          const SizedBox(height: 8),
          // Kısmi / böl / para üstü
          GestureDetector(
            onTap: _mesgul ? null : _kismiSheet,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 11), alignment: Alignment.center,
              decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.call_split, size: 17, color: t.sub2),
                const SizedBox(width: 7),
                Text('Kısmi / Böl · Para Üstü', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _dokum(TemaProvider t, String s, String v, Color renk) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Text(s, style: TextStyle(color: t.sub, fontSize: 12.5)),
          const Spacer(),
          Text(v, style: TextStyle(color: renk, fontSize: 12.5, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _kalemSatir(TemaProvider t, Map k) {
    final id = _n(k['id']).toInt();
    final adet = _n(k['adet']).toInt();
    final odendi = k['odeme_durum'] == 'odendi';
    final secili = _secili.contains(id);
    return GestureDetector(
      onTap: odendi ? null : () => setState(() { secili ? _secili.remove(id) : _secili.add(id); }),
      child: Opacity(
        opacity: odendi ? 0.55 : 1,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: secili ? t.mor1.withValues(alpha: 0.12) : t.card2,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: secili ? t.mor1 : Colors.transparent, width: 1.4),
          ),
          child: Row(children: [
            // Seçim kutusu / ödendi işareti
            odendi
                ? const Icon(Icons.check_circle, color: _yesil, size: 22)
                : Container(
                    width: 22, height: 22, alignment: Alignment.center,
                    decoration: BoxDecoration(color: secili ? t.mor1 : Colors.transparent, borderRadius: BorderRadius.circular(7), border: Border.all(color: secili ? t.mor1 : t.line, width: 1.6)),
                    child: secili ? const Icon(Icons.check, color: Colors.white, size: 15) : null,
                  ),
            const SizedBox(width: 10),
            Container(
              width: 26, height: 26, alignment: Alignment.center,
              decoration: BoxDecoration(color: t.mor1.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(8)),
              child: Text('$adet', style: TextStyle(color: t.mor1, fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(k['ad'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w500, decoration: odendi ? TextDecoration.lineThrough : null))),
            const SizedBox(width: 8),
            Text(_tl(_n(k['tutar'])), style: TextStyle(color: odendi ? t.sub : t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }

  Widget _pendingSatir(TemaProvider t, int id, int adet) {
    final u = _urunById[id];
    final ad = u?['ad']?.toString() ?? '';
    final tutar = _n(u?['fiyat']).toDouble() * adet;
    return Container(
      margin: const EdgeInsets.only(bottom: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10), border: Border.all(color: _turuncu.withValues(alpha: 0.30))),
      child: Row(children: [
        Expanded(child: Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w500))),
        _miniIkon(Icons.remove, () => _azalt(id), t),
        SizedBox(width: 28, child: Text('$adet', textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.bold))),
        _miniIkon(Icons.add, () => _ekle(id), t),
        const SizedBox(width: 8),
        SizedBox(width: 66, child: Text(_tl(tutar), textAlign: TextAlign.right, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _miniIkon(IconData i, VoidCallback onTap, TemaProvider t) => GestureDetector(
        onTap: onTap,
        child: Container(width: 28, height: 28, alignment: Alignment.center, decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)), child: Icon(i, size: 16, color: t.ink)),
      );

  Widget _ikincil(TemaProvider t, IconData ikon, String ad, Color renk, VoidCallback onTap) => Expanded(
        child: GestureDetector(
          onTap: _mesgul ? null : onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 9), alignment: Alignment.center,
            decoration: BoxDecoration(color: renk.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(11), border: Border.all(color: renk.withValues(alpha: 0.32))),
            child: Column(children: [
              Icon(ikon, size: 18, color: renk), const SizedBox(height: 3),
              Text(ad, style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      );

  Widget _odeBtn(TemaProvider t, String tip, String ad, IconData ikon, Color renk) => Expanded(
        child: Opacity(
          opacity: _mesgul ? 0.5 : 1,
          child: Material(
            color: renk, borderRadius: BorderRadius.circular(14),
            elevation: 2, shadowColor: renk.withValues(alpha: 0.4),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _mesgul ? null : () => _ode(tip),
              child: Container(
                height: 62, alignment: Alignment.center,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(ikon, color: Colors.white, size: 22), const SizedBox(height: 3),
                  Text(ad, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ),
        ),
      );

  // ---------- DAR ekran: alt sepet çubuğu ----------
  Widget _altSepetBar(TemaProvider t) => SafeArea(
        child: GestureDetector(
          onTap: () => showModalBottomSheet(
            context: context, backgroundColor: t.card, isScrollControlled: true,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            builder: (_) => SizedBox(height: MediaQuery.of(context).size.height * 0.7, child: _adisyonPaneli(t)),
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('Genel Toplam', style: TextStyle(color: t.sub, fontSize: 11)),
                Text(_tl(_genelToplam), style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
              ]),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(color: _mor, borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [
                  Text('Adisyon & Öde', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(width: 6), Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                ]),
              ),
            ]),
          ),
        ),
      );
}

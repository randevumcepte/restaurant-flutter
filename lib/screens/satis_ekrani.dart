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
  List _kalemler = []; // adisyonda KAYITLI kalemler (fis)
  double _kayitliToplam = 0;
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
      if (!mounted) return;
      kategoriler = (menu['kategoriler'] as List?) ?? [];
      urunler = (menu['urunler'] as List?) ?? [];
      _urunById.clear();
      for (final u in urunler) {
        _urunById[_n((u as Map)['id']).toInt()] = u;
      }
      _kat ??= kategoriler.isNotEmpty ? _n((kategoriler.first as Map)['id']).toInt() : null;
      if (fis['ok'] == 1) {
        _fis = fis;
        _kalemler = (fis['kalemler'] as List?) ?? [];
        _kayitliToplam = _n(fis['toplam']).toDouble();
      }
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
    if (_genelToplam <= 0) { _snack('Adisyon boş', _turuncu); return; }
    // Önce bekleyen ürünleri kaydet
    if (_pending.isNotEmpty) {
      final ok = await _kaydet();
      if (!ok) return;
    }
    if (tip == 'acik_hesap') { await _acikHesap(); return; }

    final onay = await _odeOnay(tip);
    if (onay != true || !mounted) return;
    setState(() => _mesgul = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.adisyonIslem(auth.token!, islem: 'ode', adisyonId: widget.adisyonId, odemeTip: tip, tutar: _kayitliToplam);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() => _mesgul = false);
        if (res['kapandi'] == true) { await _bitir(); } else { await _yukle(); }
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
          content: Text('${_tl(_kayitliToplam)} tahsil edilip masa kapatılsın mı?', style: TextStyle(color: t.sub, fontSize: 14)),
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
    return Column(children: [
      // Kayıtlı kalemler + bekleyenler
      Expanded(
        child: (_kalemler.isEmpty && _pending.isEmpty)
            ? Center(child: Text('Ürün ekleyin', style: TextStyle(color: t.sub, fontSize: 14)))
            : ListView(padding: const EdgeInsets.all(12), children: [
                for (final k in _kalemler)
                  _satir(t, '${_n((k as Map)['adet']).toInt()}x ${k['ad']}', _tl(_n(k['tutar'])), kayitli: true),
                if (_pending.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('YENİ (kaydedilmedi)', style: TextStyle(color: _turuncu, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
                  for (final e in _pending.entries)
                    _pendingSatir(t, e.key, e.value),
                ],
              ]),
      ),
      // Toplam + aksiyonlar
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
        child: Column(children: [
          Row(children: [
            Text('Genel Toplam', style: TextStyle(color: t.sub, fontSize: 13)),
            const Spacer(),
            Text(_tl(_genelToplam), style: TextStyle(color: t.ink, fontSize: 24, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 12),
          if (_pending.isNotEmpty)
            SizedBox(width: double.infinity, child: FilledButton.icon(
              onPressed: _mesgul ? null : () => _kaydet(),
              icon: const Icon(Icons.save_outlined, size: 19),
              label: Text('Siparişi Kaydet ($_pendingAdet)', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(backgroundColor: _mor, padding: const EdgeInsets.symmetric(vertical: 13)),
            )),
          if (_pending.isNotEmpty) const SizedBox(height: 10),
          // Ödeme yöntemleri
          Row(children: [
            _odeBtn(t, 'nakit', 'Nakit', Icons.payments_outlined, _yesil),
            const SizedBox(width: 8),
            _odeBtn(t, 'kredi', 'Kart', Icons.credit_card, _mavi),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _odeBtn(t, 'yemek_karti', 'Yemek K.', Icons.restaurant, _turuncu),
            const SizedBox(width: 8),
            _odeBtn(t, 'acik_hesap', 'Açık Hesap', Icons.receipt_long, _mor),
          ]),
        ]),
      ),
    ]);
  }

  Widget _satir(TemaProvider t, String sol, String sag, {bool kayitli = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Expanded(child: Text(sol, style: TextStyle(color: t.ink, fontSize: 13.5))),
          const SizedBox(width: 8),
          Text(sag, style: TextStyle(color: t.sub2, fontSize: 13.5, fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _pendingSatir(TemaProvider t, int id, int adet) {
    final u = _urunById[id];
    final ad = u?['ad']?.toString() ?? '';
    final tutar = _n(u?['fiyat']).toDouble() * adet;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
      child: Row(children: [
        Expanded(child: Text(ad, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 13.5))),
        _miniIkon(Icons.remove, () => _azalt(id), t),
        SizedBox(width: 26, child: Text('$adet', textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.bold))),
        _miniIkon(Icons.add, () => _ekle(id), t),
        const SizedBox(width: 6),
        SizedBox(width: 66, child: Text(_tl(tutar), textAlign: TextAlign.right, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600))),
      ]),
    );
  }

  Widget _miniIkon(IconData i, VoidCallback onTap, TemaProvider t) => GestureDetector(
        onTap: onTap,
        child: Container(width: 26, height: 26, alignment: Alignment.center, decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(7), border: Border.all(color: t.line)), child: Icon(i, size: 15, color: t.ink)),
      );

  Widget _odeBtn(TemaProvider t, String tip, String ad, IconData ikon, Color renk) => Expanded(
        child: Opacity(
          opacity: _mesgul ? 0.5 : 1,
          child: Material(
            color: renk, borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: _mesgul ? null : () => _ode(tip),
              child: Container(
                height: 58, alignment: Alignment.center,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(ikon, color: Colors.white, size: 21), const SizedBox(height: 3),
                  Text(ad, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../services/yazici_servisi.dart';
import 'barkod_tarayici.dart';
import '../widgets/not_alerji_sheet.dart';

/// Sipariş girişi (POS çekirdeği): menüden ürün seç -> sepet -> adisyona ekle.
/// Hem patron app hem (ileride) garson terminali için ortak.
class UrunEkleScreen extends StatefulWidget {
  final int adisyonId;
  final String baslik;
  const UrunEkleScreen({super.key, required this.adisyonId, this.baslik = 'Sipariş Ekle'});

  @override
  State<UrunEkleScreen> createState() => _UrunEkleScreenState();
}

class _UrunEkleScreenState extends State<UrunEkleScreen> {
  List kategoriler = [];
  List urunler = [];
  final Map<int, Map> _urunById = {};
  final Map<int, int> _sepet = {}; // urunId -> adet
  final Map<int, String> _notlar = {}; // urunId -> "Soğansız · ALERJİ: Gluten"
  List<String> _masaAlerji = []; // adisyonun alerjisi (her kaleme yazılır)
  int? _kat;
  bool loading = true;
  bool _gonderiliyor = false;
  final _f = NumberFormat.decimalPattern('tr');

  TemaProvider get _t => context.watch<TemaProvider>();
  Color get _bg => _t.bg;
  Color get _card => _t.card;
  Color get _ink => _t.ink;
  Color get _sub => _t.sub;
  Color get _line => _t.line;

  static const _mor1 = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tl(num v) => '${_f.format(v.round())}TL';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.menu(auth.token!);
      final kl = await Api.adisyonKalemleri(auth.token!, widget.adisyonId).catchError((_) => <String, dynamic>{});
      if (!mounted) return;
      _masaAlerji = ((kl['alerji'] as List?) ?? []).map((e) => e.toString()).toList();
      kategoriler = (res['kategoriler'] as List?) ?? [];
      urunler = (res['urunler'] as List?) ?? [];
      _urunById.clear();
      for (final u in urunler) {
        _urunById[_n((u as Map)['id']).toInt()] = u;
      }
      _kat = kategoriler.isNotEmpty ? _n((kategoriler.first as Map)['id']).toInt() : null;
      setState(() => loading = false);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  double get _sepetTutar {
    double t = 0;
    _sepet.forEach((id, adet) => t += _n(_urunById[id]?['fiyat']).toDouble() * adet);
    return t;
  }

  int get _sepetAdet => _sepet.values.fold(0, (a, b) => a + b);

  Future<void> _ekle() async {
    if (_sepet.isEmpty || _gonderiliyor) return;
    setState(() => _gonderiliyor = true);
    final auth = context.read<AuthProvider>();
    String notu(int id) => NotAlerji.birlestir(_notlar[id], _masaAlerji);
    final kalemler = _sepet.entries.map((e) => <String, dynamic>{'urun_id': e.key, 'adet': e.value, if (notu(e.key).isNotEmpty) 'not': notu(e.key)}).toList();
    try {
      final res = await Api.adisyonUrunEkle(auth.token!, widget.adisyonId, kalemler);
      if (!mounted) return;
      if (res['ok'] == 1) {
        // MUTFAK ÇIKTISI: moda göre fiş bas (ekran modunda hiçbir şey olmaz)
        try {
          final fisKalem = _sepet.entries.map((e) => <String, dynamic>{'adet': e.value, 'ad': _urunById[e.key]?['ad']?.toString() ?? 'Ürün', 'istasyon': _urunById[e.key]?['istasyon']?.toString() ?? 'mutfak', 'not': notu(e.key)}).toList();
          await YaziciServisi().otoMutfakFisi(masa: widget.baslik, kalemler: fisKalem, adisyonNo: widget.adisyonId, tur: int.tryParse('${res['tur'] ?? ''}'));
        } catch (_) {}
        if (!mounted) return;
        final riskli = (res['alerji_uyari'] as List?) ?? [];
        if (riskli.isNotEmpty) await NotAlerji.riskUyari(context, riskli);
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        setState(() => _gonderiliyor = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['hata']?.toString() ?? 'Eklenemedi'), backgroundColor: _card));
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) {
        setState(() => _gonderiliyor = false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı hatası')));
      }
    }
  }

  Future<void> _notDuzenle(int id) async {
    final n = await NotAlerji.kalemNotSec(context, urunAd: _urunById[id]?['ad']?.toString() ?? 'Ürün', mevcut: _notlar[id], masaAlerji: _masaAlerji);
    if (n == null || !mounted) return;
    setState(() { if (n.isEmpty) { _notlar.remove(id); } else { _notlar[id] = n; } });
  }

  Future<void> _alerjiDuzenle() async {
    final l = await NotAlerji.masaAlerjiSec(context, _masaAlerji);
    if (l == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final r = await Api.adisyonAlerji(auth.token!, widget.adisyonId, l);
      if (!mounted) return;
      if (r['ok'] != 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['hata']?.toString() ?? 'Kaydedilemedi'), backgroundColor: NotAlerji.kirmizi));
        return;
      }
      setState(() => _masaAlerji = ((r['alerji'] as List?) ?? []).map((e) => e.toString()).toList());
      final riskli = (r['riskli'] as List?) ?? [];
      if (riskli.isNotEmpty) await NotAlerji.riskUyari(context, riskli, ek: 'Müşteriye haber verin, mutfakla konuşun.');
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı hatası (alerji kaydedilemedi)')));
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
        final id = _n(r['id']).toInt();
        setState(() => _sepet[id] = (_sepet[id] ?? 0) + 1);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r['ad']} sepete eklendi'), backgroundColor: const Color(0xFF16A34A), duration: const Duration(seconds: 1)));
      } else if (r['ok'] == 1 && r['tur'] == 'malzeme') {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Bu barkod bir MALZEME (${r['ad']}) — satışa eklenmez.'), backgroundColor: const Color(0xFFF59E0B)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['hata']?.toString() ?? 'Barkod tanımlı değil'), backgroundColor: const Color(0xFFDC2626)));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final katUrun = urunler.where((u) => _n((u as Map)['kategori_id']).toInt() == (_kat ?? 0)).toList();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: _ink),
        title: Text(widget.baslik, style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(tooltip: 'Alerji / diyet', onPressed: _alerjiDuzenle, icon: Icon(Icons.health_and_safety_outlined, color: _masaAlerji.isNotEmpty ? NotAlerji.kirmizi : _sub)),
          IconButton(tooltip: 'Barkod okut', onPressed: _barkodOkut, icon: Icon(Icons.qr_code_scanner, color: _mor1)),
        ],
        bottom: _masaAlerji.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(34),
                child: InkWell(
                  onTap: _alerjiDuzenle,
                  child: Container(
                    width: double.infinity, height: 34, alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    color: NotAlerji.kirmizi,
                    child: Text('⚠️ ALERJİ: ${_masaAlerji.join(', ')}', maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : Column(children: [
              // Kategori sekmeleri
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  itemCount: kategoriler.length,
                  separatorBuilder: (context, i) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final k = kategoriler[i] as Map;
                    final id = _n(k['id']).toInt();
                    final secili = id == _kat;
                    return GestureDetector(
                      onTap: () => setState(() => _kat = id),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: secili ? const LinearGradient(colors: [_mor1, _mavi]) : null,
                          color: secili ? null : _card,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(k['ad'].toString(),
                            style: TextStyle(color: secili ? Colors.white : _sub, fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
              // Urun grid
              Expanded(
                child: katUrun.isEmpty
                    ? Center(child: Text('Bu kategoride ürün yok.', style: TextStyle(color: _sub)))
                    : GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.5),
                        itemCount: katUrun.length,
                        itemBuilder: (context, i) => _urunKart(katUrun[i] as Map),
                      ),
              ),
            ]),
      bottomNavigationBar: _sepetAdet == 0 ? null : _sepetBar(),
    );
  }

  Widget _urunKart(Map u) {
    final id = _n(u['id']).toInt();
    final adet = _sepet[id] ?? 0;
    final tukendi = u['tukendi'] == true;
    return GestureDetector(
      onTap: tukendi ? null : () => setState(() => _sepet[id] = adet + 1),
      onLongPress: adet > 0 ? () => setState(() { if (adet <= 1) { _sepet.remove(id); _notlar.remove(id); } else { _sepet[id] = adet - 1; } }) : null,
      child: Opacity(
        opacity: tukendi ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: adet > 0 ? _mor1 : _line, width: adet > 0 ? 1.6 : 1),
          ),
          child: Stack(children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u['ad'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w600)),
              Text(tukendi ? 'Tükendi' : _tl(_n(u['fiyat'])),
                  style: TextStyle(color: tukendi ? const Color(0xFFF43F5E) : const Color(0xFF6EE7B7), fontSize: 15, fontWeight: FontWeight.bold)),
            ]),
            if (adet > 0)
              Positioned(
                top: 0, right: 0,
                child: Container(
                  width: 26, height: 26, alignment: Alignment.center,
                  decoration: const BoxDecoration(color: _mor1, shape: BoxShape.circle),
                  child: Text('$adet', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            // Sepetteki ürüne not / alerji (mısırsız, az pişmiş, ALERJİ...)
            if (adet > 0)
              Positioned(
                bottom: 0, right: 0,
                child: GestureDetector(
                  onTap: () => _notDuzenle(id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (_notlar[id]?.contains('ALERJ') ?? false) ? NotAlerji.kirmizi : (_notlar.containsKey(id) ? const Color(0xFFF59E0B) : _mor1.withValues(alpha: 0.14)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_notlar.containsKey(id) ? '📝 Notlu' : '+ Not',
                        style: TextStyle(color: _notlar.containsKey(id) ? Colors.white : _mor1, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _sepetBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: BoxDecoration(color: _card, border: Border(top: BorderSide(color: _line))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$_sepetAdet ürün', style: TextStyle(color: _sub, fontSize: 12)),
            Text(_tl(_sepetTutar), style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const Spacer(),
          TextButton(onPressed: () => setState(() { _sepet.clear(); _notlar.clear(); }), child: Text('Temizle', style: TextStyle(color: _sub))),
          const SizedBox(width: 6),
          FilledButton(
            onPressed: _gonderiliyor ? null : _ekle,
            style: FilledButton.styleFrom(backgroundColor: _mor1, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13)),
            child: _gonderiliyor
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Adisyona Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }
}

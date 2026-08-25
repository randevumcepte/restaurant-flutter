import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

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
  int? _kat;
  bool loading = true;
  bool _gonderiliyor = false;
  final _f = NumberFormat.decimalPattern('tr');

  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _mor1 = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tl(num v) => '₺${_f.format(v.round())}';

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
      if (!mounted) return;
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
    final kalemler = _sepet.entries.map((e) => {'urun_id': e.key, 'adet': e.value}).toList();
    try {
      final res = await Api.adisyonUrunEkle(auth.token!, widget.adisyonId, kalemler);
      if (!mounted) return;
      if (res['ok'] == 1) {
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

  @override
  Widget build(BuildContext context) {
    final katUrun = urunler.where((u) => _n((u as Map)['kategori_id']).toInt() == (_kat ?? 0)).toList();
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.baslik, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
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
                            style: TextStyle(color: secili ? Colors.white : const Color(0xFF94A3B8), fontSize: 13, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),
              // Urun grid
              Expanded(
                child: katUrun.isEmpty
                    ? const Center(child: Text('Bu kategoride ürün yok.', style: TextStyle(color: Color(0xFF64748B))))
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
      onLongPress: adet > 0 ? () => setState(() { if (adet <= 1) { _sepet.remove(id); } else { _sepet[id] = adet - 1; } }) : null,
      child: Opacity(
        opacity: tukendi ? 0.4 : 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: adet > 0 ? _mor1 : const Color(0xFF243049), width: adet > 0 ? 1.6 : 1),
          ),
          child: Stack(children: [
            Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(u['ad'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
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
          ]),
        ),
      ),
    );
  }

  Widget _sepetBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        decoration: const BoxDecoration(color: _card, border: Border(top: BorderSide(color: Color(0xFF243049)))),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('$_sepetAdet ürün', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
            Text(_tl(_sepetTutar), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
          const Spacer(),
          TextButton(onPressed: () => setState(() => _sepet.clear()), child: const Text('Temizle', style: TextStyle(color: Color(0xFF94A3B8)))),
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

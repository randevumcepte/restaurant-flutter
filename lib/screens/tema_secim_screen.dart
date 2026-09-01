import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// QR Menü Rengi — restoran kendi renk temasini (kartela) secer.
/// Musterilerin masadaki QR ile gordugu menu bu renge burunur. Sadece Sahip/Mudur.
class TemaSecimScreen extends StatefulWidget {
  const TemaSecimScreen({super.key});

  @override
  State<TemaSecimScreen> createState() => _TemaSecimScreenState();
}

class _TemaSecimScreenState extends State<TemaSecimScreen> {
  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _gold = Color(0xFFF6CE63);

  bool loading = true;
  String? hata;
  bool duzenleyebilir = true;
  String secili = 'altin';
  List<Map<String, dynamic>> temalar = [];
  String? kaydediliyor; // o an kaydedilen key

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Color _hex(String? s) {
    s = (s ?? '').replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    return Color(int.tryParse(s, radix: 16) ?? 0xFF999999);
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() { loading = true; hata = null; });
    try {
      final res = await Api.temaGetir(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          temalar = ((res['temalar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
          secili = res['secili']?.toString() ?? 'altin';
          duzenleyebilir = res['duzenleyebilir'] != false;
          loading = false;
        });
      } else {
        setState(() { hata = res['hata']?.toString() ?? 'Alınamadı'; loading = false; });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() { hata = 'Bağlantı hatası'; loading = false; });
    }
  }

  Future<void> _sec(String key) async {
    if (!duzenleyebilir || kaydediliyor != null) return;
    final auth = context.read<AuthProvider>();
    final onceki = secili;
    setState(() { secili = key; kaydediliyor = key; });
    try {
      final res = await Api.temaKaydet(auth.token!, key);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() => kaydediliyor = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Renk kaydedildi — QR menüye uygulandı'),
          backgroundColor: Color(0xFF16A34A), duration: Duration(seconds: 2),
        ));
      } else {
        setState(() { secili = onceki; kaydediliyor = null; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['hata']?.toString() ?? 'Kaydedilemedi')));
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { secili = onceki; kaydediliyor = null; });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı hatası')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        title: const Text('QR Menü Rengi', style: TextStyle(fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : hata != null
              ? Center(child: Text(hata!, style: const TextStyle(color: Colors.white70)))
              : Column(children: [
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: _card, borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _gold.withOpacity(.25)),
                    ),
                    child: const Text(
                      '🎨 Müşterilerin masadaki QR ile açtığı menünün rengini seçin. '
                      'Dokunduğunuz an kaydedilir ve menüye anında uygulanır.',
                      style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.45),
                    ),
                  ),
                  if (!duzenleyebilir)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Bu ayarı yalnızca Sahip/Müdür değiştirebilir.', style: TextStyle(color: Color(0xFFF87171), fontSize: 12.5)),
                    ),
                  Expanded(
                    child: GridView.count(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                      crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: .92,
                      children: temalar.map(_kart).toList(),
                    ),
                  ),
                ]),
    );
  }

  Widget _kart(Map<String, dynamic> t) {
    final key = t['key']?.toString() ?? '';
    final aktif = key == secili;
    final ana = _hex(t['ana']?.toString());
    final ana3 = _hex(t['ana3']?.toString());
    final ink = _hex(t['ink']?.toString());
    return GestureDetector(
      onTap: () => _sec(key),
      child: Container(
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: aktif ? _gold : const Color(0xFF2D3752), width: aktif ? 2 : 1),
          boxShadow: aktif ? [BoxShadow(color: _gold.withOpacity(.35), blurRadius: 16, spreadRadius: 1)] : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // renk onizleme
          Expanded(
            child: Stack(children: [
              Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [ana, ana3], begin: Alignment.topLeft, end: Alignment.bottomRight))),
              // altin nokta (her palette sabit luks detay)
              Positioned(left: 12, bottom: 12, child: Container(width: 30, height: 30, decoration: const BoxDecoration(
                shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFF6DFA0), Color(0xFFC9962F)])))),
              // ornek buton
              Positioned(right: 10, bottom: 10, child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: ana, borderRadius: BorderRadius.circular(20)),
                child: Text('+ Ekle', style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800)))),
              Positioned(right: 10, top: 10, child: Text(t['emoji']?.toString() ?? '🎨', style: const TextStyle(fontSize: 22))),
              if (aktif) Positioned(left: 10, top: 10, child: Container(
                width: 26, height: 26, decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                child: const Icon(Icons.check, color: Color(0xFF3A2600), size: 17))),
              if (kaydediliyor == key) const Positioned.fill(child: ColoredBox(color: Color(0x66000000),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(children: [
              Expanded(child: Text(t['ad']?.toString() ?? '', style: TextStyle(
                color: aktif ? _gold : Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
              if (aktif) const Text('Seçili', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
      ),
    );
  }
}

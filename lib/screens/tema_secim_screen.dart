import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// QR Menü Rengi — hazir lüks paletler + KENDI RENGINI OLUSTUR (genel renk + detay/cizgi rengi).
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
  String? kaydediliyor;
  Color ozelAna = const Color(0xFFC41E3A);   // varsayilan ozel: kirmizi
  Color ozelDetay = const Color(0xFFE9C46A);  // varsayilan detay: altin
  bool detayAyri = false;                      // detay ayri renk mi (yoksa genel renkle ayni)

  @override
  void initState() { super.initState(); _yukle(); }

  Color _hex(String? s) {
    s = (s ?? '').replaceAll('#', '');
    if (s.length == 6) s = 'FF$s';
    return Color(int.tryParse(s, radix: 16) ?? 0xFF999999);
  }
  String _str(Color c) => '#${c.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

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
          ozelAna = _hex(res['renk']?.toString());
          final r2 = res['renk2']?.toString() ?? '';
          detayAyri = r2.isNotEmpty;
          ozelDetay = r2.isNotEmpty ? _hex(r2) : const Color(0xFFE9C46A);
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

  Future<void> _kaydet(String key, {String? renk, String? renk2}) async {
    if (!duzenleyebilir || kaydediliyor != null) return;
    final auth = context.read<AuthProvider>();
    final onceki = secili;
    setState(() { secili = key; kaydediliyor = key; });
    try {
      final res = await Api.temaKaydet(auth.token!, key, renk: renk, renk2: renk2);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() => kaydediliyor = null);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✓ Renk kaydedildi — QR menüye uygulandı'),
          backgroundColor: Color(0xFF16A34A), duration: Duration(seconds: 2)));
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

  void _ozelDuzenle() {
    Color ana = ozelAna, detay = ozelDetay; bool ayri = detayAyri;
    showModalBottomSheet(
      context: context, backgroundColor: _card, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        return DraggableScrollableSheet(
          expand: false, initialChildSize: .85, maxChildSize: .95, minChildSize: .5,
          builder: (_, sc) => SingleChildScrollView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(3)))),
              const SizedBox(height: 14),
              const Text('Kendi Rengini Oluştur', style: TextStyle(color: _gold, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Genel renk butonları; detay rengi fiyat/çizgi/logoyu belirler.', style: TextStyle(color: Colors.white54, fontSize: 12.5)),
              const SizedBox(height: 16),
              const Text('Genel Renk (butonlar, vurgular)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ColorPicker(pickerColor: ana, onColorChanged: (c) => ana = c, enableAlpha: false, displayThumbColor: true,
                  paletteType: PaletteType.hueWheel, labelTypes: const [], pickerAreaHeightPercent: .65),
              const Divider(color: Color(0xFF2D3752), height: 26),
              SwitchListTile(
                contentPadding: EdgeInsets.zero, activeColor: _gold,
                title: const Text('Detay/çizgi rengi ayrı olsun', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                subtitle: const Text('Kapalıysa fiyat/çizgiler de genel renk olur', style: TextStyle(color: Colors.white38, fontSize: 11.5)),
                value: ayri, onChanged: (v) => setLocal(() => ayri = v)),
              if (ayri) ...[
                const SizedBox(height: 6),
                const Text('Detay Rengi (fiyatlar, çizgiler, logo)', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                ColorPicker(pickerColor: detay, onColorChanged: (c) => detay = c, enableAlpha: false, displayThumbColor: true,
                    paletteType: PaletteType.hueWheel, labelTypes: const [], pickerAreaHeightPercent: .6),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: const Color(0xFF3A2600),
                    padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() { ozelAna = ana; ozelDetay = detay; detayAyri = ayri; });
                  _kaydet('ozel', renk: _str(ana), renk2: ayri ? _str(detay) : '');
                },
                child: const Text('Bu Rengi Uygula', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, iconTheme: const IconThemeData(color: Colors.white),
          title: const Text('QR Menü Rengi', style: TextStyle(fontWeight: FontWeight.bold))),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : hata != null
              ? Center(child: Text(hata!, style: const TextStyle(color: Colors.white70)))
              : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _gold.withOpacity(.25))),
                    child: const Text('🎨 Müşterilerin masadaki QR ile açtığı menünün rengini seçin. Dokununca anında kaydedilir.',
                        style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.45)),
                  ),
                  if (!duzenleyebilir) const Padding(padding: EdgeInsets.only(top: 12),
                      child: Text('Bu ayarı yalnızca Sahip/Müdür değiştirebilir.', style: TextStyle(color: Color(0xFFF87171), fontSize: 12.5))),

                  const SizedBox(height: 18),
                  const Text('Kendi Rengin', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _ozelKart(),

                  const SizedBox(height: 22),
                  const Text('Hazır Lüks Paletler', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: .92,
                    children: temalar.map(_kart).toList(),
                  ),
                ]),
    );
  }

  Widget _ozelKart() {
    final aktif = secili == 'ozel';
    final detayGoster = detayAyri ? ozelDetay : ozelAna;
    return GestureDetector(
      onTap: _ozelDuzenle,
      child: Container(
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: aktif ? _gold : const Color(0xFF2D3752), width: aktif ? 2 : 1),
          boxShadow: aktif ? [BoxShadow(color: _gold.withOpacity(.35), blurRadius: 16, spreadRadius: 1)] : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          SizedBox(height: 74, child: Row(children: [
            Expanded(child: Container(color: ozelAna)),
            Expanded(child: Container(color: detayGoster)),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(14, 11, 14, 12), child: Row(children: [
            const Icon(Icons.palette, color: _gold, size: 20), const SizedBox(width: 9),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(aktif ? 'Özel renginiz (seçili)' : 'Kendi rengini oluştur',
                  style: TextStyle(color: aktif ? _gold : Colors.white, fontSize: 14.5, fontWeight: FontWeight.w800)),
              const Text('Dokunup renk seç', style: TextStyle(color: Colors.white38, fontSize: 11.5)),
            ])),
            if (kaydediliyor == 'ozel') const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: _gold))
            else const Icon(Icons.chevron_right, color: Colors.white38),
          ])),
        ]),
      ),
    );
  }

  Widget _kart(Map<String, dynamic> t) {
    final key = t['key']?.toString() ?? '';
    final aktif = key == secili;
    final ana = _hex(t['ana']?.toString());
    final ana3 = _hex(t['ana3']?.toString());
    final ink = _hex(t['ink']?.toString());
    return GestureDetector(
      onTap: () => _kaydet(key),
      child: Container(
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: aktif ? _gold : const Color(0xFF2D3752), width: aktif ? 2 : 1),
          boxShadow: aktif ? [BoxShadow(color: _gold.withOpacity(.35), blurRadius: 16, spreadRadius: 1)] : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(child: Stack(children: [
            Container(decoration: BoxDecoration(gradient: LinearGradient(colors: [ana, ana3], begin: Alignment.topLeft, end: Alignment.bottomRight))),
            Positioned(left: 12, bottom: 12, child: Container(width: 30, height: 30, decoration: const BoxDecoration(
                shape: BoxShape.circle, gradient: LinearGradient(colors: [Color(0xFFF6DFA0), Color(0xFFC9962F)])))),
            Positioned(right: 10, bottom: 10, child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: ana, borderRadius: BorderRadius.circular(20)),
                child: Text('+ Ekle', style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w800)))),
            Positioned(right: 10, top: 10, child: Text(t['emoji']?.toString() ?? '🎨', style: const TextStyle(fontSize: 22))),
            if (aktif) Positioned(left: 10, top: 10, child: Container(width: 26, height: 26,
                decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle), child: const Icon(Icons.check, color: Color(0xFF3A2600), size: 17))),
            if (kaydediliyor == key) const Positioned.fill(child: ColoredBox(color: Color(0x66000000),
                child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))))),
          ])),
          Padding(padding: const EdgeInsets.fromLTRB(12, 10, 12, 12), child: Row(children: [
            Expanded(child: Text(t['ad']?.toString() ?? '', style: TextStyle(color: aktif ? _gold : Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
            if (aktif) const Text('Seçili', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w700)),
          ])),
        ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// QR Menü Rengi — hazir lüks paletler + KENDI RENGINI OLUSTUR (genel renk + detay/cizgi rengi).
/// Musterilerin masadaki QR ile gordugu menu bu renge burunur. Sadece Sahip/Mudur.
class TemaSecimScreen extends StatefulWidget {
  const TemaSecimScreen({super.key});
  @override
  State<TemaSecimScreen> createState() => _TemaSecimScreenState();
}

class _TemaSecimScreenState extends State<TemaSecimScreen> {
  static const _gold = Color(0xFFF6CE63);

  // Ekranin kendi arayuz zemini/karti/yazisi tema-duyarli (mobil koyu / masaustu aydinlik).
  // QR onizleme renkleri (ozelAna/ozelDetay/hazir palet) is mantigidir; degismez.
  TemaProvider get _t => context.watch<TemaProvider>();
  Color get _bg => _t.bg;
  Color get _card => _t.card;
  Color get _ink => _t.ink;
  Color get _sub => _t.sub;
  Color get _sub2 => _t.sub2;
  Color get _line => _t.line;

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
  String _str(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

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

  // Standart widget'larla renk seçici (harici paket YOK -> kesin çalışır): hazır kutucuklar + Ton/Canlılık/Parlaklık.
  // TAM EKRAN ayri sayfa (bottom-sheet bazi cihazlarda acilmiyordu -> kesin acilir)
  Future<void> _ozelDuzenle() async {
    if (!duzenleyebilir) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu ayarı yalnızca Sahip/Müdür değiştirebilir.')));
      return;
    }
    final sonuc = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(
      builder: (_) => _OzelRenkSayfa(
        ana: ozelAna, detay: ozelDetay, ayri: detayAyri,
        bg: _bg, card: _card, ink: _ink, sub: _sub, line: _line, gold: _gold,
      ),
    ));
    if (sonuc == null || !mounted) return;
    setState(() { ozelAna = sonuc['ana'] as Color; ozelDetay = sonuc['detay'] as Color; detayAyri = sonuc['ayri'] as bool; });
    _kaydet('ozel', renk: _str(ozelAna), renk2: detayAyri ? _str(ozelDetay) : '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(backgroundColor: _bg, iconTheme: IconThemeData(color: _ink),
          title: Text('QR Menü Rengi', style: TextStyle(color: _ink, fontWeight: FontWeight.bold))),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _gold))
          : hata != null
              ? Center(child: Text(hata!, style: TextStyle(color: _sub)))
              : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 28), children: [
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: _gold.withValues(alpha: .25))),
                    child: Text('🎨 Müşterilerin masadaki QR ile açtığı menünün rengini seçin. Dokununca anında kaydedilir.',
                        style: TextStyle(color: _sub2, fontSize: 13, height: 1.45)),
                  ),
                  if (!duzenleyebilir) const Padding(padding: EdgeInsets.only(top: 12),
                      child: Text('Bu ayarı yalnızca Sahip/Müdür değiştirebilir.', style: TextStyle(color: Color(0xFFF87171), fontSize: 12.5))),

                  const SizedBox(height: 22),
                  Text('Kendi Rengin', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _ozelKart(),

                  const SizedBox(height: 22),
                  Text('Hazır Lüks Paletler', style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w800)),
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
          border: Border.all(color: aktif ? _gold : _line, width: aktif ? 2 : 1),
          boxShadow: aktif ? [BoxShadow(color: _gold.withValues(alpha: .35), blurRadius: 16, spreadRadius: 1)] : null,
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
                  style: TextStyle(color: aktif ? _gold : _ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
              Text('Dokunup renk seç', style: TextStyle(color: _sub, fontSize: 11.5)),
            ])),
            if (kaydediliyor == 'ozel') const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: _gold))
            else Icon(Icons.chevron_right, color: _sub),
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
          border: Border.all(color: aktif ? _gold : _line, width: aktif ? 2 : 1),
          boxShadow: aktif ? [BoxShadow(color: _gold.withValues(alpha: .35), blurRadius: 16, spreadRadius: 1)] : null,
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
            Expanded(child: Text(t['ad']?.toString() ?? '', style: TextStyle(color: aktif ? _gold : _ink, fontSize: 14, fontWeight: FontWeight.w800))),
            if (aktif) const Text('Seçili', style: TextStyle(color: _gold, fontSize: 11, fontWeight: FontWeight.w700)),
          ])),
        ]),
      ),
    );
  }
}

/// TAM EKRAN kendi renk oluşturucu (harici paket YOK: hazır kutucuklar + Ton/Canlılık/Parlaklık kaydırıcıları).
class _OzelRenkSayfa extends StatefulWidget {
  final Color ana, detay;
  final bool ayri;
  final Color bg, card, ink, sub, line, gold;
  const _OzelRenkSayfa({required this.ana, required this.detay, required this.ayri,
    required this.bg, required this.card, required this.ink, required this.sub, required this.line, required this.gold});
  @override
  State<_OzelRenkSayfa> createState() => _OzelRenkSayfaState();
}

class _OzelRenkSayfaState extends State<_OzelRenkSayfa> {
  late Color ana, detay;
  late bool ayri;
  @override
  void initState() { super.initState(); ana = widget.ana; detay = widget.detay; ayri = widget.ayri; }

  Color get _ink => widget.ink;
  Color get _sub => widget.sub;
  Color get _line => widget.line;
  Color get _gold => widget.gold;

  static const List<Color> _tonSpektrum = [
    Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00), Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
  ];

  Widget _renkPaneli(Color renk, void Function(Color) onc) {
    const swatches = [0xFFC41E3A, 0xFFE23744, 0xFFF97316, 0xFFF59E0B, 0xFFEAB308, 0xFF84CC16, 0xFF22C55E, 0xFF10B981, 0xFF14B8A6, 0xFF06B6D4, 0xFF3B82F6, 0xFF6366F1, 0xFF7C3AED, 0xFF9333EA, 0xFFD946EF, 0xFFEC4899, 0xFF8B5E34, 0xFF111827];
    final hsv = HSVColor.fromColor(renk);
    final hex = renk.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 10, runSpacing: 10, children: swatches.map((v) {
        final c = Color(v);
        final sec = c.toARGB32() == renk.toARGB32();
        return GestureDetector(
          onTap: () => onc(c),
          child: Container(width: 40, height: 40, decoration: BoxDecoration(
            color: c, shape: BoxShape.circle, border: Border.all(color: sec ? _gold : Colors.white24, width: sec ? 3 : 1)),
            child: sec ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
        );
      }).toList()),
      const SizedBox(height: 16),
      // HEX kodu: logonun/markanin tam rengini yaz (hazir kutucuklarda olmayabilir)
      Row(children: [
        SizedBox(width: 88, child: Text('Renk kodu', style: TextStyle(color: _sub, fontSize: 12.5, fontWeight: FontWeight.w600))),
        Expanded(child: _HexAlan(key: ValueKey(hex), hex: hex, gold: _gold, ink: _ink, card: widget.card, line: _line, onRenk: onc)),
      ]),
      const SizedBox(height: 14),
      // Gorsel spektrum (gokkusagi) — surukleyerek ton sec
      _gradSlider('Ton', _tonSpektrum, hsv.hue, 0, 360, (val) => onc(hsv.withHue(val).toColor())),
      _gradSlider('Canlılık', [HSVColor.fromAHSV(1, hsv.hue, 0, hsv.value).toColor(), HSVColor.fromAHSV(1, hsv.hue, 1, hsv.value).toColor()],
          hsv.saturation * 100, 0, 100, (val) => onc(hsv.withSaturation((val / 100).clamp(0, 1)).toColor())),
      _gradSlider('Parlaklık', [Colors.black, HSVColor.fromAHSV(1, hsv.hue, hsv.saturation, 1).toColor()],
          hsv.value * 100, 0, 100, (val) => onc(hsv.withValue((val / 100).clamp(0, 1)).toColor())),
    ]);
  }

  Widget _gradSlider(String ad, List<Color> colors, double deger, double min, double max, void Function(double) onc) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [
      SizedBox(width: 66, child: Text(ad, style: TextStyle(color: _sub, fontSize: 12.5, fontWeight: FontWeight.w600))),
      Expanded(child: SizedBox(height: 30, child: Stack(alignment: Alignment.center, children: [
        Container(margin: const EdgeInsets.symmetric(horizontal: 10), height: 12,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), gradient: LinearGradient(colors: colors), border: Border.all(color: _line))),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 12, activeTrackColor: Colors.transparent, inactiveTrackColor: Colors.transparent,
            thumbColor: Colors.white, overlayColor: _gold.withValues(alpha: .2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10)),
          child: Slider(value: deger.clamp(min, max), min: min, max: max, onChanged: onc)),
      ]))),
    ]));
  }

  @override
  Widget build(BuildContext context) {
    final detayGoster = ayri ? detay : ana;
    return Scaffold(
      backgroundColor: widget.bg,
      appBar: AppBar(backgroundColor: widget.bg, iconTheme: IconThemeData(color: _ink),
          title: Text('Kendi Rengin', style: TextStyle(color: _ink, fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.fromLTRB(18, 14, 18, 28), children: [
        Container(height: 60, clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _line)),
          child: Row(children: [Expanded(child: Container(color: ana)), Expanded(child: Container(color: detayGoster))])),
        const SizedBox(height: 18),
        Text('Genel Renk (butonlar, vurgular)', style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        _renkPaneli(ana, (c) => setState(() => ana = c)),
        Divider(color: _line, height: 30),
        SwitchListTile(
          contentPadding: EdgeInsets.zero, activeThumbColor: _gold,
          title: Text('Detay/çizgi rengi ayrı olsun', style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: Text('Kapalıysa fiyat/çizgiler de genel renk olur', style: TextStyle(color: _sub, fontSize: 11.5)),
          value: ayri, onChanged: (v) => setState(() => ayri = v)),
        if (ayri) ...[
          const SizedBox(height: 8),
          Text('Detay Rengi (fiyatlar, çizgiler, logo)', style: TextStyle(color: _ink, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _renkPaneli(detay, (c) => setState(() => detay = c)),
        ],
        const SizedBox(height: 24),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _gold, foregroundColor: const Color(0xFF3A2600),
              padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          onPressed: () => Navigator.pop(context, {'ana': ana, 'detay': detay, 'ayri': ayri}),
          child: const Text('Bu Rengi Uygula', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

/// HEX kod girisi: logonun/markanin tam rengini yazip uygulamak icin ( or. C41E3A).
class _HexAlan extends StatefulWidget {
  final String hex;
  final Color gold, ink, card, line;
  final void Function(Color) onRenk;
  const _HexAlan({super.key, required this.hex, required this.gold, required this.ink, required this.card, required this.line, required this.onRenk});
  @override
  State<_HexAlan> createState() => _HexAlanState();
}

class _HexAlanState extends State<_HexAlan> {
  late TextEditingController c;
  @override
  void initState() { super.initState(); c = TextEditingController(text: widget.hex); }
  @override
  void dispose() { c.dispose(); super.dispose(); }

  void _uygula(String s) {
    s = s.replaceAll('#', '').trim();
    if (RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(s)) {
      widget.onRenk(Color(int.parse('FF$s', radix: 16)));
    } else {
      c.text = widget.hex;
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: c,
      maxLength: 6,
      textCapitalization: TextCapitalization.characters,
      style: TextStyle(color: widget.ink, fontSize: 14.5, letterSpacing: 1.5, fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        prefixText: '#  ', prefixStyle: TextStyle(color: widget.gold, fontSize: 15, fontWeight: FontWeight.w800),
        counterText: '', isDense: true, filled: true, fillColor: widget.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.line)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: widget.gold)),
        suffixIcon: IconButton(icon: Icon(Icons.check, color: widget.gold, size: 20), onPressed: () => _uygula(c.text)),
      ),
      onSubmitted: _uygula,
    );
  }
}

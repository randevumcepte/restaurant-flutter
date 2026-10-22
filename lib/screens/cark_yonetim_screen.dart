import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'menu_hamburger.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Patron: Çarkıfelek yönetimi — dilimler (ad/renk/tip/değer/oran) + ayar (aktif,
/// aralık, kupon geçerlilik, kurallar). Müşteri uygulamasındaki çark buna göre döner.
class CarkYonetimScreen extends StatefulWidget {
  const CarkYonetimScreen({super.key});
  @override
  State<CarkYonetimScreen> createState() => _CarkYonetimScreenState();
}

class _CarkYonetimScreenState extends State<CarkYonetimScreen> {
  static const _mor1 = Color(0xFF7C3AED);
  static const _tipler = {'puan': 'Puan', 'yuzde': '% İndirim', 'tutar': '₺ İndirim', 'tekrar': 'Tekrar Dene', 'bos': 'Boş'};
  static const _renkler = [
    Color(0xFF7C3AED), Color(0xFFF59E0B), Color(0xFF10B981), Color(0xFFE8541E),
    Color(0xFF4F46E5), Color(0xFFF43F5E), Color(0xFF0EA5E9), Color(0xFF64748B),
  ];

  bool loading = true, kaydediyor = false;
  bool _aktif = true;
  int _aralik = 7, _gecerlilik = 7;
  final _kurallar = TextEditingController();
  List<Map<String, dynamic>> dilimler = [];

  TemaProvider get _t => context.watch<TemaProvider>();

  @override
  void initState() { super.initState(); _yukle(); }

  @override
  void dispose() { _kurallar.dispose(); super.dispose(); }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final r = await Api.carkGetir(auth.token!);
      if (!mounted) return;
      if (r['ok'] == 1) {
        setState(() {
          _aktif = (r['aktif'] ?? 1) == 1;
          _aralik = (r['aralik'] as num?)?.toInt() ?? 7;
          _gecerlilik = (r['gecerlilik'] as num?)?.toInt() ?? 7;
          _kurallar.text = (r['kurallar'] ?? '').toString();
          dilimler = ((r['dilimler'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
          loading = false;
        });
      } else {
        setState(() => loading = false);
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _kaydet() async {
    if (dilimler.where((d) => '${d['ad']}'.trim().isNotEmpty).length < 2) {
      _uyar('En az 2 dilim gerekli'); return;
    }
    final auth = context.read<AuthProvider>();
    setState(() => kaydediyor = true);
    try {
      final r = await Api.carkKaydet(auth.token!,
          aktif: _aktif, aralik: _aralik, gecerlilik: _gecerlilik, kurallar: _kurallar.text.trim(), dilimler: dilimler);
      if (!mounted) return;
      setState(() => kaydediyor = false);
      final t = context.read<TemaProvider>();
      if (r['ok'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Çark ayarları kaydedildi ✓'), backgroundColor: t.yesil, behavior: SnackBarBehavior.floating));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r['hata']?.toString() ?? 'Kaydedilemedi'), backgroundColor: t.kirmizi, behavior: SnackBarBehavior.floating));
      }
    } catch (_) {
      if (mounted) { setState(() => kaydediyor = false); _uyar('Bağlantı hatası'); }
    }
  }

  void _uyar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), behavior: SnackBarBehavior.floating));

  Color _renk(String? hex) {
    var h = (hex ?? '').replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return Color(int.tryParse(h, radix: 16) ?? 0xFF7C3AED);
  }

  String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  void _dilimEkle() {
    final renk = _renkler[dilimler.length % _renkler.length];
    final yeni = {'ad': 'Yeni', 'renk': _hex(renk), 'olasilik': 10, 'tip': 'puan', 'deger': 5.0, 'aktif': 1, '_yeni': true};
    setState(() => dilimler.add(yeni));
    _dilimDuzenle(dilimler.length - 1);
  }

  Future<void> _dilimDuzenle(int i) async {
    final d = Map<String, dynamic>.from(dilimler[i]);
    final adCtrl = TextEditingController(text: '${d['ad'] ?? ''}');
    final degerCtrl = TextEditingController(text: (d['deger'] as num?)?.toString() ?? '0');
    final olasilikCtrl = TextEditingController(text: '${(d['olasilik'] as num?)?.toInt() ?? 0}');
    String tip = '${d['tip'] ?? 'puan'}';
    String renk = '${d['renk'] ?? '#7C3AED'}';
    final t = context.read<TemaProvider>();

    final sonuc = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final degersiz = tip == 'tekrar' || tip == 'bos';
        return AlertDialog(
          backgroundColor: t.card,
          title: Text('Dilim', style: TextStyle(color: t.ink, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              _dlgAlan(adCtrl, 'Dilim adı', t),
              const SizedBox(height: 12),
              Text('Ödül tipi', style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: _tipler.entries.map((e) {
                final sel = tip == e.key;
                return GestureDetector(
                  onTap: () => setSt(() => tip = e.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: sel ? _mor1 : t.card2, borderRadius: BorderRadius.circular(18), border: Border.all(color: sel ? _mor1 : t.line)),
                    child: Text(e.value, style: TextStyle(color: sel ? Colors.white : t.sub2, fontWeight: FontWeight.bold, fontSize: 12.5)),
                  ),
                );
              }).toList()),
              const SizedBox(height: 12),
              if (!degersiz) ...[
                _dlgAlan(degerCtrl, tip == 'puan' ? 'Puan miktarı' : (tip == 'yuzde' ? 'İndirim yüzdesi' : 'İndirim tutarı (₺)'), t, sayi: true),
                const SizedBox(height: 12),
              ],
              _dlgAlan(olasilikCtrl, 'Kazanma oranı (ağırlık)', t, sayi: true),
              const SizedBox(height: 14),
              Text('Renk', style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: _renkler.map((c) {
                final hx = _hex(c);
                final sel = renk.toUpperCase() == hx;
                return GestureDetector(
                  onTap: () => setSt(() => renk = hx),
                  child: Container(width: 34, height: 34, decoration: BoxDecoration(color: c, shape: BoxShape.circle,
                      border: Border.all(color: sel ? t.ink : Colors.transparent, width: 3)),
                      child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null),
                );
              }).toList()),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, 'sil'), child: Text('Sil', style: TextStyle(color: t.kirmizi))),
            TextButton(onPressed: () => Navigator.pop(ctx, null), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
            ElevatedButton(onPressed: () {
              d['ad'] = adCtrl.text.trim();
              d['tip'] = tip;
              d['renk'] = renk;
              d['deger'] = double.tryParse(degerCtrl.text.replaceAll(',', '.')) ?? 0;
              d['olasilik'] = int.tryParse(olasilikCtrl.text) ?? 0;
              Navigator.pop(ctx, 'kaydet');
            }, style: ElevatedButton.styleFrom(backgroundColor: _mor1), child: const Text('Tamam')),
          ],
        );
      }),
    );
    if (!mounted) return;
    if (sonuc == 'sil') { setState(() => dilimler.removeAt(i)); }
    else if (sonuc == 'kaydet') {
      if ('${d['ad']}'.trim().isEmpty) { setState(() => dilimler.removeAt(i)); }
      else { setState(() => dilimler[i] = d); }
    } else {
      // vazgeç: yeni eklenip boş kalan satırı temizle
      if ('${dilimler[i]['ad']}'.trim() == 'Yeni' && (dilimler[i]['_yeni'] == true)) setState(() => dilimler.removeAt(i));
    }
  }

  Widget _dlgAlan(TextEditingController c, String label, TemaProvider t, {bool sayi = false}) => TextField(
        controller: c, keyboardType: sayi ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: TextStyle(color: t.ink),
        decoration: InputDecoration(
          labelText: label, labelStyle: TextStyle(color: t.sub), isDense: true,
          filled: true, fillColor: t.card2,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _mor1)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.card, elevation: 0.5, iconTheme: IconThemeData(color: t.ink),
        title: Text('Çarkıfelek Yönetimi', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: const [MenuHamburger()],
      ),
      floatingActionButton: loading ? null : FloatingActionButton.extended(
        onPressed: _dilimEkle, backgroundColor: _mor1,
        icon: const Icon(Icons.add, color: Colors.white), label: const Text('Dilim', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor1))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 14, 16, 100), children: [
              // Önizleme
              Center(child: SizedBox(width: 210, height: 210, child: CustomPaint(painter: _OnizlemePainter(dilimler, _renk)))),
              const SizedBox(height: 18),
              // Ayarlar
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
                child: Column(children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero, dense: true,
                    value: _aktif, activeThumbColor: t.yesil,
                    onChanged: (v) => setState(() => _aktif = v),
                    title: Text('Çark aktif', style: TextStyle(color: t.ink, fontWeight: FontWeight.w600)),
                    subtitle: Text('Müşteriler çevirebilsin', style: TextStyle(color: t.sub, fontSize: 12)),
                  ),
                  const Divider(height: 18),
                  _sayiSatir('Çevirme aralığı', 'gün (0 = her gün)', _aralik, (v) => setState(() => _aralik = v), t),
                  const SizedBox(height: 10),
                  _sayiSatir('Kupon geçerlilik', 'gün', _gecerlilik, (v) => setState(() => _gecerlilik = v < 1 ? 1 : v), t),
                ]),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Text('Dilimler', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text('(${dilimler.length})', style: TextStyle(color: t.sub, fontSize: 13)),
              ]),
              const SizedBox(height: 8),
              ...dilimler.asMap().entries.map((e) => _dilimKart(e.key, e.value, t)),
              const SizedBox(height: 16),
              Text('Kullanım kuralları (yasal)', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: _kurallar, maxLines: 4, style: TextStyle(color: t.ink, fontSize: 13),
                decoration: InputDecoration(filled: true, fillColor: t.card, isDense: true,
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _mor1))),
              ),
              const SizedBox(height: 20),
              SizedBox(height: 52, child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: _mor1, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26))),
                onPressed: kaydediyor ? null : _kaydet,
                icon: const Icon(Icons.save, color: Colors.white),
                label: Text(kaydediyor ? 'Kaydediliyor...' : 'Kaydet', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              )),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
                child: Text('Puan → anında hesaba eklenir. % / ₺ indirim → kupon kodu üretir, kasada "Ödül Doğrula"dan tüketilir (puan düşmez). Tekrar Dene → çevirme hakkı yanmaz.',
                    style: TextStyle(color: t.sub, fontSize: 12, height: 1.4)),
              ),
            ]),
    );
  }

  Widget _sayiSatir(String baslik, String alt, int deger, ValueChanged<int> onChanged, TemaProvider t) => Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
          Text(alt, style: TextStyle(color: t.sub, fontSize: 11.5)),
        ])),
        _adimBtn(Icons.remove, () => onChanged(deger - 1), t),
        Container(width: 44, alignment: Alignment.center, child: Text('$deger', style: TextStyle(color: t.ink, fontSize: 16, fontWeight: FontWeight.bold))),
        _adimBtn(Icons.add, () => onChanged(deger + 1), t),
      ]);

  Widget _adimBtn(IconData i, VoidCallback onTap, TemaProvider t) => InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(8),
        child: Container(width: 34, height: 34, decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
            child: Icon(i, size: 18, color: t.ink)),
      );

  Widget _dilimKart(int i, Map<String, dynamic> d, TemaProvider t) {
    final tip = '${d['tip'] ?? 'puan'}';
    final deger = (d['deger'] as num?)?.toDouble() ?? 0;
    final ozet = tip == 'puan' ? '+${deger.toInt()} puan'
        : tip == 'yuzde' ? '%${deger.toStringAsFixed(deger % 1 == 0 ? 0 : 1)} indirim'
        : tip == 'tutar' ? '${deger.toInt()}₺ indirim'
        : _tipler[tip] ?? tip;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _dilimDuzenle(i), borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
          child: Row(children: [
            Container(width: 22, height: 22, decoration: BoxDecoration(color: _renk(d['renk']?.toString()), shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${d['ad'] ?? ''}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w600)),
              Text(ozet, style: TextStyle(color: t.sub, fontSize: 12)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(8)),
              child: Text('oran ${(d['olasilik'] as num?)?.toInt() ?? 0}', style: TextStyle(color: t.sub2, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right, color: t.sub, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _OnizlemePainter extends CustomPainter {
  final List<Map<String, dynamic>> dilimler;
  final Color Function(String?) renk;
  _OnizlemePainter(this.dilimler, this.renk);

  @override
  void paint(Canvas canvas, Size size) {
    final n = dilimler.length;
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    if (n == 0) {
      canvas.drawCircle(center, r - 2, Paint()..color = const Color(0xFFCBD5E1)..style = PaintingStyle.stroke..strokeWidth = 2);
      return;
    }
    final seg = 2 * math.pi / n;
    final rect = Rect.fromCircle(center: center, radius: r);
    final border = Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2;
    for (int i = 0; i < n; i++) {
      final start = -math.pi / 2 + i * seg;
      canvas.drawArc(rect, start, seg, true, Paint()..color = renk(dilimler[i]['renk']?.toString()));
      canvas.drawArc(rect, start, seg, true, border);
      final mid = start + seg / 2;
      final tp = TextPainter(
        text: TextSpan(text: (dilimler[i]['ad'] ?? '').toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '…')..layout(maxWidth: r * 0.7);
      canvas.save();
      canvas.translate(center.dx + math.cos(mid) * r * 0.58, center.dy + math.sin(mid) * r * 0.58);
      canvas.rotate(mid);
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
      canvas.restore();
    }
    canvas.drawCircle(center, 14, Paint()..color = Colors.white);
    canvas.drawCircle(center, 14, Paint()..color = const Color(0xFFE2E8F0)..style = PaintingStyle.stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant _OnizlemePainter old) => true;
}

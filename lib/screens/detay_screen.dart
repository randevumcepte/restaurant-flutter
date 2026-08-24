import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// Kart tiklama -> drill-down detay (Kerzz BOSS tarzi).
/// tip: urun | kayip | acik
class DetayScreen extends StatefulWidget {
  final String tip;
  final int? id;
  final String? alt;
  final String period;
  final String baslikFallback;
  const DetayScreen({super.key, required this.tip, this.id, this.alt, this.period = 'haftalik', this.baslikFallback = 'Detay'});

  @override
  State<DetayScreen> createState() => _DetayScreenState();
}

class _DetayScreenState extends State<DetayScreen> {
  Map<String, dynamic>? d;
  bool loading = true;
  String? hata;
  final _f = NumberFormat.decimalPattern('tr');

  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _mor1 = Color(0xFF7C3AED);
  static const _mor2 = Color(0xFF9D5DC8);
  static const _mavi = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tam(num v) => '₺${_f.format(v.round())}';
  String _k(num v) {
    final a = v.abs();
    if (a >= 1000000) return '₺${(v / 1000000).toStringAsFixed(2)}M';
    if (a >= 1000) return '₺${(v / 1000).toStringAsFixed(1)}K';
    return '₺${_f.format(v.round())}';
  }

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() {
      loading = true;
      hata = null;
    });
    try {
      final res = await Api.detay(auth.token!, tip: widget.tip, id: widget.id, alt: widget.alt, period: widget.period);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          d = res;
          loading = false;
        });
      } else {
        setState(() {
          hata = res['hata']?.toString() ?? 'Detay alınamadı';
          loading = false;
        });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (e) {
      if (mounted) setState(() { hata = 'Bağlantı hatası'; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final baslik = d?['baslik']?.toString() ?? widget.baslikFallback;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor2))
          : hata != null
              ? Center(child: Text(hata!, style: const TextStyle(color: _kirmizi)))
              : RefreshIndicator(
                  onRefresh: _yukle, color: _mor2, backgroundColor: _card,
                  child: ListView(padding: const EdgeInsets.all(14), children: _icerik()),
                ),
    );
  }

  List<Widget> _icerik() {
    switch (widget.tip) {
      case 'urun':
        return _urun();
      case 'kayip':
        return _kayip();
      case 'acik':
        return _acik();
      default:
        return [const Text('—', style: TextStyle(color: Colors.white))];
    }
  }

  // ---------------- URUN ----------------
  List<Widget> _urun() {
    final ozet = (d!['ozet'] as Map?) ?? {};
    final recete = (d!['recete'] as List?) ?? [];
    final garsonlar = (d!['garsonlar'] as List?) ?? [];
    final gunluk = (d!['gunluk'] as List?) ?? [];
    final maliyetYuzde = _n(d!['maliyetYuzde']).toInt();
    final renk = maliyetYuzde >= 35 ? _kirmizi : (maliyetYuzde >= 25 ? const Color(0xFFF59E0B) : _yesil);

    return [
      // Ozet chip grid
      GridView.count(
        crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        childAspectRatio: 2.6, mainAxisSpacing: 10, crossAxisSpacing: 10,
        children: ozet.entries.map((e) => _statKart(e.key, e.value.toString())).toList(),
      ),
      const SizedBox(height: 14),
      // Recete maliyet
      _kutu('🧾 Reçete & Maliyet', [
        if (recete.isEmpty)
          const Text('Bu ürün için reçete tanımlı değil (tahmini maliyet kullanıldı).', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))
        else
          for (final r in recete)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text((r as Map)['malzeme'].toString(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13))),
                Text('${_n(r['miktar']) % 1 == 0 ? _n(r['miktar']).toInt() : _n(r['miktar'])} ${r['birim']}',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(width: 12),
                SizedBox(width: 70, child: Text(_tam(_n(r['maliyet'])), textAlign: TextAlign.right, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
              ]),
            ),
        const Divider(color: Color(0xFF243049), height: 20),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('1 porsiyon birim maliyet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          Text(_tam(_n(d!['receteBirimMaliyet'])), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Dönem toplam maliyet', style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.w600)),
          Row(children: [
            Text(_tam(_n(d!['toplamMaliyet'])), style: TextStyle(color: renk, fontWeight: FontWeight.bold)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: renk.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
              child: Text('%$maliyetYuzde', style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ]),
        ]),
      ]),
      const SizedBox(height: 14),
      // En cok satan garson
      _kutu('🏆 En Çok Satan Personel', [
        if (garsonlar.isEmpty)
          const Text('Kayıt yok', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (int i = 0; i < garsonlar.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Text('${i + 1}.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                const SizedBox(width: 8),
                Expanded(child: Text((garsonlar[i] as Map)['ad'].toString(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13))),
                Text('${_n((garsonlar[i] as Map)['adet']).toInt()} adet', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(width: 12),
                Text(_k(_n((garsonlar[i] as Map)['ciro'])), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            ),
      ]),
      const SizedBox(height: 14),
      // Gunluk adet grafik
      _kutu('📈 Son 10 Gün (adet)', [_miniBar(gunluk, birim: '')]),
    ];
  }

  // ---------------- KAYIP ----------------
  List<Widget> _kayip() {
    final kayitlar = (d!['kayitlar'] as List?) ?? [];
    final sebepler = (d!['sebepler'] as List?) ?? [];
    return [
      _ozetSerit(_tam(_n(d!['toplam'])), '${_n(d!['adet']).toInt()} kayıt', _kirmizi),
      const SizedBox(height: 14),
      if (sebepler.isNotEmpty) ...[
        _kutu('Sebep Dağılımı', [
          for (final s in sebepler)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text((s as Map)['sebep'].toString(), style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13))),
                Text('${_n(s['adet']).toInt()}×', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                const SizedBox(width: 12),
                Text(_tam(_n(s['tutar'])), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              ]),
            ),
        ]),
        const SizedBox(height: 14),
      ],
      _kutu('Kayıtlar', [
        if (kayitlar.isEmpty)
          const Text('Bu dönemde kayıt yok.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (final k in kayitlar)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF1E263B), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text((k as Map)['garson'].toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${k['sebep']} · ${k['zaman']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ]),
                ),
                Text(_tam(_n(k['tutar'])), style: const TextStyle(color: _kirmizi, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
            ),
      ]),
    ];
  }

  // ---------------- ACIK ADISYON ----------------
  List<Widget> _acik() {
    final kayitlar = (d!['kayitlar'] as List?) ?? [];
    return [
      _ozetSerit(_tam(_n(d!['toplam'])), '${_n(d!['adet']).toInt()} açık adisyon', _mavi),
      const SizedBox(height: 14),
      _kutu('Açık Masalar', [
        if (kayitlar.isEmpty)
          const Text('Şu an açık adisyon yok.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12))
        else
          for (final k in kayitlar)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: const Color(0xFF1E263B), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: _mavi.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text((k as Map)['masa'].toString(), style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(k['garson'].toString(), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('${k['kalem']} ürün · ${k['misafir']} kişi · ${k['sure_dk']} dk', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                  ]),
                ),
                Text(_tam(_n(k['tutar'])), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              ]),
            ),
      ]),
    ];
  }

  // ---------------- ORTAK ----------------
  Widget _statKart(String baslik, String deger) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(baslik, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          const SizedBox(height: 3),
          FittedBox(child: Text(deger, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
        ]),
      );

  Widget _ozetSerit(String buyuk, String alt, Color renk) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [renk.withValues(alpha: 0.85), renk.withValues(alpha: 0.55)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(buyuk, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold)),
          Text(alt, style: const TextStyle(color: Colors.white70, fontSize: 13)),
        ]),
      );

  Widget _kutu(String baslik, List<Widget> cocuklar) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...cocuklar,
        ]),
      );

  Widget _miniBar(List gunluk, {String birim = ''}) {
    final maks = gunluk.fold<num>(1, (a, e) => _n((e as Map)['deger']) > a ? _n(e['deger']) : a);
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: gunluk.asMap().entries.map<Widget>((entry) {
          final i = entry.key;
          final m = entry.value as Map;
          final v = _n(m['deger']);
          final h = maks > 0 ? (v / maks * 84).clamp(3.0, 84.0).toDouble() : 3.0;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('${v % 1 == 0 ? v.toInt() : v}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 8)),
                const SizedBox(height: 2),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: h),
                  duration: Duration(milliseconds: 450 + i * 40),
                  curve: Curves.easeOutCubic,
                  builder: (_, hv, child) => Container(
                    height: hv,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_mor2, _mor1], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(m['gun'].toString(), style: const TextStyle(color: Color(0xFF64748B), fontSize: 8)),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }
}

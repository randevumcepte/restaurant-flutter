import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import 'fis.dart';

/// Gün Sonu / Z Raporu — günlük kapanış özeti + yazdır.
class ZRaporuScreen extends StatefulWidget {
  const ZRaporuScreen({super.key});

  @override
  State<ZRaporuScreen> createState() => _ZRaporuScreenState();
}

class _ZRaporuScreenState extends State<ZRaporuScreen> {
  Map<String, dynamic>? d;
  bool loading = true;
  DateTime _tarih = DateTime.now();
  final _f = NumberFormat.decimalPattern('tr');

  static const _bg = Color(0xFFF1F5F9);
  static const _mavi = Color(0xFF4F46E5);

  static const _aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tl(num v) => '₺${_f.format(v.round())}';
  String get _ymd => '${_tarih.year}-${_tarih.month.toString().padLeft(2, '0')}-${_tarih.day.toString().padLeft(2, '0')}';
  String get _tarihMetin => '${_tarih.day} ${_aylar[_tarih.month]} ${_tarih.year}';

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.zRaporu(auth.token!, tarih: _ymd);
      if (!mounted) return;
      setState(() {
        d = res['ok'] == 1 ? res : null;
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _gunDegis(int delta) {
    final yeni = _tarih.add(Duration(days: delta));
    if (yeni.isAfter(DateTime.now())) return;
    setState(() => _tarih = yeni);
    _yukle();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text('Gün Sonu (Z Raporu)', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          if (d != null)
            IconButton(onPressed: () => zRaporuYazdir(d!), icon: const Icon(Icons.print, color: _mavi)),
        ],
      ),
      body: Column(children: [
        // Tarih secici
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: () => _gunDegis(-1), icon: const Icon(Icons.chevron_left, color: _mavi)),
            Text(_tarihMetin, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 15)),
            IconButton(onPressed: () => _gunDegis(1), icon: const Icon(Icons.chevron_right, color: _mavi)),
          ]),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : d == null
                  ? const Center(child: Text('Veri alınamadı', style: TextStyle(color: Color(0xFF94A3B8))))
                  : RefreshIndicator(onRefresh: _yukle, child: _icerik()),
        ),
      ]),
    );
  }

  Widget _icerik() {
    final odeme = (d!['odeme'] as List?) ?? [];
    final servis = (d!['servis'] as List?) ?? [];
    final top = (d!['top'] as List?) ?? [];
    final my = _n(d!['maliyet_yuzde']).toInt();
    final myRenk = my >= 38 ? const Color(0xFFF43F5E) : (my >= 30 ? const Color(0xFFF59E0B) : const Color(0xFF059669));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Ciro hero
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mavi, Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(20)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Toplam Ciro', style: TextStyle(color: Colors.white70, fontSize: 13)),
            Text(_tl(_n(d!['ciro'])), style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(children: [
              _heroMini('${_n(d!['kapanan']).toInt()}', 'Adisyon'),
              _heroMini('${_n(d!['misafir']).toInt()}', 'Misafir'),
              _heroMini(_tl(_n(d!['ortalama'])), 'Ort.'),
              _heroMini(_tl(_n(d!['kisi_basi'])), 'Kişi Başı'),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        if (_n(d!['acik_kalan']) > 0)
          _uyari('${_n(d!['acik_kalan']).toInt()} adisyon hâlâ açık — gün kapanmadan kapatılmalı.'),
        _kutu('💳 Ödeme Dağılımı', [
          for (final o in odeme) _satir('${(o as Map)['tip'].toString().toUpperCase()} (${_n(o['adet']).toInt()})', _tl(_n(o['tutar']))),
        ]),
        _kutu('🍽️ Servis Tipi', [
          for (final s in servis) _satir('${(s as Map)['ad']} (${_n(s['adet']).toInt()})', _tl(_n(s['tutar']))),
        ]),
        _kutu('💰 Maliyet / Kâr', [
          _satir('Food-Cost', '${_tl(_n(d!['maliyet']))}  (%$my)', renk: myRenk),
          _satir('Brüt Kâr', _tl(_n(d!['brut_kar'])), renk: const Color(0xFF059669), kalin: true),
        ]),
        _kutu('🎯 Kayıp / Sızıntı', [
          _satir('İskonto', _tl(_n(d!['iskonto'])), renk: const Color(0xFFF43F5E)),
          _satir('İkram', _tl(_n(d!['ikram'])), renk: const Color(0xFFF43F5E)),
          _satir('Silinen Ürün', _tl(_n(d!['void'])), renk: const Color(0xFFF43F5E)),
          _satir('İptal Adisyon (${_n(d!['iptal_adet']).toInt()})', _tl(_n(d!['iptal_tutar'])), renk: const Color(0xFFF43F5E)),
          _satir('Fire', _tl(_n(d!['fire'])), renk: const Color(0xFFF43F5E)),
        ]),
        _kutu('🔥 En Çok Satan', [
          for (int i = 0; i < top.length; i++)
            _satir('${i + 1}. ${(top[i] as Map)['urun_adi']}', '${_n((top[i] as Map)['adet']).toInt()} adet'),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => zRaporuYazdir(d!),
            style: FilledButton.styleFrom(backgroundColor: _mavi, padding: const EdgeInsets.symmetric(vertical: 14)),
            icon: const Icon(Icons.print, color: Colors.white),
            label: const Text('Z Raporunu Yazdır', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _heroMini(String d, String e) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(child: Text(d, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold))),
          Text(e, style: const TextStyle(color: Colors.white60, fontSize: 10)),
        ]),
      );

  Widget _kutu(String baslik, List<Widget> c) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          ...c,
        ]),
      );

  Widget _satir(String s, String v, {Color? renk, bool kalin = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(s, style: const TextStyle(color: Color(0xFF334155)))),
          Text(v, style: TextStyle(fontWeight: kalin ? FontWeight.bold : FontWeight.w600, color: renk ?? const Color(0xFF0F172A))),
        ]),
      );

  Widget _uyari(String m) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFED7AA))),
        child: Row(children: [const Text('⚠️ '), Expanded(child: Text(m, style: const TextStyle(color: Color(0xFF9A3412), fontSize: 13)))]),
      );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Garson KENDİ özeti (dashboard): kendi sattıkları, baktığı masa, açık masaları,
/// sattığı ürün, ortalama masa, bahşiş. Finansal kâr/maliyet YOK — garsona uygun.
class GarsonOzetScreen extends StatefulWidget {
  const GarsonOzetScreen({super.key});
  @override
  State<GarsonOzetScreen> createState() => _GarsonOzetScreenState();
}

class _GarsonOzetScreenState extends State<GarsonOzetScreen> {
  static const _mor = Color(0xFF7C3AED);
  static const _mor2 = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  final _f = NumberFormat.decimalPattern('tr');

  TemaProvider get _t => context.watch<TemaProvider>();
  Map<String, dynamic>? data;
  bool loading = true;
  String? hata;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _yukle();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _yukle(sessiz: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tl(dynamic v) => '${_f.format(_n(v).round())} TL';

  Future<void> _yukle({bool sessiz = false}) async {
    final auth = context.read<AuthProvider>();
    if (!sessiz) setState(() { loading = true; hata = null; });
    try {
      final res = await Api.garsonOzet(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() { data = Map<String, dynamic>.from(res); loading = false; });
      } else {
        setState(() { hata = res['hata']?.toString() ?? 'Alınamadı'; loading = false; });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() { hata = 'Bağlantı bekleniyor…'; loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final ad = data?['ad']?.toString() ?? context.read<AuthProvider>().ad ?? '';
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text('👋 ${ad.isEmpty ? "Özetim" : ad}', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(onPressed: () => _yukle(), icon: Icon(Icons.refresh, color: t.sub)),
          IconButton(
            tooltip: 'Çıkış',
            onPressed: () async {
              final onay = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: t.card,
                  title: Text('Çıkış yapılsın mı?', style: TextStyle(color: t.ink, fontSize: 17)),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
                    ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF43F5E)), child: const Text('Çıkış')),
                  ],
                ),
              );
              if (onay == true && context.mounted) context.read<AuthProvider>().cikis();
            },
            icon: const Icon(Icons.logout, color: Color(0xFFF87171)),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor))
          : RefreshIndicator(
              onRefresh: _yukle,
              color: _mor,
              backgroundColor: t.card,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 30),
                children: [
                  if (hata != null)
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(hata!, style: TextStyle(color: t.sub, fontSize: 12.5))),
                  _hero(t),
                  const SizedBox(height: 12),
                  _kartlar(t),
                  const SizedBox(height: 18),
                  _acikMasalar(t),
                  const SizedBox(height: 18),
                  _topUrun(t),
                ],
              ),
            ),
    );
  }

  // Bugünkü satış — büyük hero
  Widget _hero(TemaProvider t) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_mor, _mor2], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _mor.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Bugünkü Satışım', style: TextStyle(color: Color(0xFFE9D5FF), fontSize: 13.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(_tl(data?['satis']), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Row(children: [
          _heroMini('🍽️ ${_n(data?['masa_sayisi']).toInt()}', 'masa'),
          const SizedBox(width: 18),
          _heroMini('📦 ${_n(data?['urun_adedi']).toInt()}', 'ürün'),
          const SizedBox(width: 18),
          _heroMini('⚖️ ${_tl(data?['ort_masa'])}', 'ort. masa'),
        ]),
      ]),
    );
  }

  Widget _heroMini(String buyuk, String alt) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(buyuk, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
        Text(alt, style: const TextStyle(color: Color(0xFFD8C7F5), fontSize: 10.5)),
      ]);

  // Kart ızgarası: açık masa, ürün, ortalama, bahşiş
  Widget _kartlar(TemaProvider t) {
    return Row(children: [
      Expanded(child: _kart(t, '🪑', 'Açık Masam', '${_n(data?['acik_masa']).toInt()}', alt: _tl(data?['acik_toplam']), renk: _amber)),
      const SizedBox(width: 10),
      Expanded(child: _kart(t, '💸', 'Bahşişim', _tl(data?['bahsis']), renk: _yesil)),
    ]);
  }

  Widget _kart(TemaProvider t, String ikon, String baslik, String buyuk, {String? alt, required Color renk}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$ikon $baslik', style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text(buyuk, style: TextStyle(color: renk, fontSize: 20, fontWeight: FontWeight.w900)),
        if (alt != null) ...[const SizedBox(height: 2), Text(alt, style: TextStyle(color: t.sub, fontSize: 11.5))],
      ]),
    );
  }

  Widget _acikMasalar(TemaProvider t) {
    final list = (data?['acik_masalar'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _baslik(t, '🪑 Açık Masalarım', '${list.length}'),
      const SizedBox(height: 8),
      if (list.isEmpty)
        _bosSatir(t, 'Şu an açık masan yok.')
      else
        Container(
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
          child: Column(children: [
            for (int i = 0; i < list.length; i++)
              Container(
                decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: t.line))),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                child: Row(children: [
                  Expanded(child: Text('${(list[i] as Map)['masa']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w700))),
                  Text(_tl((list[i] as Map)['toplam']), style: const TextStyle(color: _mor, fontSize: 14.5, fontWeight: FontWeight.w800)),
                ]),
              ),
          ]),
        ),
    ]);
  }

  Widget _topUrun(TemaProvider t) {
    final list = (data?['top_urun'] as List?) ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _baslik(t, '🔥 Bugün En Çok Sattıklarım', '${list.length}'),
      const SizedBox(height: 8),
      if (list.isEmpty)
        _bosSatir(t, 'Bugün henüz satış yok.')
      else
        Container(
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
          child: Column(children: [
            for (int i = 0; i < list.length; i++)
              Container(
                decoration: BoxDecoration(border: i == 0 ? null : Border(top: BorderSide(color: t.line))),
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 30, height: 30, alignment: Alignment.center,
                    decoration: BoxDecoration(color: _mor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(9)),
                    child: Text('${_n((list[i] as Map)['adet']).toInt()}×', style: const TextStyle(color: _mor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Text('${(list[i] as Map)['ad']}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600))),
                  Text(_tl((list[i] as Map)['tutar']), style: TextStyle(color: t.sub, fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
          ]),
        ),
    ]);
  }

  Widget _baslik(TemaProvider t, String metin, String sayi) => Row(children: [
        Text(metin, style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.line)),
          child: Text(sayi, style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
      ]);

  Widget _bosSatir(TemaProvider t, String metin) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
        child: Text(metin, style: TextStyle(color: t.sub, fontSize: 13)),
      );
}

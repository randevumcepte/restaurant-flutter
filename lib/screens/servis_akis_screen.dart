import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import 'servis_ekip_screen.dart';

/// SERVİS / GARSON İŞ AKIŞI (departman iş ekranı A):
/// Tek ekranda canlı "yapılacaklar": bekleyen çağrılarım + servise hazır bekleyen
/// ürünlerim (mutfaktan çıktı) + açık masalarım. Her biri aksiyon alınabilir.
class ServisAkisScreen extends StatefulWidget {
  const ServisAkisScreen({super.key});
  @override
  State<ServisAkisScreen> createState() => _ServisAkisScreenState();
}

class _ServisAkisScreenState extends State<ServisAkisScreen> {
  static const _mor = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);
  final _f = NumberFormat.decimalPattern('tr');

  TemaProvider get _t => context.watch<TemaProvider>();
  Map<String, dynamic>? data;
  bool loading = true;
  Timer? _timer;
  final Set<int> _islenen = {}; // çift dokunuş koruması

  @override
  void initState() {
    super.initState();
    _yukle();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _yukle(sessiz: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tl(dynamic v) => '${_f.format(_n(v).round())} TL';
  String _sure(dynamic v) {
    final sn = _n(v).toInt();
    if (sn < 60) return '$sn sn';
    final dk = sn ~/ 60;
    if (dk < 60) return '$dk dk';
    return '${dk ~/ 60} sa ${dk % 60} dk';
  }

  Future<void> _yukle({bool sessiz = false}) async {
    final auth = context.read<AuthProvider>();
    if (!sessiz) setState(() => loading = true);
    try {
      final res = await Api.servisAkis(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() { data = Map<String, dynamic>.from(res); loading = false; });
      } else {
        setState(() => loading = false);
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _cagriKapat(int id) async {
    final auth = context.read<AuthProvider>();
    try { await Api.garsonCagriKapat(auth.token!, id); } catch (_) {}
    _yukle(sessiz: true);
  }

  Future<void> _teslim(int kalemId) async {
    if (_islenen.contains(kalemId)) return;
    setState(() => _islenen.add(kalemId));
    final auth = context.read<AuthProvider>();
    try { await Api.servisTeslim(auth.token!, kalemId); } catch (_) {}
    if (mounted) setState(() => _islenen.remove(kalemId));
    _yukle(sessiz: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final auth = context.watch<AuthProvider>();
    final oz = (data?['ozet'] as Map?) ?? {};
    final cagrilar = (data?['cagrilar'] as List?) ?? [];
    final hazir = (data?['hazir'] as List?) ?? [];
    final acik = (data?['acik_masalar'] as List?) ?? [];
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        title: Text('Servis — İş Akışım', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.ink),
        actions: [
          if (auth.sorumlu)
            IconButton(
              tooltip: 'Ekip',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ServisEkipScreen())),
              icon: Icon(Icons.groups, color: _mor),
            ),
          IconButton(onPressed: () => _yukle(), icon: Icon(Icons.refresh, color: t.sub)),
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
                  _ozetBar(t, oz),
                  const SizedBox(height: 18),
                  _bolum(t, '🔔 Çağrılar', cagrilar.length, _kirmizi,
                      cagrilar.isEmpty ? _bos(t, 'Bekleyen çağrı yok.') : Column(children: [for (final c in cagrilar) _cagriSatir(t, c as Map)])),
                  const SizedBox(height: 16),
                  _bolum(t, '🍽️ Servise Hazır', hazir.length, _yesil,
                      hazir.isEmpty ? _bos(t, 'Servise hazır bekleyen ürün yok.') : Column(children: [for (final h in hazir) _hazirSatir(t, h as Map)])),
                  const SizedBox(height: 16),
                  _bolum(t, '🪑 Açık Masalarım', acik.length, _mavi,
                      acik.isEmpty ? _bos(t, 'Açık masan yok.') : Column(children: [for (final a in acik) _acikSatir(t, a as Map)])),
                ],
              ),
            ),
    );
  }

  Widget _ozetBar(TemaProvider t, Map oz) => Row(children: [
        Expanded(child: _ozetKart(t, Icons.notifications_active, '${_n(oz['cagri']).toInt()}', 'Çağrı', _kirmizi)),
        const SizedBox(width: 10),
        Expanded(child: _ozetKart(t, Icons.room_service, '${_n(oz['hazir']).toInt()}', 'Servise hazır', _yesil)),
        const SizedBox(width: 10),
        Expanded(child: _ozetKart(t, Icons.table_restaurant, '${_n(oz['acik']).toInt()}', 'Açık masam', _mavi)),
      ]);

  Widget _ozetKart(TemaProvider t, IconData ik, String say, String etiket, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 11),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: c.withValues(alpha: .15), shape: BoxShape.circle), child: Icon(ik, color: c, size: 19)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(say, style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
              Text(etiket, style: TextStyle(color: t.sub, fontSize: 10.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );

  Widget _bolum(TemaProvider t, String baslik, int sayi, Color c, Widget govde) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(baslik, style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: c.withValues(alpha: .14), borderRadius: BorderRadius.circular(20)), child: Text('$sayi', style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
        const SizedBox(height: 8),
        govde,
      ]);

  Widget _kutu(TemaProvider t, {required Widget child}) => Container(
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
        child: child,
      );

  IconData _cagriIkon(String tip) {
    switch (tip) {
      case 'servise_hazir': return Icons.room_service;
      case 'tasima': return Icons.swap_horiz;
      case 'odeme': return Icons.payments;
      case 'hesap': return Icons.receipt_long;
      case 'siparis': return Icons.restaurant_menu;
      default: return Icons.pan_tool;
    }
  }

  Widget _cagriSatir(TemaProvider t, Map c) => _kutu(t, child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: _kirmizi.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)), child: Icon(_cagriIkon('${c['tip']}'), color: _kirmizi, size: 20)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${c['masa']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
            Text('${c['tip_ad']} · ${_sure(c['saniye'])} önce${c['tutar'] != null ? ' · ${_tl(c['tutar'])}' : ''}', style: TextStyle(color: t.sub, fontSize: 12)),
          ])),
          _btn('Karşılandı', Icons.check, _yesil, () => _cagriKapat(_n(c['id']).toInt())),
        ]),
      ));

  Widget _hazirSatir(TemaProvider t, Map h) {
    final id = _n(h['id']).toInt();
    final isleniyor = _islenen.contains(id);
    return Padding(padding: const EdgeInsets.only(bottom: 8), child: _kutu(t, child: Padding(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: _yesil.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.restaurant, color: _yesil, size: 20)),
        const SizedBox(width: 11),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_n(h['adet']).toInt()}× ${h['urun']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
          Text('${h['masa']} · ${_sure(h['saniye'])} bekliyor', style: TextStyle(color: t.sub, fontSize: 12)),
        ])),
        _btn(isleniyor ? '...' : 'Teslim Ettim', Icons.done_all, _mavi, isleniyor ? null : () => _teslim(id)),
      ]),
    )));
  }

  Widget _acikSatir(TemaProvider t, Map a) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _kutu(t, child: Padding(
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: _mavi.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.table_restaurant, color: _mavi, size: 20)),
          const SizedBox(width: 11),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${a['masa']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w800)),
            Text('${_tl(a['toplam'])} · ${_sure(a['saniye'])} açık', style: TextStyle(color: t.sub, fontSize: 12)),
          ])),
          Icon(Icons.chevron_right, color: t.sub),
        ]),
      )));

  Widget _btn(String metin, IconData ik, Color c, VoidCallback? onTap) => Material(
        color: c.withValues(alpha: onTap == null ? .5 : 1),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(ik, color: Colors.white, size: 16),
              const SizedBox(width: 6),
              Text(metin, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      );

  Widget _bos(TemaProvider t, String metin) => _kutu(t, child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
        child: Text(metin, style: TextStyle(color: t.sub, fontSize: 13)),
      ));
}

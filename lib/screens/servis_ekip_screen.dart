import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// SERVİS ŞEFİ EKİP GÖRÜNÜMÜ (departman iş ekranı B):
/// Sorumlu/patron için ekip performansı (adisyon/ciro/kalem/ort. servis) + salon kapsama özeti.
class ServisEkipScreen extends StatefulWidget {
  const ServisEkipScreen({super.key});
  @override
  State<ServisEkipScreen> createState() => _ServisEkipScreenState();
}

class _ServisEkipScreenState extends State<ServisEkipScreen> {
  static const _mor = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);
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
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _yukle(sessiz: true));
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
      final res = await Api.servisEkip(auth.token!);
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
    final oz = (data?['ozet'] as Map?) ?? {};
    final garsonlar = (data?['garsonlar'] as List?) ?? [];
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        elevation: 0,
        title: Text('Servis — Ekip', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.ink),
        actions: [IconButton(onPressed: () => _yukle(), icon: Icon(Icons.refresh, color: t.sub))],
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
                  if (hata != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(hata!, style: TextStyle(color: t.sub, fontSize: 12.5))),
                  Row(children: [
                    Expanded(child: _ozetKart(t, Icons.table_restaurant, '${_n(oz['acik_masa']).toInt()}', 'Açık masa', _mavi)),
                    const SizedBox(width: 10),
                    Expanded(child: _ozetKart(t, Icons.notifications_active, '${_n(oz['bekleyen_cagri']).toInt()}', 'Bekleyen çağrı', _kirmizi)),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _ozetKart(t, Icons.room_service, '${_n(oz['servise_hazir_bekleyen']).toInt()}', 'Servise hazır bekleyen', _yesil)),
                    const SizedBox(width: 10),
                    Expanded(child: _ozetKart(t, Icons.badge, '${_n(oz['aktif_garson']).toInt()}', 'Aktif garson', _mor)),
                  ]),
                  const SizedBox(height: 20),
                  Text('👥 Garson Performansı (bugün)', style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (garsonlar.isEmpty)
                    _bos(t, 'Henüz garson verisi yok.')
                  else
                    for (final g in garsonlar) _garsonKart(t, g as Map),
                ],
              ),
            ),
    );
  }

  Widget _ozetKart(TemaProvider t, IconData ik, String say, String etiket, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 11),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: c.withValues(alpha: .15), shape: BoxShape.circle), child: Icon(ik, color: c, size: 19)),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(say, style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
            Text(etiket, style: TextStyle(color: t.sub, fontSize: 10.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );

  Widget _garsonKart(TemaProvider t, Map g) => Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(width: 34, height: 34, decoration: BoxDecoration(color: _mor.withValues(alpha: .14), shape: BoxShape.circle), child: const Icon(Icons.person, color: _mor, size: 19)),
            const SizedBox(width: 10),
            Expanded(child: Text('${g['ad']}', style: TextStyle(color: t.ink, fontSize: 14.5, fontWeight: FontWeight.w800))),
            Text(_tl(g['ciro']), style: const TextStyle(color: _yesil, fontSize: 15, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _mini(t, '${_n(g['adisyon']).toInt()}', 'Adisyon'),
            _mini(t, '${_n(g['kalem']).toInt()}', 'Kalem'),
            _mini(t, '${_n(g['ort_adisyon']).round()}₺', 'Ort. adisyon'),
            _mini(t, _n(g['ort_servis_dk']).toInt() > 0 ? '${_n(g['ort_servis_dk']).toInt()} dk' : '—', 'Ort. servis'),
          ]),
        ]),
      );

  Widget _mini(TemaProvider t, String buyuk, String alt) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(buyuk, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(alt, style: TextStyle(color: t.sub, fontSize: 10.5)),
        ]),
      );

  Widget _bos(TemaProvider t, String metin) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
        child: Text(metin, style: TextStyle(color: t.sub, fontSize: 13)),
      );
}

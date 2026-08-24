import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

class RaporlarScreen extends StatefulWidget {
  const RaporlarScreen({super.key});

  @override
  State<RaporlarScreen> createState() => _RaporlarScreenState();
}

class _RaporlarScreenState extends State<RaporlarScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  final _f = NumberFormat.decimalPattern('tr');

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _p(num v) => '${_f.format(v.round())} ₺';

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.raporlar(auth.token!);
      if (!mounted) return;
      setState(() {
        data = res;
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _kutu(String baslik, List<Widget> cocuklar) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(baslik, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          ...cocuklar,
        ]),
      );

  Widget _satir(String sol, String sag, {Color? renk}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(sol, style: const TextStyle(color: Color(0xFF334155)))),
          Text(sag, style: TextStyle(fontWeight: FontWeight.w600, color: renk ?? const Color(0xFF0F172A))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final top = (data?['top'] as List?) ?? [];
    final personel = (data?['personel'] as List?) ?? [];
    final odeme = (data?['odeme'] as List?) ?? [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('Raporlar  (30 gün)',
            style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _kutu('🔥 En Çok Satan Ürünler', [
                    for (int i = 0; i < top.length; i++)
                      _satir('${i + 1}. ${(top[i] as Map)['urun_adi']}',
                          '${_n((top[i] as Map)['adet']).round()} adet · ${_p(_n((top[i] as Map)['ciro']))}',
                          renk: const Color(0xFF059669)),
                  ]),
                  _kutu('👤 Personel Satış', [
                    for (final p in personel)
                      _satir((p as Map)['ad'].toString(),
                          '${_n(p['adisyon']).round()} adisyon · ${_p(_n(p['ciro']))}',
                          renk: const Color(0xFF4F46E5)),
                  ]),
                  _kutu('💳 Ödeme Tipleri', [
                    for (final o in odeme)
                      _satir((o as Map)['tip'].toString().replaceAll('_', ' '), _p(_n(o['t']))),
                  ]),
                ],
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

class PaketScreen extends StatefulWidget {
  const PaketScreen({super.key});

  @override
  State<PaketScreen> createState() => _PaketScreenState();
}

class _PaketScreenState extends State<PaketScreen> {
  List siparisler = [];
  bool loading = true;
  final _f = NumberFormat.decimalPattern('tr');

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.paket(auth.token!);
      if (!mounted) return;
      setState(() {
        siparisler = (res['siparisler'] as List?) ?? [];
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Color _platRenk(String p) {
    switch (p) {
      case 'getir':
        return const Color(0xFF7C3AED);
      case 'yemeksepeti':
        return const Color(0xFFE11D48);
      case 'trendyol':
        return const Color(0xFFEA580C);
      case 'migros':
        return const Color(0xFF16A34A);
      case 'whatsapp':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('Paket Siparişler  (${siparisler.length})',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: siparisler.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 120),
                      Center(child: Text('Şu an aktif paket sipariş yok.', style: TextStyle(color: Color(0xFF94A3B8)))),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: siparisler.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final s = siparisler[i];
                        final plat = (s['platform'] ?? '-').toString();
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                            color: _platRenk(plat), borderRadius: BorderRadius.circular(6)),
                                        child: Text(plat.toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                      ),
                                      const SizedBox(width: 8),
                                      Text('● ${s['teslimat_durumu'] ?? ''}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    ]),
                                    const SizedBox(height: 6),
                                    Text(s['musteri']?.toString() ?? 'Müşteri',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                    if (s['kurye'] != null)
                                      Text('🛵 ${s['kurye']}', style: const TextStyle(fontSize: 12, color: Color(0xFF4F46E5))),
                                  ],
                                ),
                              ),
                              Text('${_f.format(_n(s['toplam']).round())} ₺',
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

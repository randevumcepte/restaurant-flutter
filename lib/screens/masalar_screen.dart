import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import 'detay_screen.dart';

class MasalarScreen extends StatefulWidget {
  const MasalarScreen({super.key});

  @override
  State<MasalarScreen> createState() => _MasalarScreenState();
}

class _MasalarScreenState extends State<MasalarScreen> {
  List masalar = [];
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
      final res = await Api.masalar(auth.token!);
      if (!mounted) return;
      setState(() {
        masalar = (res['masalar'] as List?) ?? [];
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Color _renk(String durum) {
    switch (durum) {
      case 'dolu':
        return const Color(0xFFEEF2FF);
      case 'rezerve':
        return const Color(0xFFFFFBEB);
      case 'kirli':
        return const Color(0xFFFFF7ED);
      default:
        return Colors.white;
    }
  }

  Color _kenar(String durum) {
    switch (durum) {
      case 'dolu':
        return const Color(0xFFC7D2FE);
      case 'rezerve':
        return const Color(0xFFFDE68A);
      case 'kirli':
        return const Color(0xFFFED7AA);
      default:
        return const Color(0xFFE2E8F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bolgeye gore grupla
    final Map<String, List> gruplu = {};
    for (final m in masalar) {
      final b = (m['bolge'] ?? 'Salon').toString();
      gruplu.putIfAbsent(b, () => []).add(m);
    }
    final dolu = masalar.where((m) => m['durum'] == 'dolu').length;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('Masalar  ($dolu / ${masalar.length} dolu)',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _yukle,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  for (final entry in gruplu.entries) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 4),
                      child: Text('📍 ${entry.key}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155))),
                    ),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        for (final m in entry.value)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: m['adisyon_id'] != null
                                ? () async {
                                    await Navigator.of(context).push(MaterialPageRoute(
                                        builder: (_) => DetayScreen(
                                            tip: 'adisyon', id: _n(m['adisyon_id']).toInt(), baslikFallback: m['ad'].toString())));
                                    _yukle();
                                  }
                                : null,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _renk(m['durum'].toString()),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: _kenar(m['durum'].toString()), width: 1.5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(m['ad'].toString(),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  Text('${m['kapasite']} kişi',
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                  if (_n(m['tutar']) > 0)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text('${_f.format(_n(m['tutar']).round())} ₺',
                                          style: const TextStyle(
                                              fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                                    )
                                  else
                                    const Padding(
                                      padding: EdgeInsets.only(top: 4),
                                      child: Text('boş', style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
                                    ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
    );
  }
}

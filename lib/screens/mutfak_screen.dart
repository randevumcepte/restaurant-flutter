import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// Mutfak (KDS) — bekleyen sipariş kalemleri (durum=gonderildi), adisyona gruplu.
/// Süreye göre renk kodlu; "Hazır" ile mutfaktan düşer. 15 sn'de bir otomatik yenilenir.
class MutfakScreen extends StatefulWidget {
  const MutfakScreen({super.key});

  @override
  State<MutfakScreen> createState() => _MutfakScreenState();
}

class _MutfakScreenState extends State<MutfakScreen> {
  List siparisler = [];
  bool loading = true;
  Timer? _timer;

  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _yukle();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => _yukle(sessiz: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _yukle({bool sessiz = false}) async {
    final auth = context.read<AuthProvider>();
    if (!sessiz) setState(() => loading = true);
    try {
      final res = await Api.mutfak(auth.token!);
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

  Future<void> _hazir(int adisyonId) async {
    final auth = context.read<AuthProvider>();
    try {
      await Api.mutfakHazir(auth.token!, adisyonId: adisyonId);
      _yukle(sessiz: true);
    } catch (_) {}
  }

  Color _renk(int dk) {
    if (dk >= 15) return const Color(0xFFF43F5E);
    if (dk >= 8) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        title: Text('Mutfak  (${siparisler.length} sipariş)',
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF9D5DC8)))
          : siparisler.isEmpty
              ? RefreshIndicator(
                  onRefresh: _yukle,
                  color: const Color(0xFF9D5DC8), backgroundColor: _card,
                  child: ListView(children: const [
                    SizedBox(height: 160),
                    Icon(Icons.restaurant_menu, size: 54, color: Color(0xFF334155)),
                    SizedBox(height: 12),
                    Center(child: Text('Bekleyen sipariş yok. 👨‍🍳', style: TextStyle(color: Color(0xFF64748B)))),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _yukle,
                  color: const Color(0xFF9D5DC8), backgroundColor: _card,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 360, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.9),
                    itemCount: siparisler.length,
                    itemBuilder: (context, i) => _kart(siparisler[i] as Map),
                  ),
                ),
    );
  }

  Widget _kart(Map s) {
    final dk = _n(s['dk']).toInt();
    final renk = _renk(dk);
    final kalemler = (s['kalemler'] as List?) ?? [];
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16), border: Border.all(color: renk.withValues(alpha: 0.6), width: 1.5)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Baslik: masa + sure
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.15), borderRadius: const BorderRadius.vertical(top: Radius.circular(15))),
          child: Row(children: [
            Text(s['masa'].toString(), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const Spacer(),
            Icon(Icons.schedule, size: 14, color: renk),
            const SizedBox(width: 4),
            Text('$dk dk', style: TextStyle(color: renk, fontSize: 13, fontWeight: FontWeight.bold)),
          ]),
        ),
        // Kalemler
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            children: [
              for (final k in kalemler)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      margin: const EdgeInsets.only(top: 1), padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                      decoration: BoxDecoration(color: const Color(0xFF243049), borderRadius: BorderRadius.circular(6)),
                      child: Text('${_n((k as Map)['adet']).toInt()}×', style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(k['ad'].toString(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                        if ((k['not']?.toString() ?? '').isNotEmpty)
                          Text('not: ${k['not']}', style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11)),
                      ]),
                    ),
                  ]),
                ),
            ],
          ),
        ),
        // Hazir
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _hazir(_n(s['adisyon_id']).toInt()),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981), padding: const EdgeInsets.symmetric(vertical: 11)),
              icon: const Icon(Icons.check, size: 18, color: Colors.white),
              label: const Text('Hazır', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ]),
    );
  }
}

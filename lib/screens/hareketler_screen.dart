import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';
import 'detay_screen.dart';

/// Hareketler / Aktivite Log — masa taşı/birleştir/böl + ürün silme/iskonto/ikram kayıtları.
class HareketlerScreen extends StatefulWidget {
  const HareketlerScreen({super.key});

  @override
  State<HareketlerScreen> createState() => _HareketlerScreenState();
}

class _HareketlerScreenState extends State<HareketlerScreen> {
  List hareketler = [];
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
      final res = await Api.hareketler(auth.token!);
      if (!mounted) return;
      setState(() {
        hareketler = (res['hareketler'] as List?) ?? [];
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  (IconData, Color) _ikon(String tip) {
    switch (tip) {
      case 'tasima':
        return (Icons.swap_horiz, const Color(0xFF4F46E5));
      case 'birlestirme':
        return (Icons.merge_type, const Color(0xFF7C3AED));
      case 'bolme':
        return (Icons.call_split, const Color(0xFF0EA5E9));
      case 'void':
        return (Icons.remove_circle_outline, const Color(0xFFF43F5E));
      case 'indirim':
        return (Icons.local_offer_outlined, const Color(0xFFF59E0B));
      case 'ikram':
        return (Icons.card_giftcard, const Color(0xFF10B981));
      default:
        return (Icons.history, const Color(0xFF64748B));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        title: const Text('Hareketler', style: TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh, color: Color(0xFF64748B)))],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : hareketler.isEmpty
              ? const Center(child: Text('Henüz hareket yok.', style: TextStyle(color: Color(0xFF94A3B8))))
              : RefreshIndicator(
                  onRefresh: _yukle,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: hareketler.length,
                    separatorBuilder: (context, i) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final h = hareketler[i] as Map;
                      final (ikon, renk) = _ikon(h['tip'].toString());
                      final tutar = h['tutar'];
                      return GestureDetector(
                        onTap: h['adisyon_id'] != null
                            ? () => Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) => DetayScreen(tip: 'adisyon', id: _n(h['adisyon_id']).toInt(), baslikFallback: 'Adisyon')))
                            : null,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                          child: Row(children: [
                            Container(
                              width: 38, height: 38, alignment: Alignment.center,
                              decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                              child: Icon(ikon, color: renk, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(h['baslik'].toString(), style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                Text('${h['personel']} · ${h['zaman']}', style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                              ]),
                            ),
                            if (tutar != null && _n(tutar) > 0)
                              Text('₺${_f.format(_n(tutar).round())}', style: TextStyle(color: renk, fontSize: 14, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

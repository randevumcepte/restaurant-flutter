import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Üretim Riski — "bizi bizden koruyan" ekran.
/// Kritik malzemeler + kalan stokla her yemekten kaç porsiyon çıkar (yarı mamül dahil, nested).
class UretimRiskiScreen extends StatefulWidget {
  const UretimRiskiScreen({super.key});
  @override
  State<UretimRiskiScreen> createState() => _UretimRiskiScreenState();
}

class _UretimRiskiScreenState extends State<UretimRiskiScreen> {
  List kritik = [];
  List riskli = [];
  bool loading = true;
  final _f = NumberFormat.decimalPattern('tr');
  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _mik(num v) => v == v.roundToDouble() ? _f.format(v.round()) : v.toStringAsFixed(2);

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.uretimRiski(auth.token!, esik: 20);
      if (!mounted) return;
      setState(() {
        kritik = (res['kritik'] as List?) ?? [];
        riskli = (res['riskli'] as List?) ?? [];
        loading = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final huzur = kritik.isEmpty && riskli.isEmpty;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg, elevation: 0, iconTheme: IconThemeData(color: t.ink),
        title: Text('Üretim Riski', style: TextStyle(color: t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [IconButton(onPressed: _yukle, icon: Icon(Icons.refresh, color: t.sub))],
      ),
      body: loading
          ? Center(child: CircularProgressIndicator(color: t.mor1))
          : RefreshIndicator(
              onRefresh: _yukle, color: t.mor1, backgroundColor: t.card,
              child: ListView(padding: const EdgeInsets.all(14), children: [
                // Özet bant
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: huzur ? [t.yesil, t.mavi] : [const Color(0xFFF43F5E), const Color(0xFFF59E0B)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(children: [
                    Icon(huzur ? Icons.verified : Icons.warning_amber_rounded, color: Colors.white, size: 30),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      huzur
                          ? 'Her şey yolunda — kritik malzeme yok, tüm yemekler rahat çıkıyor.'
                          : '${kritik.length} kritik malzeme · ${riskli.length} yemek riskte. Hemen stok girin.',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
                    )),
                  ]),
                ),
                const SizedBox(height: 18),

                if (kritik.isNotEmpty) ...[
                  _baslik(t, '📦 Kritik Malzemeler', kritik.length),
                  for (final k in kritik) _kritikKart(t, k as Map),
                  const SizedBox(height: 18),
                ],

                if (riskli.isNotEmpty) ...[
                  _baslik(t, '🍽️ Riskli Yemekler', riskli.length),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text('Kalan stokla en fazla kaç porsiyon çıkar (yarı mamül içindeki hammadde dahil).', style: TextStyle(color: t.sub, fontSize: 12)),
                  ),
                  for (final u in riskli) _urunKart(t, u as Map),
                ],

                if (huzur)
                  Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: Text('Risk yok 🎉', style: TextStyle(color: t.sub, fontSize: 14)))),
                const SizedBox(height: 40),
              ]),
            ),
    );
  }

  Widget _baslik(TemaProvider t, String s, int n) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Text(s, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10)), child: Text('$n', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.bold))),
        ]),
      );

  Widget _kritikKart(TemaProvider t, Map k) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.5))),
      child: Row(children: [
        const Icon(Icons.inventory_2_outlined, color: Color(0xFFF43F5E), size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(k['ad'].toString(), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600))),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${_mik(_n(k['mevcut']))} ${k['birim']}', style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 14, fontWeight: FontWeight.bold)),
          Text('kritik: ${_mik(_n(k['kritik']))}', style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _urunKart(TemaProvider t, Map u) {
    final yap = _n(u['yapilabilir']).toInt();
    final cikmaz = yap <= 0;
    final renk = cikmaz ? const Color(0xFFF43F5E) : (yap <= 5 ? const Color(0xFFF59E0B) : t.yesil);
    return Container(
      margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: t.line)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u['urun'].toString(), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('darboğaz: ${u['darbogaz']}', style: TextStyle(color: t.sub, fontSize: 12)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
          child: Text(cikmaz ? 'ÇIKMIYOR' : '$yap porsiyon', style: TextStyle(color: renk, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}

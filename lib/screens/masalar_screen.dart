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
  String? _secilenBolge; // ust sekmede secili bolge
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

  void _uyar(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  // Bos masaya tiklaninca: kisi sor -> masa ac -> adisyon detayina git
  Future<void> _masaAc(Map m) async {
    final misafir = await _misafirSor(m['ad'].toString(), _n(m['kapasite']).toInt());
    if (misafir == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.masaAc(auth.token!, _n(m['id']).toInt(), misafir);
      if (!mounted) return;
      if (res['ok'] == 1 && res['adisyon_id'] != null) {
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DetayScreen(tip: 'adisyon', id: _n(res['adisyon_id']).toInt(), baslikFallback: m['ad'].toString())));
        _yukle();
      } else {
        _uyar(res['hata']?.toString() ?? 'Masa açılamadı');
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      _uyar('Bağlantı hatası');
    }
  }

  Future<int?> _misafirSor(String masaAd, int kapasite) {
    int sayi = kapasite >= 1 && kapasite <= 20 ? kapasite : 2;
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('$masaAd — Masa Aç', style: const TextStyle(fontSize: 17)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Kaç kişi?', style: TextStyle(color: Color(0xFF64748B))),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(iconSize: 34, color: const Color(0xFF4F46E5), onPressed: () => setD(() { if (sayi > 1) sayi--; }), icon: const Icon(Icons.remove_circle_outline)),
              SizedBox(width: 56, child: Text('$sayi', textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))),
              IconButton(iconSize: 34, color: const Color(0xFF4F46E5), onPressed: () => setD(() { if (sayi < 20) sayi++; }), icon: const Icon(Icons.add_circle_outline)),
            ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx, sayi), child: const Text('Masayı Aç')),
          ],
        ),
      ),
    );
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
    final bolgeler = gruplu.keys.toList();
    final aktif = (_secilenBolge != null && bolgeler.contains(_secilenBolge)) ? _secilenBolge! : (bolgeler.isNotEmpty ? bolgeler.first : '');
    final aktifMasalar = gruplu[aktif] ?? [];
    final dolu = masalar.where((m) => m['adisyon_id'] != null).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Text('Masalar  ($dolu / ${masalar.length} dolu)',
            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              // Bolge sekmeleri (buton gibi) — tiklayinca aninda o bolge (client-side, kasmaz)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: bolgeler.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final b = bolgeler[i];
                      final secili = b == aktif;
                      final bDolu = (gruplu[b] ?? []).where((m) => m['adisyon_id'] != null).length;
                      return GestureDetector(
                        onTap: () => setState(() => _secilenBolge = b),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: secili ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: secili ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(children: [
                            Text(b, style: TextStyle(color: secili ? Colors.white : const Color(0xFF334155), fontWeight: FontWeight.bold, fontSize: 13)),
                            if (bDolu > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(color: secili ? Colors.white24 : const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(10)),
                                child: Text('$bDolu', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              ),
              // Secili bolgenin masalari
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _yukle,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.0),
                    itemCount: aktifMasalar.length,
                    itemBuilder: (context, i) => _masaHucre(aktifMasalar[i] as Map),
                  ),
                ),
              ),
            ]),
    );
  }

  Widget _masaHucre(Map m) {
    final acik = m['adisyon_id'] != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        if (acik) {
          await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DetayScreen(tip: 'adisyon', id: _n(m['adisyon_id']).toInt(), baslikFallback: m['ad'].toString())));
          _yukle();
        } else {
          await _masaAc(m);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: _renk(m['durum'].toString()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kenar(m['durum'].toString()), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(m['ad'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            Text('${m['kapasite']} kişi', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: acik
                  ? Text(_n(m['tutar']) > 0 ? '${_f.format(_n(m['tutar']).round())} ₺' : 'açık',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)))
                  : const Text('boş', style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
            ),
          ],
        ),
      ),
    );
  }
}

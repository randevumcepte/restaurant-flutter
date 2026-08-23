import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? data;
  bool loading = true;
  String? hata;
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
    setState(() {
      loading = true;
      hata = null;
    });
    try {
      final res = await Api.patronOzet(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          data = res;
          loading = false;
        });
      } else {
        setState(() {
          hata = 'Veri alınamadı';
          loading = false;
        });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (e) {
      if (mounted) {
        setState(() {
          hata = 'Bağlantı hatası';
          loading = false;
        });
      }
    }
  }

  double? _yuzde(num simdi, num onceki) => onceki <= 0 ? null : (simdi - onceki) / onceki * 100;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(auth.sube ?? 'RestoOS',
                style: const TextStyle(color: Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.bold)),
            Text('Patron Özeti · ${auth.ad ?? ''}',
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => context.read<AuthProvider>().cikis(),
            icon: const Icon(Icons.logout, color: Color(0xFF64748B)),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : hata != null
              ? _hataGorunum()
              : RefreshIndicator(onRefresh: _yukle, child: _icerik()),
    );
  }

  Widget _hataGorunum() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(hata!, style: const TextStyle(color: Color(0xFFDC2626))),
            const SizedBox(height: 12),
            FilledButton(onPressed: _yukle, child: const Text('Tekrar Dene')),
          ],
        ),
      );

  Widget _icerik() {
    final d = data!;
    final bugun = _n(d['bugun']);
    final dun = _n(d['dun']);
    final gecenHafta = _n(d['gecenHaftaGun']);
    final buHafta = _n(d['buHafta']);
    final oncekiHafta = _n(d['oncekiHafta']);
    final buAy = _n(d['buAy']);
    final oncekiAy = _n(d['oncekiAy']);
    final uyarilar = (d['uyarilar'] as List?) ?? [];
    final top = (d['top'] as List?) ?? [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Uyarilar
        for (final u in uyarilar)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFFED7AA))),
            child: Row(children: [
              const Text('⚠️ '),
              Expanded(child: Text(u.toString(), style: const TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.w500))),
            ]),
          ),

        // Bugun hero
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Bugünkü Ciro', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 4),
              Text(_p(bugun), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _heroPill('Düne göre', _yuzde(bugun, dun), 'dün ${_p(dun)}'),
                _heroPill('Geçen hafta bugün', _yuzde(bugun, gecenHafta), _p(gecenHafta)),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Hafta / Ay
        Row(children: [
          Expanded(child: _kart('Bu Hafta', _p(buHafta), _yuzde(buHafta, oncekiHafta), 'geçen hafta ${_p(oncekiHafta)}')),
          const SizedBox(width: 12),
          Expanded(child: _kart('Bu Ay', _p(buAy), _yuzde(buAy, oncekiAy), 'geçen ay ${_p(oncekiAy)}')),
        ]),
        const SizedBox(height: 14),

        // Canli mini
        Row(children: [
          Expanded(child: _mini('${d['acikMasa'] ?? 0} / ${d['masaSayisi'] ?? 0}', 'Açık Masa', const Color(0xFFD97706))),
          const SizedBox(width: 12),
          Expanded(child: _mini(_p(_n(d['acikTutar'])), 'Bekleyen', const Color(0xFF4F46E5))),
          const SizedBox(width: 12),
          Expanded(child: _mini('${d['bugunAdisyon'] ?? 0}', 'Adisyon', const Color(0xFF334155))),
        ]),
        const SizedBox(height: 14),

        // Top urunler
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('🔥 Bugün En Çok Satan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              if (top.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Bugün henüz satış yok.', style: TextStyle(color: Color(0xFF94A3B8))))
              else
                for (int i = 0; i < top.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('${i + 1}. ${(top[i] as Map)['urun_adi']}', style: const TextStyle(color: Color(0xFF334155))),
                      Text('${_n((top[i] as Map)['adet']).round()} adet', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                    ]),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Center(child: Text('Tek bakışta, anlık ve doğru.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
      ],
    );
  }

  Widget _heroPill(String baslik, double? y, String alt) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(baslik, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(y == null ? '—' : '${y >= 0 ? "▲" : "▼"} %${y.abs().toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 6),
          Text(alt, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ]),
      ]),
    );
  }

  Widget _kart(String baslik, String deger, double? y, String alt) {
    final up = (y ?? 0) >= 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(baslik.toUpperCase(), style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(deger, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(y == null ? '—' : '${up ? "▲" : "▼"} %${y.abs().toStringAsFixed(1)}',
            style: TextStyle(color: up ? const Color(0xFF059669) : const Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13)),
        Text(alt, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ]),
    );
  }

  Widget _mini(String deger, String baslik, Color renk) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE2E8F0))),
      child: Column(children: [
        Text(deger, style: TextStyle(color: renk, fontSize: 17, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(baslik, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
      ]),
    );
  }
}

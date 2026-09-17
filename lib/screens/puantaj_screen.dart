import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import 'menu_hamburger.dart';

/// PUANTAJ — kim kaçta geldi/gitti, çalışma süresi, vardiya adımı. Patron tüm ekibi, personel kendini görür.
class PuantajScreen extends StatefulWidget {
  const PuantajScreen({super.key});
  @override
  State<PuantajScreen> createState() => _PuantajScreenState();
}

class _PuantajScreenState extends State<PuantajScreen> {
  bool loading = true;
  bool patron = false;
  List<Map<String, dynamic>> kayitlar = [];
  DateTime gun = DateTime.now();

  @override
  void initState() { super.initState(); _yukle(); }

  String _gunStr() => '${gun.year}-${gun.month.toString().padLeft(2, '0')}-${gun.day.toString().padLeft(2, '0')}';

  Future<void> _yukle() async {
    setState(() => loading = true);
    final auth = context.read<AuthProvider>();
    try {
      final r = await Api.mesaiListe(auth.token!, gun: _gunStr());
      if (!mounted) return;
      if (r['ok'] == 1) {
        patron = r['patron'] == 1;
        kayitlar = ((r['kayitlar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  String _sure(int dk) {
    final s = dk ~/ 60, d = dk % 60;
    return s > 0 ? '${s}s ${d}dk' : '${d}dk';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, iconTheme: IconThemeData(color: t.ink),
        title: Text('Puantaj (Mesai)', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
        actions: const [MenuHamburger()]),
      body: Column(children: [
        // gün seçici
        Container(
          color: t.card,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            IconButton(onPressed: () { setState(() => gun = gun.subtract(const Duration(days: 1))); _yukle(); },
                icon: Icon(Icons.chevron_left, color: t.ink)),
            Expanded(child: Center(child: Text(_gunStr(), style: TextStyle(color: t.ink, fontWeight: FontWeight.w700)))),
            IconButton(onPressed: () {
              final y = gun.add(const Duration(days: 1));
              if (y.isAfter(DateTime.now())) return;
              setState(() => gun = y); _yukle();
            }, icon: Icon(Icons.chevron_right, color: t.ink)),
          ]),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _yukle, color: t.mor1,
                  child: kayitlar.isEmpty
                      ? ListView(children: [Padding(padding: const EdgeInsets.all(40),
                          child: Center(child: Text('Bu gün mesai kaydı yok.', style: TextStyle(color: t.sub))))])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: kayitlar.length,
                          itemBuilder: (_, i) => _kart(t, kayitlar[i]),
                        ),
                ),
        ),
      ]),
    );
  }

  Widget _kart(TemaProvider t, Map<String, dynamic> m) {
    final acik = m['durum'] == 'acik';
    final tip = m['cikis_tip']?.toString();
    final eksik = acik || tip == 'geofence' || tip == 'kapanis';
    final dk = (m['dakika'] as num?)?.toInt() ?? 0;
    final adim = (m['adim'] as num?)?.toInt() ?? 0;
    // hedef: çalışılan saat × ~1750 adım
    final hedef = ((dk / 60.0) * 1750).round();
    final yuzde = hedef > 0 ? (adim / hedef * 100).round() : 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), boxShadow: t.golge),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          CircleAvatar(radius: 15, backgroundColor: t.mor1.withValues(alpha: 0.15),
              child: Text((m['ad']?.toString() ?? '?').characters.first, style: TextStyle(color: t.mor1, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Text(m['ad']?.toString() ?? '-', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w800))),
          if (acik) _rozet('Mesaide', const Color(0xFF16A34A))
          else if (eksik) _rozet('Eksik çıkış', const Color(0xFFF59E0B)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _kutu(t, Icons.login, 'Giriş', m['giris']?.toString() ?? '-'),
          _kutu(t, Icons.logout, 'Çıkış', m['cikis']?.toString() ?? (acik ? '—' : '?')),
          _kutu(t, Icons.timer_outlined, 'Süre', _sure(dk)),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Icon(Icons.directions_walk, size: 16, color: t.mor1),
          const SizedBox(width: 6),
          Text('$adim adım', style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          if (hedef > 0) Expanded(child: Text('hedef ~$hedef (%$yuzde)',
              style: TextStyle(color: yuzde >= 90 ? const Color(0xFF16A34A) : yuzde >= 50 ? t.sub2 : const Color(0xFFF59E0B), fontSize: 12))),
        ]),
      ]),
    );
  }

  Widget _rozet(String s, Color c) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(9), border: Border.all(color: c.withValues(alpha: 0.5))),
      child: Text(s, style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w800)));

  Widget _kutu(TemaProvider t, IconData ik, String etiket, String deger) => Expanded(
      child: Column(children: [
        Icon(ik, size: 16, color: t.sub),
        const SizedBox(height: 3),
        Text(deger, style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w900)),
        Text(etiket, style: TextStyle(color: t.sub, fontSize: 10.5)),
      ]));
}

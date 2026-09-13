import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// SEF GARSON AI — Masalar ekraninin ustune GOMULU uyari seridi (ayri sayfa DEGIL).
/// Acik masalari 20 sn'de bir tarar; satis firsati/uyari varsa yatay kart seridi gosterir,
/// yoksa hic yer kaplamaz. Her kartta "Ne satayim?" (AI oneri, context-ici sheet) + "Gordum".
class SefGarsonSerit extends StatefulWidget {
  const SefGarsonSerit({super.key});
  @override
  State<SefGarsonSerit> createState() => _SefGarsonSeritState();
}

class _SefGarsonSeritState extends State<SefGarsonSerit> {
  static const _mor = Color(0xFF7C3AED);
  static const _ink = Color(0xFF0F172A);
  static const _sub = Color(0xFF64748B);
  static const _kirmizi = Color(0xFFF43F5E);
  static const _amber = Color(0xFFF59E0B);
  static const _mavi = Color(0xFF4F46E5);
  static const _yesil = Color(0xFF16A34A);

  List<Map<String, dynamic>> uyarilar = [];
  final Set<String> _biliniyor = {};
  bool _ilk = true, _mesgul = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cek();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => _cek());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _anahtar(Map<String, dynamic> u) => '${u['adisyon_id']}.${u['tip']}';
  Color _renk(int o) => o >= 3 ? _kirmizi : (o == 2 ? _amber : _mavi);

  Future<void> _cek() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;
    try {
      final res = await Api.sefGarsonUyarilar(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        final liste = ((res['uyarilar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        final yeniOnemli = liste.where((u) => !_biliniyor.contains(_anahtar(u)) && (u['oncelik'] as num? ?? 0) >= 3).toList();
        if (!_ilk && yeniOnemli.isNotEmpty) HapticFeedback.mediumImpact();
        _biliniyor
          ..clear()
          ..addAll(liste.map(_anahtar));
        _ilk = false;
        setState(() => uyarilar = liste);
      }
    } catch (_) {/* sessiz: Masalar ekranini bozma */}
  }

  Future<void> _kapat(Map<String, dynamic> u) async {
    if (_mesgul) return;
    _mesgul = true;
    final k = _anahtar(u);
    setState(() => uyarilar.removeWhere((x) => _anahtar(x) == k));
    final auth = context.read<AuthProvider>();
    try { await Api.sefGarsonUyariKapat(auth.token!, u['adisyon_id'] as int, u['tip']?.toString() ?? ''); } catch (_) {}
    _biliniyor.remove(k);
    _mesgul = false;
  }

  Future<void> _oneriGoster(Map<String, dynamic> u) async {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => FutureBuilder<Map<String, dynamic>>(
        future: Api.sefGarsonOneri(auth.token!, u['adisyon_id'] as int, derin: true),
        builder: (ctx, snap) {
          final yuk = snap.connectionState != ConnectionState.done;
          final data = snap.data;
          final mesaj = (data?['ok'] == 1) ? (data?['mesaj']?.toString() ?? '') : 'Öneri alınamadı.';
          final urunler = ((data?['urunler'] as List?) ?? []).map((e) => e.toString()).toList();
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor, _mavi]), borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.emoji_objects, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text('${u['masa_adi']} — ne satayım?', style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 16),
              if (yuk)
                Row(children: const [
                  SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: _mor)),
                  SizedBox(width: 12),
                  Text('Şef düşünüyor…', style: TextStyle(color: _sub, fontSize: 14)),
                ])
              else ...[
                Text(mesaj, style: const TextStyle(color: _ink, fontSize: 15.5, height: 1.35, fontWeight: FontWeight.w600)),
                if (urunler.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: urunler.map((ad) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: _mor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: _mor.withValues(alpha: 0.35))),
                    child: Text(ad, style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  )).toList()),
                ],
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: FilledButton.styleFrom(backgroundColor: _mor, padding: const EdgeInsets.symmetric(vertical: 13)),
                  child: const Text('Anladım, satmaya gidiyorum', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (uyarilar.isEmpty) return const SizedBox.shrink();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 10, bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            const Text('🎯 ', style: TextStyle(fontSize: 15)),
            const Text('Şef Garson', style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w900)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(color: _mor, borderRadius: BorderRadius.circular(10)),
              child: Text('${uyarilar.length} fırsat', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        SizedBox(
          height: 132,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: uyarilar.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _kart(uyarilar[i]),
          ),
        ),
      ]),
    );
  }

  Widget _kart(Map<String, dynamic> u) {
    final oncelik = (u['oncelik'] as num? ?? 1).toInt();
    final vurgu = _renk(oncelik);
    final ikon = u['ikon']?.toString() ?? '💡';
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: oncelik >= 3 ? vurgu : const Color(0xFFE2E8F0), width: oncelik >= 3 ? 1.6 : 1),
        boxShadow: [BoxShadow(color: vurgu.withValues(alpha: 0.10), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: vurgu.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(ikon, style: const TextStyle(fontSize: 17))),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(u['baslik']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 7),
        Expanded(child: Text(u['mesaj']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _sub, fontSize: 11.5, height: 1.25))),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: SizedBox(
            height: 30,
            child: OutlinedButton(
              onPressed: () => _oneriGoster(u),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _mor), padding: EdgeInsets.zero),
              child: const Text('Ne satayım?', style: TextStyle(color: _mor, fontSize: 11.5, fontWeight: FontWeight.bold)),
            ),
          )),
          const SizedBox(width: 7),
          SizedBox(
            height: 30, width: 40,
            child: FilledButton(
              onPressed: () => _kapat(u),
              style: FilledButton.styleFrom(backgroundColor: _yesil, padding: EdgeInsets.zero),
              child: const Icon(Icons.check, size: 17, color: Colors.white),
            ),
          ),
        ]),
      ]),
    );
  }
}

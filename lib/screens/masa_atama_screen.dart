import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'menu_hamburger.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// MASA & BOLGE ATAMA (patron) — her personele sorumlu BOLGE(ler) + bolge disi EKSTRA masa(lar).
/// Ornek: garson Teras'in tamami + Bahce'den 4 masa. Sef Garson uyarilari bu kumeye gore filtrelenir.
class MasaAtamaScreen extends StatefulWidget {
  const MasaAtamaScreen({super.key});
  @override
  State<MasaAtamaScreen> createState() => _MasaAtamaScreenState();
}

class _MasaAtamaScreenState extends State<MasaAtamaScreen> {
  TemaProvider get _t => context.watch<TemaProvider>();

  bool loading = true, mesgul = false;
  List<Map<String, dynamic>> bolgeler = [];
  List<Map<String, dynamic>> masalar = [];
  List<Map<String, dynamic>> personeller = [];
  int? seciliPersonel;
  final Set<int> secBolge = {};
  final Set<int> secMasa = {};

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    setState(() => loading = true);
    try {
      final res = await Api.atamaVeri(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        bolgeler = ((res['bolgeler'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        masalar = ((res['masalar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        personeller = ((res['personeller'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        // garsonlar once
        personeller.sort((a, b) => (a['rol'] == 'garson' ? 0 : 1).compareTo(b['rol'] == 'garson' ? 0 : 1));
      }
      setState(() => loading = false);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _personelSec(Map<String, dynamic> p) {
    setState(() {
      seciliPersonel = p['id'] as int;
      secBolge
        ..clear()
        ..addAll(((p['bolge_idler'] as List?) ?? []).map((e) => e as int));
      secMasa
        ..clear()
        ..addAll(((p['masa_idler'] as List?) ?? []).map((e) => e as int));
    });
  }

  Future<void> _kaydet() async {
    if (seciliPersonel == null || mesgul) return;
    setState(() => mesgul = true);
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.atamaKaydet(auth.token!, seciliPersonel!, secBolge.toList(), secMasa.toList());
      if (!mounted) return;
      if (res['ok'] == 1) {
        // yerel veriyi guncelle
        final idx = personeller.indexWhere((x) => x['id'] == seciliPersonel);
        if (idx >= 0) {
          personeller[idx]['bolge_idler'] = secBolge.toList();
          personeller[idx]['masa_idler'] = secMasa.toList();
        }
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Atama kaydedildi ✓'), backgroundColor: Color(0xFF16A34A)));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['hata']?.toString() ?? 'Kaydedilemedi')));
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı hatası')));
    }
    if (mounted) setState(() => mesgul = false);
  }

  String _rolAd(String? r) => r == 'sahip' ? 'Sahip' : (r == 'mudur' ? 'Müdür' : (r == 'garson' ? 'Garson' : (r == 'kasa' ? 'Kasa' : (r == 'mutfak' ? 'Mutfak' : (r ?? '')))));

  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg,
        iconTheme: IconThemeData(color: t.ink),
        title: Text('Masa & Bölge Atama', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
        actions: const [MenuHamburger()],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 90), children: [
              Text('Personel seç', style: TextStyle(color: t.sub, fontSize: 12.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: personeller.map((p) {
                final secili = p['id'] == seciliPersonel;
                // Rozet = SORUMLU gercek masa sayisi (bolgelerdeki masalar ∪ ekstra masalar)
                final bIds = ((p['bolge_idler'] as List?) ?? []).map((e) => (e as num).toInt()).toSet();
                final resolved = <int>{...((p['masa_idler'] as List?) ?? []).map((e) => (e as num).toInt())};
                for (final m in masalar) {
                  if (bIds.contains((m['bolge_id'] as num).toInt())) resolved.add((m['id'] as num).toInt());
                }
                final atamaSay = resolved.length;
                return GestureDetector(
                  onTap: () => _personelSec(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                    decoration: BoxDecoration(
                      color: secili ? t.mor1 : t.card,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: secili ? t.mor1 : t.line),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(p['ad']?.toString() ?? '', style: TextStyle(color: secili ? Colors.white : t.ink, fontWeight: FontWeight.bold, fontSize: 13.5)),
                      const SizedBox(width: 6),
                      Text(_rolAd(p['rol']?.toString()), style: TextStyle(color: secili ? Colors.white70 : t.sub, fontSize: 11)),
                      if (atamaSay > 0) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Sorumlu masa sayısı',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: secili ? Colors.white24 : t.mor1, borderRadius: BorderRadius.circular(9)),
                            child: Text('$atamaSay masa', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ]),
                  ),
                );
              }).toList()),
              const SizedBox(height: 20),
              if (seciliPersonel == null)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(child: Text('Atama yapmak için bir personel seç.', style: TextStyle(color: t.sub, fontSize: 14))),
                )
              else ...[
                Text('Sorumlu bölgeler', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w900)),
                Text('Seçilen bölgenin tüm masaları bu personele aittir.', style: TextStyle(color: t.sub, fontSize: 12)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: bolgeler.map((b) {
                  final id = b['id'] as int;
                  final sec = secBolge.contains(id);
                  return FilterChip(
                    label: Text(b['ad']?.toString() ?? ''),
                    selected: sec,
                    onSelected: (v) => setState(() => v ? secBolge.add(id) : secBolge.remove(id)),
                    labelStyle: TextStyle(color: sec ? Colors.white : t.ink, fontWeight: FontWeight.w600, fontSize: 13),
                    backgroundColor: t.card,
                    selectedColor: t.mor1,
                    checkmarkColor: Colors.white,
                    side: BorderSide(color: sec ? t.mor1 : t.line),
                  );
                }).toList()),
                const SizedBox(height: 22),
                Text('Ekstra masalar (bölge dışı)', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w900)),
                Text('Bölge dışından tek tek masa ekle (örn. Teras + Bahçe’den 4 masa).', style: TextStyle(color: t.sub, fontSize: 12)),
                const SizedBox(height: 10),
                ..._bolgeBazliMasalar(t),
              ],
            ]),
      bottomSheet: seciliPersonel == null
          ? null
          : Container(
              color: t.bg,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SizedBox(
                width: double.infinity, height: 48,
                child: FilledButton.icon(
                  onPressed: mesgul ? null : _kaydet,
                  style: FilledButton.styleFrom(backgroundColor: t.mor1),
                  icon: mesgul
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                      : const Icon(Icons.save_outlined, color: Colors.white),
                  label: const Text('Atamayı Kaydet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
    );
  }

  List<Widget> _bolgeBazliMasalar(TemaProvider t) {
    final out = <Widget>[];
    for (final b in bolgeler) {
      final bid = b['id'] as int;
      final bMasa = masalar.where((m) => m['bolge_id'] == bid).toList();
      if (bMasa.isEmpty) continue;
      final bolgedeSec = secBolge.contains(bid);
      out.add(Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 6),
        child: Row(children: [
          Text(b['ad']?.toString() ?? '', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.bold)),
          if (bolgedeSec) ...[
            const SizedBox(width: 6),
            Text('(bölge seçili — tümü dahil)', style: TextStyle(color: t.yesil, fontSize: 11)),
          ],
        ]),
      ));
      out.add(Wrap(spacing: 8, runSpacing: 8, children: bMasa.map((m) {
        final id = m['id'] as int;
        final kapsandi = bolgedeSec;                 // bolgesi secili -> otomatik dahil
        final sec = kapsandi || secMasa.contains(id);
        return FilterChip(
          label: Text(m['ad']?.toString() ?? ''),
          selected: sec,
          onSelected: kapsandi ? null : (v) => setState(() => v ? secMasa.add(id) : secMasa.remove(id)),
          labelStyle: TextStyle(color: sec ? Colors.white : t.ink, fontWeight: FontWeight.w600, fontSize: 12.5),
          backgroundColor: t.card,
          selectedColor: kapsandi ? t.yesil : t.mor1,
          checkmarkColor: Colors.white,
          side: BorderSide(color: sec ? (kapsandi ? t.yesil : t.mor1) : t.line),
          disabledColor: t.yesil,
        );
      }).toList()));
    }
    return out;
  }
}

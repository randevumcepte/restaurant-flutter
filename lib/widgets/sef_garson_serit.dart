import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// SEF GARSON AI — Masalar ekranina GOMULU satis uyari seridi + AKILLI POPUP/ESKALASYON.
/// - Uyari kartlari varsayilan TURUNCU + dikkat ikonu (gorulmedi).
/// - "Ne satayim?" -> AI oneri -> "Anladim" deyince kart YESIL + onay ikonu (ustte kalir).
/// - Yeni/tekrar uyari gelince: telefon titrer + otomatik POPUP (musaitse hemen bakar).
/// - Garson bakmazsa sunucu belli araliklarla tekrar bildirir; esik asilinca YONETICIYE
///   "garson uyarilari dikkate almiyor" bildirimi gider (yonetici bu seritte kirmizi kart gorur).
class SefGarsonSerit extends StatefulWidget {
  const SefGarsonSerit({super.key});
  @override
  State<SefGarsonSerit> createState() => _SefGarsonSeritState();
}

class _SefGarsonSeritState extends State<SefGarsonSerit> {
  static const _mor = Color(0xFF7C3AED);
  static const _ink = Color(0xFF0F172A);
  static const _sub = Color(0xFF64748B);
  static const _turuncu = Color(0xFFF59E0B);
  static const _yesil = Color(0xFF16A34A);
  static const _kirmizi = Color(0xFFDC2626);

  List<Map<String, dynamic>> uyarilar = [];
  List<Map<String, dynamic>> yoneticiUyarilar = [];
  final Set<String> _gorulen = {};          // lokal: "Anladim" denen -> aninda yesil
  final Set<int> _bilinenYonetici = {};
  bool _popupAcik = false, _patron = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _cek();
    _timer = Timer.periodic(const Duration(seconds: 12), (_) => _cek());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _anahtar(Map<String, dynamic> u) => '${u['adisyon_id']}.${u['tip']}';
  bool _goruldu(Map<String, dynamic> u) => u['durum'] == 'goruldu' || _gorulen.contains(_anahtar(u));

  Future<void> _cek() async {
    final auth = context.read<AuthProvider>();
    if (auth.token == null) return;
    _patron = auth.rol == 'sahip' || auth.rol == 'mudur';
    try {
      final res = await Api.sefGarsonUyarilar(auth.token!);
      if (!mounted) return;
      List<Map<String, dynamic>> liste = [];
      if (res['ok'] == 1) {
        liste = ((res['uyarilar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      }
      // Yonetici (patron) icin eskale uyarilar
      List<Map<String, dynamic>> yon = [];
      if (_patron) {
        try {
          final yr = await Api.sefGarsonYoneticiUyarilar(auth.token!);
          if (yr['ok'] == 1) yon = ((yr['uyarilar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
        } catch (_) {}
      }
      if (!mounted) return;
      // Sunucu bir uyariyi tekrar aktive ettiyse (bos soz: "Anladim" deyip satmadi) lokal yesili kaldir
      for (final u in liste) { if (u['durum'] != 'goruldu') _gorulen.remove(_anahtar(u)); }
      setState(() { uyarilar = liste; yoneticiUyarilar = yon; });

      // POPUP: sunucu "bildir=true" dediyse (yeni ya da tekrar hatirlatma) -> titre + popup
      if (!_popupAcik) {
        final tetik = liste.where((u) => u['bildir'] == true && !_goruldu(u)).toList();
        if (tetik.isNotEmpty) {
          HapticFeedback.vibrate();
          _popupGoster(tetik.first);
        }
      }
      // Yeni eskalasyon geldiyse yoneticiyi titret
      if (_patron) {
        final yeniEsk = yon.where((y) => !_bilinenYonetici.contains(y['id'] as int)).toList();
        if (yeniEsk.isNotEmpty && _bilinenYonetici.isNotEmpty) HapticFeedback.vibrate();
        _bilinenYonetici
          ..clear()
          ..addAll(yon.map((y) => y['id'] as int));
      }
    } catch (_) {/* sessiz: Masalar ekranini bozma */}
  }

  // Yeni firsat popup'i: "Ne satayim?" -> oneri akisi; "Sonra" -> kapat (sunucu tekrar hatirlatir)
  Future<void> _popupGoster(Map<String, dynamic> u) async {
    _popupAcik = true;
    final ikon = u['ikon']?.toString() ?? '💡';
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
        title: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: _turuncu.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(ikon, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(u['baslik']?.toString() ?? 'Satış fırsatı', style: const TextStyle(color: _ink, fontSize: 16.5, fontWeight: FontWeight.w900))),
        ]),
        content: Text(u['mesaj']?.toString() ?? '', style: const TextStyle(color: _sub, fontSize: 14.5, height: 1.4)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Sonra', style: TextStyle(color: _sub, fontWeight: FontWeight.w600))),
          FilledButton.icon(
            onPressed: () { Navigator.pop(ctx); _oneriGoster(u); },
            style: FilledButton.styleFrom(backgroundColor: _mor, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11)),
            icon: const Icon(Icons.emoji_objects, color: Colors.white, size: 18),
            label: const Text('Ne satayım?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    _popupAcik = false;
  }

  // AI oneri sheet'i. Alttaki "Anladim" -> uyari GORULDU (yesil) + popup/hatirlatma durur.
  Future<void> _oneriGoster(Map<String, dynamic> u) async {
    final auth = context.read<AuthProvider>();
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (sheetCtx) => FutureBuilder<Map<String, dynamic>>(
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
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor, Color(0xFF4F46E5)]), borderRadius: BorderRadius.circular(12)),
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
                child: FilledButton.icon(
                  onPressed: () async {
                    try { await Api.sefGarsonUyariGordum(auth.token!, u['adisyon_id'] as int, u['tip']?.toString() ?? ''); } catch (_) {}
                    if (mounted) setState(() { _gorulen.add(_anahtar(u)); u['durum'] = 'goruldu'; });
                    if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                  },
                  style: FilledButton.styleFrom(backgroundColor: _yesil, padding: const EdgeInsets.symmetric(vertical: 13)),
                  icon: const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  label: const Text('Anladım, satmaya gidiyorum', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }

  Future<void> _yoneticiOku(Map<String, dynamic> y) async {
    final auth = context.read<AuthProvider>();
    setState(() => yoneticiUyarilar.removeWhere((x) => x['id'] == y['id']));
    try { await Api.sefGarsonYoneticiUyariOku(auth.token!, y['id'] as int); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final toplam = uyarilar.length + yoneticiUyarilar.length;
    if (toplam == 0) return const SizedBox.shrink();
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
              child: Text('${uyarilar.where((u) => !_goruldu(u)).length} fırsat', style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        SizedBox(
          height: 138,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              // Yonetici (kirmizi) kartlar once
              for (final y in yoneticiUyarilar) ...[_yoneticiKart(y), const SizedBox(width: 10)],
              // Uyari kartlari
              for (int i = 0; i < uyarilar.length; i++) ...[
                _kart(uyarilar[i]),
                if (i < uyarilar.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _kart(Map<String, dynamic> u) {
    final goruldu = _goruldu(u);
    final eskale = !goruldu && u['durum'] == 'eskale';   // yoneticiye bildirildi -> kirmizi (garsonda da)
    final vurgu = goruldu ? _yesil : (eskale ? _kirmizi : _turuncu);
    final bg = goruldu ? const Color(0xFFECFDF5) : (eskale ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED));
    final kenar = goruldu ? const Color(0xFFA7F3D0) : (eskale ? const Color(0xFFFECACA) : const Color(0xFFFDBA74));
    final ikon = u['ikon']?.toString() ?? '💡';
    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kenar, width: eskale ? 1.8 : 1.4),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: vurgu.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
            child: Icon(goruldu ? Icons.check_circle : (eskale ? Icons.report_gmailerrorred : Icons.warning_amber_rounded), color: vurgu, size: 20),
          ),
          const SizedBox(width: 9),
          Expanded(child: Row(children: [
            Text(ikon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 4),
            Expanded(child: Text(u['baslik']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _ink, fontSize: 13, fontWeight: FontWeight.w900))),
          ])),
        ]),
        const SizedBox(height: 7),
        Expanded(child: Text(
          goruldu
              ? 'Anlaşıldı — satışa gidiliyor 👍'
              : (eskale ? '⚠️ Yöneticiye bildirildi — hâlâ satış yok. Hemen satışı yap.' : (u['mesaj']?.toString() ?? '')),
          maxLines: 3, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: goruldu ? _yesil : (eskale ? _kirmizi : _sub), fontSize: 11.5, height: 1.25,
              fontWeight: (goruldu || eskale) ? FontWeight.w700 : FontWeight.normal),
        )),
        const SizedBox(height: 6),
        if (goruldu)
          const SizedBox(
            height: 32,
            child: Center(child: Text('✓ görüldü', style: TextStyle(color: _yesil, fontSize: 12, fontWeight: FontWeight.bold))),
          )
        else
          SizedBox(
            width: double.infinity, height: 32,
            child: FilledButton.icon(
              onPressed: () => _oneriGoster(u),
              style: FilledButton.styleFrom(backgroundColor: eskale ? _kirmizi : _mor, padding: EdgeInsets.zero),
              icon: const Icon(Icons.emoji_objects, size: 16, color: Colors.white),
              label: const Text('Ne satayım?', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
            ),
          ),
      ]),
    );
  }

  Widget _yoneticiKart(Map<String, dynamic> y) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: _kirmizi.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.report_gmailerrorred, color: _kirmizi, size: 21),
          ),
          const SizedBox(width: 9),
          const Expanded(child: Text('Dikkat edilmiyor', style: TextStyle(color: _kirmizi, fontSize: 13, fontWeight: FontWeight.w900))),
        ]),
        const SizedBox(height: 7),
        Expanded(child: Text(y['mesaj']?.toString() ?? 'Garson uyarıları dikkate almıyor.',
            maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 11.5, height: 1.25))),
        const SizedBox(height: 6),
        SizedBox(
          width: double.infinity, height: 32,
          child: OutlinedButton(
            onPressed: () => _yoneticiOku(y),
            style: OutlinedButton.styleFrom(side: const BorderSide(color: _kirmizi), padding: EdgeInsets.zero),
            child: const Text('Tamam', style: TextStyle(color: _kirmizi, fontSize: 12.5, fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

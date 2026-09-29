import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// YÖNETİCİ ONAY DİNLEYİCİ — sahip/müdür cihazında arka planda çalışır; kasiyerden gelen
/// onay isteklerini yoklar, gelince popup gösterir (Onayla/Reddet). Görünmez (SizedBox).
/// Uygulama kabuğuna (home) bir kez konur; her ekranda aktif olur.
class OnayDinleyici extends StatefulWidget {
  const OnayDinleyici({super.key});
  @override
  State<OnayDinleyici> createState() => _OnayDinleyiciState();
}

class _OnayDinleyiciState extends State<OnayDinleyici> {
  Timer? _timer;
  bool _popupAcik = false;
  final Set<int> _islenen = {};

  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);
  static const _mor = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => _cek());
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  Future<void> _cek() async {
    if (!mounted || _popupAcik) return;
    final auth = context.read<AuthProvider>();
    if (auth.token == null || !(auth.rol == 'sahip' || auth.rol == 'mudur')) return;
    try {
      final res = await Api.bekleyenOnaylar(auth.token!);
      if (!mounted || _popupAcik) return;
      final liste = ((res['onaylar'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
      final yeni = liste.where((o) => !_islenen.contains(o['id'])).toList();
      if (yeni.isNotEmpty) _popupGoster(yeni.first);
    } catch (_) {}
  }

  Future<void> _popupGoster(Map<String, dynamic> o) async {
    _popupAcik = true;
    final id = o['id'] as int;
    _islenen.add(id);
    HapticFeedback.vibrate();
    final tipAd = {'iskonto': 'İskonto', 'ikram': 'İkram', 'iptal': 'Adisyon İptali', 'odeme_geri_al': 'Ödeme Geri Al'}[o['tip']] ?? 'Onay';
    final auth0 = context.read<AuthProvider>();
    Timer? kapatma;
    final cevap = await showDialog<String>(
      useRootNavigator: true, context: context, barrierDismissible: false,
      builder: (ctx) {
        final t = ctx.read<TemaProvider>();
        // İstek başka cihazda/yönetici tarafından yanıtlandıysa bu popup'ı otomatik kapat.
        kapatma ??= Timer.periodic(const Duration(seconds: 2), (_) async {
          try {
            final d = await Api.onayDurum(auth0.token!, id);
            if (d['durum'] != null && d['durum'] != 'bekliyor' && ctx.mounted) { kapatma?.cancel(); Navigator.pop(ctx, 'otomatik'); }
          } catch (_) {}
        });
        return Dialog(
          backgroundColor: t.card, insetPadding: const EdgeInsets.all(24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: const BoxDecoration(gradient: LinearGradient(colors: [_mor, _mavi])),
                child: Column(children: [
                  Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle), child: const Icon(Icons.verified_user, color: Colors.white, size: 24)),
                  const SizedBox(height: 8),
                  const Text('Onay İsteği', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: _mor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                    child: Text(tipAd, style: const TextStyle(color: _mor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 10),
                  Text(o['baslik']?.toString() ?? 'Onay bekleniyor', textAlign: TextAlign.center, style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.w600, height: 1.35)),
                  const SizedBox(height: 8),
                  Text('İsteyen: ${o['isteyen'] ?? '-'} · ${o['saat'] ?? ''}', style: TextStyle(color: t.sub, fontSize: 12)),
                  const SizedBox(height: 18),
                  Row(children: [
                    Expanded(child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, 'red'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 13), side: const BorderSide(color: _kirmizi), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Reddet', style: TextStyle(color: _kirmizi, fontWeight: FontWeight.bold)),
                    )),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'onay'),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Onayla', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: FilledButton.styleFrom(backgroundColor: _yesil, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    )),
                  ]),
                ]),
              ),
            ]),
          ),
        );
      },
    );
    kapatma?.cancel();
    if ((cevap == 'onay' || cevap == 'red') && mounted) {
      try {
        final auth = context.read<AuthProvider>();
        final res = await Api.onayCevap(auth.token!, id, cevap == 'onay' ? 'onay' : 'red');
        if (mounted) {
          final durum = res['durum']?.toString();
          final msg = durum == 'onaylandi' ? (res['mesaj']?.toString() ?? '✓ Onaylandı') : (durum == 'reddedildi' ? 'Reddedildi' : (res['hata']?.toString() ?? 'İşlenemedi'));
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: durum == 'onaylandi' ? _yesil : _kirmizi));
        }
      } catch (_) {}
    }
    _popupAcik = false;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

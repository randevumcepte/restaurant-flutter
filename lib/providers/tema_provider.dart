import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Uygulama geneli KOYU/ACIK tema. Vurgu renkleri (mor/mavi/yesil...) iki modda ayni;
/// zemin/kart/yazi/cizgi renkleri moda gore degisir. Tercih SharedPreferences'ta saklanir.
class TemaProvider extends ChangeNotifier {
  bool koyu = true;

  TemaProvider() { _yukle(); }

  Future<void> _yukle() async {
    try {
      final sp = await SharedPreferences.getInstance();
      koyu = sp.getBool('app_koyu') ?? true;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> cevir() async {
    koyu = !koyu;
    notifyListeners();
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setBool('app_koyu', koyu);
    } catch (_) {}
  }

  // ---- moda gore degisen yuzey/yazi ----
  Color get bg   => koyu ? const Color(0xFF0B1020) : const Color(0xFFF3F5FA);
  Color get card => koyu ? const Color(0xFF161C2E) : Colors.white;
  Color get card2 => koyu ? const Color(0xFF1E2740) : const Color(0xFFEEF2F8);
  Color get ink  => koyu ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B); // ana yazi
  Color get sub  => koyu ? const Color(0xFF94A3B8) : const Color(0xFF64748B); // ikincil yazi
  Color get sub2 => koyu ? const Color(0xFFCBD5E1) : const Color(0xFF475569);
  Color get line => koyu ? const Color(0xFF2D3752) : const Color(0xFFE2E8F0); // cizgi/kenar

  // ---- vurgular (iki modda ayni) ----
  Color get mor1 => const Color(0xFF7C3AED);
  Color get mor2 => const Color(0xFF9D5DC8);
  Color get mavi => const Color(0xFF4F46E5);
  Color get yesil => const Color(0xFF10B981);
  Color get kirmizi => const Color(0xFFF43F5E);
  Color get amber => const Color(0xFFF59E0B);
  Color get gold => const Color(0xFFF6CE63);
}

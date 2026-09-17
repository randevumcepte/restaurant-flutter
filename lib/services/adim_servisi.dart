import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// GARSON ADIM SAYACI — telefonun donanim adim sensorunu dinler, GUNLUK adimi hesaplar
/// ve sunucuya (POST /api/adim-kaydet) throttle'li gonderir. Performans karnesinde gorunur.
///
/// Sensor "boot'tan beri kumulatif" verir; gunluk = kumulatif - o gunun tabani (prefs'te).
/// Reboot'ta kumulatif kucuklurse tabani yeniden alir (geri gitmez).
class AdimServisi {
  static final AdimServisi _i = AdimServisi._();
  factory AdimServisi() => _i;
  AdimServisi._();

  StreamSubscription<StepCount>? _sub;
  String? _token;
  bool _basladi = false;
  int _sonGonderilen = -1;
  DateTime? _sonGonderim;

  /// O ana kadar bilinen BUGÜNkü adım (mesai baseline/delta için).
  int get bugunkuAdim => _sonGonderilen < 0 ? 0 : _sonGonderilen;

  /// Giris sonrasi cagrilir. Idempotent (bir kez baslar).
  Future<void> baslat(String token) async {
    _token = token;
    if (_basladi) return;
    _basladi = true;
    try {
      final izin = await Permission.activityRecognition.request();
      if (!izin.isGranted) { _basladi = false; return; }
      _sub = Pedometer.stepCountStream.listen(_olay, onError: (_) {}, cancelOnError: false);
    } catch (_) {
      _basladi = false;
    }
  }

  Future<void> durdur() async {
    await _sub?.cancel();
    _sub = null;
    _basladi = false;
    _token = null;
    _sonGonderilen = -1;
    _sonGonderim = null;
  }

  Future<void> _olay(StepCount e) async {
    final token = _token;
    if (token == null) return;
    try {
      final sp = await SharedPreferences.getInstance();
      final bugun = _bugun();
      final kumulatif = e.steps;
      int taban = sp.getInt('adim_taban') ?? -1;
      final gun = sp.getString('adim_gun');
      if (gun != bugun || taban < 0 || kumulatif < taban) {
        taban = kumulatif;                 // yeni gun ya da reboot -> tabani sifirla
        await sp.setString('adim_gun', bugun);
        await sp.setInt('adim_taban', taban);
      }
      final bugunku = (kumulatif - taban).clamp(0, 1 << 30);

      // Throttle: 60 sn'de bir ya da >=25 adim degisince gonder
      final now = DateTime.now();
      final zamanTamam = _sonGonderim == null || now.difference(_sonGonderim!).inSeconds >= 60;
      final farkTamam = (bugunku - _sonGonderilen).abs() >= 25;
      if (bugunku != _sonGonderilen && (zamanTamam || farkTamam)) {
        _sonGonderilen = bugunku;
        _sonGonderim = now;
        try { await Api.adimKaydet(token, bugunku); } catch (_) {}
      }
    } catch (_) {}
  }

  String _bugun() {
    final d = DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

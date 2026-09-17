import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// BAĞLI CİHAZLAR — uygulama açıkken periyodik "buradayım" sinyali (heartbeat) gönderir.
/// Sunucu son_gorulme'ye göre online/offline (yeşil/kırmızı) gösterir. Kimlik prefs'te
/// saklanan sabit bir UUID; böylece aynı cihaz tek satır olur.
class CihazServisi {
  static final CihazServisi _i = CihazServisi._();
  factory CihazServisi() => _i;
  CihazServisi._();

  Timer? _t;
  String? _token;
  String? _rol;
  String? _kimlik;
  bool _basladi = false;

  /// Giriş sonrası çağrılır (idempotent). ~45 sn'de bir sinyal atar.
  Future<void> baslat(String token, {String? rol}) async {
    _token = token;
    _rol = rol;
    if (_basladi) return;
    _basladi = true;
    _kimlik = await _kimlikAl();
    await _gonder();
    _t = Timer.periodic(const Duration(seconds: 45), (_) => _gonder());
  }

  Future<void> durdur() async {
    _t?.cancel();
    _t = null;
    _basladi = false;
  }

  Future<String> _kimlikAl() async {
    final prefs = await SharedPreferences.getInstance();
    var k = prefs.getString('cihaz_kimlik');
    if (k == null || k.isEmpty) {
      final rnd = Random();
      k = List.generate(24, (_) => '0123456789abcdef'[rnd.nextInt(16)]).join();
      await prefs.setString('cihaz_kimlik', k);
    }
    return k;
  }

  Future<void> _gonder() async {
    if (_token == null || _kimlik == null) return;
    try {
      var platform = 'Bilinmiyor';
      var tip = 'bilgisayar';
      try {
        if (Platform.isAndroid) { platform = 'Android'; tip = 'telefon'; }
        else if (Platform.isIOS) { platform = 'iOS'; tip = 'telefon'; }
        else if (Platform.isWindows) { platform = 'Windows'; tip = 'bilgisayar'; }
        else if (Platform.isMacOS) { platform = 'macOS'; tip = 'bilgisayar'; }
        else if (Platform.isLinux) { platform = 'Linux'; tip = 'bilgisayar'; }
      } catch (_) {}
      final suffix = _kimlik!.length >= 4 ? _kimlik!.substring(_kimlik!.length - 4) : _kimlik!;
      final ad = '${_rolAd(_rol)} · ${tip == 'telefon' ? 'Telefon/Tablet' : 'Bilgisayar'} · $suffix';
      await Api.cihazPing(_token!, {'kimlik': _kimlik!, 'ad': ad, 'tip': tip, 'platform': platform, 'surum': ''});
    } catch (_) {/* sessiz — sinyal başarısız olsa da uygulamayı bozma */}
  }

  String _rolAd(String? r) => r == 'sahip'
      ? 'Sahip'
      : (r == 'mudur' ? 'Müdür' : (r == 'kasa' ? 'Kasa' : (r == 'garson' ? 'Garson' : (r == 'mutfak' ? 'Mutfak' : 'ResteOS'))));
}

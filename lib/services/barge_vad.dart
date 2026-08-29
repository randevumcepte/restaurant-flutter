import 'package:flutter/services.dart';

/// Native barge-in VAD köprüsü. Asistan konuşurken (TTS) native taraf
/// VOICE_COMMUNICATION + AcousticEchoCanceler ile dinler; kullanıcı konuşmaya
/// başlayınca `onVoice` tetiklenir (asistanın kendi sesi donanımda iptal edilir).
class BargeVad {
  static const MethodChannel _ch = MethodChannel('resto/barge');
  static void Function()? _onVoice;
  static bool _kuruldu = false;

  static void _kur() {
    if (_kuruldu) return;
    _kuruldu = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'voiceDetected') {
        final cb = _onVoice;
        _onVoice = null; // tek sefer
        cb?.call();
      }
    });
  }

  /// Dinlemeyi başlat. Kullanıcı konuşunca [onVoice] bir kez çağrılır.
  static Future<void> basla(void Function() onVoice, {int esik = 1800, int warmup = 500}) async {
    _kur();
    _onVoice = onVoice;
    try {
      await _ch.invokeMethod('start', {'esik': esik, 'warmup': warmup});
    } catch (_) {}
  }

  static Future<void> dur() async {
    _onVoice = null;
    try {
      await _ch.invokeMethod('stop');
    } catch (_) {}
  }
}

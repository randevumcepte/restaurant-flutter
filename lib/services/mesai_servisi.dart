import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'api.dart';
import 'adim_servisi.dart';

/// MESAI SERVİSİ — QR ile giriş/çıkış + geofence.
/// - kilit: true ise garson/personel işletme bilgilerini göremez, önce QR okutmalı.
/// - Girişte ping başlar (5 dk'da bir hafif konum); işletmeden ayrılırsa sunucu oto-çıkış yapar → kilit tekrar açılır.
class MesaiServisi {
  static final MesaiServisi _i = MesaiServisi._();
  factory MesaiServisi() => _i;
  MesaiServisi._();

  final ValueNotifier<bool> kilit = ValueNotifier<bool>(false);
  String? _token;
  bool _rolKilit = false;
  Timer? _ping;

  /// Girişten sonra çağrılır. rolKilit: garson/personel true, patron/müdür false.
  Future<void> baslat(String token, {required bool rolKilit}) async {
    _token = token;
    _rolKilit = rolKilit;
    if (!rolKilit) { kilit.value = false; _pingDurdur(); return; }
    kilit.value = true; // güvenli varsayılan: durum gelene kadar kilitli
    await durumKontrol();
  }

  void cikisYap() { _pingDurdur(); _token = null; kilit.value = false; }

  Future<void> durumKontrol() async {
    final t = _token;
    if (t == null) return;
    try {
      final r = await Api.mesaiDurum(t);
      final acik = r['acik'] == 1;
      final kilitRol = r['kilit'] == 1;
      _rolKilit = kilitRol;
      if (!kilitRol) { kilit.value = false; _pingDurdur(); return; }
      kilit.value = !acik;
      if (acik) { _pingBaslat(); } else { _pingDurdur(); }
    } catch (_) {/* ağ hatası: mevcut durumu koru */}
  }

  /// QR içeriği "window|code". Konum + adım ile /okut çağırır.
  Future<Map<String, dynamic>> okut(String qr) async {
    final t = _token;
    if (t == null) return {'ok': 0, 'hata': 'Oturum yok'};
    final parts = qr.split('|');
    if (parts.length < 2) return {'ok': 0, 'hata': 'Geçersiz QR'};
    final w = int.tryParse(parts[0].trim()) ?? 0;
    final kod = parts[1].trim();
    final pos = await _konum();
    try {
      final r = await Api.mesaiOkut(t, kod: kod, w: w, lat: pos?.latitude, lng: pos?.longitude, adim: AdimServisi().bugunkuAdim);
      if (r['ok'] == 1) {
        if (r['durum'] == 'giris') { kilit.value = false; _pingBaslat(); }
        else { kilit.value = true; _pingDurdur(); }
      }
      return r;
    } catch (_) {
      return {'ok': 0, 'hata': 'Bağlantı hatası'};
    }
  }

  Future<Position?> _konum() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)),
      );
    } catch (_) { return null; }
  }

  void _pingBaslat() { _ping ??= Timer.periodic(const Duration(minutes: 5), (_) => _pingAt()); }
  void _pingDurdur() { _ping?.cancel(); _ping = null; }

  Future<void> _pingAt() async {
    final t = _token;
    if (t == null) return;
    final pos = await _konum();
    try {
      final r = await Api.mesaiPing(t, lat: pos?.latitude, lng: pos?.longitude, adim: AdimServisi().bugunkuAdim);
      if (r['acik'] == 0 && _rolKilit) { kilit.value = true; _pingDurdur(); }
    } catch (_) {}
  }
}

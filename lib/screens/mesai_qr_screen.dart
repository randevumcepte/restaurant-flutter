import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// KASA MESAİ QR — kasada duran cihazda tam ekran gösterilir. Personel bunu okutup mesai başlatır.
/// QR her 20 sn'de bir CİHAZDA (client-side TOTP) yenilenir → sunucuya yük binmez.
/// İçerik: "window|code", code = HMAC-SHA256(secret, window)[0..10].
class MesaiQrScreen extends StatefulWidget {
  const MesaiQrScreen({super.key});
  @override
  State<MesaiQrScreen> createState() => _MesaiQrScreenState();
}

class _MesaiQrScreenState extends State<MesaiQrScreen> {
  String? _secret;
  int _offset = 0; // sunucu - cihaz saat farkı (sn)
  int _step = 20;
  String? _hata;
  Timer? _t;
  int _kalan = 20;
  String _icerik = '';

  @override
  void initState() {
    super.initState();
    _hazirla();
  }

  @override
  void dispose() { _t?.cancel(); super.dispose(); }

  Future<void> _hazirla() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) { setState(() => _hata = 'Oturum yok'); return; }
    try {
      final r = await Api.mesaiQrSecret(token);
      if (r['ok'] != 1) { setState(() => _hata = r['hata']?.toString() ?? 'Yetkisiz'); return; }
      _secret = r['secret']?.toString();
      _step = int.tryParse('${r['step'] ?? 20}') ?? 20;
      final serverNow = int.tryParse('${r['now'] ?? 0}') ?? 0;
      final localNow = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      _offset = serverNow - localNow;
      _tik();
      _t = Timer.periodic(const Duration(seconds: 1), (_) => _tik());
    } catch (_) {
      if (mounted) setState(() => _hata = 'Bağlantı hatası');
    }
    _kasaKonumAyarla(token); // kasa fiziksel olarak işletmede → geofence referansı
  }

  Future<void> _kasaKonumAyarla(String token) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 8)));
      await Api.mesaiKonumAyarla(token, pos.latitude, pos.longitude);
    } catch (_) {}
  }

  void _tik() {
    final s = _secret;
    if (s == null) return;
    final nowSec = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + _offset;
    final w = nowSec ~/ _step;
    final hmac = Hmac(sha256, utf8.encode(s));
    final kod = hmac.convert(utf8.encode('$w')).toString().substring(0, 10);
    if (mounted) setState(() { _icerik = '$w|$kod'; _kalan = _step - (nowSec % _step); });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, iconTheme: IconThemeData(color: t.ink),
          title: Text('Kasa — Mesai QR', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold))),
      body: Center(
        child: _hata != null
            ? Padding(padding: const EdgeInsets.all(24), child: Text(_hata!, textAlign: TextAlign.center,
                style: TextStyle(color: t.sub, fontSize: 15)))
            : _icerik.isEmpty
                ? const CircularProgressIndicator()
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('Personel bu kodu uygulamasından okutsun', style: TextStyle(color: t.sub, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text('Giriş / Çıkış', style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)]),
                      child: QrImageView(data: _icerik, size: 250, gapless: true),
                    ),
                    const SizedBox(height: 18),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.lock_clock, size: 16, color: t.mor1),
                      const SizedBox(width: 6),
                      Text('$_kalan sn sonra yenilenir', style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 6),
                    SizedBox(width: 250, child: LinearProgressIndicator(
                        value: _kalan / _step, backgroundColor: t.line, color: t.mor1, minHeight: 6)),
                    const SizedBox(height: 20),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(
                        'Güvenlik: kod 20 sn\'de bir değişir + konum kontrolü var. Fotoğrafı çekip dışarı yollamak işe yaramaz.',
                        textAlign: TextAlign.center, style: TextStyle(color: t.sub, fontSize: 11.5, height: 1.35))),
                  ]),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import 'menu_hamburger.dart';

/// İŞLETME KONUMU (mesai geofence) — patron burada işletmenin GPS noktasını ve yarıçapı belirler.
/// Personel QR okuturken bu noktaya olan mesafeye bakılır (uzaktan giriş engellenir).
class IsletmeKonumScreen extends StatefulWidget {
  const IsletmeKonumScreen({super.key});
  @override
  State<IsletmeKonumScreen> createState() => _IsletmeKonumScreenState();
}

class _IsletmeKonumScreenState extends State<IsletmeKonumScreen> {
  bool loading = true, mesgul = false;
  bool var_ = false;
  double? lat, lng;
  int yaricap = 150;
  String? mesaj;

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    final auth = context.read<AuthProvider>();
    try {
      final r = await Api.mesaiKonum(auth.token!);
      if (!mounted) return;
      if (r['ok'] == 1) {
        var_ = r['var'] == 1;
        lat = (r['lat'] as num?)?.toDouble();
        lng = (r['lng'] as num?)?.toDouble();
        yaricap = (r['yaricap'] as num?)?.toInt() ?? 150;
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {}
    if (mounted) setState(() => loading = false);
  }

  Future<void> _konumKullan() async {
    final token = context.read<AuthProvider>().token;
    if (token == null) return;
    setState(() { mesgul = true; mesaj = 'Konum alınıyor…'; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) { _hata('Konum servisi kapalı — telefonda GPS/konumu aç.'); return; }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) { _hata('Konum izni verilmedi.'); return; }
      final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)));
      final r = await Api.mesaiKonumAyarla(token, pos.latitude, pos.longitude, yaricap: yaricap);
      if (!mounted) return;
      if (r['ok'] == 1) {
        setState(() { var_ = true; lat = pos.latitude; lng = pos.longitude; mesgul = false; mesaj = 'İşletme konumu kaydedildi ✓'; });
      } else { _hata('Kaydedilemedi'); }
    } catch (_) { _hata('Konum alınamadı (kapalı alanda sinyal zayıf olabilir)'); }
  }

  Future<void> _yaricapKaydet() async {
    if (!var_ || lat == null) return;
    setState(() => mesgul = true);
    final auth = context.read<AuthProvider>();
    try { await Api.mesaiKonumAyarla(auth.token!, lat!, lng!, yaricap: yaricap); } catch (_) {}
    if (mounted) setState(() { mesgul = false; mesaj = 'Yarıçap güncellendi ✓'; });
  }

  void _hata(String m) { if (mounted) setState(() { mesgul = false; mesaj = m; }); }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(backgroundColor: t.bg, iconTheme: IconThemeData(color: t.ink),
        title: Text('İşletme Konumu', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold)),
        actions: const [MenuHamburger()]),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), boxShadow: t.golge),
                child: Row(children: [
                  Icon(var_ ? Icons.check_circle : Icons.location_off, color: var_ ? const Color(0xFF16A34A) : t.sub, size: 30),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(var_ ? 'Konum ayarlı' : 'Konum henüz ayarlanmadı',
                        style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(var_ ? 'Yarıçap: $yaricap m' : 'Ayarlanmadan geofence çalışmaz (sadece 20 sn QR)',
                        style: TextStyle(color: t.sub, fontSize: 12)),
                    if (var_ && lat != null) Text('${lat!.toStringAsFixed(5)}, ${lng!.toStringAsFixed(5)}',
                        style: TextStyle(color: t.sub, fontSize: 11)),
                  ])),
                ]),
              ),
              const SizedBox(height: 16),
              Text('Yarıçap (izin verilen mesafe)', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
              Text('Personel bu mesafe içindeyse QR okutabilir. İç mekân GPS'
                  ' sapmasına karşı 150 m önerilir.', style: TextStyle(color: t.sub, fontSize: 12)),
              Row(children: [
                Expanded(child: Slider(
                  value: yaricap.toDouble(), min: 100, max: 300, divisions: 8, label: '$yaricap m',
                  activeColor: t.mor1,
                  onChanged: (v) => setState(() => yaricap = v.round()),
                  onChangeEnd: (_) => _yaricapKaydet(),
                )),
                SizedBox(width: 56, child: Text('$yaricap m', style: TextStyle(color: t.ink, fontWeight: FontWeight.bold))),
              ]),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton.icon(
                  onPressed: mesgul ? null : _konumKullan,
                  style: ElevatedButton.styleFrom(backgroundColor: t.mor1, foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  icon: const Icon(Icons.my_location),
                  label: Text(var_ ? 'Konumu Güncelle (buradayım)' : 'Şu Anki Konumu Kullan',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
              if (mesaj != null) Padding(padding: const EdgeInsets.only(top: 12),
                  child: Text(mesaj!, textAlign: TextAlign.center, style: TextStyle(color: t.sub2, fontSize: 13))),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.info_outline, size: 18, color: t.sub),
                  const SizedBox(width: 10),
                  Expanded(child: Text('Bu ekranı İŞLETMEDEYKEN aç ve "Şu Anki Konumu Kullan"a bas. '
                      'Telefonun konumu işletme noktası olarak kaydedilir; adres/harita girmene gerek yok. '
                      '(Kasa Mesai QR ekranı da açılınca otomatik ayarlar.)',
                      style: TextStyle(color: t.sub, fontSize: 12, height: 1.35))),
                ]),
              ),
            ]),
    );
  }
}

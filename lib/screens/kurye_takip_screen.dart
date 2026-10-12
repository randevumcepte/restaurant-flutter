import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Paket siparişi için UYGULAMA İÇİ canlı kurye takibi.
/// OSM (flutter_map) ile harita gömülü gelir — dış tarayıcı/URL AÇMAZ.
/// Her 5 sn'de /api/paket/{id}/konum ile kurye konumu + mesafe/ETA tazelenir.
class KuryeTakipScreen extends StatefulWidget {
  final int adisyonId;
  final String? baslik; // müşteri adı vb.
  const KuryeTakipScreen({super.key, required this.adisyonId, this.baslik});

  @override
  State<KuryeTakipScreen> createState() => _KuryeTakipScreenState();
}

class _KuryeTakipScreenState extends State<KuryeTakipScreen> {
  final MapController _mc = MapController();
  Timer? _timer;
  Map<String, dynamic>? _veri;
  bool _loading = true;
  bool _ilkOturtmaYapildi = false;
  String? _hata;

  TemaProvider get _t => context.read<TemaProvider>();

  @override
  void initState() {
    super.initState();
    _yukle();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _yukle(sessiz: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  LatLng? _nokta(Map? m) {
    if (m == null) return null;
    final lat = m['lat'], lng = m['lng'];
    if (lat == null || lng == null) return null;
    return LatLng((lat as num).toDouble(), (lng as num).toDouble());
  }

  Future<void> _yukle({bool sessiz = false}) async {
    final auth = context.read<AuthProvider>();
    try {
      final res = await Api.paketKonum(auth.token!, widget.adisyonId);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() {
          _veri = res.cast<String, dynamic>();
          _loading = false;
          _hata = null;
        });
        _haritayiOturt();
      } else {
        setState(() {
          _loading = false;
          _hata = res['hata']?.toString() ?? 'Konum alınamadı';
        });
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (e) {
      if (!mounted) return;
      if (!sessiz) setState(() { _loading = false; _hata = 'Bağlantı hatası'; });
    }
  }

  // İlk veride tüm noktaları ekrana sığdır
  void _haritayiOturt() {
    if (_ilkOturtmaYapildi || _veri == null) return;
    final noktalar = <LatLng>[];
    final k = _nokta(_veri!['kurye'] as Map?);
    final h = _nokta(_veri!['hedef'] as Map?);
    final s = _nokta(_veri!['sube'] as Map?);
    if (k != null) noktalar.add(k);
    if (h != null) noktalar.add(h);
    if (s != null) noktalar.add(s);
    if (noktalar.isEmpty) return;
    _ilkOturtmaYapildi = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (noktalar.length == 1) {
          _mc.move(noktalar.first, 15);
        } else {
          _mc.fitCamera(CameraFit.bounds(
            bounds: LatLngBounds.fromPoints(noktalar),
            padding: const EdgeInsets.all(70),
          ));
        }
      } catch (_) {}
    });
  }

  void _kuryeyeOdaklan() {
    final k = _nokta(_veri?['kurye'] as Map?);
    if (k != null) _mc.move(k, 16);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<TemaProvider>();
    final kurye = _veri?['kurye'] as Map?;
    final k = _nokta(kurye);
    final h = _nokta(_veri?['hedef'] as Map?);
    final s = _nokta(_veri?['sube'] as Map?);
    final merkez = k ?? h ?? s ?? const LatLng(41.0082, 28.9784); // İstanbul fallback

    return Scaffold(
      backgroundColor: _t.bg,
      appBar: AppBar(
        backgroundColor: _t.card,
        elevation: 0.5,
        iconTheme: IconThemeData(color: _t.ink),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Canlı Kurye Takibi',
                style: TextStyle(color: _t.ink, fontSize: 17, fontWeight: FontWeight.bold)),
            if (widget.baslik != null && widget.baslik!.isNotEmpty)
              Text(widget.baslik!, style: TextStyle(color: _t.sub, fontSize: 12)),
          ],
        ),
        actions: [
          if (k != null)
            IconButton(
              tooltip: 'Kuryeye odaklan',
              icon: Icon(Icons.my_location, color: _t.mor1),
              onPressed: _kuryeyeOdaklan,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mc,
                  options: MapOptions(
                    initialCenter: merkez,
                    initialZoom: 14,
                    minZoom: 4,
                    maxZoom: 18,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.restoos.restoos_patron',
                      maxZoom: 19,
                    ),
                    if (k != null && h != null)
                      PolylineLayer(polylines: [
                        Polyline(points: [k, h], color: _t.mor1.withValues(alpha: 0.75), strokeWidth: 4),
                      ]),
                    MarkerLayer(markers: [
                      if (s != null)
                        Marker(
                          point: s, width: 44, height: 44,
                          child: _pin(Icons.storefront, const Color(0xFF64748B)),
                        ),
                      if (h != null)
                        Marker(
                          point: h, width: 44, height: 44,
                          child: _pin(Icons.location_on, _t.kirmizi),
                        ),
                      if (k != null)
                        Marker(
                          point: k, width: 52, height: 52,
                          child: _kuryePin(),
                        ),
                    ]),
                  ],
                ),
                // Alt bilgi paneli
                Positioned(left: 12, right: 12, bottom: 12, child: _altPanel(kurye)),
                // OSM atıf (zorunlu)
                Positioned(
                  right: 4, top: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    color: Colors.white70,
                    child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 9, color: Colors.black54)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _pin(IconData ic, Color renk) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
          border: Border.all(color: renk, width: 2.5),
        ),
        child: Icon(ic, color: renk, size: 22),
      );

  Widget _kuryePin() => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [_t.mor1, _t.mavi]),
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
          border: Border.all(color: Colors.white, width: 3),
        ),
        child: const Icon(Icons.two_wheeler, color: Colors.white, size: 26),
      );

  Widget _altPanel(Map? kurye) {
    final mesafe = _veri?['mesafe_km'];
    final eta = _veri?['tahmini_dk'];
    final konumDk = kurye?['konum_dk'];
    final konumYok = kurye == null || kurye['lat'] == null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _t.card,
        borderRadius: BorderRadius.circular(18),
        boxShadow: _t.golge,
        border: Border.all(color: _t.line),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_t.mor1, _t.mavi]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.two_wheeler, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(kurye?['ad']?.toString() ?? 'Kurye',
                    style: TextStyle(color: _t.ink, fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  _canliNokta(),
                  const SizedBox(width: 5),
                  Text(
                    konumYok
                        ? 'Konum henüz alınamadı'
                        : (konumDk == null ? 'canlı' : (konumDk == 0 ? 'şimdi güncellendi' : '$konumDk dk önce')),
                    style: TextStyle(color: konumYok ? _t.kirmizi : _t.sub, fontSize: 12),
                  ),
                ]),
              ]),
            ),
          ]),
          if (!konumYok && (mesafe != null || eta != null)) ...[
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _metrik(Icons.route, 'Kalan Yol', mesafe != null ? '${(mesafe as num).toStringAsFixed(1)} km' : '—', _t.mavi)),
              const SizedBox(width: 10),
              Expanded(child: _metrik(Icons.timer_outlined, 'Tahmini Varış', eta != null ? '~${(eta as num).toInt()} dk' : '—', _t.yesil)),
            ]),
          ],
          if (_hata != null) ...[
            const SizedBox(height: 8),
            Text(_hata!, style: TextStyle(color: _t.kirmizi, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _metrik(IconData ic, String etiket, String deger, Color renk) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: renk.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(ic, color: renk, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(etiket, style: TextStyle(color: _t.sub, fontSize: 10.5, fontWeight: FontWeight.w600)),
              Text(deger, style: TextStyle(color: renk, fontSize: 16, fontWeight: FontWeight.bold)),
            ]),
          ),
        ]),
      );

  Widget _canliNokta() => Container(
        width: 8, height: 8,
        decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../ui/kit.dart';

/// /isletme-konum — İşletme Konumu (mesai geofence). Web ile aynı uç: POST /isletme-konum/kaydet (lat, lng, yaricap, adres).
/// İşlemler: "Şu anki konumu kullan" (GPS), haritaya dokunarak nokta seç, enlem/boylam elle gir, yarıçap 100–300 m, adres.
class IkIsletmeKonumScreen extends StatelessWidget {
  const IkIsletmeKonumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return KopruEkran(
      yol: '/isletme-konum',
      baslik: 'İşletme Konumu',
      ikon: Icons.my_location,
      govde: (c, v, yenile) {
        final s = harita(v['sube']);
        return _KonumGovde(
          key: ValueKey('${s['mesai_lat']}|${s['mesai_lng']}|${s['mesai_yaricap']}|${s['adres']}'),
          sube: s,
          yenile: yenile,
        );
      },
    );
  }
}

class _KonumGovde extends StatefulWidget {
  final Map<String, dynamic> sube;
  final Future<void> Function() yenile;
  const _KonumGovde({super.key, required this.sube, required this.yenile});
  @override
  State<_KonumGovde> createState() => _KonumGovdeState();
}

class _KonumGovdeState extends State<_KonumGovde> {
  double? _lat, _lng;
  int _yaricap = 150;
  bool _mesgul = false;
  bool _degisti = false;
  String? _mesaj;
  final _adres = TextEditingController();
  final _latC = TextEditingController(), _lngC = TextEditingController();
  final _mc = MapController();

  bool get _kayitliVar => widget.sube['mesai_lat'] != null && widget.sube['mesai_lng'] != null;

  @override
  void initState() {
    super.initState();
    final s = widget.sube;
    if (s['mesai_lat'] != null && s['mesai_lng'] != null) {
      _lat = sayiOku(s['mesai_lat']);
      _lng = sayiOku(s['mesai_lng']);
    }
    _yaricap = s['mesai_yaricap'] == null ? 150 : tamOku(s['mesai_yaricap']).clamp(100, 300);
    _adres.text = metinOku(s['adres']);
    _koordYaz();
  }

  void _koordYaz() {
    _latC.text = _lat == null ? '' : _lat!.toStringAsFixed(6);
    _lngC.text = _lng == null ? '' : _lng!.toStringAsFixed(6);
  }

  Future<void> _gps() async {
    setState(() { _mesgul = true; _mesaj = 'Konum alınıyor…'; });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _hata('Konum servisi kapalı — cihazda GPS/konumu açın.');
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return _hata('Konum izni verilmedi.');
      final pos = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)));
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _degisti = true;
        _mesgul = false;
        _mesaj = 'Konum alındı (±${pos.accuracy.round()} m). Kaydediliyor…';
        _koordYaz();
      });
      try { _mc.move(LatLng(_lat!, _lng!), 17); } catch (_) {}
      await _kaydet();
    } catch (_) {
      _hata('Konum alınamadı (kapalı alanda sinyal zayıf olabilir). Haritadan dokunarak da seçebilirsiniz.');
    }
  }

  void _hata(String m) {
    if (mounted) setState(() { _mesgul = false; _mesaj = m; });
  }

  Future<void> _kaydet() async {
    final la = sayiOku(_latC.text), ln = sayiOku(_lngC.text);
    if (_latC.text.trim().isEmpty || _lngC.text.trim().isEmpty || la.abs() > 90 || ln.abs() > 180) {
      kToast(context, 'Önce konum seçin (GPS, harita ya da enlem/boylam).', hata: true);
      return;
    }
    setState(() => _mesgul = true);
    final ok = await kopruGonder(context, '/isletme-konum/kaydet', {
      'lat': la.toStringAsFixed(7), 'lng': ln.toStringAsFixed(7), 'yaricap': '$_yaricap', 'adres': _adres.text.trim(),
    }, basariMesaji: 'İşletme konumu kaydedildi.');
    if (!mounted) return;
    setState(() { _mesgul = false; if (ok) _degisti = false; });
    if (ok) await widget.yenile();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final nokta = (_lat != null && _lng != null) ? LatLng(_lat!, _lng!) : null;
    return KGovde(yenile: widget.yenile, children: [
      KKart(
        renk: _kayitliVar ? t.yesil : t.sub,
        child: Row(children: [
          KIkon(_kayitliVar ? Icons.check_circle_outline : Icons.location_off_outlined, renk: _kayitliVar ? t.yesil : t.sub, boyut: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_kayitliVar ? 'Konum ayarlı' : 'Konum henüz ayarlanmadı', style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Text(
                _kayitliVar
                    ? 'Yarıçap: ${tamOku(widget.sube['mesai_yaricap'] ?? 150)} m · ${sayiOku(widget.sube['mesai_lat']).toStringAsFixed(5)}, ${sayiOku(widget.sube['mesai_lng']).toStringAsFixed(5)}'
                    : 'Ayarlanmadan geofence çalışmaz (yalnız 20 sn QR kontrolü yapılır).',
                style: TextStyle(color: t.sub, fontSize: 13),
              ),
            ]),
          ),
        ]),
      ),
      KButon(_kayitliVar ? 'Konumu Güncelle (buradayım)' : 'Şu Anki Konumu Kullan', ikon: Icons.my_location, genis: true, yukleniyor: _mesgul, onTap: _gps),
      if (_mesaj != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_mesaj!, textAlign: TextAlign.center, style: TextStyle(color: t.sub2, fontSize: 13))),
      const SizedBox(height: 14),
      KBaslik('Haritadan seç', ikon: Icons.map_outlined, alt: 'Haritaya dokunarak işletme noktasını işaretleyin'),
      KKart(
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: genisMi(context) ? 380 : 280,
          child: Stack(children: [
            FlutterMap(
              mapController: _mc,
              options: MapOptions(
                initialCenter: nokta ?? const LatLng(39.0, 35.0),
                initialZoom: nokta == null ? 5 : 17,
                minZoom: 3,
                maxZoom: 19,
                onTap: (_, p) => setState(() {
                  _lat = p.latitude;
                  _lng = p.longitude;
                  _degisti = true;
                  _mesaj = 'Haritadan nokta seçildi. "Kaydet" ile kaydedin.';
                  _koordYaz();
                }),
              ),
              children: [
                TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.restoos.restoos_patron', maxZoom: 19),
                if (nokta != null)
                  CircleLayer(circles: [
                    CircleMarker(point: nokta, radius: _yaricap.toDouble(), useRadiusInMeter: true, color: t.mor1.withValues(alpha: .15), borderColor: t.mor1, borderStrokeWidth: 2),
                  ]),
                if (nokta != null)
                  MarkerLayer(markers: [Marker(point: nokta, width: 44, height: 44, child: Icon(Icons.location_on, color: t.kirmizi, size: 40))]),
              ],
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                color: Colors.white70,
                child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Colors.black54)),
              ),
            ),
          ]),
        ),
      ),
      KKart(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Yarıçap (izin verilen mesafe)', style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Personel bu mesafe içindeyse QR okutabilir. İç mekân GPS sapmasına karşı 150 m önerilir.', style: TextStyle(color: t.sub, fontSize: 12.5)),
          Row(children: [
            Expanded(
              child: Slider(
                value: _yaricap.toDouble(),
                min: 100,
                max: 300,
                divisions: 8,
                activeColor: t.mor1,
                label: '$_yaricap m',
                onChanged: (x) => setState(() { _yaricap = x.round(); _degisti = true; }),
              ),
            ),
            SizedBox(width: 64, child: Text('$_yaricap m', textAlign: TextAlign.right, style: TextStyle(color: t.ink, fontSize: 15, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: KAlan('Enlem', _latC, klavye: const TextInputType.numberWithOptions(decimal: true, signed: true))),
            const SizedBox(width: 10),
            Expanded(child: KAlan('Boylam', _lngC, klavye: const TextInputType.numberWithOptions(decimal: true, signed: true))),
          ]),
          KAlan('Adres (isteğe bağlı)', _adres, satir: 2),
          KButon(_degisti ? 'Kaydet (değişiklik var)' : 'Kaydet', ikon: Icons.save_outlined, genis: true, yukleniyor: _mesgul, onTap: _kaydet),
        ]),
      ),
      KKart(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline, color: t.mavi, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Bu ekranı İŞLETMEDEYKEN açıp "Şu Anki Konumu Kullan"a basın; cihazın konumu işletme noktası olarak kaydedilir. '
                'Masaüstünde GPS yoksa haritadan dokunarak seçin. (Kasa Mesai QR ekranı açılınca da otomatik ayarlanır.)',
                style: TextStyle(color: t.sub2, fontSize: 13, height: 1.4)),
          ),
        ]),
      ),
    ]);
  }
}

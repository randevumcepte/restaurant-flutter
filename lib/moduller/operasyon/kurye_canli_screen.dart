import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../kopru/kopru_api.dart';
import '../../kopru/kopru_ekran.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tema_provider.dart';
import '../../responsive.dart';
import '../../services/api.dart';
import '../../ui/kit.dart';

/// Web /kurye-canli (kurye_harita) — canlı kurye haritası, YEREL (flutter_map + OSM; dış tarayıcı yok).
/// Veri: GET /api/kurye-canli-veri (8 sn'de bir). Kuryeler haritada; yan/alt listede kuryeler + aktif teslimatlar.
class OpKuryeCanliScreen extends StatefulWidget {
  const OpKuryeCanliScreen({super.key});
  @override
  State<OpKuryeCanliScreen> createState() => _OpKuryeCanliScreenState();
}

class _OpKuryeCanliScreenState extends State<OpKuryeCanliScreen> {
  final MapController _mc = MapController();
  Map<String, dynamic>? _veri;
  String? _hata;
  bool _yetkisiz = false;
  DateTime? _son;
  Timer? _t;
  bool _ilk = true;
  int? _secili;
  String _mobilSekme = 'harita';

  @override
  void initState() {
    super.initState();
    _yukle();
    _t = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) _yukle(sessiz: true);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _yukle({bool sessiz = false}) async {
    final a = context.read<AuthProvider>();
    final tok = a.token;
    if (tok == null) return;
    try {
      final c = await KopruApi.al(tok, '/api/kurye-canli-veri', q: {if (a.subeId != null) 'sube': '${a.subeId}'});
      if (!mounted) return;
      setState(() {
        if (c.ok) {
          _veri = c.j;
          _hata = null;
          _yetkisiz = false;
          _son = DateTime.now();
        } else if (!sessiz || _veri == null) {
          _hata = c.hata;
          _yetkisiz = c.yetkisiz;
        }
      });
      if (c.ok) _ilkOturt();
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    }
  }

  LatLng? _nokta(Map<String, dynamic> k) {
    final lat = sayiOku(k['lat']);
    final lng = sayiOku(k['lng']);
    if (k['lat'] == null || k['lng'] == null || (lat == 0 && lng == 0)) return null;
    return LatLng(lat, lng);
  }

  List<Map<String, dynamic>> get _kuryeler => liste(_veri?['kuryeler']);
  List<Map<String, dynamic>> get _teslimatlar => liste(_veri?['teslimatlar']);

  void _ilkOturt() {
    if (!_ilk) return;
    final noktalar = [for (final k in _kuryeler) _nokta(k)].whereType<LatLng>().toList();
    if (noktalar.isEmpty) return;
    _ilk = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        if (noktalar.length == 1) {
          _mc.move(noktalar.first, 15);
        } else {
          _mc.fitCamera(CameraFit.bounds(bounds: LatLngBounds.fromPoints(noktalar), padding: const EdgeInsets.all(60), maxZoom: 15));
        }
      } catch (_) {}
    });
  }

  void _odak(Map<String, dynamic> k) {
    final p = _nokta(k);
    if (p == null) {
      kToast(context, '${metinOku(k['ad'])} için konum bilgisi yok (kurye uygulaması konum göndermiyor).', hata: true);
      return;
    }
    setState(() {
      _secili = tamOku(k['id']);
      _mobilSekme = 'harita';
    });
    try {
      _mc.move(p, 16);
    } catch (_) {}
  }

  Color _durumRenk(TemaProvider t, String d) => switch (d) {
        'musait' => const Color(0xFF10B981),
        'teslimatta' || 'yolda' => t.amber,
        'mola' => t.sub,
        _ => t.sub2,
      };

  String _durumEt(String d) => switch (d) {
        'musait' => 'Müsait',
        'teslimatta' => 'Teslimatta',
        'yolda' => 'Yolda',
        'mola' => 'Molada',
        _ => d.isEmpty ? '—' : d,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    Widget govde;
    if (_veri == null && _hata == null) {
      govde = const KYukleniyor(metin: 'Kurye konumları alınıyor…');
    } else if (_veri == null) {
      govde = KHata(_hata ?? 'Yüklenemedi', tekrar: _yukle, yetkisiz: _yetkisiz);
    } else {
      final genis = genisMi(context);
      final harita = _harita(t);
      final yan = _yanListe(t);
      govde = Column(children: [
        _ozetSerit(t),
        Expanded(
          child: genis
              ? Row(children: [Expanded(child: harita), SizedBox(width: 340, child: DecoratedBox(decoration: BoxDecoration(border: Border(left: BorderSide(color: t.line))), child: yan))])
              : Column(children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: KCipler(
                      secenekler: [('harita', 'Harita'), ('liste', 'Liste (${_kuryeler.length} kurye · ${_teslimatlar.length} teslimat)')],
                      secili: _mobilSekme,
                      onSec: (k) => setState(() => _mobilSekme = k),
                    ),
                  ),
                  Expanded(child: _mobilSekme == 'harita' ? harita : yan),
                ]),
        ),
      ]);
    }
    return KSayfa(
      baslik: 'Canlı Kurye Haritası',
      ikon: Icons.my_location,
      araclar: [IconButton(tooltip: 'Yenile', onPressed: _yukle, icon: const Icon(Icons.refresh))],
      govde: govde,
    );
  }

  Widget _ozetSerit(TemaProvider t) {
    final o = harita(_veri?['ozet']);
    Widget kutu(String e, dynamic v, Color r) => Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${tamOku(v)}', style: TextStyle(color: r, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(width: 5),
          Text(e, style: TextStyle(color: t.sub2, fontSize: 13, fontWeight: FontWeight.w600)),
        ]);
    final s = _son;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: t.card, border: Border(bottom: BorderSide(color: t.line))),
      child: Wrap(spacing: 18, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        kutu('kurye', o['kurye'], t.ink),
        kutu('müsait', o['musait'], const Color(0xFF10B981)),
        kutu('yolda', o['yolda'], t.amber),
        if (s != null)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.sync, size: 14, color: t.sub),
            const SizedBox(width: 4),
            Text('son güncelleme ${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}:${s.second.toString().padLeft(2, '0')} · 8 sn\'de bir yenilenir',
                style: TextStyle(color: t.sub, fontSize: 12)),
          ]),
      ]),
    );
  }

  Widget _harita(TemaProvider t) {
    final konumlu = [for (final k in _kuryeler) if (_nokta(k) != null) k];
    final merkez = konumlu.isNotEmpty ? _nokta(konumlu.first)! : const LatLng(40.9905, 29.0250);
    return Stack(children: [
      FlutterMap(
        mapController: _mc,
        options: MapOptions(initialCenter: merkez, initialZoom: 14, minZoom: 4, maxZoom: 18, onTap: (p, l) => setState(() => _secili = null)),
        children: [
          TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', userAgentPackageName: 'com.restoos.restoos_patron', maxZoom: 19),
          MarkerLayer(markers: [
            for (final k in konumlu)
              Marker(
                point: _nokta(k)!,
                width: _secili == tamOku(k['id']) ? 190 : 52,
                height: _secili == tamOku(k['id']) ? 112 : 52,
                alignment: Alignment.topCenter,
                child: GestureDetector(
                  onTap: () => setState(() => _secili = _secili == tamOku(k['id']) ? null : tamOku(k['id'])),
                  child: _pin(t, k),
                ),
              ),
          ]),
        ],
      ),
      Positioned(
        right: 4,
        bottom: 4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: Colors.white70,
          child: const Text('© OpenStreetMap', style: TextStyle(fontSize: 10, color: Colors.black54)),
        ),
      ),
      if (konumlu.isEmpty)
        Positioned(
          left: 12,
          right: 12,
          top: 12,
          child: KKart(
            margin: EdgeInsets.zero,
            renk: t.amber,
            child: Text(
              _kuryeler.isEmpty
                  ? 'Aktif kurye yok. Kuryeler Personel / Kurye ekranından eklenir; kurye uygulamasına giriş yapınca burada görünür.'
                  : 'Kuryelerin konumu henüz gelmedi. Konum, kurye telefonundaki uygulama açıkken ve konum izni verildiğinde gönderilir.',
              style: TextStyle(color: t.ink, fontSize: 13, height: 1.4),
            ),
          ),
        ),
    ]);
  }

  Widget _pin(TemaProvider t, Map<String, dynamic> k) {
    final secili = _secili == tamOku(k['id']);
    final r = _durumRenk(t, metinOku(k['durum']));
    final ikon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
        shape: BoxShape.circle,
        border: Border.all(color: r, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: const Icon(Icons.delivery_dining, color: Colors.white, size: 24),
    );
    if (!secili) return Center(child: ikon);
    final dk = k['konum_dk'];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 190,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line), boxShadow: t.golge),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(metinOku(k['ad']), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w700)),
          Text('${_durumEt(metinOku(k['durum']))} · ${tamOku(k['aktif_teslimat'])} teslimat${dk != null ? ' · ${tamOku(dk)} dk önce' : ''}',
              maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: t.sub, fontSize: 11.5)),
        ]),
      ),
      const SizedBox(height: 4),
      ikon,
    ]);
  }

  Widget _yanListe(TemaProvider t) {
    final kuryeler = _kuryeler;
    final teslimatlar = _teslimatlar;
    return RefreshIndicator(
      onRefresh: _yukle,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 40),
        children: [
          KBaslik('Kuryeler (${kuryeler.length})', ikon: Icons.delivery_dining_outlined, renk: t.mor1),
          if (kuryeler.isEmpty)
            const KBos(
              baslik: 'Aktif kurye yok',
              aciklama: 'Bu şubede aktif kurye tanımlı değil. Kuryeler Personel / Kurye yönetiminden eklenir ve kurye uygulamasına giriş yapınca burada görünür.',
              ikon: Icons.delivery_dining_outlined,
            )
          else
            for (final k in kuryeler)
              KKart(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                renk: _secili == tamOku(k['id']) ? t.mor1 : null,
                onTap: () => _odak(k),
                child: Row(children: [
                  KIkon(Icons.delivery_dining, renk: t.mor1, boyut: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(metinOku(k['ad']), style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w700)),
                      Text(
                        '${tamOku(k['aktif_teslimat'])} aktif teslimat · ${k['konum_dk'] != null ? '${tamOku(k['konum_dk'])} dk önce' : 'konum yok'}',
                        style: TextStyle(color: t.sub, fontSize: 12),
                      ),
                    ]),
                  ),
                  KRozet(_durumEt(metinOku(k['durum'])), renk: _durumRenk(t, metinOku(k['durum']))),
                ]),
              ),
          const SizedBox(height: 10),
          KBaslik('Aktif Teslimatlar (${teslimatlar.length})', ikon: Icons.location_on_outlined, renk: t.amber),
          if (teslimatlar.isEmpty)
            const KBos(
              baslik: 'Aktif teslimat yok',
              aciklama: 'Paket siparişi "hazır" ya da "yolda" durumuna geçince burada listelenir. Siparişler Paket ekranından yönetilir.',
              ikon: Icons.inventory_2_outlined,
            )
          else
            for (final s in teslimatlar)
              KKart(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                renk: metinOku(s['teslimat_durumu']) == 'yolda' ? t.amber : const Color(0xFF10B981),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.location_on_outlined, size: 17, color: t.kirmizi),
                    const SizedBox(width: 6),
                    Expanded(child: Text(metinOku(s['teslimat_adres'], 'Adres yok'), style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w600))),
                    KRozet(metinOku(s['teslimat_durumu']) == 'yolda' ? 'Yolda' : 'Hazır', renk: metinOku(s['teslimat_durumu']) == 'yolda' ? t.amber : const Color(0xFF10B981)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    '#${tamOku(s['id'])} · ${metinOku(s['kurye'], 'kurye atanmadı')} · ${metinOku(s['platform'], 'paket')} · ${tl(s['toplam'], kisa: true)}${metinOku(s['musteri']).isEmpty ? '' : ' · ${metinOku(s['musteri'])}'}',
                    style: TextStyle(color: t.sub, fontSize: 12),
                  ),
                ]),
              ),
        ],
      ),
    );
  }
}

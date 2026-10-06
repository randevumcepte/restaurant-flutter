import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api.dart';

/// Kurye uygulaması ekranı — token ile giriş, teslimatları görür,
/// "Teslim Ettim / Teslim Edemedim" işaretler, canlı GPS gönderir.
/// Para KASAYA kurye getirince kasa tahsil eder (iki aşamalı model).
class KuryeScreen extends StatefulWidget {
  const KuryeScreen({super.key});

  @override
  State<KuryeScreen> createState() => _KuryeScreenState();
}

class _KuryeScreenState extends State<KuryeScreen> {
  static const _mor = Color(0xFF7C3AED);
  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _line = Color(0xFF232B42);
  static const _ink = Color(0xFFF3E9EE);
  static const _sub = Color(0xFF94A3B8);
  static const _yesil = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  static const _kirmizi = Color(0xFFF43F5E);

  final _f = NumberFormat.decimalPattern('tr');
  final _girisCtrl = TextEditingController();

  String? token;
  List teslimatlar = [];
  String kuryeAd = '';
  bool loading = true;
  bool _gpsOk = false;
  String? hata;
  Timer? _gpsTimer;

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _gpsTimer?.cancel();
    _girisCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final sp = await SharedPreferences.getInstance();
    token = sp.getString('kurye_token');
    if (token == null || token!.isEmpty) {
      setState(() => loading = false);
      return;
    }
    await _yukle();
    _gpsBaslat();
  }

  Future<void> _yukle() async {
    if (token == null) return;
    setState(() {
      loading = true;
      hata = null;
    });
    try {
      final r = await http.get(Uri.parse('${Api.base}/api/kurye/$token/teslimatlar'));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (j['ok'] == 1) {
        setState(() {
          teslimatlar = (j['teslimatlar'] as List?) ?? [];
          kuryeAd = (j['kurye']?['ad'] ?? '').toString();
          loading = false;
        });
      } else {
        final sp = await SharedPreferences.getInstance();
        await sp.remove('kurye_token');
        setState(() {
          hata = (j['hata'] ?? 'Geçersiz kurye kodu').toString();
          token = null;
          loading = false;
        });
      }
    } catch (_) {
      setState(() {
        hata = 'Bağlantı hatası';
        loading = false;
      });
    }
  }

  Future<void> _girisYap() async {
    var t = _girisCtrl.text.trim();
    if (t.contains('/kurye/')) {
      t = t.split('/kurye/').last.split('/').first.split('?').first;
    }
    if (t.isEmpty) {
      setState(() => hata = 'Kurye kodunu veya linkini girin');
      return;
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString('kurye_token', t);
    setState(() => token = t);
    await _yukle();
    if (token != null) _gpsBaslat();
  }

  Future<void> _cikis() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove('kurye_token');
    _gpsTimer?.cancel();
    setState(() {
      token = null;
      teslimatlar = [];
      _gpsOk = false;
    });
  }

  Future<void> _gpsBaslat() async {
    try {
      var izin = await Geolocator.checkPermission();
      if (izin == LocationPermission.denied) izin = await Geolocator.requestPermission();
      if (izin == LocationPermission.denied || izin == LocationPermission.deniedForever) return;
      _gpsOk = true;
      if (mounted) setState(() {});
      _gpsGonder();
      _gpsTimer?.cancel();
      _gpsTimer = Timer.periodic(const Duration(seconds: 15), (_) => _gpsGonder());
    } catch (_) {}
  }

  Future<void> _gpsGonder() async {
    if (token == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition();
      await http.post(Uri.parse('${Api.base}/kurye/$token/konum'),
          body: {'lat': pos.latitude.toString(), 'lng': pos.longitude.toString()});
    } catch (_) {}
  }

  Future<void> _durum(int id, String durum, {String? sebep}) async {
    try {
      final body = {'adisyon_id': id.toString(), 'durum': durum};
      if (sebep != null) body['sebep'] = sebep;
      final r = await http.post(Uri.parse('${Api.base}/kurye/$token/durum'), body: body);
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      if (!mounted) return;
      if (j['ok'] == 1) {
        if (j['mesaj'] != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(j['mesaj'].toString()), backgroundColor: _yesil, duration: const Duration(seconds: 2)));
        }
        _yukle();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((j['hata'] ?? 'Hata').toString())));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bağlantı hatası')));
    }
  }

  Future<void> _teslimEdemedim(int id) async {
    final c = TextEditingController();
    final sebep = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Teslim edilemedi'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Sebep: adreste yok, ulaşılamadı, vazgeçti...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _kirmizi),
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Gönder')),
        ],
      ),
    );
    if (sebep != null) _durum(id, 'teslim_edilemedi', sebep: sebep.isEmpty ? 'Teslim edilemedi' : sebep);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : token == null
                ? _girisEkrani()
                : _listeEkrani(),
      ),
    );
  }

  Widget _girisEkrani() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🛵', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 8),
          const Text('Kurye Girişi', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _ink)),
          const SizedBox(height: 6),
          const Text('Patronunuzun verdiği kurye kodunu ya da linkini yapıştırın.',
              textAlign: TextAlign.center, style: TextStyle(color: _sub, fontSize: 13)),
          const SizedBox(height: 24),
          TextField(
            controller: _girisCtrl,
            style: const TextStyle(color: _ink),
            decoration: InputDecoration(
              hintText: 'Kurye kodu veya link',
              hintStyle: const TextStyle(color: _sub),
              filled: true,
              fillColor: _card,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _line)),
            ),
          ),
          if (hata != null)
            Padding(padding: const EdgeInsets.only(top: 12), child: Text(hata!, style: const TextStyle(color: _kirmizi))),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: _mor, padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              onPressed: _girisYap,
              child: const Text('Giriş', style: TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(onPressed: () => Navigator.of(context).maybePop(), child: const Text('← Geri', style: TextStyle(color: _sub))),
        ]),
      ),
    );
  }

  Widget _listeEkrani() {
    return Column(children: [
      // Üst bar
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor, Color(0xFF4F46E5)]), borderRadius: BorderRadius.circular(22)),
            child: const Center(child: Text('🛵', style: TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(kuryeAd.isEmpty ? 'Kurye' : kuryeAd, style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.bold)),
              Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: _gpsOk ? _yesil : _kirmizi, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_gpsOk ? 'Konum paylaşılıyor · canlı' : 'Konum kapalı', style: const TextStyle(color: _sub, fontSize: 12)),
              ]),
            ]),
          ),
          IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh, color: _sub)),
          IconButton(onPressed: _cikis, icon: const Icon(Icons.logout, color: _sub)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('AKTİF TESLİMATLARIM (${teslimatlar.length})',
              style: const TextStyle(color: _sub, fontSize: 13, fontWeight: FontWeight.bold)),
        ),
      ),
      const SizedBox(height: 8),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _yukle,
          child: teslimatlar.isEmpty
              ? ListView(children: const [SizedBox(height: 120), Center(child: Text('🎉 Şu an aktif teslimatın yok.', style: TextStyle(color: _sub)))])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: teslimatlar.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _kart(teslimatlar[i]),
                ),
        ),
      ),
    ]);
  }

  Widget _kart(dynamic t) {
    final id = _n(t['id']).toInt();
    final durum = (t['teslimat_durumu'] ?? '').toString();
    final oy = (t['odeme_yontemi'] ?? 'nakit').toString();
    final tut = _f.format(_n(t['toplam']).round());
    final adres = (t['teslimat_adres'] ?? 'Adres girilmemiş').toString();
    final tel = (t['telefon'] ?? '').toString();
    final urunler = (t['urunler'] as List?) ?? [];

    Color tahsilRenk = oy == 'online' ? _sub : (oy == 'kart_kapida' ? _amber : _yesil);
    String tahsilMetin = oy == 'online'
        ? '🔗 Online ödendi · tahsilat YOK'
        : (oy == 'kart_kapida' ? '💳 Kapıda KART (POS götür) · $tut TL' : '💵 Kapıda NAKİT al · $tut TL');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(18), border: Border.all(color: _line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: _mor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
            child: Text((t['platform'] ?? 'paket').toString().toUpperCase(),
                style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
          const Spacer(),
          Text('$tut TL', style: const TextStyle(color: _yesil, fontSize: 16, fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        Text('📍 $adres', style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('${t['musteri'] ?? 'Müşteri'}${tel.isNotEmpty ? ' · $tel' : ''} · #$id · ${durum == 'yolda' ? '🛵 Yolda' : '📦 Hazır'}',
            style: const TextStyle(color: _sub, fontSize: 13)),
        if (urunler.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(urunler.map((u) => '${_n((u as Map)['adet']).toInt()}× ${u['ad']}').join(', '),
              style: const TextStyle(color: _sub, fontSize: 12.5)),
        ],
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: tahsilRenk.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(10), border: Border.all(color: tahsilRenk.withValues(alpha: 0.35))),
          child: Text(tahsilMetin, style: TextStyle(color: tahsilRenk, fontSize: 13.5, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _ac(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(adres)}')),
              style: OutlinedButton.styleFrom(side: const BorderSide(color: _line), foregroundColor: const Color(0xFFC7D2FE), padding: const EdgeInsets.symmetric(vertical: 12)),
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Yol Tarifi'),
            ),
          ),
          if (tel.isNotEmpty) ...[
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _ac(Uri.parse('tel:$tel')),
                style: OutlinedButton.styleFrom(side: const BorderSide(color: _line), foregroundColor: _ink, padding: const EdgeInsets.symmetric(vertical: 12)),
                icon: const Icon(Icons.call, size: 18),
                label: const Text('Ara'),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        if (durum != 'yolda')
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _amber, foregroundColor: const Color(0xFF3A2600), padding: const EdgeInsets.symmetric(vertical: 13)),
              onPressed: () => _durum(id, 'yolda'),
              child: const Text('Yola Çıktım', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        else
          Row(children: [
            Expanded(
              flex: 3,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: _yesil, foregroundColor: const Color(0xFF04231A), padding: const EdgeInsets.symmetric(vertical: 13)),
                onPressed: () => _durum(id, 'teslim'),
                child: const Text('Teslim Ettim ✅', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(side: const BorderSide(color: _kirmizi), foregroundColor: const Color(0xFFFDA4AF), padding: const EdgeInsets.symmetric(vertical: 13)),
                onPressed: () => _teslimEdemedim(id),
                child: const Text('Edemedim ✖', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ]),
      ]),
    );
  }

  Future<void> _ac(Uri u) async {
    try {
      if (await canLaunchUrl(u)) await launchUrl(u, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }
}

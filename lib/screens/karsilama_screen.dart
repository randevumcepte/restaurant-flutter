import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// KARŞILAMA / HOST iş ekranı:
/// Bekleme listesi (walk-in sırası, ekle/çağır/oturt) + bugünün rezervasyonları (geldi/oturt)
/// + bölge bazlı canlı masa durumu. SevenRooms tarzı tek host akışı.
class KarsilamaScreen extends StatefulWidget {
  const KarsilamaScreen({super.key});
  @override
  State<KarsilamaScreen> createState() => _KarsilamaScreenState();
}

class _KarsilamaScreenState extends State<KarsilamaScreen> {
  static const _mor = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);
  static const _mavi2 = Color(0xFF0EA5E9);
  static const _yesil = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  static const _kirmizi = Color(0xFFF43F5E);

  TemaProvider get _t => context.watch<TemaProvider>();
  Map<String, dynamic>? data;
  bool loading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _yukle();
    _timer = Timer.periodic(const Duration(seconds: 7), (_) => _yukle(sessiz: true));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _sure(dynamic v) {
    final sn = _n(v).toInt();
    if (sn < 60) return '$sn sn';
    final dk = sn ~/ 60;
    if (dk < 60) return '$dk dk';
    return '${dk ~/ 60} sa ${dk % 60} dk';
  }

  List get _bosMasalar => (data?['bos_masalar'] as List?) ?? [];

  Future<void> _yukle({bool sessiz = false}) async {
    final auth = context.read<AuthProvider>();
    if (!sessiz) setState(() => loading = true);
    try {
      final res = await Api.karsilamaPanel(auth.token!);
      if (!mounted) return;
      if (res['ok'] == 1) {
        setState(() { data = Map<String, dynamic>.from(res); loading = false; });
      } else {
        setState(() => loading = false);
      }
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _mesaj(String m) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m))); }

  // ---- Aksiyonlar ----
  Future<void> _beklemeDurum(int id, String durum) async {
    final auth = context.read<AuthProvider>();
    try { await Api.beklemeDurum(auth.token!, id, durum); } catch (_) {}
    _yukle(sessiz: true);
  }

  Future<void> _rezGeldi(int id) async {
    final auth = context.read<AuthProvider>();
    try { await Api.rezervasyonDurum(auth.token!, id, 'geldi'); } catch (_) {}
    _yukle(sessiz: true);
  }

  Future<void> _oturt({required bool bekleme, required int id, int? masaId}) async {
    final secilen = await _masaSec(masaId);
    if (secilen == null || !mounted) return;
    final auth = context.read<AuthProvider>();
    Map<String, dynamic> r;
    try {
      r = bekleme ? await Api.beklemeOturt(auth.token!, id, secilen) : await Api.rezervasyonOturt(auth.token!, id, masaId: secilen);
    } catch (_) { r = {'ok': 0}; }
    if (r['ok'] == 1) { _mesaj(r['mesaj']?.toString() ?? 'Masa açıldı.'); } else { _mesaj(r['hata']?.toString() ?? 'Oturtulamadı.'); }
    _yukle(sessiz: true);
  }

  Future<int?> _masaSec(int? onSecili) async {
    final t = context.read<TemaProvider>();
    final liste = _bosMasalar;
    if (liste.isEmpty) { _mesaj('Boş masa yok.'); return null; }
    int secili = onSecili ?? _n((liste.first as Map)['id']).toInt();
    return showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Masaya Oturt', style: TextStyle(color: t.ink, fontSize: 17)),
        content: SizedBox(width: 320, child: DropdownButton<int>(
          value: liste.any((m) => _n((m as Map)['id']).toInt() == secili) ? secili : _n((liste.first as Map)['id']).toInt(),
          isExpanded: true, dropdownColor: t.card,
          items: [for (final m in liste) DropdownMenuItem(value: _n((m as Map)['id']).toInt(), child: Text('${m['ad']} — ${m['bolge']}', style: TextStyle(color: t.ink)))],
          onChanged: (v) { if (v != null) setD(() => secili = v); },
        )),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, secili), style: ElevatedButton.styleFrom(backgroundColor: _yesil), child: const Text('Oturt')),
        ],
      )),
    );
  }

  Future<void> _beklemeEkleDialog() async {
    final t = context.read<TemaProvider>();
    final ad = TextEditingController(), tel = TextEditingController(), kisi = TextEditingController(text: '2'), dk = TextEditingController(), not = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: t.card,
        title: Text('Bekleyen Ekle', style: TextStyle(color: t.ink, fontSize: 17)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _tf(t, ad, 'Ad Soyad *'),
          _tf(t, tel, 'Telefon', tip: TextInputType.phone),
          Row(children: [
            Expanded(child: _tf(t, kisi, 'Kişi', tip: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: _tf(t, dk, 'Tahmini dk', tip: TextInputType.number)),
          ]),
          _tf(t, not, 'Not'),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Vazgeç', style: TextStyle(color: t.sub))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: _yesil), child: const Text('Ekle')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (ad.text.trim().isEmpty) { _mesaj('İsim gerekli.'); return; }
    final auth = context.read<AuthProvider>();
    try {
      await Api.beklemeEkle(auth.token!, ad: ad.text.trim(), telefon: tel.text.trim(), kisi: int.tryParse(kisi.text) ?? 2, not: not.text.trim(), tahminiDk: dk.text.trim());
    } catch (_) {}
    _yukle(sessiz: true);
  }

  Widget _tf(TemaProvider t, TextEditingController c, String hint, {TextInputType? tip}) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(controller: c, keyboardType: tip, style: TextStyle(color: t.ink),
          decoration: InputDecoration(hintText: hint, hintStyle: TextStyle(color: t.sub2), filled: true, fillColor: t.bg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: t.line)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11))),
      );

  @override
  Widget build(BuildContext context) {
    final t = _t;
    final oz = (data?['ozet'] as Map?) ?? {};
    final bekleme = (data?['bekleme'] as List?) ?? [];
    final rez = (data?['rezervasyonlar'] as List?) ?? [];
    final bolgeler = ((data?['masa_durum'] as Map?)?['bolgeler'] as List?) ?? [];
    return Scaffold(
      backgroundColor: t.bg,
      appBar: AppBar(
        backgroundColor: t.bg, elevation: 0,
        title: Text('Karşılama / Host', style: TextStyle(color: t.ink, fontSize: 18, fontWeight: FontWeight.bold)),
        iconTheme: IconThemeData(color: t.ink),
        actions: [IconButton(onPressed: () => _yukle(), icon: Icon(Icons.refresh, color: t.sub))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _mavi2, onPressed: _beklemeEkleDialog,
        icon: const Icon(Icons.add, color: Colors.white), label: const Text('Bekleyen Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: _mor))
          : RefreshIndicator(
              onRefresh: _yukle, color: _mor, backgroundColor: t.card,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
                children: [
                  Row(children: [
                    Expanded(child: _ozetKart(t, Icons.groups, '${_n(oz['bekleme_grup']).toInt()}', 'Bekleme sırası', _mavi2)),
                    const SizedBox(width: 10),
                    Expanded(child: _ozetKart(t, Icons.event_available, '${_n(oz['rez_bekleyen']).toInt()}', 'Bekleyen rez.', _amber)),
                    const SizedBox(width: 10),
                    Expanded(child: _ozetKart(t, Icons.table_restaurant, '${_n(oz['bos_masa']).toInt()}', 'Boş masa', _yesil)),
                  ]),
                  const SizedBox(height: 18),
                  _baslik(t, '⏳ Bekleme Listesi', bekleme.length),
                  const SizedBox(height: 8),
                  if (bekleme.isEmpty) _bos(t, 'Bekleyen yok.') else for (final b in bekleme) _beklemeSatir(t, b as Map),
                  const SizedBox(height: 18),
                  _baslik(t, '📅 Bugünün Rezervasyonları', rez.length),
                  const SizedBox(height: 8),
                  if (rez.isEmpty) _bos(t, 'Bugün rezervasyon yok.') else for (final x in rez) _rezSatir(t, x as Map),
                  const SizedBox(height: 18),
                  _baslik(t, '🪑 Masa Durumu', bolgeler.length),
                  const SizedBox(height: 8),
                  if (bolgeler.isEmpty) _bos(t, 'Masa/bölge tanımlı değil.') else _masaDurum(t, bolgeler),
                ],
              ),
            ),
    );
  }

  Widget _ozetKart(TemaProvider t, IconData ik, String say, String etiket, Color c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 11),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Row(children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: c.withValues(alpha: .15), shape: BoxShape.circle), child: Icon(ik, color: c, size: 19)),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(say, style: TextStyle(color: t.ink, fontSize: 20, fontWeight: FontWeight.w900, height: 1)),
            Text(etiket, style: TextStyle(color: t.sub, fontSize: 10.5, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      );

  Widget _baslik(TemaProvider t, String metin, int sayi) => Row(children: [
        Text(metin, style: TextStyle(color: t.ink, fontSize: 15.5, fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(20), border: Border.all(color: t.line)), child: Text('$sayi', style: TextStyle(color: t.sub, fontSize: 12, fontWeight: FontWeight.bold))),
      ]);

  Widget _kutu(TemaProvider t, Widget child) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
        child: child,
      );

  Widget _beklemeSatir(TemaProvider t, Map b) {
    final id = _n(b['id']).toInt();
    final cagrildi = b['durum'] == 'cagrildi';
    return _kutu(t, Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 9, 11),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: _mavi2.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.person, color: _mavi2, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text('${b['ad']} · ${_n(b['kisi']).toInt()} kişi', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
            if (cagrildi) Padding(padding: const EdgeInsets.only(left: 6), child: _etiket('Çağrıldı', _yesil)),
          ]),
          Text('${_sure(b['saniye'])} bekliyor${b['tahmini_dk'] != null ? ' · tahmini ${_n(b['tahmini_dk']).toInt()} dk' : ''}', style: TextStyle(color: t.sub, fontSize: 11.5)),
        ])),
        if (!cagrildi) _ikonBtn(Icons.campaign, _amber, () => _beklemeDurum(id, 'cagrildi')),
        _ikonBtn(Icons.chair_alt, _yesil, () => _oturt(bekleme: true, id: id)),
        _ikonBtn(Icons.close, t.sub, () => _beklemeDurum(id, 'iptal')),
      ]),
    ));
  }

  Widget _rezSatir(TemaProvider t, Map x) {
    final id = _n(x['id']).toInt();
    final geldi = x['durum'] == 'geldi';
    final durumRenk = x['durum'] == 'onaylandi' ? _mavi : (geldi ? _yesil : _amber);
    final masaId = x['masa_id'] == null ? null : _n(x['masa_id']).toInt();
    return _kutu(t, Padding(
      padding: const EdgeInsets.fromLTRB(13, 11, 9, 11),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: _mavi.withValues(alpha: .14), borderRadius: BorderRadius.circular(11)), child: const Icon(Icons.event, color: _mavi, size: 19)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Flexible(child: Text('${x['saat'] ?? ''} · ${x['ad']} · ${_n(x['kisi']).toInt()} kişi', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
            Padding(padding: const EdgeInsets.only(left: 6), child: _etiket(x['durum'] == 'geldi' ? 'Geldi' : (x['durum'] == 'onaylandi' ? 'Onaylı' : 'Bekliyor'), durumRenk)),
          ]),
          Text(x['masa'] != null ? '🪑 ${x['masa']}' : 'masa atanmadı', style: TextStyle(color: t.sub, fontSize: 11.5)),
        ])),
        if (!geldi) _ikonBtn(Icons.how_to_reg, _amber, () => _rezGeldi(id)),
        if (!geldi) _ikonBtn(Icons.chair_alt, _yesil, () => _oturt(bekleme: false, id: id, masaId: masaId)),
      ]),
    ));
  }

  Widget _masaDurum(TemaProvider t, List bolgeler) => Wrap(
        spacing: 10, runSpacing: 10,
        children: [for (final b in bolgeler) _bolgeKart(t, b as Map)],
      );

  Widget _bolgeKart(TemaProvider t, Map b) => Container(
        width: 165,
        padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(14), border: Border.all(color: t.line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${b['bolge']}', style: TextStyle(color: t.ink, fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Wrap(spacing: 10, children: [
            Text('● ${_n(b['bos']).toInt()} boş', style: const TextStyle(color: _yesil, fontSize: 12, fontWeight: FontWeight.w700)),
            Text('● ${_n(b['dolu']).toInt()} dolu', style: const TextStyle(color: _kirmizi, fontSize: 12, fontWeight: FontWeight.w700)),
            if (_n(b['rezerve']).toInt() > 0) Text('● ${_n(b['rezerve']).toInt()} rez.', style: const TextStyle(color: _amber, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ]),
      );

  Widget _etiket(String metin, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: c.withValues(alpha: .15), borderRadius: BorderRadius.circular(20)),
        child: Text(metin, style: TextStyle(color: c, fontSize: 10.5, fontWeight: FontWeight.w800)),
      );

  Widget _ikonBtn(IconData ik, Color c, VoidCallback onTap) => IconButton(
        onPressed: onTap, icon: Icon(ik, color: c, size: 21), visualDensity: VisualDensity.compact, padding: const EdgeInsets.all(4), constraints: const BoxConstraints(),
      );

  Widget _bos(TemaProvider t, String metin) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
        decoration: BoxDecoration(color: t.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: t.line)),
        child: Text(metin, style: TextStyle(color: t.sub, fontSize: 13)),
      );
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';

/// Mutfak (KDS) hub — 4 sekme:
///  1) Siparişler: istasyon filtreli + all-day toplu üretim görünümü
///  2) Servise Hazır: mutfak bitirdi, garson alsın (servis edildi)
///  3) 86 / Tükendi: ürünü anında satıştan kaldır/geri aç
///  4) Analiz: hazırlık süresi, darboğaz istasyon, saatlik yoğunluk + prep önerileri
class MutfakScreen extends StatefulWidget {
  const MutfakScreen({super.key});

  @override
  State<MutfakScreen> createState() => _MutfakScreenState();
}

class _MutfakScreenState extends State<MutfakScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  Timer? _timer;

  // --- Sekme 1: aktif siparişler ---
  List siparisler = [];
  List istasyonlar = [];
  List toplu = [];
  int toplamBekleyen = 0;
  String seciliIst = 'hepsi';
  bool topluMod = false;
  bool loading1 = true;

  // --- Sekme 2: servise hazır ---
  List servise = [];
  bool loading2 = true;

  // --- Sekme 3: 86 ---
  List urunler = [];
  String arama = '';
  bool loading3 = true;

  // --- Sekme 4: analiz ---
  Map<String, dynamic>? analiz;
  bool loading4 = true;

  TemaProvider get _t => context.watch<TemaProvider>();
  Color get _bg => _t.bg;
  Color get _card => _t.card;
  Color get _card2 => _t.card2;
  Color get _ink => _t.ink;
  Color get _sub => _t.sub;
  Color get _sub2 => _t.sub2;
  Color get _line => _t.line;
  static const _mor = Color(0xFF9D5DC8);
  static const _yesil = Color(0xFF10B981);
  static const _amber = Color(0xFFF59E0B);
  static const _kirmizi = Color(0xFFF43F5E);
  static const _mavi = Color(0xFF4F46E5);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
    _tab.addListener(() => setState(() {}));
    _siparisYukle();
    _serviseYukle();
    // Aktif sekmeye göre 15 sn'de bir tazele (mutfak canlı olmalı)
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_tab.index == 0) _siparisYukle(sessiz: true);
      if (_tab.index == 1) _serviseYukle(sessiz: true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tab.dispose();
    super.dispose();
  }

  String get _token => context.read<AuthProvider>().token!;

  Future<void> _siparisYukle({bool sessiz = false}) async {
    if (!sessiz) setState(() => loading1 = true);
    try {
      final res = await Api.mutfak(_token, istasyon: seciliIst);
      if (!mounted) return;
      setState(() {
        siparisler = (res['siparisler'] as List?) ?? [];
        istasyonlar = (res['istasyonlar'] as List?) ?? [];
        toplu = (res['toplu'] as List?) ?? [];
        toplamBekleyen = _n(res['toplam_bekleyen']).toInt();
        loading1 = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading1 = false);
    }
  }

  Future<void> _serviseYukle({bool sessiz = false}) async {
    if (!sessiz) setState(() => loading2 = true);
    try {
      final res = await Api.mutfakServiseHazir(_token);
      if (!mounted) return;
      setState(() {
        servise = (res['siparisler'] as List?) ?? [];
        loading2 = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading2 = false);
    }
  }

  Future<void> _urunYukle() async {
    setState(() => loading3 = true);
    try {
      final res = await Api.mutfakUrunler(_token);
      if (!mounted) return;
      setState(() {
        urunler = (res['urunler'] as List?) ?? [];
        loading3 = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading3 = false);
    }
  }

  Future<void> _analizYukle() async {
    setState(() => loading4 = true);
    try {
      final res = await Api.mutfakAnaliz(_token);
      if (!mounted) return;
      setState(() {
        analiz = res;
        loading4 = false;
      });
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() => loading4 = false);
    }
  }

  Future<void> _hazir(int adisyonId) async {
    try {
      await Api.mutfakHazir(_token, adisyonId: adisyonId);
      _siparisYukle(sessiz: true);
      _serviseYukle(sessiz: true);
    } catch (_) {}
  }

  Future<void> _servisEt(int adisyonId) async {
    try {
      await Api.mutfakServis(_token, adisyonId: adisyonId);
      _serviseYukle(sessiz: true);
    } catch (_) {}
  }

  Future<void> _tukendiToggle(Map u) async {
    try {
      final res = await Api.mutfak86(_token, _n(u['id']).toInt());
      if (!mounted) return;
      setState(() => u['tukendi'] = res['tukendi'] == true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(res['mesaj']?.toString() ?? ''),
        backgroundColor: res['tukendi'] == true ? _kirmizi : _yesil,
        duration: const Duration(seconds: 2),
      ));
    } catch (_) {}
  }

  Color _renk(int dk) {
    if (dk >= 15) return _kirmizi;
    if (dk >= 8) return _amber;
    return _yesil;
  }

  String _sure(int dk) {
    if (dk < 60) return '$dk dk';
    if (dk < 1440) return '${dk ~/ 60} sa ${dk % 60} dk';
    return '${dk ~/ 1440} g ${(dk % 1440) ~/ 60} sa';
  }

  String _adet(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  Widget build(BuildContext context) {
    final basliklar = ['Siparişler', 'Servise Hazır', '86 / Tükendi', 'Analiz'];
    final rozet = [siparisler.length, servise.length, 0, 0];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: IconThemeData(color: _sub),
        title: Text('👨‍🍳 Mutfak · ${basliklar[_tab.index]}',
            style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () {
              if (_tab.index == 0) _siparisYukle();
              if (_tab.index == 1) _serviseYukle();
              if (_tab.index == 2) _urunYukle();
              if (_tab.index == 3) _analizYukle();
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: _mor,
          labelColor: _ink,
          unselectedLabelColor: _sub,
          labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
          tabs: [
            for (int i = 0; i < basliklar.length; i++)
              Tab(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(basliklar[i]),
                  if (rozet[i] > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(color: i == 1 ? _mavi : _mor, borderRadius: BorderRadius.circular(20)),
                      child: Text('${rozet[i]}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ]),
              ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          _siparisSekme(),
          _serviseSekme(),
          _tukendiSekme(),
          _analizSekme(),
        ],
      ),
    );
  }

  // ======================= SEKME 1: SİPARİŞLER =======================
  Widget _siparisSekme() {
    if (loading1) return const Center(child: CircularProgressIndicator(color: _mor));
    return Column(children: [
      // İstasyon filtre çipleri + toplu üretim toggle
      Container(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Row(children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _cip('Tümü', 'hepsi', toplamBekleyen),
                for (final ist in istasyonlar)
                  _cip((ist as Map)['ad'].toString(), ist['kod'].toString(), _n(ist['bekleyen']).toInt()),
              ]),
            ),
          ),
          const SizedBox(width: 6),
          // All-day toplu üretim
          GestureDetector(
            onTap: () => setState(() => topluMod = !topluMod),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: topluMod ? _mor : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: topluMod ? _mor : _line),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.dashboard_customize, size: 15, color: topluMod ? Colors.white : _sub),
                const SizedBox(width: 5),
                Text('Toplu', style: TextStyle(color: topluMod ? Colors.white : _sub, fontSize: 12.5, fontWeight: FontWeight.bold)),
              ]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: topluMod
            ? _topluGorunum()
            : siparisler.isEmpty
                ? _bos('Bekleyen sipariş yok. 👨‍🍳')
                : RefreshIndicator(
                    onRefresh: _siparisYukle,
                    color: _mor, backgroundColor: _card,
                    child: LayoutBuilder(builder: (ctx, c) {
                      final genis = c.maxWidth >= 640;
                      final kartW = genis ? (c.maxWidth - 36) / 2 : c.maxWidth - 24;
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        child: Wrap(spacing: 12, runSpacing: 12, children: [
                          for (final s in siparisler) SizedBox(width: kartW, child: _kart(s as Map)),
                        ]),
                      );
                    }),
                  ),
      ),
    ]);
  }

  Widget _cip(String ad, String kod, int adet) {
    final aktif = seciliIst == kod;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: GestureDetector(
        onTap: () {
          setState(() => seciliIst = kod);
          _siparisYukle();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: aktif ? _mor : _card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: aktif ? _mor : _line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(ad, style: TextStyle(color: aktif ? Colors.white : _sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
            if (adet > 0) ...[
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
                decoration: BoxDecoration(color: aktif ? Colors.white24 : _card2, borderRadius: BorderRadius.circular(20)),
                child: Text('$adet', style: TextStyle(color: aktif ? Colors.white : _mor, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  // All-day toplu üretim: aynı ürünü tüm masalardan toplar (aşçı batch yapsın)
  Widget _topluGorunum() {
    if (toplu.isEmpty) return _bos('Üretilecek ürün yok. 👨‍🍳');
    return RefreshIndicator(
      onRefresh: _siparisYukle,
      color: _mor, backgroundColor: _card,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _mor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.info_outline, size: 15, color: _mor),
              const SizedBox(width: 7),
              Expanded(child: Text('Tüm masalardaki aynı ürünler toplandı — toplu hazırla.', style: TextStyle(color: _sub2, fontSize: 12))),
            ]),
          ),
          for (final t in toplu) _topluSatir(t as Map),
        ],
      ),
    );
  }

  Widget _topluSatir(Map t) {
    final dk = _n(t['dk']).toInt();
    final renk = _renk(dk);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: renk, width: 4)),
      ),
      child: Row(children: [
        Container(
          width: 46, height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
          child: Text(_adet(_n(t['adet'])), style: TextStyle(color: renk, fontSize: 20, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t['ad'].toString(), style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(t['istasyon_ad']?.toString() ?? '', style: TextStyle(color: _sub, fontSize: 12)),
          ]),
        ),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.schedule, size: 13, color: renk),
          const SizedBox(width: 4),
          Text('en eski ${_sure(dk)}', style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold)),
        ]),
      ]),
    );
  }

  Widget _kart(Map s) {
    final dk = _n(s['dk']).toInt();
    final renk = _renk(dk);
    final kalemler = (s['kalemler'] as List?) ?? [];
    final toplamAdet = kalemler.fold<num>(0, (t, k) => t + _n((k as Map)['adet']));
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renk.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: const BorderRadius.vertical(top: Radius.circular(13))),
          child: Row(children: [
            Flexible(
              child: Text(s['masa'].toString(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Text('· ${_adet(toplamAdet)} ürün', style: TextStyle(color: _sub, fontSize: 12)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: renk.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.schedule, size: 12, color: renk),
                const SizedBox(width: 4),
                Text(_sure(dk), style: TextStyle(color: renk, fontSize: 12, fontWeight: FontWeight.bold)),
              ]),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final k in kalemler) _kalemSatir(k as Map),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
          child: SizedBox(
            width: double.infinity, height: 40,
            child: FilledButton.icon(
              onPressed: () => _hazir(_n(s['adisyon_id']).toInt()),
              style: FilledButton.styleFrom(
                backgroundColor: _yesil, padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.check, size: 17, color: Colors.white),
              label: const Text('Hazır', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _kalemSatir(Map k) {
    final not = (k['not']?.toString() ?? '');
    final kur = (k['kur']?.toString() ?? '');
    // Alerji/özel istek vurgusu
    final alerji = not.toLowerCase().contains('alerji') || not.toLowerCase().contains('alerjik');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          margin: const EdgeInsets.only(top: 1), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          decoration: BoxDecoration(color: _card2, borderRadius: BorderRadius.circular(6)),
          child: Text('${_adet(_n(k['adet']))}×', style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(k['ad'].toString(), style: TextStyle(color: _ink, fontSize: 13.5, fontWeight: FontWeight.w600))),
              if (kur.isNotEmpty && kur != 'null') ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0.5),
                  decoration: BoxDecoration(color: _mavi.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(5)),
                  child: Text(kur, style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ],
            ]),
            if (not.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: alerji ? const EdgeInsets.symmetric(horizontal: 6, vertical: 1) : EdgeInsets.zero,
                decoration: alerji ? BoxDecoration(color: _kirmizi.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(5)) : null,
                child: Text('${alerji ? '⚠️ ' : '📝 '}$not',
                    style: TextStyle(color: alerji ? _kirmizi : _amber, fontSize: 11, fontWeight: alerji ? FontWeight.bold : FontWeight.normal)),
              ),
          ]),
        ),
      ]),
    );
  }

  // ======================= SEKME 2: SERVİSE HAZIR =======================
  Widget _serviseSekme() {
    if (loading2) return const Center(child: CircularProgressIndicator(color: _mor));
    if (servise.isEmpty) return _bos('Servis bekleyen sipariş yok.');
    return RefreshIndicator(
      onRefresh: _serviseYukle,
      color: _mor, backgroundColor: _card,
      child: LayoutBuilder(builder: (ctx, c) {
        final genis = c.maxWidth >= 640;
        final kartW = genis ? (c.maxWidth - 36) / 2 : c.maxWidth - 24;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(12),
          child: Wrap(spacing: 12, runSpacing: 12, children: [
            for (final s in servise) SizedBox(width: kartW, child: _serviseKart(s as Map)),
          ]),
        );
      }),
    );
  }

  Widget _serviseKart(Map s) {
    final dk = _n(s['dk']).toInt();
    final kalemler = (s['kalemler'] as List?) ?? [];
    // Beklerken soğur: uzun bekleyen kırmızı
    final renk = dk >= 10 ? _kirmizi : (dk >= 5 ? _amber : _mavi);
    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: renk.withValues(alpha: 0.5), width: 1.2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: renk.withValues(alpha: 0.12), borderRadius: const BorderRadius.vertical(top: Radius.circular(13))),
          child: Row(children: [
            Icon(Icons.room_service, size: 15, color: _sub),
            const SizedBox(width: 6),
            Flexible(child: Text(s['masa'].toString(), overflow: TextOverflow.ellipsis, style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.bold))),
            const Spacer(),
            Text('✓ hazır ${_sure(dk)} önce', style: TextStyle(color: renk, fontSize: 11.5, fontWeight: FontWeight.bold)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final k in kalemler)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${_adet(_n((k as Map)['adet']))}× ${k['ad']}', style: TextStyle(color: _ink, fontSize: 13.5)),
              ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 10),
          child: SizedBox(
            width: double.infinity, height: 40,
            child: FilledButton.icon(
              onPressed: () => _servisEt(_n(s['adisyon_id']).toInt()),
              style: FilledButton.styleFrom(
                backgroundColor: _mavi, padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.done_all, size: 17, color: Colors.white),
              label: const Text('Servis Edildi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
            ),
          ),
        ),
      ]),
    );
  }

  // ======================= SEKME 3: 86 / TÜKENDİ =======================
  Widget _tukendiSekme() {
    // İlk açılışta yükle
    if (loading3 && urunler.isEmpty) {
      _urunYukle();
      return const Center(child: CircularProgressIndicator(color: _mor));
    }
    final q = arama.toLowerCase().trim();
    final liste = q.isEmpty ? urunler : urunler.where((u) => (u as Map)['ad'].toString().toLowerCase().contains(q)).toList();
    final tukenen = urunler.where((u) => (u as Map)['tukendi'] == true).length;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: Column(children: [
          TextField(
            style: TextStyle(color: _ink),
            onChanged: (v) => setState(() => arama = v),
            decoration: InputDecoration(
              hintText: 'Ürün ara…',
              hintStyle: TextStyle(color: _sub),
              prefixIcon: Icon(Icons.search, color: _sub, size: 20),
              filled: true, fillColor: _card,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.remove_shopping_cart, size: 15, color: _kirmizi),
            const SizedBox(width: 6),
            Text(tukenen > 0 ? '$tukenen ürün şu an tükendi (86)' : 'Tükenen ürün yok — hepsi satışta',
                style: TextStyle(color: tukenen > 0 ? _kirmizi : _sub, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _urunYukle,
          color: _mor, backgroundColor: _card,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            itemCount: liste.length,
            separatorBuilder: (_, _) => const SizedBox(height: 6),
            itemBuilder: (_, i) => _tukendiSatir(liste[i] as Map),
          ),
        ),
      ),
    ]);
  }

  Widget _tukendiSatir(Map u) {
    final tukendi = u['tukendi'] == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tukendi ? _kirmizi.withValues(alpha: 0.5) : Colors.transparent),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(u['ad'].toString(),
                style: TextStyle(color: tukendi ? _sub : _ink, fontSize: 14.5, fontWeight: FontWeight.w600,
                    decoration: tukendi ? TextDecoration.lineThrough : null, decorationColor: _kirmizi)),
            const SizedBox(height: 2),
            Text(u['kategori'].toString(), style: TextStyle(color: _sub, fontSize: 11.5)),
          ]),
        ),
        if (tukendi)
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(color: _kirmizi.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(6)),
            child: const Text('86', style: TextStyle(color: _kirmizi, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        Switch(
          value: tukendi,
          activeThumbColor: _kirmizi,
          onChanged: (_) => _tukendiToggle(u),
        ),
      ]),
    );
  }

  // ======================= SEKME 4: ANALİZ =======================
  Widget _analizSekme() {
    if (loading4 && analiz == null) {
      _analizYukle();
      return const Center(child: CircularProgressIndicator(color: _mor));
    }
    if (analiz == null) return _bos('Analiz yüklenemedi.');
    final ozet = (analiz!['ozet'] as Map?) ?? {};
    final oneriler = (analiz!['oneriler'] as List?) ?? [];
    final istYuk = (analiz!['istasyon_yuku'] as List?) ?? [];
    final enYavas = (analiz!['en_yavas'] as List?) ?? [];
    final saatlik = (analiz!['saatlik'] as List?) ?? [];
    final ortDk = ozet['ort_dk'];
    return RefreshIndicator(
      onRefresh: _analizYukle,
      color: _mor, backgroundColor: _card,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(12),
        children: [
          // Özet kutucuklar
          Row(children: [
            _ozetKutu('Ort. Hazırlık', ortDk != null ? '$ortDk dk' : '—', Icons.timer_outlined, ortDk != null && _n(ortDk) > 18 ? _kirmizi : _yesil),
            const SizedBox(width: 8),
            _ozetKutu('Bekleyen', '${_n(ozet['bekleyen']).toInt()}', Icons.pending_actions, _mor),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            _ozetKutu('Geciken (15dk+)', '${_n(ozet['geciken']).toInt()}', Icons.warning_amber_rounded, _n(ozet['geciken']) > 0 ? _kirmizi : _yesil),
            const SizedBox(width: 8),
            _ozetKutu('En Eski', _sure(_n(ozet['en_eski_dk']).toInt()), Icons.hourglass_bottom, _n(ozet['en_eski_dk']) >= 15 ? _kirmizi : _amber),
          ]),
          const SizedBox(height: 14),
          // Öneriler
          _baslik('🤖 Öneriler'),
          for (final o in oneriler) _oneriKart(o as Map),
          if (istYuk.isNotEmpty) ...[
            const SizedBox(height: 14),
            _baslik('🍳 İstasyon Yükü (şu an bekleyen)'),
            _kutu(Column(children: [
              for (final it in istYuk) _yukBar(it as Map, istYuk),
            ])),
          ],
          if (enYavas.isNotEmpty) ...[
            const SizedBox(height: 14),
            _baslik('🐢 En Yavaş Ürünler (bugün ort.)'),
            _kutu(Column(children: [
              for (final e in enYavas) _yavasSatir(e as Map),
            ])),
          ],
          if (saatlik.isNotEmpty) ...[
            const SizedBox(height: 14),
            _baslik('📈 Saatlik Yoğunluk (bugün)'),
            _kutu(_saatlikGrafik(saatlik)),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _ozetKutu(String etiket, String deger, IconData ikon, Color renk) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(ikon, size: 16, color: renk),
            const SizedBox(width: 6),
            Expanded(child: Text(etiket, style: TextStyle(color: _sub, fontSize: 11.5))),
          ]),
          const SizedBox(height: 8),
          Text(deger, style: TextStyle(color: renk, fontSize: 22, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _oneriKart(Map o) {
    final tip = o['tip']?.toString() ?? '';
    final renk = {'darbogaz': _kirmizi, 'sure': _amber, 'tukendi': _kirmizi, 'prep': _mavi, 'ok': _yesil}[tip] ?? _mor;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: renk, width: 4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(o['ikon']?.toString() ?? '•', style: const TextStyle(fontSize: 16)),
        const SizedBox(width: 9),
        Expanded(child: Text(o['metin']?.toString() ?? '', style: TextStyle(color: _ink, fontSize: 13, height: 1.35))),
      ]),
    );
  }

  Widget _yukBar(Map it, List hepsi) {
    final adet = _n(it['adet']).toInt();
    final maks = hepsi.fold<int>(1, (m, e) => _n((e as Map)['adet']).toInt() > m ? _n(e['adet']).toInt() : m);
    final oran = (adet / maks).clamp(0.05, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        SizedBox(width: 90, child: Text(it['ad'].toString(), style: TextStyle(color: _sub2, fontSize: 12.5))),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(value: oran, minHeight: 9, backgroundColor: _card2, color: _mor),
          ),
        ),
        const SizedBox(width: 8),
        Text('$adet', style: TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _yavasSatir(Map e) {
    final dk = _n(e['dk']);
    final renk = dk >= 18 ? _kirmizi : (dk >= 12 ? _amber : _yesil);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Expanded(child: Text(e['ad'].toString(), style: TextStyle(color: _ink, fontSize: 13))),
        Text('${e['adet']}×', style: TextStyle(color: _sub, fontSize: 11.5)),
        const SizedBox(width: 10),
        Text('$dk dk', style: TextStyle(color: renk, fontSize: 13.5, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _saatlikGrafik(List saatlik) {
    final maks = saatlik.fold<int>(1, (m, e) => _n((e as Map)['adet']).toInt() > m ? _n(e['adet']).toInt() : m);
    return SizedBox(
      height: 120,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final s in saatlik)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text('${_n((s as Map)['adet']).toInt()}', style: TextStyle(color: _sub, fontSize: 10)),
              const SizedBox(height: 3),
              Container(
                height: (90 * (_n(s['adet']).toInt() / maks)).clamp(4, 90).toDouble(),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_mor, _mavi], begin: Alignment.bottomCenter, end: Alignment.topCenter),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text('${_n(s['saat']).toInt()}', style: TextStyle(color: _sub, fontSize: 10)),
            ]),
          ),
      ]),
    );
  }

  // ---- ortak ----
  Widget _bos(String metin) => RefreshIndicator(
        onRefresh: () async {
          if (_tab.index == 0) await _siparisYukle();
          if (_tab.index == 1) await _serviseYukle();
        },
        color: _mor, backgroundColor: _card,
        child: ListView(children: [
          const SizedBox(height: 150),
          Icon(Icons.restaurant_menu, size: 54, color: _line),
          const SizedBox(height: 12),
          Center(child: Text(metin, style: TextStyle(color: _sub))),
        ]),
      );

  Widget _baslik(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(t, style: TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.bold)),
      );

  Widget _kutu(Widget child) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14)),
        child: child,
      );
}

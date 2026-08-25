import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// Sesli Asistan — Randevumcepte tasarimi (acik tema, buyuk isikli orb, Ses 1/Ses 2, ozet karti).
class AsistanScreen extends StatefulWidget {
  const AsistanScreen({super.key});

  @override
  State<AsistanScreen> createState() => _AsistanScreenState();
}

class _AsistanScreenState extends State<AsistanScreen> with SingleTickerProviderStateMixin {
  final _kontrol = TextEditingController();
  final _stt = SpeechToText();
  final _tts = FlutterTts();
  late final AnimationController _anim;
  final _f = NumberFormat.decimalPattern('tr');

  bool _sttHazir = false;
  bool _dinliyor = false;
  bool _konusuyor = false;
  bool _bekliyor = false;

  int _sesIndex = 0; // 0 = Ses 1 (erkek), 1 = Ses 2 (kadin)
  List<Map> _trSesler = [];

  bool _karsilamaSesli = false; // acilistaki selam bitince otomatik dinlemeye gec
  String _selam = 'Merhaba. Size nasıl yardımcı olabilirim?';
  String? _sonSoru;
  String _sonCevap = '';
  Map? _sonKart;

  static const _bg = Color(0xFFF1F5F9);
  static const _mor1 = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);
  static const _mor2 = Color(0xFF9D5DC8);
  static const _yesil = Color(0xFF10B981);
  static const _kirmizi = Color(0xFFF43F5E);
  static const _koyu = Color(0xFF0F172A);
  static const _gri = Color(0xFF64748B);

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);
  String _tl(num v) => '₺${_f.format(v.round())}';
  String _k(num v) {
    final a = v.abs();
    if (a >= 1000000) return '₺${(v / 1000000).toStringAsFixed(2)}M';
    if (a >= 1000) return '₺${(v / 1000).toStringAsFixed(1)}K';
    return '₺${_f.format(v.round())}';
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();
    _sttBaslat();
    _ttsBaslat();
  }

  Future<void> _sttBaslat() async {
    try {
      _sttHazir = await _stt.initialize(
        onStatus: (s) { if ((s == 'done' || s == 'notListening') && mounted) setState(() => _dinliyor = false); },
        onError: (e) { if (mounted) setState(() => _dinliyor = false); },
      );
      if (mounted) setState(() {});
    } catch (_) { _sttHazir = false; }
  }

  Future<void> _ttsBaslat() async {
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(0.46);
      _tts.setStartHandler(() { if (mounted) setState(() => _konusuyor = true); });
      _tts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() => _konusuyor = false);
        // Acilis selami bitince otomatik dinlemeye gec ("sorunuzu sorabilirsiniz")
        if (_karsilamaSesli) {
          _karsilamaSesli = false;
          Future.delayed(const Duration(milliseconds: 350), () { if (mounted && !_dinliyor && !_bekliyor) _dinle(); });
        }
      });
      _tts.setCancelHandler(() { if (mounted) setState(() => _konusuyor = false); });
      final sesler = await _tts.getVoices;
      if (sesler is List) {
        _trSesler = sesler.where((v) => (v['locale'] ?? '').toString().toLowerCase().startsWith('tr')).map((v) => v as Map).toList();
        // Erkek adayini basa al (Ses 1 = erkek)
        _trSesler.sort((a, b) {
          int skor(Map v) {
            final ad = (v['name'] ?? '').toString().toLowerCase();
            if (ad.contains('male') || ad.contains('erkek') || ad.contains('-tra-') || ad.contains('-mr-')) return 0;
            if (ad.contains('fmk') || ad.contains('fem') || ad.contains('female')) return 2;
            return 1;
          }
          return skor(a).compareTo(skor(b));
        });
      }
      await _sesUygula(_sesIndex, onizleme: false);
      _karsila(); // acilista AI sesli karsilar, sonra dinlemeye gecer
    } catch (_) {}
  }

  /// Acilista AI once sesli karsilar, ardindan otomatik dinlemeye gecer.
  Future<void> _karsila() async {
    if (!mounted) return;
    final ad = context.read<AuthProvider>().ad?.split(' ').first ?? '';
    setState(() => _selam = 'Merhaba${ad.isNotEmpty ? ' $ad' : ''}. Ben restoranınızın asistanıyım, sorunuzu sorabilirsiniz.');
    _karsilamaSesli = true;
    await _seslendir(_selam);
  }

  Future<void> _sesUygula(int i, {bool onizleme = true}) async {
    try {
      // Ses 1 = kalin (erkek), Ses 2 = ince (kadin)
      await _tts.setPitch(i == 0 ? 0.72 : 1.12);
      if (_trSesler.isNotEmpty) {
        final ses = _trSesler[i == 0 ? 0 : (_trSesler.length > 1 ? 1 : 0)];
        await _tts.setVoice({'name': ses['name'].toString(), 'locale': ses['locale'].toString()});
      }
      if (onizleme) await _seslendir('Merhaba, ben restoranınızın asistanıyım.');
    } catch (_) {}
  }

  Future<void> _seslendir(String metin) async {
    try { await _tts.stop(); await _tts.speak(metin); } catch (_) {}
  }

  Future<void> _dinle() async {
    if (_konusuyor) { await _tts.stop(); setState(() => _konusuyor = false); }
    if (!_sttHazir) { await _sttBaslat(); if (!_sttHazir) { _uyar('Mikrofon kullanılamıyor, yazarak sorabilirsiniz.'); return; } }
    if (_dinliyor) { await _stt.stop(); setState(() => _dinliyor = false); return; }
    setState(() => _dinliyor = true);
    await _stt.listen(
      listenOptions: SpeechListenOptions(localeId: 'tr_TR', partialResults: true),
      onResult: (r) {
        setState(() => _sonSoru = r.recognizedWords);
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) { _dinliyor = false; _gonder(r.recognizedWords); }
      },
    );
  }

  Future<void> _gonder([String? metin]) async {
    final soru = (metin ?? _kontrol.text).trim();
    if (soru.isEmpty || _bekliyor) return;
    _kontrol.clear();
    setState(() { _sonSoru = soru; _bekliyor = true; });
    try {
      final auth = context.read<AuthProvider>();
      final res = await Api.asistanSor(auth.token!, soru);
      if (!mounted) return;
      setState(() {
        _sonCevap = res['cevap']?.toString() ?? 'Bunu şu an yanıtlayamadım.';
        _sonKart = res['kart'] as Map?;
        _bekliyor = false;
      });
      if (res['seslendir'] == true) _seslendir(_sonCevap);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) setState(() { _sonCevap = 'Bağlantı hatası, tekrar dener misiniz?'; _sonKart = null; _bekliyor = false; });
    }
  }

  Future<void> _derinAnaliz() async {
    if (_bekliyor) return;
    setState(() { _sonSoru = 'İşletmeyi analiz et'; _bekliyor = true; });
    try {
      final auth = context.read<AuthProvider>();
      final res = await Api.aiAnaliz(auth.token!, kapsam: 'ozet', period: 'haftalik');
      final yorumlar = (res['yorumlar'] as List?) ?? [];
      if (!mounted) return;
      setState(() {
        _sonCevap = yorumlar.isEmpty ? 'Şu an ek analiz üretemedim.' : yorumlar.map((y) => '• $y').join('\n');
        _sonKart = null;
        _bekliyor = false;
      });
    } catch (_) {
      if (mounted) setState(() { _sonCevap = 'Analiz alınamadı.'; _bekliyor = false; });
    }
  }

  void _uyar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  void dispose() {
    _anim.dispose();
    _kontrol.dispose();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  String get _durum {
    if (_dinliyor) return 'Dinliyorum…';
    if (_bekliyor) return 'Düşünüyorum…';
    if (_sonCevap.isEmpty) return _selam; // acilis selami (konusurken de gorunur)
    if (_konusuyor) return 'Yanıtlıyorum…';
    return _sonSoru ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: _koyu),
        title: const Text('Sesli Asistan', style: TextStyle(color: _koyu, fontSize: 19, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(children: [
            const SizedBox(height: 12),
            _orb(),
            const SizedBox(height: 22),
            Text(_durum, textAlign: TextAlign.center,
                style: TextStyle(color: _sonCevap.isEmpty && !_dinliyor ? _gri : _koyu, fontSize: 17, fontWeight: FontWeight.w500, height: 1.35)),
            const SizedBox(height: 22),
            _sesKart(),
            const SizedBox(height: 14),
            if (_sonCevap.isNotEmpty) _cevapKart(),
            if (_sonCevap.isEmpty) _oneriler(),
            const SizedBox(height: 10),
            _yaziAlani(),
          ]),
        ),
      ),
    );
  }

  // -------- ORB --------
  Widget _orb() {
    return GestureDetector(
      onTap: _dinle,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, child) {
          final t = _anim.value; // 0..1
          final aktif = _dinliyor || _konusuyor;
          final scale = aktif ? (1.0 + 0.05 * math.sin(t * 2 * math.pi * 3)) : 1.0;
          return Transform.scale(
            scale: scale,
            child: Container(
              width: 210, height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  transform: GradientRotation(t * 2 * math.pi),
                  colors: const [Color(0xFF22D3EE), Color(0xFF3B82F6), Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF22D3EE)],
                ),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF8B5CF6).withValues(alpha: aktif ? 0.55 : 0.35), blurRadius: 45, spreadRadius: aktif ? 8 : 2),
                  BoxShadow(color: const Color(0xFF22D3EE).withValues(alpha: 0.25), blurRadius: 30, spreadRadius: 1),
                ],
              ),
              child: Center(
                child: Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [Colors.white, Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0.0)], stops: const [0.0, 0.55, 1.0]),
                  ),
                  child: aktif ? Icon(_dinliyor ? Icons.mic : Icons.graphic_eq, color: _mor1.withValues(alpha: 0.55), size: 30) : null,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // -------- SES SECICI (Ses 1 / Ses 2) --------
  Widget _sesKart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.record_voice_over, size: 18, color: _mor1),
          SizedBox(width: 8),
          Text('Asistan sesi', style: TextStyle(color: _koyu, fontSize: 15, fontWeight: FontWeight.bold)),
          SizedBox(width: 6),
          Text('(dokunup dinle)', style: TextStyle(color: _gri, fontSize: 12)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _sesButon(0, 'Ses 1')),
          const SizedBox(width: 12),
          Expanded(child: _sesButon(1, 'Ses 2')),
        ]),
      ]),
    );
  }

  Widget _sesButon(int i, String etiket) {
    final secili = _sesIndex == i;
    return GestureDetector(
      onTap: () { setState(() => _sesIndex = i); _sesUygula(i, onizleme: true); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: secili ? const LinearGradient(colors: [_mor1, _mavi]) : null,
          color: secili ? null : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (secili) const Icon(Icons.check, color: Colors.white, size: 17),
          if (secili) const SizedBox(width: 6),
          Text(etiket, style: TextStyle(color: secili ? Colors.white : _gri, fontSize: 15, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  // -------- ONERI CIPLERI (cevap yokken) --------
  Widget _oneriler() {
    const list = ['🔍 Derin analiz', 'Bu hafta ciro', 'En çok kim sattı', 'En çok satan ürün', 'Kaç masa dolu', 'Food-cost', 'Kayıp radarı'];
    return Wrap(
      spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
      children: [
        for (final o in list)
          ActionChip(
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            label: Text(o, style: const TextStyle(color: _mor1, fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: _bekliyor ? null : () => o.contains('Derin analiz') ? _derinAnaliz() : _gonder(o),
          ),
      ],
    );
  }

  // -------- CEVAP KARTI (patron asistan gorselligi) --------
  Widget _cevapKart() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10)]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi]), borderRadius: BorderRadius.circular(9)), child: const Text('✨', style: TextStyle(fontSize: 13))),
          const SizedBox(width: 8),
          const Text('Yanıt', style: TextStyle(color: _koyu, fontSize: 14, fontWeight: FontWeight.bold)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.volume_up, size: 18, color: _mor1), onPressed: () => _seslendir(_sonCevap)),
        ]),
        Text(_sonCevap, style: const TextStyle(color: _koyu, fontSize: 15, height: 1.4)),
        if (_sonKart != null) ...[const SizedBox(height: 12), _kartWidget(_sonKart!)],
      ]),
    );
  }

  Widget _kartWidget(Map k) {
    final tip = k['tip']?.toString() ?? '';
    switch (tip) {
      case 'ciro':
        return _statSatir([_kv('Ciro', _tl(_n(k['ciro'])), _yesil), _kv('Adisyon', '${_n(k['adet']).toInt()}', _mavi)]);
      case 'masa':
        return _statSatir([_kv('Dolu', '${_n(k['acik']).toInt()}/${_n(k['toplam']).toInt()}', _mavi), _kv('Bekleyen', _tl(_n(k['tutar'])), _mor2)]);
      case 'paket':
        return _statSatir([_kv('Aktif Sipariş', '${_n(k['acik']).toInt()}', _mor2)]);
      case 'iptal':
        return _statSatir([_kv('İptal', '${_n(k['adet']).toInt()}', _kirmizi), _kv('Tutar', _tl(_n(k['tutar'])), _kirmizi)]);
      case 'musteri':
        return _statSatir([_kv('Misafir', '${_n(k['misafir']).toInt()}', _mavi), _kv('Adisyon', '${_n(k['folyo']).toInt()}', _mor2)]);
      case 'maliyet':
        final y = _n(k['yuzde']).toInt();
        final renk = y >= 38 ? _kirmizi : (y >= 30 ? const Color(0xFFF59E0B) : _yesil);
        return _statSatir([_kv('Food-Cost', '%$y', renk), _kv('Maliyet', _k(_n(k['maliyet'])), renk), _kv('Ciro', _k(_n(k['ciro'])), _mavi)]);
      case 'ozet':
        return _statSatir([_kv('Ciro', _k(_n(k['ciro'])), _yesil), _kv('Adisyon', '${_n(k['folyo']).toInt()}', _mavi), _kv('Açık', '${_n(k['acik']).toInt()}', _mor2)]);
      case 'kayip':
        return Column(children: [
          _satirKV('İskonto', _tl(_n(k['iskonto']))),
          _satirKV('İkram', _tl(_n(k['ikram']))),
          _satirKV('Silinen Ürün', _tl(_n(k['silinen']))),
          _satirKV('İptal Adisyon', _tl(_n(k['iptal']))),
          _satirKV('Fire', _tl(_n(k['fire']))),
          const Divider(color: Color(0xFFE2E8F0), height: 16),
          _satirKV('Toplam Sızıntı', _tl(_n(k['toplam'])), vurgu: true),
        ]);
      case 'garson':
        final s = (k['satirlar'] as List?) ?? [];
        return Column(children: [for (int i = 0; i < s.length && i < 6; i++) _siraSatir(i + 1, (s[i] as Map)['ad']?.toString() ?? '-', '${_n(s[i]['adet']).toInt()} adisyon', _k(_n(s[i]['ciro'])))]);
      case 'urun':
        final s = (k['satirlar'] as List?) ?? [];
        return Column(children: [for (int i = 0; i < s.length && i < 6; i++) _siraSatir(i + 1, (s[i] as Map)['urun_adi']?.toString() ?? '-', '${_n(s[i]['adet']).toInt()} adet', _k(_n(s[i]['ciro'])))]);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _statSatir(List<Widget> kvs) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Row(children: [for (final w in kvs) Expanded(child: w)]),
      );

  Widget _kv(String etiket, String deger, Color renk) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FittedBox(child: Text(deger, style: TextStyle(color: renk, fontSize: 19, fontWeight: FontWeight.bold))),
        const SizedBox(height: 2),
        Text(etiket, style: const TextStyle(color: _gri, fontSize: 11)),
      ]);

  Widget _satirKV(String sol, String sag, {bool vurgu = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(sol, style: TextStyle(color: vurgu ? _koyu : _gri, fontSize: 13, fontWeight: vurgu ? FontWeight.bold : FontWeight.normal)),
          Text(sag, style: TextStyle(color: vurgu ? _kirmizi : _koyu, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      );

  Widget _siraSatir(int sira, String ad, String alt, String sag) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Container(width: 22, height: 22, alignment: Alignment.center, decoration: BoxDecoration(color: sira == 1 ? _mor1 : const Color(0xFFEEF2FF), shape: BoxShape.circle), child: Text('$sira', style: TextStyle(color: sira == 1 ? Colors.white : _mor1, fontSize: 11, fontWeight: FontWeight.bold))),
          const SizedBox(width: 10),
          Expanded(child: Text(ad, style: const TextStyle(color: _koyu, fontSize: 13), overflow: TextOverflow.ellipsis)),
          Text(alt, style: const TextStyle(color: _gri, fontSize: 11)),
          const SizedBox(width: 10),
          Text(sag, style: const TextStyle(color: _koyu, fontSize: 13, fontWeight: FontWeight.bold)),
        ]),
      );

  // -------- YAZI ALANI --------
  Widget _yaziAlani() {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _kontrol,
          style: const TextStyle(color: _koyu),
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _gonder(),
          decoration: InputDecoration(
            hintText: 'Yazarak da sorabilirsiniz…',
            hintStyle: const TextStyle(color: _gri),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            suffixIcon: IconButton(icon: const Icon(Icons.send, color: _mor1, size: 20), onPressed: () => _gonder()),
          ),
        ),
      ),
    ]);
  }
}

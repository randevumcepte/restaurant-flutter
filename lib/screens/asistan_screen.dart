import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// SESLI ASISTAN — Randevumcepte sesli_randevu.dart tasariminin birebir portu.
/// Buyuk Siri kuresi + surekli konusma dongusu (_basla): karsilar -> dinler ->
/// cevap -> tekrar dinler -> ses yoksa/tesekkurde nazikce kapatir. Restoran Q&A.
class AsistanScreen extends StatefulWidget {
  const AsistanScreen({super.key});

  @override
  State<AsistanScreen> createState() => _AsistanScreenState();
}

class _AsistanScreenState extends State<AsistanScreen> with SingleTickerProviderStateMixin {
  static const Color _mor = Color(0xFF8B5CF6);
  static const List<String> _aylar = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool _hazir = false;
  bool _dinliyor = false;
  bool _mesgul = false;
  bool _iptal = false;

  late final AnimationController _pulse;
  double _sesN = 0;

  String? _isCevap;
  Map<String, dynamic>? _isKart;
  String _sistemMesaji = 'Başlamak için dokun';

  // Proaktif tespitler (açılışta patronun göremediği kaçak/risk/fırsat)
  List _tespitler = [];
  String? _tespitSelam;
  bool _otoBasladi = false;  // açılışta otomatik konuşmayı bir kez başlat

  Completer<String>? _dinleC;
  String _dinleSon = '';
  bool _konusmaBasladi = false;
  bool _dinlemeBekle = false;

  // TTS ses secimi
  List<Map<String, String>> _sesler = [];
  List<Map<String, String>> _sunulan = [];
  String? _seciliSes;
  static const String _ses1Name = 'tr-tr-x-tmc-network'; // erkek, akici (varsayilan)
  static const String _ses2Name = 'tr-tr-x-tmb-network'; // alternatif erkek

  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
    _hazirla();
    _tespitYukle();
  }

  Future<void> _tespitYukle() async {
    try {
      final auth = context.read<AuthProvider>();
      final res = await Api.asistanTespitler(auth.token!);
      if (mounted && res['ok'] == 1) {
        setState(() {
          _tespitler = (res['tespitler'] as List?) ?? [];
          _tespitSelam = res['selam']?.toString();
        });
      }
    } catch (_) {} finally {
      _otoBaslat();
    }
  }

  // Ekran acilir acilmaz asistan KENDISI konussun (dokunmaya gerek yok).
  // TTS hazir olur olmaz tek sefer baslatir (tespitler arkada yuklenmeye devam eder).
  void _otoBaslat() {
    if (_otoBasladi || !_hazir || !mounted || _mesgul) return;
    _otoBasladi = true;
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _basla(); });
  }

  Future<void> _hazirla() async {
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (_dinlemeBekle && !_konusmaBasladi) return;
          _dinlemeTamamla();
        }
      },
      onError: (e) => _dinlemeTamamla(),
    );
    await _sesAyarla();
    if (mounted) _ss(() => _hazir = ok);
    _otoBaslat(); // hazir olunca (tespitler de bittiyse) kendiliginden konus
  }

  Future<void> _sesAyarla() async {
    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.contains('com.google.android.tts')) {
        await _tts.setEngine('com.google.android.tts');
      }
    } catch (_) {}
    await _tts.setLanguage('tr-TR');
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        final trAll = voices.map((v) => Map<String, dynamic>.from(v as Map))
            .where((v) => (v['locale'] ?? '').toString().toLowerCase().startsWith('tr')).toList();
        // Erkek adaylarini (tmc/tmb/-erkek) one al
        int skor(Map v) {
          final ad = (v['name'] ?? '').toString().toLowerCase();
          if (ad.contains('tmc') || ad.contains('tmb') || ad.contains('male') || ad.contains('erkek')) return 0;
          if (ad.contains('fmk') || ad.contains('fem') || ad.contains('efu')) return 2;
          return 1;
        }
        trAll.sort((a, b) => skor(a).compareTo(skor(b)));
        _sesler = trAll.map((v) => {'name': v['name'].toString(), 'locale': v['locale'].toString()}).toList();
      }
    } catch (_) {}
    await _tts.setSpeechRate(0.40); // daha yavas + daha vurgulu okusun (onceki 0.46 hizliydi)
    await _tts.setPitch(1.06);
    await _tts.awaitSpeakCompletion(true);

    // Sunulacak sesler: isimle sabit 2 erkek secenek; yoksa siraya gore
    _sunulan = [];
    final s1 = _sesBul(_ses1Name) ?? (_sesler.isNotEmpty ? _sesler[0] : null);
    final s2 = _sesBul(_ses2Name) ?? (_sesler.length > 1 ? _sesler[1] : null);
    if (s1 != null) _sunulan.add({'etiket': 'Ses 1', 'name': s1['name']!, 'locale': s1['locale']!});
    if (s2 != null && (s1 == null || s2['name'] != s1['name'])) _sunulan.add({'etiket': 'Ses 2', 'name': s2['name']!, 'locale': s2['locale']!});

    final prefs = await SharedPreferences.getInstance();
    final kayitli = prefs.getString('asistan_ses');
    String? hedef;
    if (kayitli != null && _sunulan.any((s) => s['name'] == kayitli)) {
      hedef = kayitli;
    } else if (_sunulan.isNotEmpty) {
      hedef = _sunulan.first['name'];
    }
    if (hedef != null) await _sesUygula(hedef, kaydet: false);
    if (mounted) _ss(() {});
  }

  Map<String, String>? _sesBul(String name) {
    for (final s in _sesler) {
      if (s['name'] == name) return s;
    }
    return null;
  }

  Future<void> _sesUygula(String name, {bool kaydet = true}) async {
    final ses = _sesler.firstWhere((s) => s['name'] == name, orElse: () => {'name': name, 'locale': 'tr-TR'});
    try { await _tts.setVoice({'name': ses['name']!, 'locale': ses['locale']!}); } catch (_) {}
    _seciliSes = name;
    if (kaydet) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('asistan_ses', name);
    }
    if (mounted) _ss(() {});
  }

  Future<void> _sesDene(String name) async {
    await _sesUygula(name);
    await _konus('Merhaba, ben restoranınızın asistanıyım. Sesim böyle.');
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _pulse.dispose();
    super.dispose();
  }

  void _ss(VoidCallback fn) { if (mounted) setState(fn); }

  // ---------------- SES: konus / dinle ----------------
  int _konusToken = 0;
  Future<void> _konus(String metin) async {
    final int tok = ++_konusToken;
    _ss(() => _sistemMesaji = metin);
    try { HapticFeedback.lightImpact(); } catch (_) {}
    try {
      await _tts.stop();
      if (tok != _konusToken) return;
      await _tts.speak(_seslendirmeMetni(metin));
    } catch (_) {}
  }

  String _trKucuk(String s) => s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase();

  // TTS icin metni KONUSMAYA uygun hale getir: sembolleri kelimeye cevir,
  // binlik noktayi kaldir (106.942 -> dogru okunsun), TL->lira, %->yuzde.
  String _seslendirmeMetni(String s) {
    var t = s;
    // Binlik ayirici nokta -> kaldir (coklu gruplar icin iki gecis)
    t = t.replaceAllMapped(RegExp(r'(\d)\.(?=\d{3}\b)'), (m) => m.group(1)!);
    t = t.replaceAllMapped(RegExp(r'(\d)\.(?=\d{3}\b)'), (m) => m.group(1)!);
    // Semboller -> dogal soyleyis
    t = t.replaceAll('→', ' ');
    t = t.replaceAll('%', ' yüzde ');
    t = t.replaceAll('/', ', ');
    t = t.replaceAll('&', ' ve ');
    t = t.replaceAllMapped(RegExp(r'TL\b'), (m) => ' lira');
    // ALL-CAPS kisaltmalari Baslik yap (TTS harf harf hecelemesin)
    t = t.replaceAllMapped(RegExp(r'[A-ZÇĞİÖŞÜ]{2,}'), (m) {
      final w = m.group(0)!;
      return w.substring(0, 1) + _trKucuk(w.substring(1));
    });
    return t.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Tek cumle dinler; oturum kapaninca duyulan metni doner.
  Future<String> _dinle({int pause = 2, int listen = 15}) async {
    if (!_hazir) return '';
    _dinleC = Completer<String>();
    _dinleSon = '';
    _konusmaBasladi = false;
    _dinlemeBekle = true;
    _sesN = 0;
    _ss(() => _dinliyor = true);
    try { HapticFeedback.mediumImpact(); } catch (_) {}

    Timer? sessizlikT;
    Timer? watchdogT;
    final int sessizlikMs = pause.clamp(1, 5) * 1000 + 400;

    void kapat() {
      sessizlikT?.cancel();
      watchdogT?.cancel();
      _dinlemeBekle = false;
      try { _speech.stop(); } catch (_) {}
      _dinlemeTamamla();
    }

    void sessizligiZamanla() {
      sessizlikT?.cancel();
      sessizlikT = Timer(Duration(milliseconds: sessizlikMs), () { if (_konusmaBasladi) kapat(); });
    }

    watchdogT = Timer(Duration(seconds: listen + 3), kapat);

    try {
      await _speech.listen(
        onResult: (r) {
          final t = r.recognizedWords.trim();
          if (t.isNotEmpty) {
            _dinleSon = t;
            _konusmaBasladi = true;
            _ss(() {});
            if (r.finalResult) { kapat(); return; }
            sessizligiZamanla();
          }
        },
        // ignore: deprecated_member_use
        listenFor: Duration(seconds: listen + 3),
        // ignore: deprecated_member_use
        pauseFor: Duration(seconds: listen + 3),
        onSoundLevelChange: (level) {
          final hedef = (level.clamp(0.0, 10.0)) / 10.0;
          _sesN = _sesN + (hedef - _sesN) * 0.4;
        },
        listenOptions: stt.SpeechListenOptions(localeId: 'tr_TR', partialResults: true, cancelOnError: true, autoPunctuation: false),
      );
    } catch (_) {
      kapat();
    }
    final sonuc = await _dinleC!.future;
    sessizlikT?.cancel();
    watchdogT.cancel();
    _dinlemeBekle = false;
    if (_iptalKomutu(sonuc)) {
      _ss(() => _iptal = true);
      await _konus('Tamam, kapatıyorum.');
      return '';
    }
    return sonuc;
  }

  void _dinlemeTamamla() {
    if (_dinleC != null && !_dinleC!.isCompleted) _dinleC!.complete(_dinleSon.trim());
    _sesN = 0;
    if (mounted) _ss(() => _dinliyor = false);
  }

  String _fold(String s) => s
      .replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase()
      .replaceAll('ı', 'i').replaceAll('ş', 's').replaceAll('ğ', 'g')
      .replaceAll('ü', 'u').replaceAll('ö', 'o').replaceAll('ç', 'c').trim();

  bool _iptalKomutu(String s) {
    final c = _fold(s);
    return c == 'iptal' || c == 'kapat' || c == 'dur' || c == 'vazgec' || c.contains('konusmayi kapat') || c.contains('gorusmeyi kapat');
  }

  bool _kufurMu(String metin) {
    final norm = ' ${_fold(metin)} ';
    const k = ['amk', 'aq', 'orospu', 'pic', 'siktir', 'yarrak', 'ibne', 'serefsiz', 'gerizekali', 'salak', 'aptal', 'geber', 'defol', 'oc'];
    for (final w in k) { if (norm.contains(' $w ')) return true; }
    return false;
  }

  String _kufurCevabi() => 'Sizi saygıya davet ediyorum. Böyle devam ederseniz görüşmeyi kapatmak zorunda kalacağım.';

  // AÇIK veda -> görüşmeyi kapat (teşekkür değil!)
  bool _vedaMu(String metin) {
    final c = _fold(metin);
    const v = ['gorusuruz', 'hosca kal', 'hoscakal', 'iyi gunler', 'iyi aksamlar', 'iyi geceler',
      'kendine iyi bak', 'bay bay', 'baybay', 'gorusmek uzere', 'yeter bu kadar', 'yeter artik',
      'kapatabilirsin', 'konusmayi kapat', 'konusmayi bitir', 'gorusmeyi kapat', 'simdilik bu kadar', 'kapanabilirsin'];
    return v.any((k) => c.contains(k));
  }

  // SADECE teşekkür (içinde soru/istek YOK) -> kapatma; "rica ederim" deyip dinlemeye devam
  bool _sadeceTesekkurMu(String metin) {
    final c = _fold(metin);
    const tesk = ['tesekkur', 'tesekurler', 'tesekkurler', 'sagol', 'sag ol', 'saol', 'eyvallah'];
    if (!tesk.any((k) => c.contains(k))) return false;
    if (RegExp(r'\d').hasMatch(c)) return false; // rakam -> muhtemelen soru/istek
    // Teşekkür + dolgu kelimelerini çıkar; geriye anlamlı söz kalırsa (soru) teşekkür sayma
    var kalan = c;
    for (final k in [...tesk, 'ederim', 'ederiz', 'cok', 'ya', 'be', 'abi', 'kardesim', 'canim', 'valla', 'iste', 'sana', 'size', 'her', 'sey', 'hersey', 'yardim', 'icin']) {
      kalan = kalan.replaceAll(k, ' ');
    }
    kalan = kalan.replaceAll(RegExp(r'[^a-z ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final anlamli = kalan.isEmpty ? 0 : kalan.split(' ').where((w) => w.length > 2).length;
    return anlamli == 0;
  }

  /// Saat / tarih (bedava, offline).
  String? _bilgiCevap(String metin) {
    final c = _fold(metin);
    if (c.contains('saat kac') || (c.contains('saat') && c.contains('kac'))) {
      final n = DateTime.now();
      return 'Şu an saat ${n.hour.toString().padLeft(2, '0')} ${n.minute.toString().padLeft(2, '0')}';
    }
    if (c.contains('gunlerden ne') || c.contains('bugun gun') || c.contains('tarih ne') || c.contains('hangi gun') || c.contains('ayin kaci') || c.contains('bugun ayin')) {
      final n = DateTime.now();
      const g = ['', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
      return 'Bugün ${g[n.weekday]}, ${n.day} ${_aylar[n.month]} ${n.year}';
    }
    return null;
  }

  /// Backend soruyu COZEMEDI mi? (yardim fallback / bilinmiyor -> anlamsiz soru)
  bool _anlasilmadi(Map yanit) {
    final kaynak = (yanit['kaynak'] ?? '').toString();
    final intent = (yanit['intent'] ?? '').toString();
    return kaynak == 'yardim' || kaynak == 'yardim_anahtarsiz' || intent == 'yardim' || intent == 'bilinmiyor';
  }

  // ---------------- ANA AKIS (surekli dongu) ----------------
  Future<void> _basla() async {
    if (_mesgul) {
      // Calisirken dokunulursa: durdur.
      _iptal = true;
      await _speech.stop();
      await _tts.stop();
      _dinlemeTamamla();
      _ss(() => _mesgul = false);
      return;
    }
    _ss(() { _mesgul = true; _iptal = false; });
    final auth = context.read<AuthProvider>();
    try {
      final ad = auth.ad?.split(' ').first ?? '';
      final selam = ad.isNotEmpty ? 'Merhaba $ad.' : 'Merhaba.';
      bool ilk = true;
      int bosSay = 0;
      int kufurSay = 0;
      while (!_iptal && mounted) {
        if (ilk) {
          // Acilista SADECE sicak selam; bulgular sorulunca verilir (karta da bakabilir).
          await _konus('$selam Nasıl yardımcı olabilirim?');
        }
        ilk = false;
        final c = await _dinle(pause: 2, listen: 15);
        if (_iptal) return;
        if (c.trim().isEmpty) {
          if (++bosSay >= 2) { await _konus('Başka sorunuz yoksa konuşmayı kapatıyorum. İstediğinizde tekrar dokunun.'); return; }
          await _konus('Sizi tam anlayamadım. Sorunuzu tekrarlar mısınız?');
          continue;
        }
        bosSay = 0;
        if (_kufurMu(c)) {
          kufurSay++;
          if (kufurSay >= 2) { await _konus('Bu şekilde devam edemeyeceğim. Görüşmeyi kapatıyorum.'); return; }
          await _konus(_kufurCevabi());
          continue;
        }
        // AÇIK veda -> kapat. Ama SADECE teşekkür -> "rica ederim" deyip DİNLEMEYE DEVAM (kapatma).
        if (_vedaMu(c)) { await _konus('Rica ederim, görüşmek üzere. İyi çalışmalar.'); return; }
        if (_sadeceTesekkurMu(c)) { await _konus('Rica ederim. Başka merak ettiğin bir şey varsa dinliyorum.'); continue; }
        final bilgi = _bilgiCevap(c);
        if (bilgi != null) { _ss(() { _isCevap = bilgi; _isKart = null; }); await _konus(bilgi); continue; }
        // Restoran sorusu -> backend
        _ss(() => _sistemMesaji = 'Bakıyorum…');
        try {
          final yanit = await Api.asistanSor(auth.token!, c);
          if (_anlasilmadi(yanit)) {
            const m = 'Sizi tam anlayamadım. Sorunuzu tekrarlar mısınız?';
            _ss(() { _isCevap = m; _isKart = null; });
            await _konus(m);
          } else {
            final cevap = (yanit['cevap'] ?? 'Bir sorun oldu.').toString();
            final kart = yanit['kart'] is Map ? Map<String, dynamic>.from(yanit['kart']) : null;
            _ss(() { _isCevap = cevap; _isKart = kart; });
            if (yanit['seslendir'] == true) await _konus(cevap);
          }
        } on ApiYetkiHatasi {
          auth.cikis();
          return;
        } catch (_) {
          await _konus('Bağlantı hatası oldu, tekrar dener misiniz?');
        }
        continue; // LOOP -> tekrar dinle (2. soru)
      }
    } finally {
      if (mounted) _ss(() => _mesgul = false);
    }
  }

  /// Chip/yazili soru (mikrofonsuz).
  Future<void> _yaziliSor(String c) async {
    if (_mesgul) return;
    _ss(() => _mesgul = true);
    try {
      final bilgi = _bilgiCevap(c);
      if (bilgi != null) { _ss(() { _isCevap = bilgi; _isKart = null; }); await _konus(bilgi); return; }
      _ss(() => _sistemMesaji = 'Bakıyorum…');
      final auth = context.read<AuthProvider>();
      final yanit = await Api.asistanSor(auth.token!, c);
      if (_anlasilmadi(yanit)) {
        const m = 'Sizi tam anlayamadım. Sorunuzu tekrarlar mısınız?';
        _ss(() { _isCevap = m; _isKart = null; });
        await _konus(m);
      } else {
        final cevap = (yanit['cevap'] ?? 'Bir sorun oldu.').toString();
        final kart = yanit['kart'] is Map ? Map<String, dynamic>.from(yanit['kart']) : null;
        _ss(() { _isCevap = cevap; _isKart = kart; });
        if (yanit['seslendir'] == true) await _konus(cevap);
      }
    } catch (_) {
      _ss(() => _isCevap = 'Bağlantı hatası, tekrar deneyin.');
    } finally {
      if (mounted) _ss(() => _mesgul = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F5FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6F5FB),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF221F35),
        title: const Text('Patron Asistan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        actions: [
          if (_sunulan.length >= 2)
            IconButton(
              tooltip: 'Asistan sesi',
              icon: const Icon(Icons.record_voice_over_rounded),
              color: _mor,
              onPressed: _sesSecPaneliAc,
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 22),
            _mikrofon(),
            const SizedBox(height: 30),
            if (_isCevap != null)
              _isCevapKart()
            else ...[
              if (_tespitler.isNotEmpty) _tespitBolum(),
              _baslangicKart(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mikrofon() {
    final aktif = _dinliyor;
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _basla,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(width: 200, height: 200, child: Center(child: _orb(size: 168, aktif: aktif))),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              aktif ? (_dinleSon.isNotEmpty ? _dinleSon : 'Dinliyorum…') : (_mesgul ? _sistemMesaji : 'Başlamak için dokun'),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF6B6880), fontSize: 15, height: 1.35, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orb({required double size, required bool aktif}) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (c, _) {
        final olcek = aktif ? (1.0 + _sesN * 0.16) : 1.0;
        final ph = _pulse.value * 2 * pi;
        final genlik = aktif ? _sesN * 3.0 : 0.0;
        final dx = sin(ph * 57) * genlik;
        final dy = cos(ph * 63) * genlik;
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: olcek,
            child: SizedBox(width: size, height: size, child: CustomPaint(painter: _SiriOrbPainter(_pulse.value, aktif ? _sesN : 0.0, aktif))),
          ),
        );
      },
    );
  }

  void _sesSecPaneliAc() {
    if (_sunulan.length < 2) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE0DCEC), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Row(children: const [
                Icon(Icons.record_voice_over_rounded, size: 20, color: _mor),
                SizedBox(width: 8),
                Text('Asistan sesi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF221F35))),
              ]),
              const SizedBox(height: 4),
              const Text('Dokunup dinleyin, beğendiğinizi seçin.', style: TextStyle(fontSize: 13, color: Color(0xFF8A8699))),
              const SizedBox(height: 14),
              ..._sunulan.map((s) {
                final name = s['name']!;
                final secili = name == _seciliSes;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GestureDetector(
                    onTap: () { _sesDene(name); setSheet(() {}); },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        gradient: secili ? const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)]) : null,
                        color: secili ? null : const Color(0xFFF3F1FA),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        Icon(secili ? Icons.check_circle_rounded : Icons.volume_up_rounded, size: 20, color: secili ? Colors.white : _mor),
                        const SizedBox(width: 10),
                        Text(s['etiket']!, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: secili ? Colors.white : const Color(0xFF4A4660))),
                      ]),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _isCevapKart() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEBF7)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.auto_awesome_rounded, size: 19, color: _mor),
            SizedBox(width: 8),
            Text('Asistan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF221F35))),
          ]),
          const SizedBox(height: 8),
          Text(_isCevap ?? '', style: const TextStyle(fontSize: 15, height: 1.4, color: Color(0xFF2B2740))),
          if (_isKart != null) _kart(_isKart!),
        ],
      ),
    );
  }

  // Seviye -> (renk, arkaplan, ikon)
  (Color, Color, IconData) _seviyeStil(String s) {
    switch (s) {
      case 'risk': return (const Color(0xFFDC2626), const Color(0xFFFEF2F2), Icons.warning_amber_rounded);
      case 'firsat': return (const Color(0xFF7C3AED), const Color(0xFFF5F3FF), Icons.lightbulb_outline);
      case 'uyari': return (const Color(0xFFD97706), const Color(0xFFFFFBEB), Icons.visibility_outlined);
      case 'iyi': return (const Color(0xFF059669), const Color(0xFFECFDF5), Icons.check_circle_outline);
      default: return (const Color(0xFF64748B), const Color(0xFFF8FAFC), Icons.info_outline);
    }
  }

  Widget _tespitBolum() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(children: [
            const Icon(Icons.shield_moon_outlined, size: 19, color: _mor),
            const SizedBox(width: 8),
            const Text('Senin için baktım', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF221F35))),
          ]),
        ),
        if (_tespitSelam != null && _tespitSelam!.isNotEmpty)
          Padding(padding: const EdgeInsets.only(left: 4, bottom: 10, right: 4), child: Text(_tespitSelam!, style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF6B6880)))),
        for (final tRaw in _tespitler) _tespitKart(Map<String, dynamic>.from(tRaw as Map)),
      ]),
    );
  }

  Widget _tespitKart(Map<String, dynamic> t) {
    final stil = _seviyeStil((t['seviye'] ?? '').toString());
    final kv = (t['kv'] is List) ? (t['kv'] as List) : const [];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: stil.$2, borderRadius: BorderRadius.circular(16), border: Border.all(color: stil.$1.withValues(alpha: 0.22))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(stil.$3, size: 18, color: stil.$1),
          const SizedBox(width: 8),
          Expanded(child: Text((t['baslik'] ?? '').toString(), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: stil.$1))),
        ]),
        const SizedBox(height: 6),
        Text((t['mesaj'] ?? '').toString(), style: const TextStyle(fontSize: 13.5, height: 1.42, color: Color(0xFF2B2740))),
        if (kv.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final r in kv)
              Builder(builder: (_) {
                final m = Map<String, dynamic>.from(r as Map);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9), border: Border.all(color: stil.$1.withValues(alpha: 0.2))),
                  child: Text('${m['k']}: ${m['v']}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: stil.$1)),
                );
              }),
          ]),
        ],
      ]),
    );
  }

  Widget _baslangicKart() {
    const oneri = ['Benim göremediğim ne var?', 'Nerede para kaçıyor?', 'Bu ay kâr mı ettim?', 'Fiyatı artan malzeme var mı?', 'Stokta ne bitiyor?', 'En çok hangi tedarikçiden aldım?'];
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEBF7)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: const [
            Icon(Icons.auto_awesome_rounded, size: 19, color: _mor),
            SizedBox(width: 8),
            Text('Göremediğini sor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF221F35))),
          ]),
          const SizedBox(height: 4),
          const Text('Rakamları uygulamada zaten görüyorsun. Bana asıl gözden kaçanı sor — küreye dokun ya da seç.', style: TextStyle(fontSize: 13, color: Color(0xFF8A8699))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final o in oneri)
              GestureDetector(
                onTap: _mesgul ? null : () => _yaziliSor(o),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: const Color(0xFFF3F1FA), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE6DDF4))),
                  child: Text(o, style: const TextStyle(fontSize: 12.5, color: Color(0xFF6D4AA8), fontWeight: FontWeight.w600)),
                ),
              ),
          ]),
        ],
      ),
    );
  }

  String _tl(dynamic n) {
    final d = (n is num) ? n.toDouble() : double.tryParse('$n') ?? 0;
    final tam = d.round().toString();
    final buf = StringBuffer();
    for (int i = 0; i < tam.length; i++) {
      if (i > 0 && (tam.length - i) % 3 == 0) buf.write('.');
      buf.write(tam[i]);
    }
    return '${buf.toString()}TL';
  }

  Widget _satirKV(String etiket, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: Text(etiket, style: const TextStyle(fontSize: 13.5, color: Color(0xFF6B6880)))),
        const SizedBox(width: 10),
        Text(deger, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF221F35))),
      ]),
    );
  }

  Widget _kart(Map<String, dynamic> k) {
    final tip = (k['tip'] ?? '').toString();
    final List<Widget> satirlar = [];
    if (tip == 'ciro') {
      satirlar.add(_satirKV('Ciro', _tl(k['ciro'] ?? 0)));
      satirlar.add(_satirKV('Adisyon', '${k['adet'] ?? 0}'));
    } else if (tip == 'garson') {
      for (final r in ((k['satirlar'] as List?) ?? []).take(6)) {
        final m = Map<String, dynamic>.from(r as Map);
        satirlar.add(_satirKV(m['ad'].toString(), _tl(m['ciro'] ?? 0)));
      }
    } else if (tip == 'urun') {
      for (final r in ((k['satirlar'] as List?) ?? []).take(6)) {
        final m = Map<String, dynamic>.from(r as Map);
        satirlar.add(_satirKV(m['urun_adi'].toString(), '${_n(m['adet']).toInt()} adet'));
      }
    } else if (tip == 'masa') {
      satirlar.add(_satirKV('Dolu masa', '${k['acik'] ?? 0} / ${k['toplam'] ?? 0}'));
      satirlar.add(_satirKV('Bekleyen', _tl(k['tutar'] ?? 0)));
    } else if (tip == 'paket') {
      satirlar.add(_satirKV('Aktif paket', '${k['acik'] ?? 0}'));
    } else if (tip == 'maliyet') {
      satirlar.add(_satirKV('Food-Cost', '%${k['yuzde'] ?? 0}'));
      satirlar.add(_satirKV('Maliyet', _tl(k['maliyet'] ?? 0)));
      satirlar.add(_satirKV('Ciro', _tl(k['ciro'] ?? 0)));
    } else if (tip == 'kayip') {
      satirlar.add(_satirKV('İskonto', _tl(k['iskonto'] ?? 0)));
      satirlar.add(_satirKV('İkram', _tl(k['ikram'] ?? 0)));
      satirlar.add(_satirKV('Silinen ürün', _tl(k['silinen'] ?? 0)));
      satirlar.add(_satirKV('İptal adisyon', _tl(k['iptal'] ?? 0)));
      satirlar.add(_satirKV('Fire', _tl(k['fire'] ?? 0)));
      satirlar.add(_satirKV('Toplam sızıntı', _tl(k['toplam'] ?? 0)));
    } else if (tip == 'iptal') {
      satirlar.add(_satirKV('İptal', '${k['adet'] ?? 0}'));
      satirlar.add(_satirKV('Tutar', _tl(k['tutar'] ?? 0)));
    } else if (tip == 'musteri') {
      satirlar.add(_satirKV('Misafir', '${k['misafir'] ?? 0}'));
      satirlar.add(_satirKV('Adisyon', '${k['folyo'] ?? 0}'));
    } else if (tip == 'ozet') {
      satirlar.add(_satirKV('Ciro', _tl(k['ciro'] ?? 0)));
      satirlar.add(_satirKV('Adisyon', '${k['folyo'] ?? 0}'));
      satirlar.add(_satirKV('Açık masa', '${k['acik'] ?? 0}'));
    }
    // Genel anahtar-değer kartı (finans/stok/maaş/gider/satın alma vb.)
    if (satirlar.isEmpty && k['kv'] is List) {
      for (final r in (k['kv'] as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        satirlar.add(_satirKV(m['k'].toString(), m['v'].toString()));
      }
    }
    if (satirlar.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: BoxDecoration(color: const Color(0xFFF8F7FC), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFECE7F6))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text((k['baslik'] ?? '').toString().toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _mor, letterSpacing: .3)),
          const SizedBox(height: 6),
          ...satirlar,
        ]),
      ),
    );
  }
}

/// Siri tarzi iridescent kure (Randevumcepte sesli_randevu.dart'tan birebir).
class _SiriOrbPainter extends CustomPainter {
  final double t;
  final double level;
  final bool aktif;
  _SiriOrbPainter(this.t, this.level, this.aktif);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final ang = t * 2 * pi;

    if (aktif) {
      for (int i = 0; i < 3; i++) {
        final f = 1 - i * 0.28;
        final rr = r * (0.86 + i * 0.16) + level * r * 0.40;
        final op = ((0.22 * f) * (0.4 + level)).clamp(0.0, 0.5);
        canvas.drawCircle(c, rr, Paint()..color = const Color(0xFF3AD8FF).withValues(alpha: op)..style = PaintingStyle.stroke..strokeWidth = 1.6);
      }
    }

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));

    canvas.drawCircle(c, r, Paint()..shader = const RadialGradient(colors: [Color(0xFF2A0B4A), Color(0xFF0E0022)]).createShader(Rect.fromCircle(center: c, radius: r)));

    final blobs = <List<dynamic>>[
      [const Color(0xFF00D2FF), 0.0],
      [const Color(0xFF7C4DFF), 2.1],
      [const Color(0xFFFF4DA6), 4.2],
      [const Color(0xFF00E5A8), 5.6],
    ];
    final kayma = r * (0.34 + level * 0.12);
    for (final b in blobs) {
      final col = b[0] as Color;
      final ph = b[1] as double;
      final bc = Offset(c.dx + cos(ang + ph) * kayma, c.dy + sin(ang * 1.3 + ph) * kayma);
      canvas.drawCircle(bc, r * 0.85, Paint()..blendMode = BlendMode.plus..shader = RadialGradient(colors: [col.withValues(alpha: 0.85), col.withValues(alpha: 0.0)]).createShader(Rect.fromCircle(center: bc, radius: r * 0.85)));
    }

    final cr = r * (0.42 + level * 0.18);
    canvas.drawCircle(c, cr, Paint()..blendMode = BlendMode.plus..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.0)]).createShader(Rect.fromCircle(center: c, radius: cr)));

    canvas.restore();
    canvas.drawCircle(c, r - 0.6, Paint()..color = Colors.white.withValues(alpha: 0.16)..style = PaintingStyle.stroke..strokeWidth = 1.1);
  }

  @override
  bool shouldRepaint(covariant _SiriOrbPainter old) => old.t != t || old.level != level || old.aktif != aktif;
}

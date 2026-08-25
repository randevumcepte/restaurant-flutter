import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// RESTORAN PATRON ASISTANI — Randevumcepte patron_asistan.dart'tan birebir taşındı.
/// Sohbet + dokun-konuş mikrofon + dinlerken Siri küresi + erkek TTS (tr-tr-x-tmc).
class AsistanScreen extends StatefulWidget {
  const AsistanScreen({super.key});

  @override
  State<AsistanScreen> createState() => _AsistanScreenState();
}

class _Mesaj {
  final bool soru; // true = kullanici sorusu, false = asistan cevabi
  final String metin;
  final Map<String, dynamic>? kart;
  _Mesaj(this.soru, this.metin, {this.kart});
}

class _AsistanScreenState extends State<AsistanScreen> with SingleTickerProviderStateMixin {
  static const Color _mor = Color(0xFF7C3AED);
  static const Color _mor2 = Color(0xFF9D5DC8);

  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  final TextEditingController _metinC = TextEditingController();
  final ScrollController _scrollC = ScrollController();

  final List<_Mesaj> _mesajlar = [];
  bool _hazir = false;
  bool _dinliyor = false;
  bool _mesgul = false;
  bool _sesli = true;
  bool _sttGonderildi = false;
  String _sonTaninan = '';
  String? _sonSoru;
  DateTime? _sonSoruZamani;
  late final AnimationController _donC;
  double _sesN = 0;

  @override
  void initState() {
    super.initState();
    _donC = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
    final ad = context.read<AuthProvider>().ad?.split(' ').first ?? '';
    _mesajlar.add(_Mesaj(false,
        'Merhaba${ad.isNotEmpty ? ' $ad' : ''}! Restoranınız hakkında ne öğrenmek istersiniz? Mikrofona dokunup konuşun, bitince otomatik algılarım.'));
    _hazirla();
  }

  Future<void> _hazirla() async {
    final ok = await _speech.initialize(
      onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _dinliyor = false);
          // OTO-GONDERIM: bazi STT motorlari finalResult ATMAZ. Dinleme bitince
          // taninan metin varsa ve henuz gonderilmediyse KENDILIGINDEN sor.
          if (!_sttGonderildi && _sonTaninan.trim().isNotEmpty) {
            _sttGonderildi = true;
            final t = _sonTaninan.trim();
            _sonTaninan = '';
            _sor(t);
          }
        }
      },
      onError: (e) {
        if (mounted) setState(() => _dinliyor = false);
      },
    );
    await _sesAyarla();
    if (mounted) setState(() => _hazir = ok);
  }

  /// TTS dogal/akici + ERKEK ses: Google motoru + Turkce erkek sesi (tr-tr-x-tmc).
  Future<void> _sesAyarla() async {
    try {
      final engines = await _tts.getEngines;
      if (engines is List && engines.contains('com.google.android.tts')) {
        await _tts.setEngine('com.google.android.tts');
      }
    } catch (_) {}
    try {
      await _tts.setLanguage('tr-TR');
      await _erkekSesSec();
      await _tts.setSpeechRate(0.46);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  /// Erkek Turkce sesi sec: tr-tr-x-tmc (erkek/akici). Yoksa herhangi tr sesine dus.
  Future<void> _erkekSesSec() async {
    try {
      final voices = await _tts.getVoices;
      if (voices is! List) return;
      final tr = voices
          .map((v) => Map<String, dynamic>.from(v as Map))
          .where((v) => (v['locale'] ?? '').toString().toLowerCase().startsWith('tr'))
          .toList();
      if (tr.isEmpty) return;
      Map<String, dynamic>? hedef;
      for (final v in tr) {
        if (v['name'].toString() == 'tr-tr-x-tmc-network') { hedef = v; break; }
      }
      if (hedef == null) {
        for (final v in tr) {
          if (v['name'].toString().contains('tmc')) { hedef = v; break; }
        }
      }
      hedef ??= tr.first;
      await _tts.setVoice({'name': hedef['name'].toString(), 'locale': hedef['locale'].toString()});
    } catch (_) {}
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();
    _donC.dispose();
    _metinC.dispose();
    _scrollC.dispose();
    super.dispose();
  }

  void _kaydir() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollC.hasClients) {
        _scrollC.animateTo(_scrollC.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _konus(String metin) async {
    if (!_sesli) return;
    try { await _tts.stop(); await _tts.speak(metin); } catch (_) {}
  }

  /// Mikrofon: tek cumle dinle -> metne cevir -> otomatik sor.
  Future<void> _mic() async {
    if (!_hazir) return;
    if (_dinliyor) {
      await _speech.stop();
      if (mounted) setState(() => _dinliyor = false);
      return;
    }
    await _tts.stop();
    _sttGonderildi = false;
    _sonTaninan = '';
    _sesN = 0;
    setState(() => _dinliyor = true);
    try {
      await _speech.listen(
        onSoundLevelChange: (level) {
          final hedef = (level.clamp(0.0, 10.0)) / 10.0;
          _sesN = _sesN + (hedef - _sesN) * 0.35;
          if (mounted && _dinliyor) setState(() {});
        },
        onResult: (r) {
          final t = r.recognizedWords.trim();
          if (t.isNotEmpty) {
            _metinC.text = t;
            _sonTaninan = t;
          }
          if (r.finalResult && !_sttGonderildi) {
            _sttGonderildi = true;
            _sonTaninan = '';
            _speech.stop();
            if (mounted) setState(() => _dinliyor = false);
            if (t.isNotEmpty) _sor(t);
          }
        },
        // ignore: deprecated_member_use
        listenFor: const Duration(seconds: 60),
        listenOptions: stt.SpeechListenOptions(
          localeId: 'tr_TR',
          partialResults: true,
          cancelOnError: true,
          autoPunctuation: false,
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _dinliyor = false);
    }
  }

  Future<void> _gonder() async {
    final t = _metinC.text.trim();
    if (t.isEmpty) return;
    _sttGonderildi = true;
    _speech.stop();
    if (_dinliyor && mounted) setState(() => _dinliyor = false);
    _sor(t);
  }

  Future<void> _sor(String metin) async {
    if (_mesgul) return;
    final simdi = DateTime.now();
    if (_sonSoru == metin && _sonSoruZamani != null && simdi.difference(_sonSoruZamani!).inSeconds < 6) return;
    _sonSoru = metin;
    _sonSoruZamani = simdi;
    _metinC.clear();

    // ONCE SAAT / TARIH -> yerel/ucretsiz cevap.
    final bilgi = _bilgiCevap(metin);
    if (bilgi != null) {
      setState(() {
        _mesajlar.add(_Mesaj(true, metin));
        _mesajlar.add(_Mesaj(false, bilgi));
      });
      _kaydir();
      _konus(bilgi);
      return;
    }

    setState(() {
      _mesajlar.add(_Mesaj(true, metin));
      _mesajlar.add(_Mesaj(false, '…'));
      _mesgul = true;
    });
    _kaydir();

    try {
      final auth = context.read<AuthProvider>();
      final yanit = await Api.asistanSor(auth.token!, metin);
      final cevap = (yanit['cevap'] ?? 'Bir sorun oldu.').toString();
      final kart = yanit['kart'] is Map ? Map<String, dynamic>.from(yanit['kart']) : null;
      final seslendir = yanit['seslendir'] == true;
      if (!mounted) return;
      setState(() {
        _mesajlar.removeLast();
        _mesajlar.add(_Mesaj(false, cevap, kart: kart));
        _mesgul = false;
      });
      _kaydir();
      if (seslendir) _konus(cevap);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) {
        setState(() {
          _mesajlar.removeLast();
          _mesajlar.add(_Mesaj(false, 'Bağlantı hatası, tekrar dener misiniz?'));
          _mesgul = false;
        });
      }
    }
  }

  String _fold(String s) => s
      .replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase()
      .replaceAll('ı', 'i').replaceAll('ş', 's').replaceAll('ğ', 'g')
      .replaceAll('ü', 'u').replaceAll('ö', 'o').replaceAll('ç', 'c').trim();

  /// Saat / tarih gibi bilgi sorulari (bedava). Cevap ya da null.
  String? _bilgiCevap(String metin) {
    final c = _fold(metin);
    if (c.contains('saat kac') || (c.contains('saat') && c.contains('kac'))) {
      final n = DateTime.now();
      return 'Şu an saat ${n.hour.toString().padLeft(2, '0')} ${n.minute.toString().padLeft(2, '0')}';
    }
    if (c.contains('gunlerden ne') || c.contains('hangi gun') || c.contains('bugun gun') ||
        c.contains('tarih ne') || c.contains('ayin kaci') || c.contains('bugun ayin')) {
      final n = DateTime.now();
      const g = ['', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
      const a = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
      return 'Bugün ${g[n.weekday]}, ${n.day} ${a[n.month]} ${n.year}';
    }
    return null;
  }

  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6FB),
      appBar: AppBar(
        backgroundColor: _mor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Patron Asistanı', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            tooltip: _sesli ? 'Sesli okuma açık' : 'Sesli okuma kapalı',
            icon: Icon(_sesli ? Icons.volume_up : Icons.volume_off),
            onPressed: () {
              setState(() => _sesli = !_sesli);
              if (!_sesli) _tts.stop();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollC,
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
              itemCount: _mesajlar.length,
              itemBuilder: (c, i) => _baloncuk(_mesajlar[i]),
            ),
          ),
          _dinliyor ? _dinlemePaneli() : _oneriler(),
          _altBar(),
        ],
      ),
    );
  }

  Widget _oneriler() {
    final oneri = <String>['Bugün kasa ne durumda?', 'Bu ay ciro ne kadar?', 'Bu hafta en çok kim sattı?', 'Kaç masa dolu?', 'Food-cost ne durumda?'];
    return Container(
      height: 46,
      margin: const EdgeInsets.only(bottom: 2),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: oneri.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (c, i) {
          final o = oneri[i];
          return Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _mesgul ? null : () => _sor(o),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE6DDF4)),
                  boxShadow: const [BoxShadow(color: Color(0x0F5C008E), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_awesome, size: 13, color: _mor2),
                    const SizedBox(width: 6),
                    Text(o, style: const TextStyle(fontSize: 12.5, color: Color(0xFF4A3B6B), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _altBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Color(0x12000000), blurRadius: 14, offset: Offset(0, -3))],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _micDugme(),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 50),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FB),
                  borderRadius: BorderRadius.circular(26),
                  border: Border.all(
                    color: _dinliyor ? _mor2.withValues(alpha: .55) : const Color(0xFFEAE4F5),
                    width: _dinliyor ? 1.4 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 18),
                    Expanded(
                      child: TextField(
                        controller: _metinC,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _gonder(),
                        style: const TextStyle(fontSize: 14.5, color: Color(0xFF2a2340)),
                        decoration: InputDecoration(
                          isCollapsed: true,
                          hintText: _dinliyor ? 'Dinliyorum, sizi duyuyorum…' : 'Sorunu yaz ya da mikrofona bas',
                          hintStyle: TextStyle(color: _dinliyor ? _mor2 : const Color(0xFF9B90B3), fontSize: 13.5),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _metinC,
                      builder: (c, val, _) {
                        if (val.text.trim().isEmpty) return const SizedBox(width: 8);
                        return Padding(
                          padding: const EdgeInsets.all(5),
                          child: GestureDetector(
                            onTap: _gonder,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_mor, _mor2])),
                              child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _micDugme() {
    return GestureDetector(
      onTap: _mic,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _dinliyor ? const [Color(0xFF7B2FB8), Color(0xFF9D5DC8)] : const [_mor, _mor2],
          ),
          boxShadow: [BoxShadow(color: _mor.withValues(alpha: 0.38), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        child: Icon(_dinliyor ? Icons.stop_rounded : Icons.mic_rounded, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _orb({required double size, required bool aktif}) {
    return AnimatedBuilder(
      animation: _donC,
      builder: (c, _) {
        final olcek = aktif ? (1.0 + _sesN * 0.14) : 1.0;
        return Transform.scale(
          scale: olcek,
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _SiriOrbPainter(_donC.value, aktif ? _sesN : 0.0, aktif)),
          ),
        );
      },
    );
  }

  Widget _dinlemePaneli() {
    return GestureDetector(
      onTap: _mic,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _orb(size: 92, aktif: true),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _sonTaninan.isNotEmpty ? _sonTaninan : 'Sizi dinliyorum, konuşabilirsiniz…',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6A5A8C), fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _baloncuk(_Mesaj m) {
    if (m.soru) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10, left: 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(
            color: Color(0xFFECE7F6),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomLeft: Radius.circular(14), bottomRight: Radius.circular(2)),
          ),
          child: Text(m.metin, style: const TextStyle(fontSize: 14, color: Color(0xFF3a2a5c))),
        ),
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 6, right: 30),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE7E2F0)),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(14), topRight: Radius.circular(14), bottomLeft: Radius.circular(2), bottomRight: Radius.circular(14)),
            ),
            child: Text(m.metin, style: const TextStyle(fontSize: 14.5, color: Color(0xFF2a2340))),
          ),
          if (m.kart != null) _kart(m.kart!),
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
    return '${buf.toString()} ₺';
  }

  Widget _satir(String etiket, String deger) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(etiket, style: const TextStyle(fontSize: 13, color: Color(0xFF555555)))),
          const SizedBox(width: 10),
          Text(deger, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _mor)),
        ],
      ),
    );
  }

  /// Cevap karti — restoran backend'inin kart tipleri.
  Widget _kart(Map<String, dynamic> k) {
    final tip = (k['tip'] ?? '').toString();
    final List<Widget> satirlar = [];

    if (tip == 'ciro') {
      satirlar.add(_satir('Ciro', _tl(k['ciro'] ?? 0)));
      satirlar.add(_satir('Adisyon', '${k['adet'] ?? 0}'));
    } else if (tip == 'garson') {
      for (final r in ((k['satirlar'] as List?) ?? []).take(6)) {
        final m = Map<String, dynamic>.from(r as Map);
        satirlar.add(_satir(m['ad'].toString(), _tl(m['ciro'] ?? 0)));
      }
    } else if (tip == 'urun') {
      for (final r in ((k['satirlar'] as List?) ?? []).take(6)) {
        final m = Map<String, dynamic>.from(r as Map);
        satirlar.add(_satir(m['urun_adi'].toString(), '${(m['adet'] as num?)?.round() ?? 0} adet'));
      }
    } else if (tip == 'masa') {
      satirlar.add(_satir('Dolu masa', '${k['acik'] ?? 0} / ${k['toplam'] ?? 0}'));
      satirlar.add(_satir('Bekleyen', _tl(k['tutar'] ?? 0)));
    } else if (tip == 'paket') {
      satirlar.add(_satir('Aktif paket', '${k['acik'] ?? 0}'));
    } else if (tip == 'maliyet') {
      satirlar.add(_satir('Food-Cost', '%${k['yuzde'] ?? 0}'));
      satirlar.add(_satir('Maliyet', _tl(k['maliyet'] ?? 0)));
      satirlar.add(_satir('Ciro', _tl(k['ciro'] ?? 0)));
    } else if (tip == 'kayip') {
      satirlar.add(_satir('İskonto', _tl(k['iskonto'] ?? 0)));
      satirlar.add(_satir('İkram', _tl(k['ikram'] ?? 0)));
      satirlar.add(_satir('Silinen ürün', _tl(k['silinen'] ?? 0)));
      satirlar.add(_satir('İptal adisyon', _tl(k['iptal'] ?? 0)));
      satirlar.add(_satir('Fire', _tl(k['fire'] ?? 0)));
      satirlar.add(_satir('Toplam sızıntı', _tl(k['toplam'] ?? 0)));
    } else if (tip == 'iptal') {
      satirlar.add(_satir('İptal', '${k['adet'] ?? 0}'));
      satirlar.add(_satir('Tutar', _tl(k['tutar'] ?? 0)));
    } else if (tip == 'musteri') {
      satirlar.add(_satir('Misafir', '${k['misafir'] ?? 0}'));
      satirlar.add(_satir('Adisyon', '${k['folyo'] ?? 0}'));
    } else if (tip == 'ozet') {
      satirlar.add(_satir('Ciro', _tl(k['ciro'] ?? 0)));
      satirlar.add(_satir('Adisyon', '${k['folyo'] ?? 0}'));
      satirlar.add(_satir('Açık masa', '${k['acik'] ?? 0}'));
    }

    if (satirlar.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12, right: 20),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFECE7F6)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text((k['baslik'] ?? '').toString().toUpperCase(),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _mor2, letterSpacing: .3)),
          const SizedBox(height: 6),
          ...satirlar,
        ],
      ),
    );
  }
}

/// Siri tarzi iridescent kure cizeri (Randevumcepte'den birebir).
class _SiriOrbPainter extends CustomPainter {
  final double t;
  final double level;
  final bool aktif;
  _SiriOrbPainter(this.t, this.level, this.aktif);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final ang = t * 2 * math.pi;

    if (aktif) {
      for (int i = 0; i < 3; i++) {
        final f = 1 - i * 0.28;
        final rr = r * (0.86 + i * 0.16) + level * r * 0.22;
        final op = ((0.22 * f) * (0.4 + level)).clamp(0.0, 0.5);
        canvas.drawCircle(c, rr,
            Paint()..color = const Color(0xFF3AD8FF).withValues(alpha: op)..style = PaintingStyle.stroke..strokeWidth = 1.6);
      }
    }

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r)));

    canvas.drawCircle(c, r,
        Paint()..shader = const RadialGradient(colors: [Color(0xFF2A0B4A), Color(0xFF0E0022)]).createShader(Rect.fromCircle(center: c, radius: r)));

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
      final bc = Offset(c.dx + math.cos(ang + ph) * kayma, c.dy + math.sin(ang * 1.3 + ph) * kayma);
      canvas.drawCircle(bc, r * 0.85,
          Paint()..blendMode = BlendMode.plus..shader = RadialGradient(colors: [col.withValues(alpha: 0.85), col.withValues(alpha: 0.0)]).createShader(Rect.fromCircle(center: bc, radius: r * 0.85)));
    }

    final cr = r * (0.42 + level * 0.18);
    canvas.drawCircle(c, cr,
        Paint()..blendMode = BlendMode.plus..shader = RadialGradient(colors: [Colors.white.withValues(alpha: 0.9), Colors.white.withValues(alpha: 0.0)]).createShader(Rect.fromCircle(center: c, radius: cr)));

    canvas.restore();

    canvas.drawCircle(c, r - 0.6,
        Paint()..color = Colors.white.withValues(alpha: 0.16)..style = PaintingStyle.stroke..strokeWidth = 1.1);
  }

  @override
  bool shouldRepaint(covariant _SiriOrbPainter old) => old.t != t || old.level != level || old.aktif != aktif;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../providers/auth_provider.dart';
import '../services/api.dart';

/// Patron sesli/yazili asistan — sohbet ekrani.
/// STT cihazda (bedava), cevap TTS ile seslendirilir; backend kural motoru + Haiku.
class AsistanScreen extends StatefulWidget {
  const AsistanScreen({super.key});

  @override
  State<AsistanScreen> createState() => _AsistanScreenState();
}

class _Mesaj {
  final String metin;
  final bool benim; // true = patron, false = asistan
  final bool yaziliyor;
  _Mesaj(this.metin, this.benim, {this.yaziliyor = false});
}

class _AsistanScreenState extends State<AsistanScreen> {
  final _kontrol = TextEditingController();
  final _scroll = ScrollController();
  final List<_Mesaj> _mesajlar = [];
  final _stt = SpeechToText();
  final _tts = FlutterTts();

  bool _sttHazir = false;
  bool _dinliyor = false;
  bool _bekliyor = false;

  static const _bg = Color(0xFF0B1020);
  static const _card = Color(0xFF161C2E);
  static const _mor1 = Color(0xFF7C3AED);
  static const _mavi = Color(0xFF4F46E5);

  final _oneriler = ['🔍 Derin analiz', 'Bu hafta ciro', 'En çok kim sattı', 'En çok satan ürün', 'Kaç masa dolu', 'Food-cost ne durumda', 'Kayıp radarı'];

  @override
  void initState() {
    super.initState();
    _sttBaslat();
    _ttsBaslat();
    _mesajlar.add(_Mesaj('Merhaba, restoranınızın asistanıyım. Ciro, satış, personel, masa, food-cost, kayıp ya da genel analiz için sesli veya yazılı sorabilirsiniz.', false));
    WidgetsBinding.instance.addPostFrameCallback((_) => _proaktif());
  }

  /// Acilista sessiz proaktif ozet (kural motoru, bedava, seslendirmeden).
  Future<void> _proaktif() async {
    try {
      final auth = context.read<AuthProvider>();
      final res = await Api.asistanSor(auth.token!, 'bu hafta nasıl gidiyor');
      if (!mounted) return;
      final c = res['cevap']?.toString();
      if (c != null && c.isNotEmpty) {
        setState(() => _mesajlar.add(_Mesaj(c, false)));
        _kaydir();
      }
    } catch (_) {}
  }

  /// Derin analiz (LLM/kural) -> sonucu sohbete asistan balonu olarak basar.
  Future<void> _derinAnaliz() async {
    if (_bekliyor) return;
    setState(() {
      _mesajlar.add(_Mesaj('İşletmeyi derinlemesine analiz et', true));
      _mesajlar.add(_Mesaj('', false, yaziliyor: true));
      _bekliyor = true;
    });
    _kaydir();
    try {
      final auth = context.read<AuthProvider>();
      final res = await Api.aiAnaliz(auth.token!, kapsam: 'ozet', period: 'haftalik');
      final yorumlar = (res['yorumlar'] as List?) ?? [];
      final metin = yorumlar.isEmpty ? 'Şu an ek analiz üretemedim.' : yorumlar.map((y) => '• $y').join('\n\n');
      if (!mounted) return;
      setState(() {
        _mesajlar.removeWhere((m) => m.yaziliyor);
        _mesajlar.add(_Mesaj(metin, false));
        _bekliyor = false;
      });
      _kaydir();
    } catch (_) {
      if (mounted) {
        setState(() {
          _mesajlar.removeWhere((m) => m.yaziliyor);
          _mesajlar.add(_Mesaj('Analiz alınamadı, tekrar deneyin.', false));
          _bekliyor = false;
        });
      }
    }
  }

  Future<void> _sttBaslat() async {
    try {
      _sttHazir = await _stt.initialize(onStatus: (s) {
        if (s == 'done' || s == 'notListening') {
          if (mounted) setState(() => _dinliyor = false);
        }
      }, onError: (e) {
        if (mounted) setState(() => _dinliyor = false);
      });
      if (mounted) setState(() {});
    } catch (_) {
      _sttHazir = false;
    }
  }

  Future<void> _ttsBaslat() async {
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setSpeechRate(0.46);
      await _tts.setPitch(0.72); // belirgin kalin ton -> erkek tinisi (cihazda erkek ses yoksa da)
      final sesler = await _tts.getVoices;
      if (sesler is List) {
        final tr = sesler.where((v) => (v['locale'] ?? '').toString().toLowerCase().startsWith('tr')).toList();
        // 1) Gercek erkek ses adayi
        Map? sec;
        for (final v in tr) {
          final ad = (v['name'] ?? '').toString().toLowerCase();
          if (ad.contains('male') || ad.contains('erkek') || ad.contains('-tra-') || ad.contains('-mr-')) { sec = v as Map; break; }
        }
        // 2) Yoksa kadin-belirtili olmayan ilk ses
        sec ??= tr.cast<Map?>().firstWhere((v) {
          final ad = (v?['name'] ?? '').toString().toLowerCase();
          return !(ad.contains('fmk') || ad.contains('fem') || ad.contains('female') || ad.contains('woman'));
        }, orElse: () => null);
        if (sec != null) {
          await _tts.setVoice({'name': sec['name'].toString(), 'locale': sec['locale'].toString()});
        }
      }
    } catch (_) {}
  }

  Future<void> _seslendir(String metin) async {
    try {
      await _tts.stop();
      await _tts.speak(metin);
    } catch (_) {}
  }

  Future<void> _dinle() async {
    if (!_sttHazir) {
      await _sttBaslat();
      if (!_sttHazir) {
        _uyar('Mikrofon kullanılamıyor. Yazarak sorabilirsiniz.');
        return;
      }
    }
    if (_dinliyor) {
      await _stt.stop();
      setState(() => _dinliyor = false);
      return;
    }
    await _tts.stop();
    setState(() => _dinliyor = true);
    await _stt.listen(
      listenOptions: SpeechListenOptions(localeId: 'tr_TR', partialResults: true),
      onResult: (r) {
        setState(() => _kontrol.text = r.recognizedWords);
        if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
          _dinliyor = false;
          _gonder();
        }
      },
    );
  }

  Future<void> _gonder([String? metin]) async {
    final soru = (metin ?? _kontrol.text).trim();
    if (soru.isEmpty || _bekliyor) return;
    _kontrol.clear();
    setState(() {
      _mesajlar.add(_Mesaj(soru, true));
      _mesajlar.add(_Mesaj('', false, yaziliyor: true));
      _bekliyor = true;
    });
    _kaydir();
    try {
      final auth = context.read<AuthProvider>();
      final res = await Api.asistanSor(auth.token!, soru);
      if (!mounted) return;
      final cevap = res['cevap']?.toString() ?? 'Bunu şu an yanıtlayamadım.';
      final seslendir = res['seslendir'] == true;
      setState(() {
        _mesajlar.removeWhere((m) => m.yaziliyor);
        _mesajlar.add(_Mesaj(cevap, false));
        _bekliyor = false;
      });
      _kaydir();
      if (seslendir) _seslendir(cevap);
    } on ApiYetkiHatasi {
      if (mounted) context.read<AuthProvider>().cikis();
    } catch (_) {
      if (mounted) {
        setState(() {
          _mesajlar.removeWhere((m) => m.yaziliyor);
          _mesajlar.add(_Mesaj('Bağlantı hatası, tekrar dener misiniz?', false));
          _bekliyor = false;
        });
      }
    }
  }

  void _kaydir() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent + 120, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _uyar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: _card));

  @override
  void dispose() {
    _kontrol.dispose();
    _scroll.dispose();
    _tts.stop();
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_mor1, _mavi]), borderRadius: BorderRadius.circular(10)),
            child: const Text('✨', style: TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('AI Asistan', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text('Sesli veya yazılı sorun', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ]),
        ]),
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(14),
            itemCount: _mesajlar.length,
            itemBuilder: (context, i) => _balon(_mesajlar[i]),
          ),
        ),
        // Oneri cipleri
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final o in _oneriler)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
                    backgroundColor: _card,
                    side: const BorderSide(color: Color(0xFF2D3752)),
                    label: Text(o, style: const TextStyle(color: Color(0xFFC4B5FD), fontSize: 12)),
                    onPressed: _bekliyor ? null : () => o.contains('Derin analiz') ? _derinAnaliz() : _gonder(o),
                  ),
                ),
            ],
          ),
        ),
        _girisAlani(),
      ]),
    );
  }

  Widget _balon(_Mesaj m) {
    if (m.yaziliyor) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
          child: const Text('...', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      );
    }
    return Align(
      alignment: m.benim ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          gradient: m.benim ? const LinearGradient(colors: [_mor1, _mavi]) : null,
          color: m.benim ? null : _card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(m.benim ? 16 : 4), bottomRight: Radius.circular(m.benim ? 4 : 16),
          ),
        ),
        child: Text(m.metin, style: TextStyle(color: m.benim ? Colors.white : const Color(0xFFE2E8F0), fontSize: 14, height: 1.35)),
      ),
    );
  }

  Widget _girisAlani() {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + MediaQuery.of(context).padding.bottom),
      color: _bg,
      child: Row(children: [
        Expanded(
          child: TextField(
            controller: _kontrol,
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _gonder(),
            decoration: InputDecoration(
              hintText: _dinliyor ? 'Dinliyorum…' : 'Sorunuzu yazın…',
              hintStyle: const TextStyle(color: Color(0xFF64748B)),
              filled: true,
              fillColor: _card,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Mikrofon
        GestureDetector(
          onTap: _dinle,
          child: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: _dinliyor ? const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFEF4444)]) : const LinearGradient(colors: [_mor1, _mavi]),
              shape: BoxShape.circle,
            ),
            child: Icon(_dinliyor ? Icons.stop : Icons.mic, color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        // Gonder
        GestureDetector(
          onTap: () => _gonder(),
          child: Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(color: _card, shape: BoxShape.circle),
            child: const Icon(Icons.send, color: Color(0xFFC4B5FD), size: 20),
          ),
        ),
      ]),
    );
  }
}

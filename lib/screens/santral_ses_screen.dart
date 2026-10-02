import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/tema_provider.dart';
import '../services/santral_api.dart';
import '../ui/masaustu_kit.dart';

/// AI Santral — Ses (Google TTS ses seçimi + deneme). Native.
class SantralSesScreen extends StatefulWidget {
  const SantralSesScreen({super.key});
  @override
  State<SantralSesScreen> createState() => _SantralSesScreenState();
}

class _SantralSesScreenState extends State<SantralSesScreen> {
  final _p = AudioPlayer();
  final _metin = TextEditingController(
      text: 'Siparişinizi ilettim, en kısa sürede hazırlayıp göndereceğiz. Afiyet olsun, iyi günler.');

  // tr-TR Google sesleri (erkek/kadın). Uretimde kullanilan: tr-TR-Wavenet-E (erkek).
  static const _sesler = <String, String>{
    'tr-TR-Wavenet-E': 'Wavenet E — Erkek (üretim)',
    'tr-TR-Wavenet-B': 'Wavenet B — Erkek',
    'tr-TR-Wavenet-A': 'Wavenet A — Kadın',
    'tr-TR-Wavenet-C': 'Wavenet C — Kadın',
    'tr-TR-Wavenet-D': 'Wavenet D — Kadın',
    'tr-TR-Standard-E': 'Standard E — Erkek',
    'tr-TR-Standard-B': 'Standard B — Erkek',
    'tr-TR-Standard-A': 'Standard A — Kadın',
  };

  String _voice = 'tr-TR-Wavenet-E';
  double _rate = 1.0;
  bool _telefon = true;
  bool _calisiyor = false;
  String? _hata;

  @override
  void dispose() { _p.dispose(); _metin.dispose(); super.dispose(); }

  Future<void> _dene() async {
    setState(() { _calisiyor = true; _hata = null; });
    try {
      final r = await SantralApi.sesDene(voice: _voice, metin: _metin.text.trim(), rate: _rate, telefon: _telefon);
      if (r['ok'] == 1 && r['audio'] != null) {
        final bytes = base64Decode('${r['audio']}');
        await _p.play(BytesSource(bytes));
      } else {
        _hata = '${r['hata'] ?? 'ses üretilemedi'}';
      }
    } catch (e) {
      _hata = '$e';
    }
    if (mounted) setState(() => _calisiyor = false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Santral — Ses',
      altBaslik: 'AI telefon sesini seç ve dene (Google TTS)',
      ikon: Icons.graphic_eq,
      govde: ListView(padding: const EdgeInsets.all(16), children: [
        MKart(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const MBolumBaslik('Ses Seçimi', renk: Color(0xFF7C3AED)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(8), border: Border.all(color: t.line)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _voice,
                isExpanded: true,
                dropdownColor: t.card,
                style: TextStyle(color: t.ink, fontSize: 13.5),
                items: _sesler.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                onChanged: (v) { if (v != null) setState(() => _voice = v); },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Deneme metni', style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextField(
            controller: _metin,
            maxLines: 3,
            style: TextStyle(color: t.ink, fontSize: 13.5),
            decoration: InputDecoration(
              isDense: true, filled: true, fillColor: t.card2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF7C3AED))),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Text('Hız: ${_rate.toStringAsFixed(2)}x', style: TextStyle(color: t.sub2, fontSize: 13)),
            Expanded(
              child: Slider(
                value: _rate, min: 0.5, max: 1.5, divisions: 20,
                activeColor: const Color(0xFF7C3AED), inactiveColor: t.line,
                label: '${_rate.toStringAsFixed(2)}x',
                onChanged: (v) => setState(() => _rate = v),
              ),
            ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _telefon,
            activeThumbColor: const Color(0xFF7C3AED),
            title: Text('Telefon kalitesi (8 kHz)', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('Hattaki gerçek ses kalitesini birebir dinle (dar bant). Kapalıyken tam kalite.', style: TextStyle(color: t.sub, fontSize: 12)),
            onChanged: (v) => setState(() => _telefon = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _calisiyor ? null : _dene,
              icon: _calisiyor
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.play_arrow),
              label: Text(_calisiyor ? 'Üretiliyor...' : 'Sesi Dene'),
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF7C3AED), padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
          if (_hata != null) Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_hata!, style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 13)),
          ),
        ])),
        const SizedBox(height: 12),
        MKart(child: Row(children: [
          const Icon(Icons.info_outline, color: Color(0xFF64748B), size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(
            'Telefonda bazen aksan farkı olması, hattın 8 kHz dar bant sınırındandır (örnekteki tam kalite daha nettir). Üretimdeki ses: Wavenet E (erkek).',
            style: TextStyle(color: t.sub, fontSize: 12.5),
          )),
        ])),
      ]),
    );
  }
}

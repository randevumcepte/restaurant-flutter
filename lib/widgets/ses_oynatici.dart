import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/tema_provider.dart';

/// Tema-duyarli ses oynatici (audioplayers). AI Santral cagri kayitlari + rezervasyon
/// cagri dinleme icin ortak. URL uzaktan (ornek: https://.../santral-ses-dinle/ID).
class SesOynatici extends StatefulWidget {
  final String url;
  final String etiket;
  final int boyutKb;
  const SesOynatici({super.key, required this.url, required this.etiket, this.boyutKb = 0});
  @override
  State<SesOynatici> createState() => _SesOynaticiState();
}

class _SesOynaticiState extends State<SesOynatici> {
  final _p = AudioPlayer();
  Duration _poz = Duration.zero;
  Duration _sure = Duration.zero;
  bool _caliyor = false;

  @override
  void initState() {
    super.initState();
    _p.onPositionChanged.listen((d) { if (mounted) setState(() => _poz = d); });
    _p.onDurationChanged.listen((d) { if (mounted) setState(() => _sure = d); });
    _p.onPlayerComplete.listen((_) { if (mounted) setState(() { _caliyor = false; _poz = Duration.zero; }); });
    _p.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _caliyor = s == PlayerState.playing); });
  }

  @override
  void dispose() { _p.dispose(); super.dispose(); }

  Future<void> _calDurdur() async {
    if (_caliyor) { await _p.pause(); }
    else { await _p.play(UrlSource(widget.url)); }
  }

  String _fmt(Duration d) => '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    final max = _sure.inMilliseconds.toDouble();
    final val = _poz.inMilliseconds.clamp(0, _sure.inMilliseconds).toDouble();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.card2, borderRadius: BorderRadius.circular(10), border: Border.all(color: t.line)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(widget.etiket, style: TextStyle(color: t.ink, fontSize: 13, fontWeight: FontWeight.w600))),
          if (widget.boyutKb > 0) Text('${widget.boyutKb} KB', style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          IconButton(
            onPressed: _calDurdur,
            icon: Icon(_caliyor ? Icons.pause_circle_filled : Icons.play_circle_fill, color: const Color(0xFF7C3AED), size: 34),
          ),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6)),
              child: Slider(
                min: 0,
                max: max <= 0 ? 1 : max,
                value: max <= 0 ? 0 : val,
                activeColor: const Color(0xFF7C3AED),
                inactiveColor: t.line,
                onChanged: max <= 0 ? null : (v) => _p.seek(Duration(milliseconds: v.round())),
              ),
            ),
          ),
          Text('${_fmt(_poz)} / ${_fmt(_sure)}', style: TextStyle(color: t.sub, fontSize: 11)),
        ]),
      ]),
    );
  }
}

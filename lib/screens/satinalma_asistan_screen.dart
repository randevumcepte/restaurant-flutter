import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Satınalma AI Asistanı — stok/fiyat/tedarikçi verinden sohbetle cevap.
/// Veri /api/patron/satinalma-asistan (Haiku; bakiye yoksa kural-özet).
class SatinalmaAsistanScreen extends StatefulWidget {
  const SatinalmaAsistanScreen({super.key});
  @override
  State<SatinalmaAsistanScreen> createState() => _SatinalmaAsistanScreenState();
}

const _mor1 = Color(0xFF7C3AED);

class _Mesaj {
  final String metin;
  final bool ben;
  _Mesaj(this.metin, this.ben);
}

class _SatinalmaAsistanScreenState extends State<SatinalmaAsistanScreen> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<_Mesaj> _mesajlar = [];
  bool _busy = false;

  static const _hizli = ['Bu hafta ne almalıyım?', 'Gizli zam var mı?', 'En çok nereye harcıyorum?', 'Hangi tedarikçiyle pazarlık etmeliyim?'];

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sor([String? metin]) async {
    final soru = (metin ?? _ctrl.text).trim();
    if (soru.isEmpty || _busy) return;
    _ctrl.clear();
    setState(() {
      _mesajlar.add(_Mesaj(soru, true));
      _busy = true;
    });
    _kaydir();
    try {
      final auth = context.read<AuthProvider>();
      final res = await Api.satinalmaAsistan(auth.token!, soru);
      if (!mounted) return;
      setState(() {
        _mesajlar.add(_Mesaj('${res['cevap'] ?? 'Cevap alınamadı.'}', false));
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _mesajlar.add(_Mesaj('Bağlantı hatası, tekrar dene.', false));
        _busy = false;
      });
    }
    _kaydir();
  }

  void _kaydir() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'Satınalma Asistanı',
      ikon: Icons.smart_toy,
      geri: true,
      altBaslik: 'Veriden anında cevap',
      govde: Column(
        children: [
          // hızlı sorular
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final q in _hizli) MButon(q, _mor1, () => _sor(q), dolu: false)],
            ),
          ),
          Expanded(
            child: _mesajlar.isEmpty
                ? Center(child: Text('Satınalma sorunu yaz…', style: TextStyle(color: t.sub2, fontSize: 13)))
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(14),
                    itemCount: _mesajlar.length + (_busy ? 1 : 0),
                    itemBuilder: (c, i) {
                      if (i >= _mesajlar.length) {
                        return Align(alignment: Alignment.centerLeft, child: _balon(t, '…', false, soluk: true));
                      }
                      final m = _mesajlar[i];
                      return Align(alignment: m.ben ? Alignment.centerRight : Alignment.centerLeft, child: _balon(t, m.metin, m.ben));
                    },
                  ),
          ),
          // giriş
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(color: t.card, border: Border(top: BorderSide(color: t.line))),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: TextStyle(color: t.ink),
                  onSubmitted: (_) => _sor(),
                  decoration: InputDecoration(
                    hintText: 'Sorunu yaz…',
                    hintStyle: TextStyle(color: t.sub2),
                    isDense: true,
                    filled: true,
                    fillColor: t.card2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: _mor1,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: _busy ? null : () => _sor(),
                  child: const Padding(padding: EdgeInsets.all(12), child: Icon(Icons.send, color: Colors.white, size: 20)),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _balon(TemaProvider t, String metin, bool ben, {bool soluk = false}) => Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: ben ? _mor1 : t.card2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(ben ? 14 : 4),
            bottomRight: Radius.circular(ben ? 4 : 14),
          ),
          border: ben ? null : Border.all(color: t.line),
        ),
        child: Opacity(
          opacity: soluk ? 0.6 : 1,
          child: Text(metin, style: TextStyle(color: ben ? Colors.white : t.ink, fontSize: 13.5, height: 1.45)),
        ),
      );
}

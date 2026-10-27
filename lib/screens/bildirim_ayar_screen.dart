import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/tema_provider.dart';
import '../services/api.dart';
import '../ui/masaustu_kit.dart';

/// Kişiye özel bildirim tercihleri — hangi push bildirimleri gelsin.
/// Backend: GET /api/bildirim/tercih , POST /api/bildirim/tercih-kaydet
class BildirimAyarScreen extends StatefulWidget {
  const BildirimAyarScreen({super.key});
  @override
  State<BildirimAyarScreen> createState() => _BildirimAyarScreenState();
}

class _BildirimAyarScreenState extends State<BildirimAyarScreen> {
  bool _yukleniyor = true;
  String? _hata;
  List<Map<String, dynamic>> _liste = [];

  @override
  void initState() {
    super.initState();
    _getir();
  }

  Future<void> _getir() async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null || tok.isEmpty) {
      setState(() { _yukleniyor = false; _hata = 'Oturum bulunamadı'; });
      return;
    }
    try {
      final res = await Api.bildirimTercih(tok);
      if (res['ok'] == 1) {
        final t = res['tercihler'];
        _liste = (t is List) ? t.map((e) => Map<String, dynamic>.from(e as Map)).toList() : [];
      } else {
        _hata = res['hata']?.toString() ?? 'Yüklenemedi';
      }
    } catch (_) {
      _hata = 'Bağlantı hatası';
    }
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _degis(int i, bool v) async {
    final tok = context.read<AuthProvider>().token;
    if (tok == null) return;
    setState(() => _liste[i]['acik'] = v);
    try {
      await Api.bildirimTercihKaydet(tok, tip: _liste[i]['tip'].toString(), acik: v);
    } catch (_) {/* sessiz; UI zaten güncellendi */}
  }

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    Widget govde;
    if (_yukleniyor) {
      govde = const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()));
    } else if (_hata != null) {
      govde = Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(_hata!, style: TextStyle(color: t.sub))));
    } else {
      govde = ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text(
              'Buradaki anahtarlar yalnızca sana özeldir. Kapattığın bildirim türü sana push olarak gelmez. '
              'Garsona çağrı, mutfağa sipariş gibi işine özel bildirimler varsayılan gelir.',
              style: TextStyle(color: t.sub, fontSize: 12.5, height: 1.4),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: t.line),
              boxShadow: t.golge,
            ),
            child: Column(
              children: [
                for (int i = 0; i < _liste.length; i++)
                  Container(
                    decoration: BoxDecoration(
                      border: i == _liste.length - 1 ? null : Border(bottom: BorderSide(color: t.line)),
                    ),
                    child: SwitchListTile(
                      value: _liste[i]['acik'] == true,
                      onChanged: (v) => _degis(i, v),
                      activeColor: t.mor1,
                      title: Text(_liste[i]['etiket']?.toString() ?? '', style: TextStyle(color: t.ink, fontSize: 14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                    ),
                  ),
                if (_liste.isEmpty)
                  Padding(padding: const EdgeInsets.all(24), child: Text('Ayarlanabilir bildirim yok.', style: TextStyle(color: t.sub))),
              ],
            ),
          ),
        ],
      );
    }
    return MasaustuSayfa(
      baslik: 'Bildirim Ayarları',
      ikon: Icons.notifications_active,
      geri: true,
      govde: govde,
    );
  }
}

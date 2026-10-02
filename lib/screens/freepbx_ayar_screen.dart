import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/tema_provider.dart';
import '../services/santral_api.dart';
import '../ui/masaustu_kit.dart';

/// AI Santral — FreePBX API ayarı (GraphQL + trunk). Native.
class FreepbxAyarScreen extends StatefulWidget {
  const FreepbxAyarScreen({super.key});
  @override
  State<FreepbxAyarScreen> createState() => _FreepbxAyarScreenState();
}

class _FreepbxAyarScreenState extends State<FreepbxAyarScreen> {
  bool _yukleniyor = true;
  bool _kaydediyor = false;
  bool _aktif = false;
  final _baseUrl = TextEditingController();
  final _clientId = TextEditingController();
  final _clientSecret = TextEditingController();
  final _trunkUrl = TextEditingController();
  final _trunkSecret = TextEditingController();
  String? _testSonuc;
  bool _testIyi = false;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    for (final c in [_baseUrl, _clientId, _clientSecret, _trunkUrl, _trunkSecret]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _yukle() async {
    setState(() => _yukleniyor = true);
    try {
      final r = await SantralApi.freepbxAyar();
      if (r['ok'] == 1) {
        final a = Map<String, dynamic>.from(r['ayar']);
        _baseUrl.text = '${a['base_url'] ?? ''}';
        _clientId.text = '${a['client_id'] ?? ''}';
        _clientSecret.text = '${a['client_secret'] ?? ''}';
        _trunkUrl.text = '${a['trunk_api_url'] ?? ''}';
        _trunkSecret.text = '${a['trunk_api_secret'] ?? ''}';
        _aktif = (a['aktif'] ?? 0) == 1;
      }
    } catch (_) {}
    if (mounted) setState(() => _yukleniyor = false);
  }

  Future<void> _kaydet() async {
    setState(() => _kaydediyor = true);
    try {
      final r = await SantralApi.freepbxKaydet({
        'base_url': _baseUrl.text.trim(),
        'client_id': _clientId.text.trim(),
        'client_secret': _clientSecret.text.trim(),
        'trunk_api_url': _trunkUrl.text.trim(),
        'trunk_api_secret': _trunkSecret.text.trim(),
        'aktif': _aktif ? 1 : 0,
      });
      _uyar(r['ok'] == 1 ? 'Kaydedildi ✓' : 'Hata: ${r['hata'] ?? ''}');
    } catch (e) {
      _uyar('Hata: $e');
    }
    if (mounted) setState(() => _kaydediyor = false);
  }

  Future<void> _test() async {
    setState(() { _testSonuc = 'Bağlanılıyor...'; _testIyi = false; });
    try {
      final r = await SantralApi.freepbxTest();
      final ok = r['ok'] == 1 || r['ok'] == true;
      setState(() { _testIyi = ok; _testSonuc = ok ? 'Bağlantı başarılı ✓ ${r['mesaj'] ?? ''}' : 'Başarısız: ${r['hata'] ?? r['message'] ?? 'bağlanılamadı'}'; });
    } catch (e) {
      setState(() { _testIyi = false; _testSonuc = 'Hata: $e'; });
    }
  }

  void _uyar(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final t = context.watch<TemaProvider>();
    return MasaustuSayfa(
      baslik: 'FreePBX API',
      altBaslik: 'FreePBX GraphQL + trunk API bağlantı ayarları',
      ikon: Icons.settings_input_antenna,
      araclar: [
        MButon('Test', const Color(0xFF4F46E5), _test, dolu: false, ikon: Icons.wifi_tethering),
        const SizedBox(width: 8),
        MButon(_kaydediyor ? 'Kaydediliyor...' : 'Kaydet', const Color(0xFF22C55E), _kaydediyor ? () {} : _kaydet, ikon: Icons.save),
      ],
      govde: _yukleniyor
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              MKart(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const MBolumBaslik('GraphQL API (dahili yönetimi)', renk: Color(0xFF0EA5E9)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _aktif,
                  activeThumbColor: const Color(0xFF0EA5E9),
                  title: Text('Entegrasyon aktif', style: TextStyle(color: t.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                  onChanged: (v) => setState(() => _aktif = v),
                ),
                _alan('Base URL', _baseUrl, 'https://pbx.sunucunuz.com', t),
                _alan('Client ID', _clientId, 'GraphQL API Application client id', t),
                _alan('Client Secret', _clientSecret, 'GraphQL API Application secret', t, gizli: true),
              ])),
              const SizedBox(height: 14),
              MKart(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const MBolumBaslik('Trunk API (hat yönetimi — opsiyonel)', renk: Color(0xFF7C3AED)),
                _alan('Trunk API URL', _trunkUrl, 'https://pbx.sunucunuz.com/santral-trunk.php', t),
                _alan('Trunk API Secret', _trunkSecret, 'santral-trunk.php gizli anahtarı', t, gizli: true),
              ])),
              if (_testSonuc != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (_testIyi ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: (_testIyi ? const Color(0xFF10B981) : const Color(0xFFF43F5E)).withValues(alpha: 0.4)),
                  ),
                  child: Row(children: [
                    Icon(_testIyi ? Icons.check_circle : Icons.error_outline, color: _testIyi ? const Color(0xFF10B981) : const Color(0xFFF43F5E), size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_testSonuc!, style: TextStyle(color: t.ink, fontSize: 13))),
                  ]),
                ),
              ],
            ]),
    );
  }

  Widget _alan(String etiket, TextEditingController c, String ipucu, TemaProvider t, {bool gizli = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiket, style: TextStyle(color: t.sub2, fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        TextField(
          controller: c,
          obscureText: gizli,
          style: TextStyle(color: t.ink, fontSize: 13),
          decoration: InputDecoration(
            hintText: ipucu,
            hintStyle: TextStyle(color: t.sub, fontSize: 12),
            isDense: true,
            filled: true,
            fillColor: t.card2,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: t.line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF0EA5E9))),
          ),
        ),
      ]),
    );
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../local/cihaz_rol.dart';
import '../local/kasa_sunucu.dart';

/// LAN / Kasa Sunucu ayarlari.
///  - Kasa: bu cihaz yerel sunucu olur (terminaller buna baglanir).
///  - Terminal: kasanin LAN adresini girip baglanir.
///  - Bagimsiz: dogrudan buluta (varsayilan).
class LanAyarScreen extends StatefulWidget {
  const LanAyarScreen({super.key});
  @override
  State<LanAyarScreen> createState() => _LanAyarScreenState();
}

class _LanAyarScreenState extends State<LanAyarScreen> {
  Rol _rol = CihazRol.rol;
  final _urlCtrl = TextEditingController(text: CihazRol.kasaUrl);
  String? _lanIp;
  String? _test;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    KasaSunucu.lanIp().then((ip) { if (mounted) setState(() => _lanIp = ip); });
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _kaydet() async {
    await CihazRol.rolAyarla(_rol, kasaUrl: _urlCtrl.text);
    if (_rol == Rol.kasa) {
      await KasaSunucu.instance.baslat();
    } else {
      await KasaSunucu.instance.durdur();
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kaydedildi. (Değişiklik için uygulamayı yeniden başlatman önerilir.)')));
      setState(() {});
    }
  }

  Future<void> _baglantiTest() async {
    setState(() { _testing = true; _test = null; });
    try {
      final url = _urlCtrl.text.trim().replaceAll(RegExp(r'/+$'), '');
      final r = await http.get(Uri.parse('$url/api/health')).timeout(const Duration(seconds: 5));
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      _test = j['rol'] == 'kasa' ? '✅ Kasa bulundu (bağlantı başarılı)' : '⚠️ Yanıt var ama kasa değil';
    } catch (e) {
      _test = '❌ Bağlanılamadı — IP/port doğru mu, aynı WiFi mı?';
    }
    if (mounted) setState(() => _testing = false);
  }

  Widget _rolSecim(Rol r, String baslik, String alt) {
    final secili = _rol == r;
    return ListTile(
      onTap: () => setState(() => _rol = r),
      leading: Icon(secili ? Icons.radio_button_checked : Icons.radio_button_off,
          color: secili ? const Color(0xFF6366F1) : const Color(0xFF94A3B8)),
      title: Text(baslik, style: TextStyle(fontWeight: secili ? FontWeight.bold : FontWeight.normal)),
      subtitle: Text(alt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final kasaAdres = _lanIp != null ? 'http://$_lanIp:${CihazRol.kasaPort}' : 'IP bulunamadı';
    return Scaffold(
      appBar: AppBar(title: const Text('LAN / Kasa Sunucu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Bu cihazın rolü', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          _rolSecim(Rol.bagimsiz, 'Bağımsız', 'Doğrudan buluta (tek cihaz)'),
          _rolSecim(Rol.kasa, 'Kasa (yerel sunucu)', 'Terminaller bu cihaza bağlanır; buluta senkronlar'),
          _rolSecim(Rol.terminal, 'Terminal', 'Garson/mutfak — kasaya bağlanır'),
          const Divider(height: 28),

          if (_rol == Rol.kasa) ...[
            const Text('Kasa sunucu adresi', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            SelectableText(kasaAdres, style: const TextStyle(fontSize: 16, color: Color(0xFF6366F1), fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('Terminallere bu adresi gir. Durum: ${KasaSunucu.instance.calisiyor ? "çalışıyor ✅" : "duruyor"}',
                style: const TextStyle(color: Color(0xFF64748B))),
          ],

          if (_rol == Rol.terminal) ...[
            const Text('Kasa adresi', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _urlCtrl,
              decoration: const InputDecoration(hintText: 'http://192.168.1.50:8787', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton.icon(
                onPressed: _testing ? null : _baglantiTest,
                icon: _testing
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.wifi_find),
                label: const Text('Bağlantıyı test et'),
              ),
            ]),
            if (_test != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_test!)),
          ],

          const SizedBox(height: 24),
          FilledButton.icon(onPressed: _kaydet, icon: const Icon(Icons.save), label: const Text('Kaydet')),
          const SizedBox(height: 12),
          const Text(
            'Not: Kasa modu gömülü bir yerel sunucu çalıştırır (şu an okuma uçları: masalar, menü). '
            'Sipariş/ödeme yazma uçları sonraki aşamada eklenecek.',
            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

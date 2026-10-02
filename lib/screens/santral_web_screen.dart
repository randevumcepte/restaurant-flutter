import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_windows/webview_windows.dart';
import '../services/api.dart';

/// AI Santral panel sayfalarini (web, standalone HTML) uygulama ICINDE gosterir.
/// Windows'ta webview_windows (WebView2) -> native kaydirma sorunsuz calisir.
class SantralWebScreen extends StatefulWidget {
  final String path;   // ornek: '/santral-kayitlar'
  final String baslik; // ustteki baslik
  const SantralWebScreen(this.path, this.baslik, {super.key});

  @override
  State<SantralWebScreen> createState() => _SantralWebScreenState();
}

class _SantralWebScreenState extends State<SantralWebScreen> {
  final _ctrl = WebviewController();
  bool _hazir = false;
  String? _hata;

  static const _koyu = Color(0xFF0F172A);

  String get _url => '${Api.base}${widget.path}';

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _baslat();
    } else {
      _hata = 'desktop-disi';
    }
  }

  Future<void> _baslat() async {
    try {
      await _ctrl.initialize();
      await _ctrl.setBackgroundColor(Colors.transparent);
      await _ctrl.loadUrl(_url);
      if (mounted) setState(() => _hazir = true);
    } catch (e) {
      if (mounted) setState(() => _hata = e.toString());
    }
  }

  Future<void> _tarayicida() async {
    try {
      await launchUrl(Uri.parse(_url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _koyu,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.baslik,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _hazir ? () => _ctrl.reload() : null,
          ),
          IconButton(
            tooltip: 'Tarayıcıda aç',
            icon: const Icon(Icons.open_in_new, color: Colors.white),
            onPressed: _tarayicida,
          ),
        ],
      ),
      body: _govde(),
    );
  }

  Widget _govde() {
    if (_hata != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.public_off, size: 48, color: Color(0xFF94A3B8)),
              const SizedBox(height: 12),
              Text(
                _hata == 'desktop-disi'
                    ? 'Bu sayfa masaüstü uygulamasında görüntülenir.'
                    : 'Sayfa açılamadı.\nWebView2 bileşeni gerekli olabilir.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF475569), fontSize: 14),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _tarayicida,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Tarayıcıda aç'),
                style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              ),
            ],
          ),
        ),
      );
    }
    return Stack(
      children: [
        if (_hazir) Positioned.fill(child: Webview(_ctrl)),
        if (!_hazir)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
      ],
    );
  }
}

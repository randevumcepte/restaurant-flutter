import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../services/api.dart';

/// AI Santral panel sayfalarini (web, standalone HTML) uygulama ICINDE gosterir.
/// Harici tarayici yerine gomulu webview (Windows + Android).
class SantralWebScreen extends StatefulWidget {
  final String path;   // ornek: '/santral-kayitlar'
  final String baslik; // ustteki baslik
  const SantralWebScreen(this.path, this.baslik, {super.key});

  @override
  State<SantralWebScreen> createState() => _SantralWebScreenState();
}

class _SantralWebScreenState extends State<SantralWebScreen> {
  InAppWebViewController? _ctrl;
  double _ilerleme = 0;

  static const _mor = Color(0xFF8B5CF6);

  @override
  Widget build(BuildContext context) {
    final url = '${Api.base}${widget.path}';
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(widget.baslik,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _ctrl?.reload(),
          ),
        ],
        bottom: _ilerleme < 1.0
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: _ilerleme == 0 ? null : _ilerleme,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                  valueColor: const AlwaysStoppedAnimation<Color>(_mor),
                ),
              )
            : null,
      ),
      body: InAppWebView(
        initialUrlRequest: URLRequest(url: WebUri(url)),
        initialSettings: InAppWebViewSettings(
          // transparentBackground Windows/WebView2'de agir compositing + kaydirma
          // takilmasi yapar -> opak brak. Donanim hizlandirma acik.
          transparentBackground: false,
          javaScriptEnabled: true,
          supportZoom: false,
          hardwareAcceleration: true,
          disableVerticalScroll: false,
          disableHorizontalScroll: false,
          useHybridComposition: true, // Android: daha akici kaydirma
        ),
        onWebViewCreated: (c) => _ctrl = c,
        onProgressChanged: (c, p) {
          if (mounted) setState(() => _ilerleme = p / 100.0);
        },
      ),
    );
  }
}

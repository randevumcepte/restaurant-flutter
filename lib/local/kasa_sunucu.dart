import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'cihaz_rol.dart';
import 'local_db.dart';

/// KASA YEREL SUNUCUSU (LAN otorite).
///
/// Kasa cihazinda calisir; terminaller (garson/mutfak) buluta degil BUNA baglanir.
/// Cekirdek uclari yerel SQLite'tan sunar -> internet olmasa bile LAN ici POS calisir.
/// Kasa ayrica sync_worker ile buluta senkronlanir.
///
/// ASAMA 1: iskelet + okuma uclari (health, masalar, menu). Yazma uclari (masa-ac,
/// adisyon-islem...) sonraki asamada adisyon_repo'ya baglanacak.
class KasaSunucu {
  KasaSunucu._();
  static final KasaSunucu instance = KasaSunucu._();

  HttpServer? _server;
  bool get calisiyor => _server != null;
  int get port => CihazRol.kasaPort;

  Future<void> baslat() async {
    if (_server != null) return;
    final router = Router();

    // Saglik: terminal kasayi bu uctan bulur/dogrular.
    router.get('/api/health', (Request r) =>
        _json({'ok': 1, 'rol': 'kasa', 'zaman': DateTime.now().millisecondsSinceEpoch}));

    // Okuma uclari (yerel SQLite). Terminalin Api.* cagrilariyla ayni sozlesmeyi hedefler.
    router.get('/api/masalar', (Request r) => _tablo('masalar', 'masalar'));
    router.get('/api/menu', _menu);

    final handler = const Pipeline()
        .addMiddleware(_cors())
        .addHandler(router.call);

    // anyIPv4 -> LAN'daki tum terminaller erisebilir.
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    _server!.autoCompress = true;
  }

  Future<void> durdur() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// Bu cihazin LAN IP'si (terminallere verilecek adres). Bulunamazsa null.
  static Future<String?> lanIp() async {
    try {
      final aglar = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final a in aglar) {
        for (final addr in a.addresses) {
          if (!addr.isLoopback) return addr.address; // ilk LAN IPv4
        }
      }
    } catch (_) {}
    return null;
  }

  // --- yardimcilar ---
  Future<Response> _tablo(String tablo, String anahtar) async {
    final d = await LocalDb.instance.db;
    final rows = await d.query(tablo, where: 'deleted = 0');
    return _json({'ok': 1, anahtar: rows});
  }

  Future<Response> _menu(Request r) async {
    final d = await LocalDb.instance.db;
    final kat = await d.query('menu_kategorileri', where: 'deleted = 0 AND aktif = 1', orderBy: 'sira, ad');
    final urun = await d.query('urunler', where: 'deleted = 0 AND aktif = 1', orderBy: 'ad');
    return _json({'ok': 1, 'kategoriler': kat, 'urunler': urun});
  }

  Response _json(Object data) => Response.ok(jsonEncode(data),
      headers: {'Content-Type': 'application/json; charset=utf-8'});

  // Terminaller farkli origin'den gelebilir (web/debug) -> CORS serbest.
  Middleware _cors() => (inner) => (req) async {
        if (req.method == 'OPTIONS') return Response.ok('', headers: _corsBaslik);
        final res = await inner(req);
        return res.change(headers: _corsBaslik);
      };
  static const _corsBaslik = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, Authorization',
  };
}

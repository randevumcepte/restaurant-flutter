import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../config/app_config.dart';
import 'local_db.dart';

/// KASA YEREL SUNUCUSU (LAN otorite).
///
/// Terminaller (garson/mutfak) buluta degil BUNA baglanir. Model:
///   - Internet VARKEN  : istegi oldugu gibi BULUTA iletir (proxy) -> tam ozellik, sifir yeniden-yazim.
///   - Internet YOKKEN   : cekirdek uclari (masalar/menu + yazma) YEREL SQLite'tan sunar.
/// Kasa ayrica sync_worker ile buluta senkronlanir.
///
/// ASAMA 3a: genel proxy + offline okuma (masalar/menu). Offline YAZMA (masa-ac/
/// adisyon-islem) sonraki asamada adisyon_repo'ya baglanacak.
class KasaSunucu {
  KasaSunucu._();
  static final KasaSunucu instance = KasaSunucu._();

  HttpServer? _server;
  bool get calisiyor => _server != null;
  int get port => 8787;

  Future<void> baslat() async {
    if (_server != null) return;
    final handler = const Pipeline().addMiddleware(_cors()).addHandler(_handle);
    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    _server!.autoCompress = true;
  }

  Future<void> durdur() async {
    await _server?.close(force: true);
    _server = null;
  }

  // Tek giris: health yerel; gerisi once bulut (proxy), bulut yoksa yerel.
  Future<Response> _handle(Request req) async {
    final yol = req.requestedUri.path;
    if (yol == '/api/health') {
      return _json({'ok': 1, 'rol': 'kasa', 'online': _sonProxyBasarili, 'zaman': DateTime.now().millisecondsSinceEpoch});
    }
    // Govde bir kez okunur (hem proxy hem yerel icin).
    final govde = (req.method == 'GET' || req.method == 'HEAD') ? '' : await req.readAsString();
    try {
      final r = await _buluta(req, govde);
      _sonProxyBasarili = true;
      return r;
    } catch (_) {
      _sonProxyBasarili = false;
      return await _yerel(req, govde); // offline -> yerel cekirdek
    }
  }

  bool _sonProxyBasarili = true;

  // --- PROXY: istegi buluta ilet ---
  Future<Response> _buluta(Request req, String govde) async {
    final hedef = Uri.parse(AppConfig.baseUrl).replace(
      path: req.requestedUri.path,
      query: req.requestedUri.query.isEmpty ? null : req.requestedUri.query,
    );
    final ireq = http.Request(req.method, hedef);
    final auth = req.headers['authorization'];
    if (auth != null) ireq.headers['Authorization'] = auth;
    ireq.headers['Accept'] = 'application/json';
    final ct = req.headers['content-type'];
    if (ct != null) ireq.headers['Content-Type'] = ct;
    if (govde.isNotEmpty) ireq.body = govde;

    final streamed = await ireq.send().timeout(const Duration(seconds: 12));
    final bytes = await streamed.stream.toBytes();
    final respCt = streamed.headers['content-type'] ?? 'application/json; charset=utf-8';
    return Response(streamed.statusCode, body: bytes, headers: {'Content-Type': respCt});
  }

  // --- YEREL (offline cekirdek) ---
  Future<Response> _yerel(Request req, String govde) async {
    final yol = req.requestedUri.path;
    if (req.method == 'GET' && yol == '/api/masalar') return _yerelMasalar();
    if (req.method == 'GET' && yol == '/api/menu') return _yerelMenu();
    // Diger uclar offline'da henuz desteklenmiyor (yazma uclari sonraki asama).
    return _json({'ok': 0, 'offline': 1, 'hata': 'Çevrimdışı — bu işlem şu an desteklenmiyor'}, 503);
  }

  Future<Response> _yerelMasalar() async {
    final d = await LocalDb.instance.db;
    final masalar = await d.query('masalar', where: 'deleted = 0', orderBy: 'ad');
    // Her masaya acik adisyonu (varsa) rowid ile bagla -> terminal 'adisyon_id' bekler.
    final liste = <Map<String, Object?>>[];
    for (final m in masalar) {
      final acik = await d.rawQuery(
          "SELECT rowid, toplam FROM adisyonlar WHERE masa_uuid = ? AND durum='acik' AND deleted=0 LIMIT 1",
          [m['uuid']]);
      liste.add({
        'id': m['uuid'], // terminal icin kimlik (offline: uuid)
        'ad': m['ad'],
        'durum': acik.isNotEmpty ? 'dolu' : (m['durum'] ?? 'bos'),
        'adisyon_id': acik.isNotEmpty ? acik.first['rowid'] : null,
        'tutar': acik.isNotEmpty ? acik.first['toplam'] : 0,
      });
    }
    return _json({'ok': 1, 'masalar': liste, 'offline': 1});
  }

  Future<Response> _yerelMenu() async {
    final d = await LocalDb.instance.db;
    final kat = await d.query('menu_kategorileri', where: 'deleted = 0 AND aktif = 1', orderBy: 'sira, ad');
    final urun = await d.query('urunler', where: 'deleted = 0 AND aktif = 1', orderBy: 'ad');
    return _json({'ok': 1, 'kategoriler': kat, 'urunler': urun, 'offline': 1});
  }

  /// Bu cihazin LAN IP'si (terminallere verilecek adres). Bulunamazsa null.
  static Future<String?> lanIp() async {
    try {
      final aglar = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
      for (final a in aglar) {
        for (final addr in a.addresses) {
          if (!addr.isLoopback) return addr.address;
        }
      }
    } catch (_) {}
    return null;
  }

  Response _json(Object data, [int kod = 200]) => Response(kod,
      body: jsonEncode(data), headers: {'Content-Type': 'application/json; charset=utf-8'});

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

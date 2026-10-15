import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import '../config/app_config.dart';
import 'adisyon_repo.dart';
import 'local_db.dart';
import 'sync_repo.dart';

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
    final m = req.method;
    if (m == 'GET' && yol == '/api/masalar') return _yerelMasalar();
    if (m == 'GET' && yol == '/api/menu') return _yerelMenu();
    if (m == 'POST' && yol == '/api/patron/masa-ac') return _yerelMasaAc(govde);
    if (m == 'POST' && yol == '/api/patron/adisyon-urun-ekle') return _yerelSiparisEkle(govde);
    if (m == 'GET' && yol == '/api/patron/fis') return _yerelFis(int.tryParse(req.requestedUri.queryParameters['adisyon_id'] ?? '') ?? 0);
    if (m == 'GET' && yol == '/api/patron/adisyon-kalemleri') return _yerelKalemler(int.tryParse(req.requestedUri.queryParameters['adisyon_id'] ?? '') ?? 0);
    if (m == 'POST' && yol == '/api/patron/adisyon-islem') return _yerelIslem(govde);
    if (m == 'GET' && yol == '/api/mutfak') return _yerelMutfak();
    if (m == 'POST' && yol == '/api/mutfak/basla') return _yerelMutfakDurum(govde, 'hazirlaniyor', ['gonderildi']);
    if (m == 'POST' && yol == '/api/mutfak/hazir') return _yerelMutfakDurum(govde, 'hazir', ['gonderildi', 'hazirlaniyor']);
    if (m == 'POST' && yol == '/api/mutfak/servis') return _yerelMutfakDurum(govde, 'servis', ['hazir']);
    // Diger uclar offline'da henuz desteklenmiyor (sonraki asamalar).
    return _json({'ok': 0, 'offline': 1, 'hata': 'Çevrimdışı — bu işlem şu an desteklenmiyor'}, 503);
  }

  // OFFLINE: mutfak (KDS) — gonderilmis/hazirlanan kalemler, acik adisyonlardan.
  Future<Response> _yerelMutfak() async {
    final d = await LocalDb.instance.db;
    final rows = await d.rawQuery('''
      SELECT k.rowid AS id, k.urun_adi, k.adet, k.not_metni AS not, k.kur, k.gonderim_zamani, k.durum,
             a.rowid AS adisyon_id, m.ad AS masa, a.kanal
      FROM adisyon_kalemleri k
      JOIN adisyonlar a ON k.adisyon_uuid = a.uuid AND a.deleted = 0
      LEFT JOIN masalar m ON a.masa_uuid = m.uuid
      WHERE a.durum = 'acik' AND k.deleted = 0 AND k.durum IN ('gonderildi','hazirlaniyor')
      ORDER BY k.gonderim_zamani, k.rowid
    ''');
    final kalemler = rows.map((r) => {...r, 'hedef': 15}).toList();
    return _json({'ok': 1, 'offline': 1, 'kalemler': kalemler});
  }

  // OFFLINE: mutfak durum gecisi (basla/hazir/servis) — adisyonun uygun kalemlerini gunceller.
  Future<Response> _yerelMutfakDurum(String govde, String yeni, List<String> kaynak) async {
    final b = Uri.splitQueryString(govde);
    final rowid = int.tryParse(b['adisyon_id'] ?? '') ?? 0;
    final ad = await _adisyonRowid(rowid);
    if (ad == null) return _json({'ok': 0, 'hata': 'Adisyon bulunamadı (offline)'});
    final uuid = ad['uuid'] as String;
    final d = await LocalDb.instance.db;
    final yer = kaynak.map((_) => '?').join(',');
    final kalemler = await d.rawQuery(
        'SELECT uuid FROM adisyon_kalemleri WHERE adisyon_uuid = ? AND deleted = 0 AND durum IN ($yer)',
        [uuid, ...kaynak]);
    for (final k in kalemler) {
      await SyncRepo.instance.yaz('adisyon_kalemleri', {'uuid': k['uuid'], 'durum': yeni}, op: 'update');
    }
    return _json({'ok': 1, 'offline': 1, 'guncellenen': kalemler.length});
  }

  Future<Map<String, Object?>?> _adisyonRowid(int rowid) async {
    final d = await LocalDb.instance.db;
    final a = await d.rawQuery('SELECT rowid, * FROM adisyonlar WHERE rowid = ? AND deleted = 0 LIMIT 1', [rowid]);
    return a.isEmpty ? null : a.first;
  }

  String _tarih() {
    final n = DateTime.now();
    String i2(int x) => x.toString().padLeft(2, '0');
    return '${i2(n.day)}.${i2(n.month)}.${n.year} ${i2(n.hour)}:${i2(n.minute)}';
  }

  // OFFLINE: hesap fisi (adisyon + kalemler + odemeler) yerelden.
  Future<Response> _yerelFis(int rowid) async {
    final d = await LocalDb.instance.db;
    final ad = await _adisyonRowid(rowid);
    if (ad == null) return _json({'ok': 0, 'hata': 'Adisyon bulunamadı (offline)'});
    final uuid = ad['uuid'] as String;
    final kalemler = await d.rawQuery(
        "SELECT urun_adi, adet, birim_fiyat, tutar FROM adisyon_kalemleri WHERE adisyon_uuid = ? AND durum != 'iptal' AND deleted = 0 ORDER BY updated_at",
        [uuid]);
    final odemeler = await d.rawQuery(
        'SELECT tip, tutar FROM odemeler WHERE adisyon_uuid = ? AND deleted = 0', [uuid]);
    String? masaAd;
    if (ad['masa_uuid'] != null) {
      final mm = await d.query('masalar', columns: ['ad'], where: 'uuid = ?', whereArgs: [ad['masa_uuid']], limit: 1);
      if (mm.isNotEmpty) masaAd = mm.first['ad'] as String?;
    }
    return _json({
      'ok': 1, 'offline': 1,
      'isletme': '', 'adres': '', 'telefon': '',
      'masa': masaAd ?? (ad['kanal'] ?? 'Masa'), 'garson': '-',
      'tarih': _tarih(), 'adisyon_no': rowid,
      'kalemler': kalemler.map((k) => {
            'ad': k['urun_adi'], 'adet': (k['adet'] as num?)?.toDouble() ?? 0,
            'birim_fiyat': (k['birim_fiyat'] as num?)?.toDouble() ?? 0, 'tutar': (k['tutar'] as num?)?.toDouble() ?? 0,
          }).toList(),
      'birlesik_masalar': [],
      'ara_toplam': ad['ara_toplam'], 'indirim': ad['indirim'], 'ikram': ad['ikram'], 'toplam': ad['toplam'],
      'odemeler': odemeler.map((o) => {'tip': o['tip'], 'tutar': (o['tutar'] as num?)?.toDouble() ?? 0}).toList(),
    });
  }

  // OFFLINE: adisyon kalemleri (satis ekrani kalem listesi).
  Future<Response> _yerelKalemler(int rowid) async {
    final d = await LocalDb.instance.db;
    final ad = await _adisyonRowid(rowid);
    if (ad == null) return _json({'ok': 0, 'hata': 'Adisyon bulunamadı (offline)'});
    final uuid = ad['uuid'] as String;
    final kalemler = await d.rawQuery(
        'SELECT rowid AS id, urun_adi, adet, tutar, durum FROM adisyon_kalemleri WHERE adisyon_uuid = ? AND deleted = 0 ORDER BY updated_at',
        [uuid]);
    final gecerli = kalemler.where((k) => k['durum'] != 'iptal');
    final toplam = gecerli.fold<double>(0, (t, k) => t + ((k['tutar'] as num?)?.toDouble() ?? 0));
    final odemeler = await d.rawQuery('SELECT tutar FROM odemeler WHERE adisyon_uuid = ? AND deleted = 0', [uuid]);
    final odenen = odemeler.fold<double>(0, (t, o) => t + ((o['tutar'] as num?)?.toDouble() ?? 0));
    return _json({
      'ok': 1, 'offline': 1,
      'kalemler': kalemler.map((k) => {
            'id': k['id'], 'ad': k['urun_adi'], 'adet': (k['adet'] as num?)?.round() ?? 0,
            'tutar': (k['tutar'] as num?)?.toDouble() ?? 0, 'odeme_durum': 'acik',
            'durum': k['durum'] ?? 'gonderildi', 'ikram': 0,
          }).toList(),
      'toplam': toplam, 'kalan': (toplam - odenen).clamp(0, double.infinity),
    });
  }

  // OFFLINE: odeme/kapat. Iskonto/ikram/void offline desteklenmiyor (503).
  Future<Response> _yerelIslem(String govde) async {
    final b = Uri.splitQueryString(govde);
    final islem = b['islem'] ?? '';
    final rowid = int.tryParse(b['adisyon_id'] ?? '') ?? 0;
    final ad = await _adisyonRowid(rowid);
    if (ad == null) return _json({'ok': 0, 'hata': 'Adisyon bulunamadı (offline)'});
    if (ad['durum'] != 'acik') return _json({'ok': 0, 'hata': 'Bu adisyon zaten kapanmış.'});

    if (islem == 'ode' || islem == 'kapat') {
      final uuid = ad['uuid'] as String;
      final toplam = (ad['toplam'] as num?)?.toDouble() ?? 0;
      final tipGecerli = ['nakit', 'kredi', 'yemek_karti'];
      final tip = tipGecerli.contains(b['odeme_tip']) ? b['odeme_tip']! : 'nakit';
      final d = await LocalDb.instance.db;
      final odemeler = await d.rawQuery('SELECT tutar FROM odemeler WHERE adisyon_uuid = ? AND deleted = 0', [uuid]);
      final odenen = odemeler.fold<double>(0, (t, o) => t + ((o['tutar'] as num?)?.toDouble() ?? 0));
      final double kalan = (toplam - odenen).clamp(0, double.infinity).toDouble();
      final double tutar = islem == 'kapat' ? kalan : (double.tryParse(b['tutar'] ?? '') ?? kalan);
      await AdisyonRepo.instance.odemeEkle(adisyonUuid: uuid, tip: tip, tutar: tutar); // tam odenince adisyon kapanir + masa bosalir
      return _json({'ok': 1, 'offline': 1, 'mesaj': 'Ödeme alındı (çevrimdışı)'});
    }
    return _json({'ok': 0, 'offline': 1, 'hata': 'Bu işlem çevrimdışı desteklenmiyor (sadece ödeme/kapat).'}, 503);
  }

  // OFFLINE: adisyona kalem ekle + mutfaga dus (durum=gonderildi). Donus toplam.
  Future<Response> _yerelSiparisEkle(String govde) async {
    final b = Uri.splitQueryString(govde);
    final rowid = int.tryParse(b['adisyon_id'] ?? '') ?? 0;
    final List kalemler = jsonDecode(b['kalemler'] ?? '[]') as List;
    final d = await LocalDb.instance.db;
    final adi = await d.rawQuery('SELECT uuid FROM adisyonlar WHERE rowid = ? AND deleted = 0', [rowid]);
    if (adi.isEmpty) return _json({'ok': 0, 'hata': 'Adisyon bulunamadı (offline)'});
    final adisyonUuid = adi.first['uuid'] as String;

    int eklenen = 0;
    for (final k in kalemler) {
      final urunSid = (k['urun_id'] as num?)?.toInt();
      final adet = (k['adet'] as num?)?.toDouble() ?? 1;
      if (urunSid == null || adet <= 0) continue;
      final u = await d.query('urunler', where: 'server_id = ? AND deleted = 0', whereArgs: [urunSid], limit: 1);
      if (u.isEmpty) continue;
      await AdisyonRepo.instance.kalemEkle(
        adisyonUuid: adisyonUuid,
        urunSid: urunSid,
        urunAdi: (u.first['ad'] as String?) ?? '',
        adet: adet,
        birimFiyat: (u.first['fiyat'] as num?)?.toDouble() ?? 0,
        durum: 'gonderildi', // mutfaga dus
      );
      eklenen++;
    }
    final ad = await d.query('adisyonlar', columns: ['toplam'], where: 'uuid = ?', whereArgs: [adisyonUuid], limit: 1);
    return _json({'ok': 1, 'offline': 1, 'eklenen': eklenen, 'toplam': ad.isNotEmpty ? ad.first['toplam'] : 0, 'mesaj': 'Sipariş eklendi (çevrimdışı)'});
  }

  // OFFLINE: masa ac -> yerel adisyon (adisyon_repo + outbox). Donus: adisyon_id = rowid.
  Future<Response> _yerelMasaAc(String govde) async {
    final b = Uri.splitQueryString(govde);
    final masaSid = int.tryParse(b['masa_id'] ?? '') ?? 0; // terminalin gonderdigi = bulut masa id (server_id)
    final misafir = int.tryParse(b['misafir'] ?? '1') ?? 1;
    final d = await LocalDb.instance.db;
    final masaRows = await d.query('masalar',
        where: 'server_id = ? AND deleted = 0', whereArgs: [masaSid], limit: 1);
    if (masaRows.isEmpty) return _json({'ok': 0, 'hata': 'Masa bulunamadı (offline)'});
    final masa = masaRows.first;
    final masaUuid = masa['uuid'] as String;
    final subeId = (masa['sube_id'] as int?) ?? 0;

    // Zaten acik adisyon varsa onu don (cift acilma olmasin).
    final acik = await d.rawQuery(
        "SELECT rowid FROM adisyonlar WHERE masa_uuid = ? AND durum='acik' AND deleted=0 LIMIT 1",
        [masaUuid]);
    if (acik.isNotEmpty) {
      return _json({'ok': 1, 'adisyon_id': acik.first['rowid'], 'mesaj': '${masa['ad']} zaten açık.', 'offline': 1});
    }

    final uuid = await AdisyonRepo.instance.masaAc(masaUuid: masaUuid, subeId: subeId, masaSid: masaSid);
    final yeni = await d.rawQuery('SELECT rowid FROM adisyonlar WHERE uuid = ?', [uuid]);
    final rowid = yeni.isNotEmpty ? yeni.first['rowid'] : null;
    return _json({'ok': 1, 'adisyon_id': rowid, 'mesaj': '${masa['ad']} açıldı ($misafir kişi).', 'offline': 1});
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
        'id': m['server_id'], // terminal icin kimlik = bulut masa id (online/offline tutarli)
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

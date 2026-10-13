import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../config/app_config.dart';
import 'local_db.dart';

/// Senkron iscisi: outbox'i buluta bosaltir (push) + degisenleri indirir (pull).
///
/// Internet yoksa HTTP hata verir -> senkronla() false doner, outbox birikir.
/// Internet gelince tekrar cagrilinca kuyruk bosalir. UI her zaman yerelden calisir.
class SyncWorker {
  SyncWorker._();
  static final SyncWorker instance = SyncWorker._();

  static const _zamanAsimi = Duration(seconds: 20);
  bool _calisiyor = false;

  // Pull: backend kolon -> yerel kolon (push eslemesinin tersi)
  static const Map<String, Map<String, String>> _pullCols = {
    'masalar': {'id': 'server_id', 'uuid': 'uuid', 'sube_id': 'sube_id', 'bolge_id': 'bolge_sid', 'ad': 'ad', 'sekil': 'sekil', 'x': 'x', 'y': 'y', 'durum': 'durum', 'updated_at': 'updated_at'},
    'menu_kategorileri': {'id': 'server_id', 'uuid': 'uuid', 'sube_id': 'sube_id', 'ad': 'ad', 'sira': 'sira', 'aktif': 'aktif', 'updated_at': 'updated_at'},
    'urunler': {'id': 'server_id', 'uuid': 'uuid', 'sube_id': 'sube_id', 'kategori_id': 'kategori_sid', 'ad': 'ad', 'aciklama': 'aciklama', 'fiyat': 'fiyat', 'stok_takipli': 'stok_takipli', 'tukendi': 'tukendi', 'aktif': 'aktif', 'gorsel': 'gorsel', 'updated_at': 'updated_at'},
    'adisyonlar': {'id': 'server_id', 'uuid': 'uuid', 'sube_id': 'sube_id', 'masa_id': 'masa_sid', 'kanal': 'kanal', 'durum': 'durum', 'acan_personel_id': 'acan_personel_id', 'ara_toplam': 'ara_toplam', 'indirim': 'indirim', 'ikram': 'ikram', 'toplam': 'toplam', 'acilis': 'acilis', 'kapanis': 'kapanis', 'updated_at': 'updated_at'},
    'adisyon_kalemleri': {'id': 'server_id', 'uuid': 'uuid', 'adisyon_id': 'adisyon_sid', 'urun_id': 'urun_sid', 'urun_adi': 'urun_adi', 'adet': 'adet', 'birim_fiyat': 'birim_fiyat', 'tutar': 'tutar', 'durum': 'durum', 'kur': 'kur', 'not': 'not_metni', 'personel_id': 'personel_id', 'gonderim_zamani': 'gonderim_zamani', 'updated_at': 'updated_at'},
    'odemeler': {'id': 'server_id', 'uuid': 'uuid', 'adisyon_id': 'adisyon_sid', 'tip': 'tip', 'tutar': 'tutar', 'bahsis': 'bahsis', 'personel_id': 'personel_id', 'created_at': 'created_at', 'updated_at': 'updated_at'},
  };
  // Backend'den datetime string gelen alanlar -> ms'e cevrilir (updated_at zaten ms)
  static const _dtAlanlar = {'acilis', 'kapanis', 'gonderim_zamani', 'created_at'};

  Future<String?> _token() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString('token');
  }

  /// Push + pull. ok: basari; degisti: push/pull'da gercek aktivite oldu mu
  /// (adaptif aralik icin — bos gecen turlarda istemci yavaslar, sunucu zorlanmaz).
  Future<({bool ok, bool degisti})> senkronla() async {
    if (_calisiyor) return (ok: false, degisti: false);
    _calisiyor = true;
    try {
      final token = await _token();
      if (token == null || token.isEmpty) return (ok: false, degisti: false);
      final pushAktif = await _push(token);
      final pullAktif = await _pull(token);
      return (ok: true, degisti: pushAktif || pullAktif);
    } catch (_) {
      return (ok: false, degisti: false);
    } finally {
      _calisiyor = false;
    }
  }

  // ----------------- PUSH -----------------  (aktivite oldu mu -> bool)
  Future<bool> _push(String token) async {
    final d = await LocalDb.instance.db;
    bool aktif = false;
    while (true) {
      final satirlar = await d.query('outbox', orderBy: 'created_at', limit: 200);
      if (satirlar.isEmpty) return aktif;
      aktif = true;

      final ops = satirlar
          .map((o) => {
                'entity': o['entity'],
                'op': o['op'],
                'row_uuid': o['row_uuid'],
                'idem_key': o['idem_key'],
                'payload': o['payload'], // zaten JSON string
              })
          .toList();

      final r = await http
          .post(Uri.parse('${AppConfig.baseUrl}/api/sync/push'),
              headers: {'Accept': 'application/json', 'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
              body: jsonEncode({'ops': ops}))
          .timeout(_zamanAsimi);
      if (r.statusCode != 200) throw Exception('push ${r.statusCode}');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final acks = (body['acks'] as List?) ?? [];

      for (final a in acks) {
        final idem = a['idem'] as String?;
        final uuid = a['uuid'] as String?;
        final entity = a['entity'] as String?;
        final sid = a['server_id'];
        if (idem == null) continue;
        if (a['hata'] != null) {
          // basarisiz -> outbox'ta kalsin, tries++
          await d.rawUpdate('UPDATE outbox SET tries = tries + 1, last_error = ? WHERE idem_key = ?', [a['hata'].toString(), idem]);
          continue;
        }
        // basarili -> server_id'yi yaz, dirty temizle, outbox'tan sil
        if (sid != null && uuid != null && entity != null && _pullCols.containsKey(entity)) {
          await d.update(entity, {'server_id': sid, 'dirty': 0}, where: 'uuid = ?', whereArgs: [uuid]);
        }
        await d.delete('outbox', where: 'idem_key = ?', whereArgs: [idem]);
      }
      if (satirlar.length < 200) return aktif; // son batch
    }
  }

  // ----------------- PULL -----------------  (degisiklik indi mi -> bool)
  Future<bool> _pull(String token) async {
    final d = await LocalDb.instance.db;
    final ss = await d.query('sync_state', where: "entity = 'ALL'", limit: 1);
    final cursor = ss.isEmpty ? 0 : int.tryParse('${ss.first['cursor']}') ?? 0;
    final entities = _pullCols.keys.join(',');

    final r = await http.get(
      Uri.parse('${AppConfig.baseUrl}/api/sync/pull?since=$cursor&entities=$entities'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    ).timeout(_zamanAsimi);
    if (r.statusCode != 200) throw Exception('pull ${r.statusCode}');
    final body = jsonDecode(r.body) as Map<String, dynamic>;
    final changes = (body['changes'] as Map?) ?? {};
    final yeniCursor = (body['cursor'] as num?)?.toInt() ?? cursor;

    for (final entry in changes.entries) {
      final entity = entry.key as String;
      final map = _pullCols[entity];
      if (map == null) continue;
      for (final row in (entry.value as List)) {
        await _uygula(d, entity, map, Map<String, dynamic>.from(row as Map));
      }
    }

    await d.insert('sync_state', {'entity': 'ALL', 'cursor': yeniCursor, 'last_pull_at': DateTime.now().millisecondsSinceEpoch},
        conflictAlgorithm: ConflictAlgorithm.replace);
    return changes.isNotEmpty;
  }

  /// YEREL DB'yi kucuk tut: senkronlanmis (dirty=0) + kapanmis (odendi/iptal) adisyonlari
  /// ve bagli kalem/odemelerini [gun] gunden eskiyse sil. Acik/gonderilmemis veri ASLA silinmez.
  /// Gecmis/rapor zaten bulutta; telefon sadece guncel + aktif veriyi tutar.
  Future<int> budaEski({int gun = 3}) async {
    final d = await LocalDb.instance.db;
    final esik = DateTime.now().subtract(Duration(days: gun)).millisecondsSinceEpoch;
    final hedef = await d.query('adisyonlar',
        columns: ['uuid'],
        where: "durum IN ('odendi','iptal') AND dirty = 0 AND (kapanis IS NOT NULL AND kapanis < ?)",
        whereArgs: [esik]);
    int n = 0;
    for (final a in hedef) {
      final u = a['uuid'] as String;
      // bagli kalemler/odemeler de dirty=0 degilse adisyonu silme (gonderilmemis veri koru)
      final bekleyen = await d.rawQuery(
          'SELECT 1 FROM adisyon_kalemleri WHERE adisyon_uuid=? AND dirty=1 '
          'UNION SELECT 1 FROM odemeler WHERE adisyon_uuid=? AND dirty=1 LIMIT 1',
          [u, u]);
      if (bekleyen.isNotEmpty) continue;
      await d.delete('adisyon_kalemleri', where: 'adisyon_uuid=?', whereArgs: [u]);
      await d.delete('odemeler', where: 'adisyon_uuid=?', whereArgs: [u]);
      await d.delete('adisyonlar', where: 'uuid=?', whereArgs: [u]);
      n++;
    }
    return n;
  }

  Future<void> _uygula(Database d, String entity, Map<String, String> map, Map<String, dynamic> backend) async {
    final yerel = <String, Object?>{};
    backend.forEach((bCol, val) {
      final lCol = map[bCol];
      if (lCol == null) return;
      if (_dtAlanlar.contains(bCol) && val is String && val.isNotEmpty) {
        yerel[lCol] = DateTime.tryParse(val)?.millisecondsSinceEpoch;
      } else {
        yerel[lCol] = val;
      }
    });
    final uuid = yerel['uuid'] as String?;
    if (uuid == null) return;

    // Cakisma korumasi: yerel satir dirty ise (gonderilmemis yerel degisiklik) ustune yazma
    final mevcut = await d.query(entity, columns: ['dirty'], where: 'uuid = ?', whereArgs: [uuid], limit: 1);
    if (mevcut.isNotEmpty && (mevcut.first['dirty'] as int? ?? 0) == 1) return;

    // Referans server_id -> yerel uuid cozumu (mumkunse)
    if (entity == 'adisyonlar' && yerel['masa_sid'] != null) {
      final m = await d.query('masalar', columns: ['uuid'], where: 'server_id = ?', whereArgs: [yerel['masa_sid']], limit: 1);
      if (m.isNotEmpty) yerel['masa_uuid'] = m.first['uuid'];
    }
    if ((entity == 'adisyon_kalemleri' || entity == 'odemeler') && yerel['adisyon_sid'] != null) {
      final a = await d.query('adisyonlar', columns: ['uuid'], where: 'server_id = ?', whereArgs: [yerel['adisyon_sid']], limit: 1);
      if (a.isNotEmpty) yerel['adisyon_uuid'] = a.first['uuid'];
    }

    yerel['dirty'] = 0;
    yerel['deleted'] = 0;
    await d.insert(entity, yerel, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

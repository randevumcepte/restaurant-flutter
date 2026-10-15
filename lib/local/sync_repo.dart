import 'dart:convert';
import 'local_db.dart';

/// Local-first yazma motoru.
///
/// TEK kural: her yazma, ayni transaction icinde (1) yerel tabloyu gunceller
/// (2) outbox'a bir islem ekler. UI yerelden aninda guncellenir; senkron iscisi
/// internet gelince outbox'i buluta bosaltir.
class SyncRepo {
  SyncRepo._();
  static final SyncRepo instance = SyncRepo._();

  int get _now => DateTime.now().millisecondsSinceEpoch;

  /// Yereli yaz + outbox'a kuyrukla. [row] uuid icermeli (yoksa uretilir).
  /// Donen: satirin uuid'i.
  Future<String> yaz(
    String entity,
    Map<String, Object?> row, {
    required String op, // insert | update | delete
  }) async {
    final d = await LocalDb.instance.db;
    final uuid = (row['uuid'] as String?) ?? LocalDb.yeniUuid();

    return d.transaction<String>((txn) async {
      final mevcut = await txn.query(entity, where: 'uuid = ?', whereArgs: [uuid], limit: 1);
      final varMi = mevcut.isNotEmpty;
      final rev = varMi ? ((mevcut.first['rev'] as int? ?? 0) + 1) : 0;

      final yazilacak = <String, Object?>{
        ...row,
        'uuid': uuid,
        'updated_at': _now,
        'dirty': 1,
        'deleted': op == 'delete' ? 1 : (row['deleted'] ?? (varMi ? mevcut.first['deleted'] : 0)),
        'rev': rev,
      };

      if (varMi) {
        // KISMI GUNCELLEME: sadece verilen alanlar degisir (REPLACE diger kolonlari silmesin).
        await txn.update(entity, yazilacak, where: 'uuid = ?', whereArgs: [uuid]);
      } else {
        await txn.insert(entity, yazilacak);
      }

      // Outbox'a BIRLESMIS tam satir gider -> bulut eksiksiz alir (insert/update ayni sekilde).
      final tamRow = (await txn.query(entity, where: 'uuid = ?', whereArgs: [uuid], limit: 1)).first;
      await txn.insert('outbox', {
        'entity': entity,
        'op': op,
        'row_uuid': uuid,
        'payload': jsonEncode(tamRow),
        'idem_key': '$entity:$uuid:$rev', // her degisim tekil
        'created_at': _now,
        'tries': 0,
      });
      return uuid;
    });
  }

  /// Tombstone sil (senkron geri getirmesin).
  Future<void> sil(String entity, String uuid) =>
      yaz(entity, {'uuid': uuid}, op: 'delete');

  /// Yerel okuma yardimcisi: silinmemis satirlar.
  Future<List<Map<String, Object?>>> listele(
    String entity, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
  }) async {
    final d = await LocalDb.instance.db;
    final w = where == null ? 'deleted = 0' : '($where) AND deleted = 0';
    return d.query(entity, where: w, whereArgs: whereArgs, orderBy: orderBy);
  }

  Future<Map<String, Object?>?> tek(String entity, String uuid) async {
    final d = await LocalDb.instance.db;
    final r = await d.query(entity,
        where: 'uuid = ? AND deleted = 0', whereArgs: [uuid], limit: 1);
    return r.isEmpty ? null : r.first;
  }
}

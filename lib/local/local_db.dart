import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
// ignore: unnecessary_import  (mobil veritabani fabrikasini kaydeder; silinmemeli)
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Local-first veritabani (SQLite / sqflite).
///
/// Ilke: uygulama HER ZAMAN yereli okur/yazar. Internet sadece arka plandaki
/// senkron iscisinin calismasini belirler (bkz. sync_repo + sync_worker).
///
/// Her senkronlanan tabloda ortak "sync meta" kolonlari:
///   uuid       TEXT  -> istemci uretir (PK); autoincrement YOK -> offline cihazlar cakismaz
///   server_id  INTEGER -> bulut MySQL'deki id (senkrondan sonra dolar)
///   updated_at INTEGER -> epoch ms (yerel degisim ani)
///   dirty      INTEGER -> 1: buluta gonderilmeyi bekliyor
///   deleted    INTEGER -> 1: tombstone (gercek silme degil; senkron geri getirmesin)
///   rev        INTEGER -> surum (cakisma tespiti / idempotency)
class LocalDb {
  LocalDb._();
  static final LocalDb instance = LocalDb._();

  static const _dosya = 'resteos_local.db';
  static const _surum = 1;

  Database? _db;

  Future<Database> get db async => _db ??= await _ac();

  Future<Database> _ac() async {
    final opts = OpenDatabaseOptions(
      version: _surum,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: _olustur,
    );
    // Masaustu (windows/linux/macos): sqflite yerine ffi motoru gerekir.
    final masaustu = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    if (masaustu) {
      sqfliteFfiInit();
      final dir = await getApplicationSupportDirectory();
      return databaseFactoryFfi.openDatabase(p.join(dir.path, _dosya), options: opts);
    }
    // Mobil (ios/android): varsayilan sqflite.
    final dir = await getDatabasesPath();
    return openDatabase(
      p.join(dir, _dosya),
      version: opts.version!,
      onConfigure: opts.onConfigure,
      onCreate: opts.onCreate,
    );
  }

  Future<void> _olustur(Database d, int v) async {
    final batch = d.batch();

    // --- MASALAR (durum: bos/dolu/rezerve) ---
    batch.execute('''
      CREATE TABLE masalar (
        uuid        TEXT PRIMARY KEY,
        server_id   INTEGER,
        sube_id     INTEGER,
        bolge_sid   INTEGER,          -- bolge server_id (salon/bahce...)
        ad          TEXT,
        sekil       TEXT DEFAULT 'kare',
        x           INTEGER DEFAULT 0,
        y           INTEGER DEFAULT 0,
        durum       TEXT DEFAULT 'bos',
        updated_at  INTEGER, dirty INTEGER DEFAULT 1, deleted INTEGER DEFAULT 0, rev INTEGER DEFAULT 0
      )''');

    // --- MENU: kategoriler ---
    batch.execute('''
      CREATE TABLE menu_kategorileri (
        uuid        TEXT PRIMARY KEY,
        server_id   INTEGER,
        sube_id     INTEGER,
        ad          TEXT,
        sira        INTEGER DEFAULT 0,
        aktif       INTEGER DEFAULT 1,
        updated_at  INTEGER, dirty INTEGER DEFAULT 1, deleted INTEGER DEFAULT 0, rev INTEGER DEFAULT 0
      )''');

    // --- MENU: urunler ---
    batch.execute('''
      CREATE TABLE urunler (
        uuid         TEXT PRIMARY KEY,
        server_id    INTEGER,
        sube_id      INTEGER,
        kategori_sid INTEGER,          -- kategori server_id
        ad           TEXT,
        aciklama     TEXT,
        fiyat        REAL DEFAULT 0,
        stok_takipli INTEGER DEFAULT 1,
        tukendi      INTEGER DEFAULT 0, -- 86
        aktif        INTEGER DEFAULT 1,
        gorsel       TEXT,
        updated_at   INTEGER, dirty INTEGER DEFAULT 1, deleted INTEGER DEFAULT 0, rev INTEGER DEFAULT 0
      )''');

    // --- ADISYONLAR (hesap) ---
    batch.execute('''
      CREATE TABLE adisyonlar (
        uuid         TEXT PRIMARY KEY,
        server_id    INTEGER,
        sube_id      INTEGER,
        masa_uuid    TEXT,             -- yerel masa referansi (server_id yokken de calisir)
        masa_sid     INTEGER,
        kanal        TEXT DEFAULT 'salon',
        durum        TEXT DEFAULT 'acik',  -- acik | odendi | iptal
        acan_personel_id INTEGER,
        ara_toplam   REAL DEFAULT 0,
        indirim      REAL DEFAULT 0,
        ikram        REAL DEFAULT 0,
        toplam       REAL DEFAULT 0,
        acilis       INTEGER,
        kapanis      INTEGER,
        updated_at   INTEGER, dirty INTEGER DEFAULT 1, deleted INTEGER DEFAULT 0, rev INTEGER DEFAULT 0
      )''');

    // --- ADISYON KALEMLERI (siparis satirlari) — mumkun oldugunca olay-tabanli ---
    batch.execute('''
      CREATE TABLE adisyon_kalemleri (
        uuid          TEXT PRIMARY KEY,
        server_id     INTEGER,
        adisyon_uuid  TEXT,
        adisyon_sid   INTEGER,
        urun_sid      INTEGER,
        urun_adi      TEXT,            -- snapshot
        adet          REAL DEFAULT 1,
        birim_fiyat   REAL DEFAULT 0,
        tutar         REAL DEFAULT 0,
        durum         TEXT DEFAULT 'yeni',  -- yeni | gonderildi | hazir | iptal
        kur           TEXT,
        not_metni     TEXT,
        personel_id   INTEGER,
        gonderim_zamani INTEGER,
        updated_at    INTEGER, dirty INTEGER DEFAULT 1, deleted INTEGER DEFAULT 0, rev INTEGER DEFAULT 0
      )''');

    // --- ODEMELER (append-only) ---
    batch.execute('''
      CREATE TABLE odemeler (
        uuid          TEXT PRIMARY KEY,
        server_id     INTEGER,
        adisyon_uuid  TEXT,
        adisyon_sid   INTEGER,
        tip           TEXT,            -- nakit | kredi | yemek_karti | acik
        tutar         REAL,
        bahsis        REAL DEFAULT 0,
        personel_id   INTEGER,
        created_at    INTEGER,
        updated_at    INTEGER, dirty INTEGER DEFAULT 1, deleted INTEGER DEFAULT 0, rev INTEGER DEFAULT 0
      )''');

    // --- OUTBOX: buluta gonderilecek islemler kuyrugu ---
    batch.execute('''
      CREATE TABLE outbox (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        entity       TEXT NOT NULL,   -- masalar | adisyonlar | adisyon_kalemleri | odemeler ...
        op           TEXT NOT NULL,   -- insert | update | delete
        row_uuid     TEXT NOT NULL,
        payload      TEXT NOT NULL,   -- satirin JSON hali
        idem_key     TEXT NOT NULL,   -- idempotency: ayni islem iki kez islenmesin
        created_at   INTEGER NOT NULL,
        tries        INTEGER DEFAULT 0,
        last_error   TEXT
      )''');
    batch.execute('CREATE UNIQUE INDEX ux_outbox_idem ON outbox(idem_key)');
    batch.execute('CREATE INDEX ix_outbox_created ON outbox(created_at)');

    // --- SYNC_STATE: her entity icin pull cursor'u ---
    batch.execute('''
      CREATE TABLE sync_state (
        entity       TEXT PRIMARY KEY,
        cursor       TEXT,            -- buluttan son alinan degisim imleci
        last_pull_at INTEGER
      )''');

    await batch.commit(noResult: true);
  }

  /// Yeni yerel kimlik: zaman + rastgele -> offline cihazlar arasinda cakismaz.
  /// (Ileride cihaz kimligi de eklenebilir; simdilik ms+random yeterli.)
  static String yeniUuid() {
    final ms = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = Random.secure();
    final rnd = List.generate(8, (_) => r.nextInt(36).toRadixString(36)).join();
    return '$ms$rnd';
  }

  Future<void> kapat() async {
    await _db?.close();
    _db = null;
  }
}

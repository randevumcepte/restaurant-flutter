import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'local_db.dart';
import 'adisyon_repo.dart';
import 'sync_repo.dart';

/// IN-PROCESS OFFLINE MOTORU (bagimsiz / kasa cihazinin KENDI islemleri icin).
///
/// KasaSunucu terminallere HTTP uzerinden offline hizmet verir; bu motor ise
/// AYNI cihazin kendi POS cagrilari internet yokken buluta gidemeyince devreye
/// girer (Api connection-error fallback). KasaSunucu'ya DOKUNMAZ — terminal+kasa
/// topolojisi (rowid uzay) oldugu gibi korunur; burada bagimsiz cihaz online'da
/// server_id kullandigi icin adisyon cozumu server_id ONCELIKLI yapilir.
///
/// Donus sekilleri bilerek Api'nin bulut yanitlariyla AYNI (ekranlar fark etmez).
class YerelMotor {
  YerelMotor._();
  static final YerelMotor instance = YerelMotor._();

  // OFSET: offline-uretilmis adisyon tutamagi = rowid + _ofset. Boylece kucuk
  // server_id'lerle (bulut adisyonlari) ASLA cakismaz -> yanlis adisyona yazma biter.
  static const int _ofset = 1000000000;

  // Adisyon kimligi cozumu: tutamac >= _ofset ise YEREL (rowid), degilse bulut (server_id).
  Future<Map<String, Object?>?> _adisyonBul(int id) async {
    final d = await LocalDb.instance.db;
    final List<Map<String, Object?>> r;
    if (id >= _ofset) {
      r = await d.rawQuery(
          'SELECT rowid, * FROM adisyonlar WHERE rowid = ? AND deleted = 0 LIMIT 1', [id - _ofset]);
    } else {
      r = await d.rawQuery(
          'SELECT rowid, * FROM adisyonlar WHERE server_id = ? AND deleted = 0 LIMIT 1', [id]);
    }
    return r.isEmpty ? null : r.first;
  }

  // Ekrana/çağrılara verilecek tutamaç: senkronlanmışsa server_id, değilse rowid+_ofset.
  int _handle(Map<String, Object?> row) =>
      (row['server_id'] as int?) ?? ((row['rowid'] as int) + _ofset);

  // Fişte gösterilecek DOSTANE numara (küçük): server_id ya da rowid (ofsetsiz).
  int _fisNo(Map<String, Object?> row) =>
      (row['server_id'] as int?) ?? (row['rowid'] as int);

  String _tarih() {
    final n = DateTime.now();
    String i2(int x) => x.toString().padLeft(2, '0');
    return '${i2(n.day)}.${i2(n.month)}.${n.year} ${i2(n.hour)}:${i2(n.minute)}';
  }

  // --- MASALAR: online /api/masalar ile ayni sekil (id = server masa id). ---
  Future<Map<String, dynamic>> masalar() async {
    final d = await LocalDb.instance.db;
    final masalar = await d.query('masalar', where: 'deleted = 0', orderBy: 'ad');
    final liste = <Map<String, Object?>>[];
    for (final m in masalar) {
      final acik = await d.rawQuery(
          "SELECT rowid, server_id, toplam FROM adisyonlar WHERE masa_uuid = ? AND durum='acik' AND deleted=0 LIMIT 1",
          [m['uuid']]);
      final a = acik.isNotEmpty ? acik.first : null;
      liste.add({
        'id': m['server_id'], // masalar hep senkronlu -> server_id (online ile tutarli)
        'ad': m['ad'],
        'durum': a != null ? 'dolu' : (m['durum'] ?? 'bos'),
        'adisyon_id': a != null ? _handle(a) : null,
        'tutar': a != null ? a['toplam'] : 0,
      });
    }
    return {'ok': 1, 'masalar': liste, 'offline': 1};
  }

  // --- MASALAR (BÖLGELİ): online /api/masalar önbelleğini TEMEL al (bölge/ad/kapasite
  //     korunur), DOLULUK'u yerelden bindir (offline açılan/kapanan masalar dahil). ---
  Future<Map<String, dynamic>> masalarOverlay(Map<String, dynamic> cached) async {
    final d = await LocalDb.instance.db;
    final list = (cached['masalar'] as List?) ?? [];
    final out = <Map<String, dynamic>>[];
    for (final m in list) {
      final mm = Map<String, dynamic>.from(m as Map);
      final sid = (mm['id'] is num) ? (mm['id'] as num).toInt() : int.tryParse('${mm['id']}') ?? 0;
      // Yerel masa uuid'sini çöz: offline-açılan adisyon masa_UUID ile bağlı (masa_sid NULL olabilir).
      final masaRow = await d.query('masalar', columns: ['uuid'], where: 'server_id = ?', whereArgs: [sid], limit: 1);
      final masaUuid = masaRow.isNotEmpty ? masaRow.first['uuid'] : null;
      final acik = await d.rawQuery(
          "SELECT rowid, server_id, toplam FROM adisyonlar WHERE durum = 'acik' AND deleted = 0 AND (masa_uuid = ? OR masa_sid = ?) LIMIT 1",
          [masaUuid, sid]);
      if (acik.isNotEmpty) {
        mm['durum'] = 'dolu';
        mm['adisyon_id'] = _handle(acik.first);
        mm['tutar'] = acik.first['toplam'];
      } else {
        // OFFLINE DOLULUK = YEREL OTORİTE. Yerelde açık adisyon yoksa masa BOŞ.
        // (Senkronlanmamış bulut adisyonuna offline müdahale edilemez; garson temiz
        //  yeni adisyon açıp çalışır. Bulut adisyonu online dönünce yerinde durur.)
        mm['durum'] = 'bos';
        mm['adisyon_id'] = null;
        mm['tutar'] = 0;
      }
      out.add(mm);
    }
    return {'ok': 1, 'masalar': out, 'offline': 1};
  }

  // --- MENU: online /api/menu ile AYNI sekil (ekran id/kategori_id/fiyat bekler).
  //     SQLite kolonlari (server_id/kategori_sid) backend anahtarlarina cevrilir. ---
  Future<Map<String, dynamic>> menu() async {
    final d = await LocalDb.instance.db;
    final kat = await d.query('menu_kategorileri', where: 'deleted = 0 AND aktif = 1', orderBy: 'sira, ad');
    final urun = await d.query('urunler', where: 'deleted = 0 AND aktif = 1', orderBy: 'ad');
    return {
      'ok': 1,
      'offline': 1,
      'kategoriler': kat.map((k) => {
            'id': k['server_id'], 'ad': k['ad'], 'sira': k['sira'], 'aktif': k['aktif'],
          }).toList(),
      'urunler': urun.map((u) => {
            'id': u['server_id'],
            'kategori_id': u['kategori_sid'],
            'ad': u['ad'],
            'aciklama': u['aciklama'],
            'fiyat': (u['fiyat'] as num?)?.toDouble() ?? 0,
            'gorsel': u['gorsel'],
            'tukendi': u['tukendi'],
            'aktif': u['aktif'],
            'istasyon': 'mutfak', // SQLite'ta istasyon yok -> offline varsayilan
          }).toList(),
    };
  }

  // --- MASA AC: yerel adisyon olustur (cift acilmayi onle). Donus: adisyon_id tutamagi. ---
  Future<Map<String, dynamic>> masaAc(int masaServerId, int misafir) async {
    final d = await LocalDb.instance.db;
    final masaRows = await d.query('masalar',
        where: 'server_id = ? AND deleted = 0', whereArgs: [masaServerId], limit: 1);
    if (masaRows.isEmpty) return {'ok': 0, 'hata': 'Masa bulunamadı (çevrimdışı)'};
    final masa = masaRows.first;
    final masaUuid = masa['uuid'] as String;
    final subeId = (masa['sube_id'] as int?) ?? 0;

    final acik = await d.rawQuery(
        "SELECT rowid, server_id FROM adisyonlar WHERE masa_uuid = ? AND durum='acik' AND deleted=0 LIMIT 1",
        [masaUuid]);
    if (acik.isNotEmpty) {
      return {'ok': 1, 'adisyon_id': _handle(acik.first), 'mesaj': '${masa['ad']} zaten açık.', 'offline': 1};
    }

    final uuid = await AdisyonRepo.instance.masaAc(masaUuid: masaUuid, subeId: subeId, masaSid: masaServerId);
    final yeni = await d.rawQuery('SELECT rowid, server_id FROM adisyonlar WHERE uuid = ?', [uuid]);
    final handle = yeni.isNotEmpty ? _handle(yeni.first) : null;
    return {'ok': 1, 'adisyon_id': handle, 'mesaj': '${masa['ad']} açıldı ($misafir kişi).', 'offline': 1};
  }

  // --- SIPARIS EKLE: kalemleri adisyona ekle + mutfaga dus (durum=gonderildi). ---
  Future<Map<String, dynamic>> siparisEkle(int adisyonHandle, List kalemler) async {
    final ad = await _adisyonBul(adisyonHandle);
    if (ad == null) return {'ok': 0, 'hata': 'Adisyon bulunamadı (çevrimdışı)'};
    final adisyonUuid = ad['uuid'] as String;
    final d = await LocalDb.instance.db;
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
    final son = await d.query('adisyonlar', columns: ['toplam'], where: 'uuid = ?', whereArgs: [adisyonUuid], limit: 1);
    return {'ok': 1, 'offline': 1, 'eklenen': eklenen, 'toplam': son.isNotEmpty ? son.first['toplam'] : 0, 'mesaj': 'Sipariş eklendi (çevrimdışı)'};
  }

  // --- FIS: hesap fisi (adisyon + kalemler + odemeler). ---
  Future<Map<String, dynamic>> fis(int adisyonHandle) async {
    final d = await LocalDb.instance.db;
    final ad = await _adisyonBul(adisyonHandle);
    if (ad == null) return {'ok': 0, 'hata': 'Adisyon bulunamadı (çevrimdışı)'};
    final uuid = ad['uuid'] as String;
    final kalemler = await d.rawQuery(
        "SELECT urun_adi, adet, birim_fiyat, tutar, ikram FROM adisyon_kalemleri WHERE adisyon_uuid = ? AND durum != 'iptal' AND deleted = 0 ORDER BY updated_at",
        [uuid]);
    final odemeler = await d.rawQuery(
        'SELECT tip, tutar FROM odemeler WHERE adisyon_uuid = ? AND deleted = 0', [uuid]);
    String? masaAd;
    if (ad['masa_uuid'] != null) {
      final mm = await d.query('masalar', columns: ['ad'], where: 'uuid = ?', whereArgs: [ad['masa_uuid']], limit: 1);
      if (mm.isNotEmpty) masaAd = mm.first['ad'] as String?;
    }
    return {
      'ok': 1, 'offline': 1,
      'isletme': '', 'adres': '', 'telefon': '',
      'masa': masaAd ?? (ad['kanal'] ?? 'Masa'), 'garson': '-',
      'tarih': _tarih(), 'adisyon_no': _fisNo(ad),
      'kalemler': kalemler.map((k) => {
            'ad': k['urun_adi'], 'adet': (k['adet'] as num?)?.toDouble() ?? 0,
            'birim_fiyat': (k['birim_fiyat'] as num?)?.toDouble() ?? 0, 'tutar': (k['tutar'] as num?)?.toDouble() ?? 0,
            'ikram': (k['ikram'] as num?)?.toInt() ?? 0,
          }).toList(),
      'birlesik_masalar': [],
      'ara_toplam': ad['ara_toplam'], 'indirim': ad['indirim'], 'ikram': ad['ikram'], 'toplam': ad['toplam'],
      'odemeler': odemeler.map((o) => {'tip': o['tip'], 'tutar': (o['tutar'] as num?)?.toDouble() ?? 0}).toList(),
    };
  }

  // --- KALEMLER: satis ekrani kalem listesi. ---
  Future<Map<String, dynamic>> kalemler(int adisyonHandle) async {
    final d = await LocalDb.instance.db;
    final ad = await _adisyonBul(adisyonHandle);
    if (ad == null) return {'ok': 0, 'hata': 'Adisyon bulunamadı (çevrimdışı)'};
    final uuid = ad['uuid'] as String;
    final kalemler = await d.rawQuery(
        'SELECT rowid AS id, urun_adi, adet, tutar, durum, ikram FROM adisyon_kalemleri WHERE adisyon_uuid = ? AND deleted = 0 ORDER BY updated_at',
        [uuid]);
    final gecerli = kalemler.where((k) => k['durum'] != 'iptal');
    final toplam = gecerli.fold<double>(0, (t, k) => t + ((k['tutar'] as num?)?.toDouble() ?? 0));
    final odemeler = await d.rawQuery('SELECT tutar FROM odemeler WHERE adisyon_uuid = ? AND deleted = 0', [uuid]);
    final odenen = odemeler.fold<double>(0, (t, o) => t + ((o['tutar'] as num?)?.toDouble() ?? 0));
    return {
      'ok': 1, 'offline': 1,
      'kalemler': kalemler.map((k) => {
            'id': k['id'], 'ad': k['urun_adi'], 'adet': (k['adet'] as num?)?.round() ?? 0,
            'tutar': (k['tutar'] as num?)?.toDouble() ?? 0, 'odeme_durum': 'acik',
            'durum': k['durum'] ?? 'gonderildi', 'ikram': (k['ikram'] as num?)?.toInt() ?? 0,
          }).toList(),
      'toplam': toplam, 'kalan': (toplam - odenen).clamp(0, double.infinity),
    };
  }

  // Yönetici PIN'i yerelde doğrula (girişte cache'lenen hash listesine karşı). Offline onay.
  Future<bool> _yetkiliPinGecerli(String? pin) async {
    if (pin == null || pin.trim().isEmpty) return false;
    try {
      final sp = await SharedPreferences.getInstance();
      final kayit = sp.getString('yetkili_pinler_v1');
      if (kayit == null) return false;
      final list = jsonDecode(kayit) as List;
      final h = sha256.convert(utf8.encode('rpos|${pin.trim()}')).toString();
      return list.any((e) => (e as Map)['pin_hash'] == h);
    } catch (_) {
      return false;
    }
  }

  // --- İŞLEM: ODEME/KAPAT (herkes) + İKRAM/İSKONTO (yönetici PIN ile, offline onay).
  //     Diğer işlemler (void vb.) offline DESTEKLENMEZ -> null (Api rethrow/eder). ---
  Future<Map<String, dynamic>?> islem({
    required String islem,
    required int adisyonHandle,
    String? odemeTip,
    double? tutar,
    double? oran,
    String? onayPin,
    String? kalemIdler,
  }) async {
    // İKRAM / İSKONTO: yönetici PIN'i yerelde doğrula, adisyon indirim/ikram'ı güncelle.
    if (islem == 'ikram' || islem == 'iskonto') {
      if (!await _yetkiliPinGecerli(onayPin)) {
        return {'ok': 0, 'offline': 1, 'hata': 'Yönetici PIN geçersiz (çevrimdışı onay)'};
      }
      final ad = await _adisyonBul(adisyonHandle);
      if (ad == null) return {'ok': 0, 'hata': 'Adisyon bulunamadı (çevrimdışı)'};
      if (ad['durum'] != 'acik') return {'ok': 0, 'hata': 'Bu adisyon zaten kapanmış.'};
      final uuid = ad['uuid'] as String;
      final d = await LocalDb.instance.db;
      final ara = (ad['ara_toplam'] as num?)?.toDouble() ?? 0;
      double indirim = (ad['indirim'] as num?)?.toDouble() ?? 0;
      double ikram = (ad['ikram'] as num?)?.toDouble() ?? 0;
      if (islem == 'iskonto') {
        indirim = (ara * (oran ?? 0) / 100);
      } else {
        ikram = ikram + (tutar ?? 0); // seçilen ürünlerin tutarı kadar ikram eklenir
        // SEÇİLEN KALEMLERİ ikram İŞARETLE (fişte üstü çizili görünsün). kalemIdler = rowid listesi.
        final rowids = (kalemIdler ?? '').split(',').map((s) => int.tryParse(s.trim())).whereType<int>().toList();
        if (rowids.isNotEmpty) {
          final yer = rowids.map((_) => '?').join(',');
          await d.rawUpdate('UPDATE adisyon_kalemleri SET ikram = 1 WHERE adisyon_uuid = ? AND rowid IN ($yer)', [uuid, ...rowids]);
        }
      }
      final yeniToplam = (ara - indirim - ikram).clamp(0, double.infinity).toDouble();
      await SyncRepo.instance.yaz('adisyonlar', {
        'uuid': uuid, 'indirim': indirim, 'ikram': ikram, 'toplam': yeniToplam,
      }, op: 'update');
      return {
        'ok': 1, 'offline': 1,
        'mesaj': islem == 'iskonto' ? 'İskonto uygulandı (çevrimdışı)' : 'İkram uygulandı (çevrimdışı)',
      };
    }
    if (islem != 'ode' && islem != 'kapat') return null; // offline sadece odeme/kapat/ikram/iskonto
    final ad = await _adisyonBul(adisyonHandle);
    if (ad == null) return {'ok': 0, 'hata': 'Adisyon bulunamadı (çevrimdışı)'};
    if (ad['durum'] != 'acik') return {'ok': 0, 'hata': 'Bu adisyon zaten kapanmış.'};
    final uuid = ad['uuid'] as String;
    final toplam = (ad['toplam'] as num?)?.toDouble() ?? 0;
    final d = await LocalDb.instance.db;
    final odemeler = await d.rawQuery('SELECT tutar FROM odemeler WHERE adisyon_uuid = ? AND deleted = 0', [uuid]);
    final odenen = odemeler.fold<double>(0, (t, o) => t + ((o['tutar'] as num?)?.toDouble() ?? 0));
    final double kalan = (toplam - odenen).clamp(0, double.infinity).toDouble();
    const tipGecerli = ['nakit', 'kredi', 'yemek_karti'];
    final tip = tipGecerli.contains(odemeTip) ? odemeTip! : 'nakit';
    final double uygulanan = islem == 'kapat' ? kalan : ((tutar != null && tutar > 0) ? tutar : kalan);
    await AdisyonRepo.instance.odemeEkle(adisyonUuid: uuid, tip: tip, tutar: uygulanan);
    return {'ok': 1, 'offline': 1, 'mesaj': 'Ödeme alındı (çevrimdışı)'};
  }

  String _kanalAd(String? k) {
    switch (k) {
      case 'paket': return 'Paket';
      case 'gelal': return 'Gel-Al';
      default: return (k == null || k.isEmpty) ? 'Masa' : (k[0].toUpperCase() + k.substring(1));
    }
  }

  // --- MUTFAK (KDS): online /api/mutfak ile AYNI yapı -> 'siparisler' ADİSYONA GÖRE GRUPLU.
  //     (Ekran res['siparisler'] okur; düz 'kalemler' döndürmek boş gösteriyordu.) ---
  Future<Map<String, dynamic>> mutfak() async {
    final d = await LocalDb.instance.db;
    final rows = await d.rawQuery('''
      SELECT k.rowid AS id, k.urun_adi, k.adet, k.not_metni AS notu, k.kur, k.gonderim_zamani, k.durum,
             COALESCE(a.server_id, a.rowid + 1000000000) AS adisyon_id, a.kanal, m.ad AS masa
      FROM adisyon_kalemleri k
      JOIN adisyonlar a ON k.adisyon_uuid = a.uuid AND a.deleted = 0
      LEFT JOIN masalar m ON a.masa_uuid = m.uuid
      WHERE a.durum = 'acik' AND k.deleted = 0 AND k.durum IN ('gonderildi','hazirlaniyor')
      ORDER BY k.gonderim_zamani, k.rowid
    ''');
    final now = DateTime.now().millisecondsSinceEpoch;
    final grup = <int, Map<String, dynamic>>{};
    double toplamBekleyen = 0;
    for (final k in rows) {
      final aid = (k['adisyon_id'] as num).toInt();
      final gz = (k['gonderim_zamani'] as num?)?.toInt();
      final dk = gz != null ? ((now - gz) / 60000).floor().clamp(0, 1 << 30) : 0;
      final adet = (k['adet'] as num?)?.toDouble() ?? 1;
      toplamBekleyen += adet;
      final g = grup.putIfAbsent(aid, () => {
            'adisyon_id': aid,
            'masa': (k['masa'] as String?) ?? _kanalAd(k['kanal']?.toString()),
            'kanal': k['kanal'],
            'masali': k['masa'] != null,
            'gecen': dk, 'dk': dk, 'hedef': 15, 'kalan': 15 - dk,
            'hazirlik_gecen': 0, 'basladi': false, 'asama': 'yeni', 'renk': '#6366F1',
            'kalemler': <Map<String, dynamic>>[],
          });
      if ((g['gecen'] as int) < dk) { g['gecen'] = dk; g['dk'] = dk; g['kalan'] = 15 - dk; }
      if (k['durum'] == 'hazirlaniyor') { g['basladi'] = true; g['asama'] = 'hazirlaniyor'; }
      (g['kalemler'] as List).add({
        'id': k['id'], 'ad': k['urun_adi'], 'adet': adet, 'not': k['notu'],
        'kur': k['kur'], 'istasyon': 'mutfak', 'durum': k['durum'],
      });
    }
    return {
      'ok': 1, 'offline': 1,
      'siparisler': grup.values.toList(),
      'istasyonlar': const [], 'toplu': const [], 'toplam_bekleyen': toplamBekleyen.round(),
    };
  }

  // --- MUTFAK DURUM: basla/hazir/servis — adisyonun uygun kalemlerini gunceller. ---
  Future<Map<String, dynamic>> mutfakDurum(int adisyonHandle, String yeni, List<String> kaynak) async {
    final ad = await _adisyonBul(adisyonHandle);
    if (ad == null) return {'ok': 0, 'hata': 'Adisyon bulunamadı (çevrimdışı)'};
    final uuid = ad['uuid'] as String;
    final d = await LocalDb.instance.db;
    final yer = kaynak.map((_) => '?').join(',');
    final kalemler = await d.rawQuery(
        'SELECT uuid FROM adisyon_kalemleri WHERE adisyon_uuid = ? AND deleted = 0 AND durum IN ($yer)',
        [uuid, ...kaynak]);
    for (final k in kalemler) {
      await SyncRepo.instance.yaz('adisyon_kalemleri', {'uuid': k['uuid'], 'durum': yeni}, op: 'update');
    }
    return {'ok': 1, 'offline': 1, 'guncellenen': kalemler.length};
  }
}

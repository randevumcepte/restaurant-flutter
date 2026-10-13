import 'sync_repo.dart';

/// Cekirdek POS dongusu — tamamen YEREL calisir (internet gerekmez).
/// Hesap/toplam Dart'ta hesaplanir; her yazma outbox'a kuyruklanir.
class AdisyonRepo {
  AdisyonRepo._();
  static final AdisyonRepo instance = AdisyonRepo._();
  final _r = SyncRepo.instance;

  /// Masayi ac -> yeni adisyon olustur + masayi 'dolu' yap. Donen: adisyon uuid.
  Future<String> masaAc({
    required String masaUuid,
    required int subeId,
    int? masaSid,
    int? personelId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final uuid = await _r.yaz('adisyonlar', {
      'sube_id': subeId,
      'masa_uuid': masaUuid,
      'masa_sid': masaSid,
      'kanal': 'salon',
      'durum': 'acik',
      'acan_personel_id': personelId,
      'ara_toplam': 0, 'indirim': 0, 'ikram': 0, 'toplam': 0,
      'acilis': now,
    }, op: 'insert');
    await _r.yaz('masalar', {'uuid': masaUuid, 'durum': 'dolu'}, op: 'update');
    return uuid;
  }

  /// Masanin acik adisyonu (varsa).
  Future<Map<String, Object?>?> acikAdisyon(String masaUuid) async {
    final l = await _r.listele('adisyonlar',
        where: "masa_uuid = ? AND durum = 'acik'", whereArgs: [masaUuid]);
    return l.isEmpty ? null : l.first;
  }

  /// Siparis kalemi ekle (olay) + adisyon toplamlarini yeniden hesapla.
  Future<String> kalemEkle({
    required String adisyonUuid,
    int? urunSid,
    required String urunAdi,
    double adet = 1,
    required double birimFiyat,
    int? personelId,
    String? not,
  }) async {
    final uuid = await _r.yaz('adisyon_kalemleri', {
      'adisyon_uuid': adisyonUuid,
      'urun_sid': urunSid,
      'urun_adi': urunAdi,
      'adet': adet,
      'birim_fiyat': birimFiyat,
      'tutar': adet * birimFiyat,
      'durum': 'yeni',
      'not_metni': not,
      'personel_id': personelId,
    }, op: 'insert');
    await _toplamYenile(adisyonUuid);
    return uuid;
  }

  Future<List<Map<String, Object?>>> kalemler(String adisyonUuid) =>
      _r.listele('adisyon_kalemleri',
          where: "adisyon_uuid = ? AND durum != 'iptal'",
          whereArgs: [adisyonUuid],
          orderBy: 'updated_at');

  /// Yerel hesap: kalemlerden ara_toplam/toplam hesapla, adisyonu guncelle.
  Future<void> _toplamYenile(String adisyonUuid) async {
    final kl = await kalemler(adisyonUuid);
    final ara = kl.fold<double>(0, (t, k) => t + ((k['tutar'] as num?)?.toDouble() ?? 0));
    final ad = await _r.tek('adisyonlar', adisyonUuid);
    final indirim = (ad?['indirim'] as num?)?.toDouble() ?? 0;
    final ikram = (ad?['ikram'] as num?)?.toDouble() ?? 0;
    await _r.yaz('adisyonlar', {
      'uuid': adisyonUuid,
      'ara_toplam': ara,
      'toplam': (ara - indirim - ikram).clamp(0, double.infinity),
    }, op: 'update');
  }

  /// Nakit odeme ekle; toplam karsilandiysa adisyonu kapat + masayi bosalt.
  Future<void> odemeEkle({
    required String adisyonUuid,
    required String tip, // nakit | kredi | yemek_karti
    required double tutar,
    double bahsis = 0,
    int? personelId,
  }) async {
    await _r.yaz('odemeler', {
      'adisyon_uuid': adisyonUuid,
      'tip': tip,
      'tutar': tutar,
      'bahsis': bahsis,
      'personel_id': personelId,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    }, op: 'insert');

    final ad = await _r.tek('adisyonlar', adisyonUuid);
    final toplam = (ad?['toplam'] as num?)?.toDouble() ?? 0;
    final odemeler = await _r.listele('odemeler',
        where: 'adisyon_uuid = ?', whereArgs: [adisyonUuid]);
    final odenen = odemeler.fold<double>(0, (t, o) => t + ((o['tutar'] as num?)?.toDouble() ?? 0));

    if (odenen + 0.001 >= toplam && toplam > 0) {
      await _r.yaz('adisyonlar', {
        'uuid': adisyonUuid,
        'durum': 'odendi',
        'kapanis': DateTime.now().millisecondsSinceEpoch,
      }, op: 'update');
      final masaUuid = ad?['masa_uuid'] as String?;
      if (masaUuid != null) {
        await _r.yaz('masalar', {'uuid': masaUuid, 'durum': 'bos'}, op: 'update');
      }
    }
  }
}

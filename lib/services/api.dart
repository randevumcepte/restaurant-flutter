import 'dart:convert';
import 'package:http/http.dart' as http;

/// RestoOS backend (Laravel) — restoran API'si.
class Api {
  static const String base = 'https://restaurant.webfirmam.com.tr';

  static Future<Map<String, dynamic>> login(String pin) async {
    final r = await http.post(
      Uri.parse('$base/api/login'),
      headers: {'Accept': 'application/json'},
      body: {'pin': pin},
    );
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _get(String path, String token) async {
    final r = await http.get(
      Uri.parse('$base$path'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (r.statusCode == 401) {
      throw ApiYetkiHatasi();
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> patronOzet(String token, {String period = 'gunluk'}) =>
      _get('/api/patron/ozet?period=$period', token);
  static Future<Map<String, dynamic>> detay(String token,
          {required String tip, int? id, String? alt, String period = 'haftalik'}) =>
      _get('/api/patron/detay?tip=$tip&period=$period${id != null ? '&id=$id' : ''}${alt != null ? '&alt=$alt' : ''}', token);

  static Future<Map<String, dynamic>> aiAnaliz(String token,
          {required String kapsam, int? id, String period = 'haftalik'}) =>
      _get('/api/patron/ai-analiz?kapsam=$kapsam&period=$period${id != null ? '&id=$id' : ''}', token);

  static Future<Map<String, dynamic>> asistanSor(String token, String soru) async {
    final r = await http.post(
      Uri.parse('$base/api/patron/asistan-sor'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: {'soru': soru},
    );
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> adisyonIslem(String token,
      {required String islem, required int adisyonId, String? odemeTip, double? oran, double? tutar, String? sebep, String? onayPin, String? kalemIdler, int? cariId}) async {
    final body = <String, String>{'islem': islem, 'adisyon_id': '$adisyonId'};
    if (odemeTip != null) body['odeme_tip'] = odemeTip;
    if (oran != null) body['oran'] = '$oran';
    if (tutar != null) body['tutar'] = '$tutar';
    if (sebep != null && sebep.isNotEmpty) body['sebep'] = sebep;
    if (onayPin != null && onayPin.isNotEmpty) body['onay_pin'] = onayPin;
    if (kalemIdler != null && kalemIdler.isNotEmpty) body['kalem_idler'] = kalemIdler;
    if (cariId != null) body['cari_id'] = '$cariId';
    final r = await http.post(
      Uri.parse('$base/api/patron/adisyon-islem'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: body,
    );
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> personeller(String token) => _get('/api/patron/personeller', token);

  static Future<Map<String, dynamic>> yetkiKaydet(String token, int personelId, Map<String, bool> yetkiler, double iskontoLimit, double ikramLimit) async {
    final r = await http.post(
      Uri.parse('$base/api/patron/yetki-kaydet'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: {'personel_id': '$personelId', 'yetkiler': jsonEncode(yetkiler), 'iskonto_limit': '$iskontoLimit', 'ikram_limit': '$ikramLimit'},
    );
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> masaAc(String token, int masaId, int misafir) async {
    final r = await http.post(
      Uri.parse('$base/api/patron/masa-ac'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: {'masa_id': '$masaId', 'misafir': '$misafir'},
    );
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> cariler(String token) => _get('/api/patron/cariler', token);
  static Future<Map<String, dynamic>> cariDetay(String token, int id) => _get('/api/patron/cari-detay?id=$id', token);

  static Future<Map<String, dynamic>> cariTahsilat(String token, int cariId, double tutar, String odemeSekli) async {
    final r = await http.post(Uri.parse('$base/api/patron/cari-tahsilat'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        body: {'cari_id': '$cariId', 'tutar': '$tutar', 'odeme_sekli': odemeSekli});
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> cariEkle(String token, String ad, String tip, String telefon) async {
    final r = await http.post(Uri.parse('$base/api/patron/cari-ekle'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
        body: {'ad': ad, 'tip': tip, 'telefon': telefon});
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> menu(String token) => _get('/api/menu', token);

  static Future<Map<String, dynamic>> adisyonUrunEkle(String token, int adisyonId, List<Map<String, int>> kalemler) async {
    final r = await http.post(
      Uri.parse('$base/api/patron/adisyon-urun-ekle'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: {'adisyon_id': '$adisyonId', 'kalemler': jsonEncode(kalemler)},
    );
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> kalemVoid(String token, int adisyonId, int kalemId, {String? sebep, String? onayPin}) async {
    final body = <String, String>{'adisyon_id': '$adisyonId', 'kalem_id': '$kalemId'};
    if (sebep != null && sebep.isNotEmpty) body['sebep'] = sebep;
    if (onayPin != null && onayPin.isNotEmpty) body['onay_pin'] = onayPin;
    final r = await http.post(Uri.parse('$base/api/patron/kalem-void'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}, body: body);
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> mutfak(String token) => _get('/api/mutfak', token);

  static Future<Map<String, dynamic>> mutfakHazir(String token, {int? kalemId, int? adisyonId}) async {
    final body = <String, String>{};
    if (kalemId != null) body['kalem_id'] = '$kalemId';
    if (adisyonId != null) body['adisyon_id'] = '$adisyonId';
    final r = await http.post(Uri.parse('$base/api/mutfak/hazir'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}, body: body);
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> masalar(String token) => _get('/api/masalar', token);
  static Future<Map<String, dynamic>> paket(String token) => _get('/api/paket', token);
  static Future<Map<String, dynamic>> paketDetay(String token, int id) => _get('/api/paket/$id', token);
  static Future<Map<String, dynamic>> raporlar(String token) => _get('/api/raporlar', token);
}

class ApiYetkiHatasi implements Exception {}

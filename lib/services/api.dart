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
      {required String islem, required int adisyonId, String? odemeTip, double? oran, double? tutar, String? sebep, String? onayPin}) async {
    final body = <String, String>{'islem': islem, 'adisyon_id': '$adisyonId'};
    if (odemeTip != null) body['odeme_tip'] = odemeTip;
    if (oran != null) body['oran'] = '$oran';
    if (tutar != null) body['tutar'] = '$tutar';
    if (sebep != null && sebep.isNotEmpty) body['sebep'] = sebep;
    if (onayPin != null && onayPin.isNotEmpty) body['onay_pin'] = onayPin;
    final r = await http.post(
      Uri.parse('$base/api/patron/adisyon-islem'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: body,
    );
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> personeller(String token) => _get('/api/patron/personeller', token);

  static Future<Map<String, dynamic>> yetkiKaydet(String token, int personelId, Map<String, bool> yetkiler, double iskontoLimit) async {
    final r = await http.post(
      Uri.parse('$base/api/patron/yetki-kaydet'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      body: {'personel_id': '$personelId', 'yetkiler': jsonEncode(yetkiler), 'iskonto_limit': '$iskontoLimit'},
    );
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> masalar(String token) => _get('/api/masalar', token);
  static Future<Map<String, dynamic>> paket(String token) => _get('/api/paket', token);
  static Future<Map<String, dynamic>> paketDetay(String token, int id) => _get('/api/paket/$id', token);
  static Future<Map<String, dynamic>> raporlar(String token) => _get('/api/raporlar', token);
}

class ApiYetkiHatasi implements Exception {}

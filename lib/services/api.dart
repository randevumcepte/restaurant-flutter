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

  static Future<Map<String, dynamic>> masalar(String token) => _get('/api/masalar', token);
  static Future<Map<String, dynamic>> paket(String token) => _get('/api/paket', token);
  static Future<Map<String, dynamic>> raporlar(String token) => _get('/api/raporlar', token);
}

class ApiYetkiHatasi implements Exception {}

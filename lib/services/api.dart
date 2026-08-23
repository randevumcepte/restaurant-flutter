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

  static Future<Map<String, dynamic>> patronOzet(String token) async {
    final r = await http.get(
      Uri.parse('$base/api/patron/ozet'),
      headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
    );
    if (r.statusCode == 401) {
      throw ApiYetkiHatasi();
    }
    return jsonDecode(r.body) as Map<String, dynamic>;
  }
}

class ApiYetkiHatasi implements Exception {}

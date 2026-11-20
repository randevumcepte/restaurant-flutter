import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/api.dart';

/// UYGULAMA KÖPRÜSÜ — web paneldeki sayfayı aynı adresle açar (sunucu: routes/app_kopru.php).
/// Sayfa web'deki route + yetki kapılarıyla çalışır; view verisi JSON gelir. Böylece uygulama ile web
/// AYNI veriyi, AYNI hesapla, AYNI yetkiyle gösterir (mantık uygulamada tekrar yazılmaz).
///   al('/stok')                        → sayfanın verisi (veri)
///   gonder('/ajanda/ekle', {...})      → {ok, mesaj | hata} (web formu gibi)
///   dosya('/x/indir?format=xlsx')      → Excel/PDF baytları
class KopruCevap {
  final int durum;
  final Map<String, dynamic> j;
  KopruCevap(this.durum, this.j);

  bool get ok => j['ok'] == 1 || j['ok'] == true;
  /// Sayfa verisi (view değişkenleri). Uç doğrudan JSON döndürüyorsa cevabın kendisi.
  Map<String, dynamic> get veri {
    final v = j['veri'];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return j;
  }
  String? get mesaj => _metin(j['mesaj']);
  String? get hata => _metin(j['hata']) ?? (ok ? null : (_metin(j['message']) ?? 'İşlem tamamlanamadı (HTTP $durum).'));
  bool get yetkisiz => durum == 403 || j['yetkisiz'] == 1;
  static String? _metin(dynamic v) => (v is String && v.trim().isNotEmpty) ? v.trim() : null;
}

class KopruApi {
  static const Duration _zamanAsimi = Duration(seconds: 30);

  static Map<String, String> _bas(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        'X-Resteos-Kopru': '1',
      };

  static Uri _uri(String yol, [Map<String, String>? q]) {
    final u = Uri.parse('${AppConfig.baseUrl}$yol');
    if (q == null || q.isEmpty) return u;
    return u.replace(queryParameters: {...u.queryParameters, ...q});
  }

  static KopruCevap _coz(http.Response r) {
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    try {
      final d = jsonDecode(utf8.decode(r.bodyBytes));
      if (d is Map) return KopruCevap(r.statusCode, Map<String, dynamic>.from(d));
      return KopruCevap(r.statusCode, {'ok': 1, 'veri': {'liste': d}});
    } catch (_) {
      return KopruCevap(r.statusCode, {'ok': 0, 'hata': 'Sunucu yanıtı okunamadı (HTTP ${r.statusCode}).'});
    }
  }

  /// Web sayfasını aç (GET). Bağlantı hatasında KopruCevap ok=0 döner (ekran "tekrar dene" gösterir).
  static Future<KopruCevap> al(String token, String yol, {Map<String, String>? q}) async {
    try {
      final r = await http.get(_uri(yol, q), headers: _bas(token)).timeout(_zamanAsimi);
      return _coz(r);
    } on ApiYetkiHatasi {
      rethrow;
    } catch (e) {
      return KopruCevap(0, {'ok': 0, 'hata': e is TimeoutException ? 'Sunucu geç cevap verdi. Tekrar deneyin.' : 'İnternet bağlantısı yok ya da sunucuya ulaşılamadı.'});
    }
  }

  /// Web formu gönder (POST). Liste değerleri `ad[]` olarak gider (web formlarıyla aynı).
  static Future<KopruCevap> gonder(String token, String yol, Map<String, dynamic> veri) async {
    try {
      final govde = _formGovde(veri);
      final r = await http
          .post(_uri(yol), headers: {..._bas(token), 'Content-Type': 'application/x-www-form-urlencoded; charset=utf-8'}, body: govde)
          .timeout(_zamanAsimi);
      return _coz(r);
    } on ApiYetkiHatasi {
      rethrow;
    } catch (e) {
      return KopruCevap(0, {'ok': 0, 'hata': e is TimeoutException ? 'Sunucu geç cevap verdi; işlemin durumunu kontrol edin.' : 'İnternet bağlantısı yok; işlem gönderilemedi.'});
    }
  }

  /// JSON gövdeli POST (web'de fetch ile JSON gönderen uçlar için).
  static Future<KopruCevap> gonderJson(String token, String yol, Map<String, dynamic> veri) async {
    try {
      final r = await http
          .post(_uri(yol), headers: {..._bas(token), 'Content-Type': 'application/json'}, body: jsonEncode(veri))
          .timeout(_zamanAsimi);
      return _coz(r);
    } on ApiYetkiHatasi {
      rethrow;
    } catch (e) {
      return KopruCevap(0, {'ok': 0, 'hata': 'İnternet bağlantısı yok; işlem gönderilemedi.'});
    }
  }

  /// Dosya indir (Excel/PDF). Hata olursa null.
  static Future<Uint8List?> dosya(String token, String yol, {Map<String, String>? q}) async {
    try {
      final r = await http.get(_uri(yol, q), headers: _bas(token)).timeout(const Duration(seconds: 60));
      if (r.statusCode == 401) throw ApiYetkiHatasi();
      if (r.statusCode != 200) return null;
      final tur = r.headers['content-type'] ?? '';
      if (tur.contains('json') || tur.contains('text/html')) return null;
      return r.bodyBytes;
    } on ApiYetkiHatasi {
      rethrow;
    } catch (_) {
      return null;
    }
  }

  static String _formGovde(Map<String, dynamic> veri) {
    final parcalar = <String>[];
    void ekle(String k, dynamic v) {
      if (v == null) return;
      if (v is List) {
        for (final x in v) { ekle('$k[]', x); }
        return;
      }
      if (v is Map) {
        v.forEach((ak, av) => ekle('$k[$ak]', av));
        return;
      }
      final s = v is bool ? (v ? '1' : '0') : '$v';
      parcalar.add('${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(s)}');
    }
    veri.forEach(ekle);
    return parcalar.join('&');
  }
}

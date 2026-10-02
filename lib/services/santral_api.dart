import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api.dart';

/// AI Santral panel uclari. Bu rotalar oturum/token GEREKTIRMEZ (acik panel uclari),
/// o yuzden Bearer yok; dogrudan JSON cagri.
class SantralApi {
  static String get _b => Api.base;

  static Future<Map<String, dynamic>> _get(String path) async {
    final r = await http.get(Uri.parse('$_b$path'), headers: {'Accept': 'application/json'});
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final r = await http.post(
      Uri.parse('$_b$path'),
      headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- Cagri kayitlari ----
  static Future<Map<String, dynamic>> kayitListe() => _get('/api/santral-kayit/liste');
  static Future<Map<String, dynamic>> kayitDetay(int id) => _post('/api/santral-kayit/detay', {'id': id});
  static String sesUrl(String relUrl) => '$_b$relUrl'; // /santral-ses-dinle/{id}

  // ---- Subeler ----
  static Future<Map<String, dynamic>> subeler() => _get('/api/santral/subeler');

  // ---- Aktarma / Teslimat ayari ----
  static Future<Map<String, dynamic>> ayarGet(int subeId) => _get('/api/santral/ayar?sube_id=$subeId');
  static Future<Map<String, dynamic>> ayarKaydet({
    required int subeId,
    required bool aktif,
    required String strateji, // hepsi | sirali
    required List<Map<String, dynamic>> hedefler,
    required int zilSure,
    required String teslimatBolge,
  }) =>
      _post('/api/santral/ayar-kaydet', {
        'sube_id': subeId,
        'aktarma_aktif': aktif ? 1 : 0,
        'strateji': strateji,
        'hedefler': hedefler,
        'zil_sure': zilSure,
        'teslimat_bolge': teslimatBolge,
      });

  // ---- Dahili (FreePBX GraphQL) ----
  static Future<Map<String, dynamic>> dahiliListe() => _get('/api/dahili/liste');
  static Future<Map<String, dynamic>> dahiliEkle(String numara, String ad, String sifre) =>
      _post('/api/dahili/ekle', {'numara': numara, 'ad': ad, 'sifre': sifre});
  static Future<Map<String, dynamic>> dahiliSil(String numara) => _post('/api/dahili/sil', {'numara': numara});
  static Future<Map<String, dynamic>> dahiliSifre(String numara, String sifre) =>
      _post('/api/dahili/sifre', {'numara': numara, 'sifre': sifre});

  // ---- FreePBX API ayari ----
  static Future<Map<String, dynamic>> freepbxAyar() => _get('/api/freepbx/ayar');
  static Future<Map<String, dynamic>> freepbxKaydet(Map<String, dynamic> veri) => _post('/api/freepbx/ayar-kaydet', veri);
  static Future<Map<String, dynamic>> freepbxTest() => _get('/api/freepbx/test');

  // ---- Egitim: kalip ----
  static Future<Map<String, dynamic>> kalipListe(int subeId) => _get('/api/santral-egitim/kalip-liste?sube_id=$subeId');
  static Future<Map<String, dynamic>> kalipEkle(int subeId, String tetik, String cevap, String kategori) =>
      _post('/api/santral-egitim/kalip-ekle', {'sube_id': subeId, 'tetikleyiciler': tetik, 'cevap': cevap, 'kategori': kategori});
  static Future<Map<String, dynamic>> kalipGuncelle(int id, {String? tetik, String? cevap, bool? aktif}) =>
      _post('/api/santral-egitim/kalip-guncelle', {
        'id': id,
        'tetikleyiciler': ?tetik,
        'cevap': ?cevap,
        if (aktif != null) 'aktif': aktif ? 1 : 0,
      });
  static Future<Map<String, dynamic>> kalipSil(int id) => _post('/api/santral-egitim/kalip-sil', {'id': id});

  // ---- Egitim: ogrenilen onbellek ----
  static Future<Map<String, dynamic>> ogrenilenListe(int subeId) => _get('/api/santral-egitim/ogrenilen-liste?sube_id=$subeId');
  static Future<Map<String, dynamic>> ogrenilenGuncelle(int id, String cevap) =>
      _post('/api/santral-egitim/ogrenilen-guncelle', {'id': id, 'cevap': cevap});
  static Future<Map<String, dynamic>> ogrenilenSil(int id) => _post('/api/santral-egitim/ogrenilen-sil', {'id': id});

  // ---- Egitim: cozulemeyen ----
  static Future<Map<String, dynamic>> cozulemeyenListe(int subeId) => _get('/api/santral-egitim/cozulemeyen-liste?sube_id=$subeId');
  static Future<Map<String, dynamic>> cozulemeyenKalipla(int id, String cevap) =>
      _post('/api/santral-egitim/cozulemeyen-kalipla', {'id': id, 'cevap': cevap});
  static Future<Map<String, dynamic>> cozulemeyenSil(int id) => _post('/api/santral-egitim/cozulemeyen-sil', {'id': id});

  // ---- Egitim: PDF -> kalip ----
  static Future<Map<String, dynamic>> pdfCikar(int subeId, String pdfBase64) =>
      _post('/api/santral-egitim/pdf-cikar', {'sube_id': subeId, 'pdf_base64': pdfBase64});
  static Future<Map<String, dynamic>> pdfOnayla(int subeId, List<Map<String, dynamic>> kaliplar) =>
      _post('/api/santral-egitim/pdf-onayla', {'sube_id': subeId, 'kaliplar': jsonEncode(kaliplar)});

  // ---- Ses (TTS deneme) ----
  static Future<Map<String, dynamic>> sesDene({required String voice, required String metin, double rate = 1.0, bool telefon = false}) =>
      _post('/api/santral-ses/dene', {'voice': voice, 'metin': metin, 'rate': rate, 'telefon': telefon ? 1 : 0});
}

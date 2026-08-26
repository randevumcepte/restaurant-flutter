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

  static Future<Map<String, dynamic>> mutfak(String token, {String? istasyon}) =>
      _get('/api/mutfak${istasyon != null && istasyon != 'hepsi' ? '?istasyon=$istasyon' : ''}', token);

  static Future<Map<String, dynamic>> mutfakHazir(String token, {int? kalemId, int? adisyonId}) async {
    final body = <String, String>{};
    if (kalemId != null) body['kalem_id'] = '$kalemId';
    if (adisyonId != null) body['adisyon_id'] = '$adisyonId';
    final r = await http.post(Uri.parse('$base/api/mutfak/hazir'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}, body: body);
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // Servise hazir (durum=hazir) siparisler + garson aldi (servis)
  static Future<Map<String, dynamic>> mutfakServiseHazir(String token) => _get('/api/mutfak/servise-hazir', token);
  static Future<Map<String, dynamic>> mutfakServis(String token, {int? kalemId, int? adisyonId}) async {
    final body = <String, String>{};
    if (kalemId != null) body['kalem_id'] = '$kalemId';
    if (adisyonId != null) body['adisyon_id'] = '$adisyonId';
    return _post('/api/mutfak/servis', token, body);
  }

  // 86 / Tukendi yonetimi
  static Future<Map<String, dynamic>> mutfakUrunler(String token) => _get('/api/mutfak/urunler', token);
  static Future<Map<String, dynamic>> mutfak86(String token, int urunId) =>
      _post('/api/mutfak/86', token, {'urun_id': '$urunId'});

  // Mutfak analitigi
  static Future<Map<String, dynamic>> mutfakAnaliz(String token) => _get('/api/mutfak/analiz', token);

  static Future<Map<String, dynamic>> sebepler(String token, {String? tur}) =>
      _get('/api/patron/sebepler${tur != null ? '?tur=$tur' : ''}', token);

  static Future<Map<String, dynamic>> _post(String path, String token, Map<String, String> body) async {
    final r = await http.post(Uri.parse('$base$path'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'}, body: body);
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> sebepEkle(String token, String tur, String metin) =>
      _post('/api/patron/sebep-ekle', token, {'tur': tur, 'metin': metin});
  static Future<Map<String, dynamic>> sebepSil(String token, int id) =>
      _post('/api/patron/sebep-sil', token, {'id': '$id'});

  static Future<Map<String, dynamic>> masaTasi(String token, int adisyonId, int yeniMasaId) =>
      _post('/api/patron/masa-tasi', token, {'adisyon_id': '$adisyonId', 'yeni_masa_id': '$yeniMasaId'});
  static Future<Map<String, dynamic>> masaBirlestir(String token, int adisyonId, int kaynakAdisyonId) =>
      _post('/api/patron/masa-birlestir', token, {'adisyon_id': '$adisyonId', 'kaynak_adisyon_id': '$kaynakAdisyonId'});
  // Bos masa da dahil gruplama: hedef bos ise adisyon acar (misafir); kaynak bos/dolu fark etmez.
  static Future<Map<String, dynamic>> masaGrupla(String token, {required int hedefMasaId, required int kaynakMasaId, int? misafir}) =>
      _post('/api/patron/masa-grupla', token, {
        'hedef_masa_id': '$hedefMasaId',
        'kaynak_masa_id': '$kaynakMasaId',
        if (misafir != null) 'misafir': '$misafir',
      });
  static Future<Map<String, dynamic>> adisyonBol(String token, int adisyonId, String kalemIdler) =>
      _post('/api/patron/adisyon-bol', token, {'adisyon_id': '$adisyonId', 'kalem_idler': kalemIdler});

  static Future<Map<String, dynamic>> fis(String token, int adisyonId) => _get('/api/patron/fis?adisyon_id=$adisyonId', token);
  static Future<Map<String, dynamic>> zRaporu(String token, {String? tarih}) => _get('/api/patron/z-raporu${tarih != null ? '?tarih=$tarih' : ''}', token);
  static Future<Map<String, dynamic>> hareketler(String token) => _get('/api/patron/hareketler', token);

  // ---- MENU YONETIMI (sahip/mudur) ----
  static Future<Map<String, dynamic>> menuYonetim(String token) => _get('/api/patron/menu-yonetim', token);

  static Future<Map<String, dynamic>> urunKaydet(String token,
      {int? id, required String ad, String aciklama = '', required double fiyat, int kategoriId = 0, bool tukendi = false, bool aktif = true}) {
    final body = {
      'ad': ad, 'aciklama': aciklama, 'fiyat': '$fiyat', 'kategori_id': '$kategoriId',
      'tukendi': tukendi ? '1' : '0', 'aktif': aktif ? '1' : '0',
    };
    if (id != null) body['id'] = '$id';
    return _post('/api/patron/urun-kaydet', token, body);
  }

  static Future<Map<String, dynamic>> urunSil(String token, int id) => _post('/api/patron/urun-sil', token, {'id': '$id'});

  static Future<Map<String, dynamic>> kategoriKaydet(String token, {int? id, required String ad, int sira = 0}) {
    final body = {'ad': ad, 'sira': '$sira'};
    if (id != null) body['id'] = '$id';
    return _post('/api/patron/kategori-kaydet', token, body);
  }

  static Future<Map<String, dynamic>> kategoriSil(String token, int id) => _post('/api/patron/kategori-sil', token, {'id': '$id'});

  static Future<Map<String, dynamic>> urunFotoYukle(String token, int urunId, String dosyaYolu) async {
    final req = http.MultipartRequest('POST', Uri.parse('$base/api/patron/urun-foto'));
    req.headers['Accept'] = 'application/json';
    req.headers['Authorization'] = 'Bearer $token';
    req.fields['urun_id'] = '$urunId';
    req.files.add(await http.MultipartFile.fromPath('foto', dosyaYolu));
    final streamed = await req.send();
    final r = await http.Response.fromStream(streamed);
    if (r.statusCode == 401) throw ApiYetkiHatasi();
    return jsonDecode(r.body) as Map<String, dynamic>;
  }

  // ---- PERSONEL YONETIMI (maas / prim / hareket) ----
  static Future<Map<String, dynamic>> personelList(String token, {String? ay}) =>
      _get('/api/patron/personel-list${ay != null ? '?ay=$ay' : ''}', token);
  static Future<Map<String, dynamic>> personelDetay(String token, int id, {String? ay}) =>
      _get('/api/patron/personel-detay?id=$id${ay != null ? '&ay=$ay' : ''}', token);

  static Future<Map<String, dynamic>> personelKaydet(String token, {
    int? id, required String ad, String telefon = '', required String rol, bool aktif = true,
    String pin = '', double maas = 0, String maasTipi = 'aylik', String primTipi = 'yok',
    double primOran = 0, String iban = '', String iseBaslama = '',
  }) {
    final body = <String, String>{
      'ad': ad, 'telefon': telefon, 'rol': rol, 'aktif': aktif ? '1' : '0',
      'maas': '$maas', 'maas_tipi': maasTipi, 'prim_tipi': primTipi, 'prim_oran': '$primOran',
      'iban': iban, 'ise_baslama': iseBaslama,
    };
    if (id != null) body['id'] = '$id';
    if (pin.isNotEmpty) body['pin'] = pin;
    return _post('/api/patron/personel-kaydet', token, body);
  }

  static Future<Map<String, dynamic>> personelHareket(String token, int personelId, String tur, double tutar, {String aciklama = '', String tarih = ''}) =>
      _post('/api/patron/personel-hareket', token, {'personel_id': '$personelId', 'tur': tur, 'tutar': '$tutar', 'aciklama': aciklama, 'tarih': tarih});
  static Future<Map<String, dynamic>> personelHareketSil(String token, int id) =>
      _post('/api/patron/personel-hareket-sil', token, {'id': '$id'});

  // ---- GIDERLER ----
  static Future<Map<String, dynamic>> giderler(String token, {String? ay}) =>
      _get('/api/patron/giderler${ay != null ? '?ay=$ay' : ''}', token);
  static Future<Map<String, dynamic>> giderEkle(String token, String kategori, double tutar, {String aciklama = '', String tarih = ''}) =>
      _post('/api/patron/gider-ekle', token, {'kategori': kategori, 'tutar': '$tutar', 'aciklama': aciklama, 'tarih': tarih});
  static Future<Map<String, dynamic>> giderSil(String token, int id) =>
      _post('/api/patron/gider-sil', token, {'id': '$id'});

  // ---- STOK / MALZEME ----
  static Future<Map<String, dynamic>> stokMeta(String token) => _get('/api/patron/stok-meta', token);
  static Future<Map<String, dynamic>> malzemeler(String token) => _get('/api/patron/malzemeler', token);
  static Future<Map<String, dynamic>> malzemeDetay(String token, int id) => _get('/api/patron/malzeme-detay?id=$id', token);
  static Future<Map<String, dynamic>> malzemeKaydet(String token, {
    int? id, required String ad, int kategoriId = 0, required int temelBirimId, double kritikStok = 0, bool stokTakipli = true, double guncelMaliyet = 0,
  }) {
    final body = <String, String>{'ad': ad, 'kategori_id': '$kategoriId', 'temel_birim_id': '$temelBirimId', 'kritik_stok': '$kritikStok', 'stok_takipli': stokTakipli ? '1' : '0', 'guncel_maliyet': '$guncelMaliyet'};
    if (id != null) body['id'] = '$id';
    return _post('/api/patron/malzeme-kaydet', token, body);
  }
  static Future<Map<String, dynamic>> malzemeSil(String token, int id) => _post('/api/patron/malzeme-sil', token, {'id': '$id'});
  static Future<Map<String, dynamic>> malzemeKategoriEkle(String token, String ad) => _post('/api/patron/malzeme-kategori-ekle', token, {'ad': ad});
  static Future<Map<String, dynamic>> stokHareket(String token, int malzemeId, String tip, double miktar, {String aciklama = ''}) =>
      _post('/api/patron/stok-hareket', token, {'malzeme_id': '$malzemeId', 'tip': tip, 'miktar': '$miktar', 'aciklama': aciklama});

  // ---- TEDARIKCILER ----
  static Future<Map<String, dynamic>> tedarikciler(String token) => _get('/api/patron/tedarikciler', token);
  static Future<Map<String, dynamic>> tedarikciKaydet(String token, {int? id, required String ad, String telefon = '', String aciklama = ''}) {
    final body = <String, String>{'ad': ad, 'telefon': telefon, 'aciklama': aciklama};
    if (id != null) body['id'] = '$id';
    return _post('/api/patron/tedarikci-kaydet', token, body);
  }
  static Future<Map<String, dynamic>> tedarikciSil(String token, int id) => _post('/api/patron/tedarikci-sil', token, {'id': '$id'});

  // ---- ALIS FATURALARI ----
  static Future<Map<String, dynamic>> alisFaturalari(String token, {String? ay}) => _get('/api/patron/alis-faturalari${ay != null ? '?ay=$ay' : ''}', token);
  static Future<Map<String, dynamic>> alisFaturaDetay(String token, int id) => _get('/api/patron/alis-fatura-detay?id=$id', token);
  static Future<Map<String, dynamic>> alisFaturaKaydet(String token, {int? tedarikciId, String faturaNo = '', String tarih = '', required List<Map<String, dynamic>> kalemler}) =>
      _post('/api/patron/alis-fatura-kaydet', token, {'tedarikci_id': tedarikciId != null ? '$tedarikciId' : '', 'fatura_no': faturaNo, 'tarih': tarih, 'kalemler': jsonEncode(kalemler)});
  static Future<Map<String, dynamic>> alisFaturaSil(String token, int id) => _post('/api/patron/alis-fatura-sil', token, {'id': '$id'});

  // ---- RECETE ----
  static Future<Map<String, dynamic>> receteUrunler(String token) => _get('/api/patron/recete-urunler', token);
  static Future<Map<String, dynamic>> urunRecete(String token, int urunId) => _get('/api/patron/urun-recete?urun_id=$urunId', token);
  static Future<Map<String, dynamic>> receteKaydet(String token, int urunId, List<Map<String, dynamic>> kalemler) =>
      _post('/api/patron/recete-kaydet', token, {'urun_id': '$urunId', 'kalemler': jsonEncode(kalemler)});

  // ---- FINANS ----
  static Future<Map<String, dynamic>> finans(String token, {String? ay}) => _get('/api/patron/finans${ay != null ? '?ay=$ay' : ''}', token);

  // ---- KASA (vardiya bazli nakit) ----
  static Future<Map<String, dynamic>> kasa(String token) => _get('/api/patron/kasa', token);
  static Future<Map<String, dynamic>> kasaGecmis(String token) => _get('/api/patron/kasa-gecmis', token);
  static Future<Map<String, dynamic>> kasaAc(String token, double devir) =>
      _post('/api/patron/kasa-ac', token, {'devir': '$devir'});
  static Future<Map<String, dynamic>> kasaHareket(String token, {required String yon, required double tutar, String aciklama = ''}) =>
      _post('/api/patron/kasa-hareket', token, {'yon': yon, 'tutar': '$tutar', 'aciklama': aciklama});
  static Future<Map<String, dynamic>> kasaKapat(String token, double sayilan, {String not = ''}) =>
      _post('/api/patron/kasa-kapat', token, {'sayilan': '$sayilan', 'not': not});

  static Future<Map<String, dynamic>> masalar(String token) => _get('/api/masalar', token);
  static Future<Map<String, dynamic>> paket(String token) => _get('/api/paket', token);
  static Future<Map<String, dynamic>> paketDetay(String token, int id) => _get('/api/paket/$id', token);
  static Future<Map<String, dynamic>> raporlar(String token) => _get('/api/raporlar', token);
}

class ApiYetkiHatasi implements Exception {}

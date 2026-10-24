import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../local/sync_service.dart';
import '../services/api.dart';
import '../services/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  String? token;
  String? ad;
  String? rol;
  String? sube;
  int? subeId;
  // WHITE-LABEL: login'de backend'den gelen marka adı (yoksa AppConfig varsayılanı).
  String markaAd = AppConfig.markaAd;
  bool loading = false;

  // DEPARTMAN + YETKI (Patron AI Faz 1) — additif. Çekilemezse eski davranış (rol bazlı) korunur.
  List<String> yetkiler = [];          // etkin sayfa anahtarları (gor_*)
  String aiErisim = 'kapali';          // tam | kisitli | kapali
  String? departmanAd;
  String? departmanRenk;
  String? departmanIkon;
  String? departmanKod;              // servis | mutfak | bar ... (departman-bilinçli yönlendirme için)
  bool departmanSorumlu = false;     // departman sorumlusu mu (ekip/yönetim görünümleri)

  bool get girisli => token != null;

  // Patron/müdür -> her şeyi görür. Alt personelde: anahtar listesinde var mı?
  bool get patron => rol == 'sahip' || rol == 'mudur';
  bool yetkiVar(String key) => patron || yetkiler.contains(key);
  // Servis Şefi / sorumlu görünümü (ekip): patron VEYA departman sorumlusu.
  bool get sorumlu => patron || departmanSorumlu;

  /// Giriş yapanın etkin yetkilerini sunucudan çeker. Hata olursa sessizce atlar (giriş bozulmaz).
  Future<void> yetkileriCek() async {
    if (token == null || token!.isEmpty) return;
    try {
      final res = await Api.yetkilerim(token!);
      if (res['ok'] == 1) {
        final y = res['yetkiler'];
        yetkiler = (y is List) ? y.map((e) => e.toString()).toList() : [];
        aiErisim = res['ai_erisim']?.toString() ?? 'kapali';
        final dep = res['departman'] as Map<String, dynamic>?;
        departmanAd = dep?['ad']?.toString();
        departmanRenk = dep?['renk']?.toString();
        departmanIkon = dep?['ikon']?.toString();
        departmanKod = dep?['kod']?.toString();
        departmanSorumlu = (dep?['sorumlu']?.toString() == '1') || (dep?['sorumlu'] == 1) || (dep?['sorumlu'] == true);
        final sp = await SharedPreferences.getInstance();
        await sp.setString('yetkiler', yetkiler.join(','));
        await sp.setString('ai_erisim', aiErisim);
        await sp.setString('departman_ad', departmanAd ?? '');
        await sp.setString('departman_kod', departmanKod ?? '');
        await sp.setBool('departman_sorumlu', departmanSorumlu);
        notifyListeners();
      }
    } catch (_) {/* sessiz: eski rol bazlı davranış sürer */}
  }

  Future<void> yukle() async {
    final sp = await SharedPreferences.getInstance();
    token = sp.getString('token');
    ad = sp.getString('ad');
    rol = sp.getString('rol');
    sube = sp.getString('sube');
    subeId = sp.getInt('sube_id');
    markaAd = sp.getString('marka_ad') ?? AppConfig.markaAd;
    // Önbellekten yetkiler (çevrimdışı/ilk frame için); ardından sunucudan tazelenir.
    final yCache = sp.getString('yetkiler') ?? '';
    yetkiler = yCache.isEmpty ? [] : yCache.split(',');
    aiErisim = sp.getString('ai_erisim') ?? 'kapali';
    departmanAd = sp.getString('departman_ad');
    if (departmanAd != null && departmanAd!.isEmpty) departmanAd = null;
    departmanKod = sp.getString('departman_kod');
    if (departmanKod != null && departmanKod!.isEmpty) departmanKod = null;
    departmanSorumlu = sp.getBool('departman_sorumlu') ?? false;
    notifyListeners();
    // Açılışta zaten girişliyse push token'ını tazele + senkronu başlat (ilk pull dahil).
    if (token != null && token!.isNotEmpty) {
      NotificationService().tokenKaydet();
      SyncService.instance.basla();
      Api.menu(token!).catchError((_) => <String, dynamic>{'ok': 0}); // menü önbelleğini ısıt (offline)
      _yetkiliPinleriCek();
      yetkileriCek();
    }
  }

  /// Yönetici PIN hash'lerini çekip yerele cache'le (çevrimdışı İkram/İskonto onayı için).
  Future<void> _yetkiliPinleriCek() async {
    if (token == null || token!.isEmpty) return;
    try {
      final r = await Api.yetkiliPinler(token!);
      if (r['ok'] == 1) {
        final sp = await SharedPreferences.getInstance();
        await sp.setString('yetkili_pinler_v1', jsonEncode(r['yetkililer'] ?? []));
      }
    } catch (_) {}
  }

  /// Basarili ise null, hata varsa mesaj doner.
  Future<String?> girisYap(String pin) async {
    if (pin.isEmpty) return 'PIN girin';
    loading = true;
    notifyListeners();
    try {
      final res = await Api.login(pin);
      if (res['ok'] == 1) {
        token = res['token']?.toString();
        final p = res['personel'] as Map<String, dynamic>?;
        ad = p?['ad']?.toString();
        rol = p?['rol']?.toString();
        sube = res['sube']?.toString();
        subeId = res['sube_id'] is int ? res['sube_id'] as int : int.tryParse('${res['sube_id'] ?? ''}');
        final marka = res['marka'] as Map<String, dynamic>?;
        final mAd = marka?['ad']?.toString();
        markaAd = (mAd != null && mAd.isNotEmpty) ? mAd : AppConfig.markaAd;
        final sp = await SharedPreferences.getInstance();
        await sp.setString('token', token ?? '');
        await sp.setString('ad', ad ?? '');
        await sp.setString('rol', rol ?? '');
        await sp.setString('sube', sube ?? '');
        if (subeId != null) await sp.setInt('sube_id', subeId!);
        await sp.setString('marka_ad', markaAd);
        // ÇEVRİMDIŞI GİRİŞ: bu PIN + oturum bilgisini (hash'li) sakla -> internet yokken de giriş.
        await _offlineGirisKaydet(pin);
        loading = false;
        notifyListeners();
        // Push token'ını backend'e kaydet (giriş yapan personele bağlanır).
        NotificationService().tokenKaydet();
        // Senkronu başlat: ilk pull ile menü/masalar yerele iner (bootstrap).
        SyncService.instance.basla();
        // Menü önbelleğini önden ısıt (çevrimdışı satış ekranı için garanti).
        Api.menu(token!).catchError((_) => <String, dynamic>{'ok': 0});
        // Yönetici PIN'lerini cache'le (çevrimdışı İkram/İskonto onayı için).
        _yetkiliPinleriCek();
        // Etkin yetkileri + departman + AI erişimini çek (giriş akışını bloklamaz).
        yetkileriCek();
        return null;
      }
      loading = false;
      notifyListeners();
      return res['hata']?.toString() ?? 'Giriş başarısız';
    } catch (e) {
      // İNTERNET YOK: daha önce online giriş yapmış PIN ise çevrimdışı gir.
      final offlineOk = await _offlineGiris(pin);
      loading = false;
      notifyListeners();
      if (offlineOk) return null;
      return 'Çevrimdışı — bu PIN daha önce internetle giriş yapmamış (ilk giriş internet ister).';
    }
  }

  // PIN'i düz saklamadan karşılaştırmak için hash (SharedPreferences cihaz-özel ama yine de).
  String _pinAnahtar(String pin) =>
      'offline_giris_${sha256.convert(utf8.encode('rpos|$pin')).toString()}';

  /// Online giriş başarılıysa oturumu PIN hash'i altında sakla (çevrimdışı giriş için).
  Future<void> _offlineGirisKaydet(String pin) async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_pinAnahtar(pin), jsonEncode({
        'token': token, 'ad': ad, 'rol': rol, 'sube': sube, 'sube_id': subeId, 'marka_ad': markaAd,
        'yetkiler': yetkiler, 'ai_erisim': aiErisim, 'departman_ad': departmanAd,
        'departman_kod': departmanKod, 'departman_sorumlu': departmanSorumlu,
      }));
    } catch (_) {}
  }

  /// Çevrimdışı giriş: saklı PIN hash'i varsa oturumu geri yükle. Başarılıysa true.
  Future<bool> _offlineGiris(String pin) async {
    try {
      final sp = await SharedPreferences.getInstance();
      final kayit = sp.getString(_pinAnahtar(pin));
      if (kayit == null) return false;
      final d = jsonDecode(kayit) as Map<String, dynamic>;
      token = d['token']?.toString();
      if (token == null || token!.isEmpty) return false;
      ad = d['ad']?.toString();
      rol = d['rol']?.toString();
      sube = d['sube']?.toString();
      subeId = d['sube_id'] is int ? d['sube_id'] as int : int.tryParse('${d['sube_id'] ?? ''}');
      markaAd = d['marka_ad']?.toString() ?? AppConfig.markaAd;
      final y = d['yetkiler'];
      yetkiler = (y is List) ? y.map((e) => e.toString()).toList() : [];
      aiErisim = d['ai_erisim']?.toString() ?? 'kapali';
      departmanAd = d['departman_ad']?.toString();
      if (departmanAd != null && departmanAd!.isEmpty) departmanAd = null;
      departmanKod = d['departman_kod']?.toString();
      if (departmanKod != null && departmanKod!.isEmpty) departmanKod = null;
      departmanSorumlu = d['departman_sorumlu'] == true;
      // Aktif oturum olarak da yaz (uygulama yeniden açılınca otomatik girişli gelsin).
      await sp.setString('token', token ?? '');
      await sp.setString('ad', ad ?? '');
      await sp.setString('rol', rol ?? '');
      await sp.setString('sube', sube ?? '');
      if (subeId != null) await sp.setInt('sube_id', subeId!);
      await sp.setString('marka_ad', markaAd);
      await sp.setString('yetkiler', yetkiler.join(','));
      await sp.setString('ai_erisim', aiErisim);
      await sp.setString('departman_ad', departmanAd ?? '');
      await sp.setString('departman_kod', departmanKod ?? '');
      await sp.setBool('departman_sorumlu', departmanSorumlu);
      SyncService.instance.basla(); // internet gelince biriken veri senkronlanır
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Patron adini sunucudan gelen guncel degerle tazele (yeniden giris gerekmeden).
  Future<void> adGuncelle(String yeni) async {
    yeni = yeni.trim();
    if (yeni.isEmpty || yeni == ad) return;
    ad = yeni;
    final sp = await SharedPreferences.getInstance();
    await sp.setString('ad', yeni);
    notifyListeners();
  }

  Future<void> cikis() async {
    // Senkronu durdur (timer/observer).
    SyncService.instance.durdur();
    // Önce bu cihazın push kaydını backend'den düşür (token hâlâ geçerliyken).
    await NotificationService().tokenSil();
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
    token = null;
    ad = null;
    rol = null;
    sube = null;
    subeId = null;
    yetkiler = [];
    aiErisim = 'kapali';
    departmanAd = null;
    departmanRenk = null;
    departmanIkon = null;
    departmanKod = null;
    departmanSorumlu = false;
    notifyListeners();
  }
}

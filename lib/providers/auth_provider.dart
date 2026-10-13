import 'package:flutter/material.dart';
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

  bool get girisli => token != null;

  Future<void> yukle() async {
    final sp = await SharedPreferences.getInstance();
    token = sp.getString('token');
    ad = sp.getString('ad');
    rol = sp.getString('rol');
    sube = sp.getString('sube');
    subeId = sp.getInt('sube_id');
    markaAd = sp.getString('marka_ad') ?? AppConfig.markaAd;
    notifyListeners();
    // Açılışta zaten girişliyse push token'ını tazele + senkronu başlat (ilk pull dahil).
    if (token != null && token!.isNotEmpty) {
      NotificationService().tokenKaydet();
      SyncService.instance.basla();
    }
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
        loading = false;
        notifyListeners();
        // Push token'ını backend'e kaydet (giriş yapan personele bağlanır).
        NotificationService().tokenKaydet();
        // Senkronu başlat: ilk pull ile menü/masalar yerele iner (bootstrap).
        SyncService.instance.basla();
        return null;
      }
      loading = false;
      notifyListeners();
      return res['hata']?.toString() ?? 'Giriş başarısız';
    } catch (e) {
      loading = false;
      notifyListeners();
      return 'Bağlantı hatası — internet / sunucu';
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
    notifyListeners();
  }
}

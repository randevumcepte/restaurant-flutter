import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api.dart';

class AuthProvider extends ChangeNotifier {
  String? token;
  String? ad;
  String? rol;
  String? sube;
  bool loading = false;

  bool get girisli => token != null;

  Future<void> yukle() async {
    final sp = await SharedPreferences.getInstance();
    token = sp.getString('token');
    ad = sp.getString('ad');
    rol = sp.getString('rol');
    sube = sp.getString('sube');
    notifyListeners();
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
        final sp = await SharedPreferences.getInstance();
        await sp.setString('token', token ?? '');
        await sp.setString('ad', ad ?? '');
        await sp.setString('rol', rol ?? '');
        await sp.setString('sube', sube ?? '');
        loading = false;
        notifyListeners();
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
    final sp = await SharedPreferences.getInstance();
    await sp.clear();
    token = null;
    ad = null;
    rol = null;
    sube = null;
    notifyListeners();
  }
}

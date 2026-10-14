import 'package:shared_preferences/shared_preferences.dart';

/// Cihazin LAN'daki rolu.
///  - bagimsiz : tek cihaz / dogrudan buluta (varsayilan)
///  - kasa     : bu cihaz yerel sunucu (LAN otorite); gomulu HTTP sunucusu calisir
///  - terminal : garson/mutfak; veriyi kasanin LAN adresinden ceker
enum Rol { bagimsiz, kasa, terminal }

class CihazRol {
  CihazRol._();
  static const _rolKey = 'cihaz_rol';
  static const _kasaUrlKey = 'kasa_url';
  static const int kasaPort = 8787;

  static Rol _rol = Rol.bagimsiz;
  static String _kasaUrl = '';

  static Rol get rol => _rol;
  static String get kasaUrl => _kasaUrl; // terminal icin kasanin LAN adresi (http://ip:8787)

  static Future<void> yukle() async {
    final sp = await SharedPreferences.getInstance();
    _rol = Rol.values.firstWhere((r) => r.name == (sp.getString(_rolKey) ?? 'bagimsiz'),
        orElse: () => Rol.bagimsiz);
    _kasaUrl = sp.getString(_kasaUrlKey) ?? '';
  }

  static Future<void> rolAyarla(Rol rol, {String? kasaUrl}) async {
    _rol = rol;
    if (kasaUrl != null) _kasaUrl = kasaUrl.trim();
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_rolKey, rol.name);
    await sp.setString(_kasaUrlKey, _kasaUrl);
  }
}

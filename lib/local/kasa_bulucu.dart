import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'cihaz_rol.dart';
import 'kasa_sunucu.dart';

/// TERMINAL icin kasa kesfi.
/// Internet komple gitse bile (router reset -> kasa IP degisse bile) terminal
/// kasayi yerel agda otomatik bulur. Boylece "kayitli IP olunce baglanamadi"
/// sorunu kalkar. Kasa hic bulunamaz ama internet varsa -> buluta duser.
class KasaBulucu {
  KasaBulucu._();

  /// Son saglikli kontrolde kasa LAN'da erisilir miydi?
  /// Api.base bunu kullanir: erisilmezse (ve internet varsa) buluta duser.
  static bool kasaErisilir = true; // kasaUrl kayitliysa kanitlanana kadar iyimser
  static Timer? _timer;
  static bool _calisiyor = false;

  /// Terminal acilisinda cagir: ilk kesif + periyodik saglik kontrolu.
  static void baslat() {
    if (CihazRol.rol != Rol.terminal) return;
    _timer?.cancel();
    sagla(); // hemen bir kez
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => sagla());
  }

  static void durdur() {
    _timer?.cancel();
    _timer = null;
  }

  static String _temiz(String url) => url.replaceAll(RegExp(r'/+$'), '');

  /// Verilen base canli bir kasa mi? (/api/health -> rol:kasa)
  static Future<bool> _canli(String base, {Duration zamanAsimi = const Duration(milliseconds: 1500)}) async {
    try {
      final r = await http.get(Uri.parse('${_temiz(base)}/api/health')).timeout(zamanAsimi);
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        return j is Map && j['rol'] == 'kasa';
      }
    } catch (_) {}
    return false;
  }

  /// Yerel agi elle tara (LAN ayar ekranindaki "otomatik bul" butonu icin).
  static Future<String?> tara() => _tara();

  /// Yerel /24 agini tara, ilk bulunan kasayi dondur (http://ip:port).
  static Future<String?> _tara() async {
    final ip = await KasaSunucu.lanIp();
    if (ip == null || !ip.contains('.')) return null;
    final onek = ip.substring(0, ip.lastIndexOf('.') + 1); // "192.168.1."
    const port = CihazRol.kasaPort;
    // 254 adresi 32'lik gruplar halinde, kisa zaman asimiyla tara (soket tukenmesi olmasin).
    for (var basla = 1; basla <= 254; basla += 32) {
      final grup = <Future<String?>>[];
      for (var i = basla; i < basla + 32 && i <= 254; i++) {
        final base = 'http://$onek$i:$port';
        grup.add(_canli(base, zamanAsimi: const Duration(milliseconds: 700)).then((ok) => ok ? base : null));
      }
      final sonuc = await Future.wait(grup);
      final bulunan = sonuc.firstWhere((e) => e != null, orElse: () => null);
      if (bulunan != null) return bulunan;
    }
    return null;
  }

  /// Kasayi sagla: kayitli canli mi? degilse tara + kaydet. Sonuc kasaErisilir'e yazilir.
  /// [zorla] true ise kayitli IP'yi atlayip direkt tarar (ornegin baglanti hatasindan sonra).
  static Future<void> sagla({bool zorla = false}) async {
    if (CihazRol.rol != Rol.terminal) return;
    if (_calisiyor) return;
    _calisiyor = true;
    try {
      // 1) Kayitli IP canli mi?
      if (!zorla && CihazRol.kasaUrl.isNotEmpty && await _canli(CihazRol.kasaUrl)) {
        kasaErisilir = true;
        return;
      }
      // 2) Yerel agi tara
      final bulunan = await _tara();
      if (bulunan != null) {
        if (_temiz(bulunan) != _temiz(CihazRol.kasaUrl)) {
          await CihazRol.rolAyarla(Rol.terminal, kasaUrl: bulunan); // yeni IP'yi kaydet
        }
        kasaErisilir = true;
        return;
      }
      // 3) Kasa bulunamadi -> internet varsa buluta dusecegiz (Api.base), yoksa gercek offline
      kasaErisilir = false;
    } finally {
      _calisiyor = false;
    }
  }

  /// Bir istek baglanti hatasi verdiginde cagir: arka planda yeniden kesif tetikle.
  static void baglantiHatasi() {
    kasaErisilir = false;
    // ignore: discarded_futures
    sagla(zorla: true);
  }
}

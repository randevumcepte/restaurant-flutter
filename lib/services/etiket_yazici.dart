import 'dart:convert';
import 'dart:io';
import 'api.dart';
import 'yazici_servisi.dart';

/// ETİKET YAZICISI — sunucunun ürettiği ham ZPL (Zebra) / TSPL (TSC/Godex/Xprinter)
/// komutunu ağdaki etiket yazıcısına (IP:port, genelde 9100) TCP ile gönderir.
/// Dil escpos/tarayici ise etiketleri mevcut fiş yazıcısına (YaziciServisi.etiketBas) basar.
/// Mevcut YaziciServisi davranışına DOKUNMAZ; yalnız ek yol.
class EtiketYazici {
  EtiketYazici._();

  /// Ham metni yazıcıya gönderir. 'ok' ya da Türkçe hata metni döner.
  static Future<String> hamGonder(String ip, int port, String komut) async {
    final adres = ip.trim();
    if (adres.isEmpty) return 'Etiket yazıcısı IP adresi tanımlı değil (Etiket Ayarları).';
    List<int> bytes;
    try {
      bytes = latin1.encode(komut);
    } catch (_) {
      bytes = utf8.encode(komut);
    }
    Socket? s;
    try {
      s = await Socket.connect(adres, port <= 0 ? 9100 : port, timeout: const Duration(seconds: 5));
      s.add(bytes);
      await s.flush();
      await Future.delayed(const Duration(milliseconds: 250));
      return 'ok';
    } on SocketException catch (e) {
      return 'Etiket yazıcısına bağlanılamadı ($adres:$port): ${e.message}';
    } catch (e) {
      return 'Etiket yazıcısı hatası: $e';
    } finally {
      try {
        s?.destroy();
      } catch (_) {}
    }
  }

  /// /api/etiket/komut ile etiketleri hazırlatıp uygun yazıcıya basar.
  /// tur: demirbas | barkod. Dönüş: 'ok' ya da hata metni.
  static Future<String> yazdir(String token, {required String tur, required List<int> ids, int adet = 1}) async {
    final r = await Api.etiketKomut(token, tur: tur, ids: ids, adet: adet);
    if (!(r['ok'] == 1 || r['ok'] == true)) return r['hata']?.toString() ?? 'Etiket hazırlanamadı.';
    final dil = r['dil']?.toString() ?? '';
    final komut = r['komut']?.toString() ?? '';
    if ((dil == 'zpl' || dil == 'tspl') && komut.isNotEmpty) {
      final port = r['port'] is num ? (r['port'] as num).toInt() : (int.tryParse('${r['port']}') ?? 9100);
      return hamGonder(r['ip']?.toString() ?? '', port, komut);
    }
    return fisYazicisinaBas((r['etiketler'] as List?) ?? const []);
  }

  /// escpos / tarayici: her etiketi fiş yazıcısına (ESC/POS CODE128) basar.
  static Future<String> fisYazicisinaBas(List etiketler) async {
    final yz = YaziciServisi();
    await yz.yukle();
    if (!yz.ayarli) return 'Fiş yazıcısı IP tanımlı değil — Yazıcı Ayarları';
    for (final e in etiketler) {
      if (e is! Map) continue;
      final adet = e['adet'] is num ? (e['adet'] as num).toInt() : (int.tryParse('${e['adet']}') ?? 1);
      final sonuc = await yz.etiketBas(ad: e['ad']?.toString() ?? '', barkod: e['barkod']?.toString() ?? '', adet: adet);
      if (sonuc != 'ok') return sonuc;
    }
    return 'ok';
  }

  /// Ayar ekranındaki "Test etiketi": kaydetmeden, girilen dil/IP/port ile küçük bir etiket basar.
  static Future<String> testBas({required String dil, required String ip, required int port}) {
    if (dil == 'zpl') {
      return hamGonder(ip, port, '^XA^CI28^FO30,20^A0N,30,30^FDResteOS test etiketi^FS^FO30,70^BY2^BCN,70,Y,N,N^FDTEST0001^FS^PQ1^XZ\n');
    }
    if (dil == 'tspl') {
      return hamGonder(ip, port,
          'SIZE 50 mm,30 mm\r\nGAP 2 mm,0 mm\r\nDIRECTION 1\r\nCLS\r\nTEXT 20,15,"3",0,1,1,"ResteOS test"\r\nBARCODE 20,60,"128M",80,1,0,2,2,"TEST0001"\r\nPRINT 1,1\r\n');
    }
    return YaziciServisi().etiketBas(ad: 'ResteOS test etiketi', barkod: 'TEST0001');
  }
}

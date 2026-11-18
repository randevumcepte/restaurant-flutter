import 'dart:async';
import 'api.dart';
import 'yazici_servisi.dart';

/// QR SİPARİŞ FİŞİ — masa QR'ından gelen siparişte araya garson cihazı girmez; mutfak/bar fişini
/// restorandaki yazıcılı cihaz basar. ~8 sn'de bir sunucudan bekleyen fişleri alır (/api/mutfak/fis-al,
/// kalemler bu cihaza 90 sn kiralanır), istasyona göre basar (bar kendi yazıcısına), sonucu bildirir.
/// Basamazsa kalem sıraya geri döner (başka cihaz / sonraki deneme basar). Hata asla dışarı taşmaz.
class QrFisServisi {
  static final QrFisServisi _i = QrFisServisi._();
  factory QrFisServisi() => _i;
  QrFisServisi._();

  Timer? _t;
  String? _token;
  bool _mesgul = false;

  /// Giriş sonrası çağrılır (idempotent).
  void baslat(String token) {
    _token = token;
    _t ??= Timer.periodic(const Duration(seconds: 8), (_) => _tur());
  }

  void durdur() {
    _t?.cancel();
    _t = null;
    _token = null;
  }

  Future<void> _tur() async {
    if (_mesgul) return; // önceki tur sürüyorsa üst üste binme
    final tok = _token;
    if (tok == null || tok.isEmpty) return;
    _mesgul = true;
    try {
      final y = YaziciServisi();
      await y.yukle();
      if (!y.mutfakYazar || !y.mutfakIpVar || !y.qrFisBas) return;
      final r = await Api.mutfakFisAl(tok); // çevrimdışıyken buluta gitmez (ok:0 döner)
      if (r['ok'] != 1) return;
      final fisler = r['fisler'];
      if (fisler is! List || fisler.isEmpty) return;
      for (final f in fisler) {
        if (_token != tok) return; // bu arada çıkış yapıldı
        if (f is! Map) continue;
        await _fisBas(tok, y, f);
      }
    } catch (_) {
      /* sessiz — basılamayan kalem 90 sn sonra sıraya geri döner */
    } finally {
      _mesgul = false;
    }
  }

  Future<void> _fisBas(String tok, YaziciServisi y, Map f) async {
    final kalemler = (f['kalemler'] is List) ? (f['kalemler'] as List).whereType<Map>().toList() : <Map>[];
    if (kalemler.isEmpty) return;
    // İstasyona göre grupla -> her istasyon (bar/ızgara/...) kendi fişi, kendi yazıcısı
    final gruplar = <String, List<Map>>{};
    for (final k in kalemler) {
      final ist = (k['istasyon']?.toString().isNotEmpty ?? false) ? k['istasyon'].toString() : 'mutfak';
      (gruplar[ist] ??= []).add(k);
    }
    final basilan = <int>[];
    final basilamayan = <int>[];
    for (final e in gruplar.entries) {
      final ids = e.value.map((k) => int.tryParse('${k['id']}') ?? 0).where((i) => i > 0).toList();
      String sonuc;
      try {
        sonuc = await y.mutfakFisi({
          'masa': f['masa'] ?? '-',
          'kaynak': f['kaynak'] ?? 'QR',
          'tarih': f['saat'] ?? '',
          'no': f['adisyon_id'],
          'tur': f['tur'],
          'istasyon': e.key,
          'kalemler': e.value,
        });
      } catch (_) {
        sonuc = 'hata';
      }
      (sonuc == 'ok' ? basilan : basilamayan).addAll(ids);
    }
    // İstasyon bazında bildir: basılan grup tekrar basılmasın, basılamayan sıraya dönsün.
    if (basilan.isNotEmpty) {
      try { await Api.mutfakFisSonuc(tok, basilan, true); } catch (_) {}
    }
    if (basilamayan.isNotEmpty) {
      try { await Api.mutfakFisSonuc(tok, basilamayan, false); } catch (_) {}
    }
  }
}

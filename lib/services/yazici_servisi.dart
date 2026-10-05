import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AĞ (LAN) TERMAL YAZICI — ham ESC/POS, doğrudan yazıcı IP:port (9100) soketine.
/// Bağımlılık YOK (dart:io Socket). Kerzz'e dokunmaz; yazıcıyı ağdan paylaşır.
/// Mali fiş DEĞİL — hesap/adisyon + mutfak (hazırlık) fişi + çekmece tetiği.
/// Ayarlar shared_preferences'ta; her baskıda tazeden okunur (yukle()).
class YaziciServisi {
  static final YaziciServisi _i = YaziciServisi._();
  factory YaziciServisi() => _i;
  YaziciServisi._();

  String ip = '';
  int port = 9100;
  bool dar = false;    // false = 80mm (48 karakter) · true = 58mm (32 karakter)
  bool cekmece = true; // hesap fişi sonrası çekmeceyi tetikle
  bool turkce = true;  // true = CP857 Türkçe · false = ASCII sadeleştir
  int kodSayfa = 13;   // ESC t n — CP857 seçimi (yazıcıya göre; Türkçe bozuksa değiştirilebilir)
  // MUTFAK ÇIKTI MODU: ekran (sadece KDS) · yazici (sadece fiş) · ikisi (KDS + fiş)
  String mutfakMod = 'ekran';
  String mutfakIp = ''; // boş = ana yazıcı IP'si kullanılır (ayrı mutfak yazıcısı için doldur)
  // İSTASYON -> YAZICI IP eşlemesi (bar/izgara/firin/soguk/tatli ayrı yazıcı). Boşsa mutfakIp/ana kullanılır.
  Map<String, String> istasyonIp = {};
  bool get mutfakYazar => mutfakMod == 'yazici' || mutfakMod == 'ikisi';
  String get _mutfakHedefIp => mutfakIp.trim().isNotEmpty ? mutfakIp.trim() : ip.trim();
  String _istasyonHedefIp(String ist) {
    final v = istasyonIp[ist]?.trim() ?? '';
    return v.isNotEmpty ? v : _mutfakHedefIp;
  }
  static const Map<String, String> istasyonAd = {
    'bar': 'BAR', 'izgara': 'IZGARA', 'firin': 'FIRIN', 'soguk': 'SOGUK', 'tatli': 'TATLI', 'mutfak': 'MUTFAK',
  };

  int get _sut => dar ? 32 : 48;
  bool get ayarli => ip.trim().isNotEmpty;

  final _f = NumberFormat.decimalPattern('tr');
  String _tl(dynamic v) => '${_f.format((v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0)).round())} TL';
  num _n(dynamic v) => v is num ? v : (num.tryParse(v?.toString() ?? '0') ?? 0);

  Future<void> yukle() async {
    final p = await SharedPreferences.getInstance();
    ip = p.getString('yz_ip') ?? '';
    port = p.getInt('yz_port') ?? 9100;
    dar = p.getBool('yz_dar') ?? false;
    cekmece = p.getBool('yz_cekmece') ?? true;
    turkce = p.getBool('yz_turkce') ?? true;
    kodSayfa = p.getInt('yz_kod') ?? 13;
    mutfakMod = p.getString('yz_mutfak_mod') ?? 'ekran';
    mutfakIp = p.getString('yz_mutfak_ip') ?? '';
    try {
      final j = p.getString('yz_ist_ip');
      istasyonIp = (j != null && j.isNotEmpty) ? (jsonDecode(j) as Map).map((k, v) => MapEntry(k.toString(), v.toString())) : {};
    } catch (_) { istasyonIp = {}; }
  }

  Future<void> kaydet() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('yz_ip', ip.trim());
    await p.setInt('yz_port', port);
    await p.setBool('yz_dar', dar);
    await p.setBool('yz_cekmece', cekmece);
    await p.setBool('yz_turkce', turkce);
    await p.setInt('yz_kod', kodSayfa);
    await p.setString('yz_mutfak_mod', mutfakMod);
    await p.setString('yz_mutfak_ip', mutfakIp.trim());
    await p.setString('yz_ist_ip', jsonEncode(istasyonIp));
  }

  // ---------- ESC/POS byte kurucu ----------
  final List<int> _b = [];
  void _init() {
    _b.clear();
    _b.addAll([0x1B, 0x40]); // ESC @ (reset)
    if (turkce) _b.addAll([0x1B, 0x74, kodSayfa & 0xFF]); // ESC t n (kod sayfası)
  }
  void _hizala(int n) => _b.addAll([0x1B, 0x61, n]); // 0 sol · 1 orta · 2 sağ
  void _kalin(bool v) => _b.addAll([0x1B, 0x45, v ? 1 : 0]);
  void _boyut(int w, int h) => _b.addAll([0x1D, 0x21, ((w & 7) << 4) | (h & 7)]); // GS ! (0=normal, 1=2x)
  void _nl() => _b.add(0x0A);
  void _satir(String s) { _b.addAll(_enc(s)); _nl(); }
  void _besle(int n) { for (var i = 0; i < n; i++) { _nl(); } }
  void _cizgi() => _satir(''.padRight(_sut, '-'));
  void _kes() => _b.addAll([0x1D, 0x56, 0x42, 0x00]); // GS V B 0 (besle + kısmi kes)
  void _cekmeceAc() => _b.addAll([0x1B, 0x70, 0x00, 0x19, 0xFA]); // ESC p 0 t1 t2 (çekmece darbesi)

  /// sol + sağ (sağa hizalı) tek satır; sığmazsa solu kırpar.
  void _ikiSutun(String sol, String sag) {
    var s = sol;
    final maxSol = _sut - sag.length - 1;
    if (maxSol > 0 && s.length > maxSol) s = s.substring(0, maxSol);
    final bosluk = _sut - s.length - sag.length;
    _satir(s + (bosluk > 0 ? ''.padRight(bosluk) : ' ') + sag);
  }

  List<int> _enc(String s) {
    final out = <int>[];
    for (final ch in s.runes) {
      if (ch < 128) { out.add(ch); continue; }
      final c = String.fromCharCode(ch);
      if (turkce && _cp857.containsKey(c)) { out.add(_cp857[c]!); continue; }
      out.add(_ascii[c] ?? 0x3F); // Türkçe kapalıysa / eşleşmezse sadeleştir ('?')
    }
    return out;
  }

  // CP857 (Türkçe) tek-bayt eşlemesi
  static const Map<String, int> _cp857 = {
    'Ç': 0x80, 'ü': 0x81, 'é': 0x82, 'â': 0x83, 'ä': 0x84, 'ç': 0x87, 'ê': 0x88, 'ë': 0x89,
    'î': 0x8C, 'ı': 0x8D, 'Ä': 0x8E, 'É': 0x90, 'ô': 0x93, 'ö': 0x94, 'û': 0x96, 'ù': 0x97,
    'İ': 0x98, 'Ö': 0x99, 'Ü': 0x9A, 'Ş': 0x9E, 'ş': 0x9F, 'Ğ': 0xA6, 'ğ': 0xA7,
  };
  // ASCII sadeleştirme (yazıcı Türkçe basamıyorsa okunur kalsın)
  static const Map<String, int> _ascii = {
    'İ': 0x49, 'I': 0x49, 'ı': 0x69, 'Ş': 0x53, 'ş': 0x73, 'Ğ': 0x47, 'ğ': 0x67,
    'Ç': 0x43, 'ç': 0x63, 'Ö': 0x4F, 'ö': 0x6F, 'Ü': 0x55, 'ü': 0x75,
    'â': 0x61, 'î': 0x69, 'û': 0x75, 'é': 0x65, 'ê': 0x65, 'ä': 0x61, 'ô': 0x6F,
  };

  // ---------- Ağ gönderimi ----------
  Future<String> _gonder(List<int> bytes, {String? hedefIp}) async {
    final adres = (hedefIp ?? ip).trim();
    if (adres.isEmpty) return 'Yazıcı IP tanımlı değil. Ayarlar → Yazıcı Ayarları';
    Socket? s;
    try {
      s = await Socket.connect(adres, port, timeout: const Duration(seconds: 5));
      s.add(bytes);
      await s.flush();
      await Future.delayed(const Duration(milliseconds: 250));
      return 'ok';
    } on SocketException catch (e) {
      return 'Bağlanılamadı ($adres:$port): ${e.message}';
    } catch (e) {
      return 'Yazıcı hatası: $e';
    } finally {
      try { s?.destroy(); } catch (_) {}
    }
  }

  void _baslik(Map d, String? ustyazi) {
    _hizala(1);
    _boyut(1, 1); _kalin(true);
    _satir(d['isletme']?.toString() ?? 'ResteOS');
    _kalin(false); _boyut(0, 0);
    if ((d['adres']?.toString() ?? '').isNotEmpty) _satir(d['adres'].toString());
    if ((d['telefon']?.toString() ?? '').isNotEmpty) _satir(d['telefon'].toString());
    if (ustyazi != null) { _besle(1); _kalin(true); _satir(ustyazi); _kalin(false); }
    _hizala(0);
  }

  /// HESAP / ADİSYON FİŞİ (mali değil). d: Api.fis çıktısı şeması.
  Future<String> hesapFisi(Map d) async {
    await yukle();
    _init();
    _baslik(d, null);
    _cizgi();
    _ikiSutun('Masa: ${d['masa'] ?? '-'}', 'No: ${d['adisyon_no'] ?? '-'}');
    _ikiSutun('Garson: ${d['garson'] ?? '-'}', d['tarih']?.toString() ?? '');
    _cizgi();
    for (final k in (d['kalemler'] as List?) ?? []) {
      final m = k as Map;
      _ikiSutun('${_n(m['adet']).toInt()}x ${m['ad'] ?? ''}', _tl(m['tutar']));
    }
    _cizgi();
    _ikiSutun('Ara Toplam', _tl(d['ara_toplam']));
    if (_n(d['indirim']) > 0) _ikiSutun('İskonto', '-${_tl(d['indirim'])}');
    if (_n(d['ikram']) > 0) _ikiSutun('İkram', '-${_tl(d['ikram'])}');
    // KDV/matrah (bilgi) — web fiş ile tutarlı. Yeme-içme %10.
    final toplamN = _n(d['toplam']).toDouble();
    if (toplamN > 0) {
      final matrah = toplamN / 1.10;
      _ikiSutun('Matrah', _tl(matrah));
      _ikiSutun('KDV %10', _tl(toplamN - matrah));
    }
    _boyut(1, 1); _kalin(true);
    _ikiSutun('TOPLAM', _tl(d['toplam']));
    _kalin(false); _boyut(0, 0);
    _besle(1);
    _hizala(1); _satir('Afiyet olsun · Teşekkürler'); _hizala(0);
    _besle(3);
    if (cekmece) _cekmeceAc();
    _kes();
    return _gonder(_b);
  }

  /// MUTFAK / HAZIRLIK FİŞİ (fiyatsız, büyük punto). d: {masa, garson, tarih, no?, istasyon?, kalemler:[{adet,ad,not?}], not}
  Future<String> mutfakFisi(Map d) async {
    await yukle();
    final ist = (d['istasyon']?.toString() ?? 'mutfak');
    _init();
    _hizala(1); _boyut(1, 1); _kalin(true);
    _satir('*** ${istasyonAd[ist] ?? 'MUTFAK'} ***');
    _kalin(false); _boyut(0, 0); _hizala(0);
    _cizgi();
    _ikiSutun('Masa: ${d['masa'] ?? '-'}', (d['no'] != null && '${d['no']}'.isNotEmpty) ? 'Fis #${d['no']}' : (d['tarih']?.toString() ?? ''));
    if (d['no'] != null) _ikiSutun('', d['tarih']?.toString() ?? '');
    if ((d['garson']?.toString() ?? '').isNotEmpty) _satir('Garson: ${d['garson']}');
    _cizgi();
    _boyut(1, 1);
    for (final k in (d['kalemler'] as List?) ?? []) {
      final m = k as Map;
      _satir('${_n(m['adet']).toInt()}x ${m['ad'] ?? ''}');
      final not = m['not']?.toString() ?? '';
      if (not.isNotEmpty) { _boyut(0, 0); _satir('   > $not'); _boyut(1, 1); }
    }
    _boyut(0, 0);
    if ((d['not']?.toString() ?? '').isNotEmpty) { _cizgi(); _satir('NOT: ${d['not']}'); }
    _besle(3);
    _kes();
    return _gonder(_b, hedefIp: _istasyonHedefIp(ist)); // istasyon yazıcısı (yoksa mutfak/ana)
  }

  /// OTOMATİK mutfak fişi: sipariş mutfağa gönderilince moda göre basılır.
  /// Mod 'ekran' ise HİÇBİR ŞEY yapmaz (sadece KDS). 'yazici'/'ikisi' ise fiş basar.
  /// kalemler: [{adet, ad, not?, istasyon?}]. İSTASYONA GÖRE AYRI FİŞ (bar ayrı, ızgara ayrı) + ayrı yazıcıya.
  /// Hata olursa sessizce kısa mesaj döner (akışı bozmaz).
  Future<String?> otoMutfakFisi({required String masa, String? garson, required List<Map> kalemler, dynamic adisyonNo}) async {
    await yukle();
    if (!mutfakYazar) return null;            // sadece ekran modu -> yazdırma yok
    if (kalemler.isEmpty) return null;
    if (_mutfakHedefIp.isEmpty) return 'Mutfak yazıcı IP tanımlı değil';
    final saat = DateFormat('dd.MM HH:mm').format(DateTime.now());
    // İstasyona göre grupla -> her istasyona (bar/ızgara/...) KENDİ fişi, kendi yazıcısına
    final gruplar = <String, List<Map>>{};
    for (final k in kalemler) {
      final ist = (k['istasyon']?.toString().isNotEmpty ?? false) ? k['istasyon'].toString() : 'mutfak';
      (gruplar[ist] ??= []).add(k);
    }
    final hatalar = <String>[];
    for (final e in gruplar.entries) {
      final r = await mutfakFisi({'masa': masa, 'garson': garson ?? '', 'tarih': saat, 'no': adisyonNo, 'istasyon': e.key, 'kalemler': e.value});
      if (r != 'ok') hatalar.add('${istasyonAd[e.key] ?? e.key}: $r');
    }
    return hatalar.isEmpty ? 'ok' : hatalar.join(' · ');
  }

  /// Sadece çekmeceyi aç (kısa besleme + darbe).
  Future<String> cekmeceAcTest() async {
    await yukle();
    _init();
    _cekmeceAc();
    _besle(1);
    return _gonder(_b);
  }

  /// Bağlantı + Türkçe karakter testi (örnek hesap fişi).
  Future<String> testFisi() => hesapFisi({
        'isletme': 'ResteOS Test Şubesi',
        'adres': 'Örnek Mah. Çğüşöı Sk. No:1',
        'telefon': '0242 000 00 00',
        'masa': 'A5', 'adisyon_no': '1001', 'garson': 'Şükrü Çğ',
        'tarih': DateFormat('dd.MM HH:mm').format(DateTime.now()),
        'kalemler': [
          {'adet': 2, 'ad': 'İskender Porsiyon', 'tutar': 640},
          {'adet': 1, 'ad': 'Çoban Salata', 'tutar': 120},
          {'adet': 3, 'ad': 'Ayran', 'tutar': 90},
        ],
        'ara_toplam': 850, 'indirim': 50, 'ikram': 0, 'toplam': 800,
      });

  /// Mutfak fişi testi (örnek).
  Future<String> testMutfak() => mutfakFisi({
        'masa': 'A5', 'garson': 'Şükrü Çğ',
        'tarih': DateFormat('dd.MM HH:mm').format(DateTime.now()),
        'kalemler': [
          {'adet': 2, 'ad': 'İskender Porsiyon', 'not': 'Az yağlı'},
          {'adet': 1, 'ad': 'Çoban Salata', 'not': 'Soğansız'},
          {'adet': 3, 'ad': 'Ayran'},
        ],
        'not': 'Masaya birlikte çıksın',
      });

  // ---------- İÇ BARKOD ETİKETİ ----------
  // CODE128 barkod çizer (HRI altta). Dahili numaralar için ideal.
  void _barkodCiz(String kod) {
    _hizala(1);
    _b.addAll([0x1D, 0x48, 0x02]);   // GS H 2 — HRI barkodun ALTINDA
    _b.addAll([0x1D, 0x68, 90]);     // GS h — yükseklik (dot)
    _b.addAll([0x1D, 0x77, 0x02]);   // GS w — modül genişliği
    final veri = <int>[0x7B, 0x42];  // CODE128 "{B" (kod seti B)
    veri.addAll(kod.codeUnits);
    _b.addAll([0x1D, 0x6B, 73, veri.length]); // GS k 73 n
    _b.addAll(veri);
    _nl();
    _hizala(0);
  }

  /// İÇ BARKOD ETİKETİ — ad + CODE128 barkod + (ops.) fiyat + üretim/SKT. adet kadar basar.
  Future<String> etiketBas({required String ad, required String barkod, String? fiyat, String? uretim, String? skt, int adet = 1}) async {
    await yukle();
    final n = adet.clamp(1, 50);
    for (var i = 0; i < n; i++) {
      _init();
      _hizala(1);
      _boyut(1, 1); _kalin(true);
      _satir(ad.length > 22 ? ad.substring(0, 22) : ad);
      _kalin(false); _boyut(0, 0);
      _besle(1);
      _barkodCiz(barkod);
      if (fiyat != null && fiyat.trim().isNotEmpty) {
        _boyut(1, 1); _kalin(true); _hizala(1); _satir(fiyat); _hizala(0); _kalin(false); _boyut(0, 0);
      }
      if ((uretim ?? '').isNotEmpty) _satir('Uretim: $uretim');
      if ((skt ?? '').isNotEmpty) { _kalin(true); _satir('SKT: $skt'); _kalin(false); }
      _besle(3);
      _kes();
      final r = await _gonder(List<int>.from(_b));
      if (r != 'ok') return r;
    }
    return 'ok';
  }
}

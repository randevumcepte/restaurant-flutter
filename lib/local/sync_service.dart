import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import 'cihaz_rol.dart';
import 'local_db.dart';
import 'sync_worker.dart';

/// Senkron tetikleme + durum yonetimi.
///
/// KURAL: senkron SADECE internet baglantisi varken denenir. Baglanti yoksa
/// sistem tamamen YEREL calisir (hic istek atilmaz, pil/veri bosa gitmez).
/// Baglanti gelince aninda senkronlanir.
///
/// Adaptif aralik: aktivite varsa hizli (15sn), bos gecerse yavaslar (120sn'ye kadar)
/// -> sunucu bos yere zorlanmaz.
class SyncService extends ChangeNotifier with WidgetsBindingObserver {
  SyncService._();
  static final SyncService instance = SyncService._();

  static const _min = Duration(seconds: 15);
  static const _max = Duration(seconds: 120);

  Timer? _timer;
  Timer? _debounce;
  StreamSubscription? _baglantiAbone;
  bool _basladi = false;
  Duration _aralik = _min;
  int _bosTur = 0;

  bool online = true;       // GERÇEK internet erişimi var mı (İYİMSER başlangıç: aksi kanıtlanana
                            // kadar çevrimiçi say -> açılışta menü/masa buluttan çekilip önbelleğe/foto diske iner).
  bool _baglanti = true;    // ağ arayüzü bağlı mı (wifi/mobil) — erişim bundan ayrı
  bool calisiyor = false;
  int bekleyen = 0;         // outbox'ta bekleyen islem sayisi
  DateTime? sonSenkron;

  Future<void> basla() async {
    if (_basladi) return;
    // TERMINAL: yerel otorite degil (her seyi kasadan ceker) -> bulut senkronu CALISTIRMA.
    if (CihazRol.rol == Rol.terminal) return;
    _basladi = true;
    WidgetsBinding.instance.addObserver(this);

    // Baglanti durumunu dinle: kesilince dur, gelince GERÇEK erişimi doğrula.
    final c = Connectivity();
    _baglanti = !(await c.checkConnectivity()).contains(ConnectivityResult.none);
    // İYİMSER BAŞLANGIÇ: ağ varsa online say (probe birkaç sn sonra düzeltir).
    // Yoksa ilk saniyelerde "çevrimdışı" sanılıp masa/menü önbelleğe YAZILMADAN düz liste gösteriliyordu.
    online = _baglanti;
    _baglantiAbone = c.onConnectivityChanged.listen((sonuc) {
      _baglanti = !sonuc.contains(ConnectivityResult.none);
      if (!_baglanti) { // ağ gitti -> kesin çevrimdışı
        if (online) { online = false; notifyListeners(); }
      } else {
        simdiSenkronla(); // ağ geldi -> gerçek erişimi yokla + senkronla
      }
    });

    _zamanla();
    await _bekleyenGuncelle();
    simdiSenkronla();
  }

  // GERÇEK internet erişimi yoklaması: "wifi bağlı ama internet yok" durumunu yakalar.
  // connectivity sadece arayüzü bilir; bu ise sunucuya ulaşılıyor mu onu test eder.
  Future<void> _erisimYokla() async {
    if (!_baglanti) { if (online) { online = false; notifyListeners(); } return; }
    bool eristi = false;
    try {
      final r = await http.head(Uri.parse(AppConfig.baseUrl)).timeout(const Duration(seconds: 4));
      eristi = r.statusCode > 0;
    } catch (_) {
      eristi = false;
    }
    if (eristi != online) { online = eristi; notifyListeners(); }
  }

  void durdur() {
    _basladi = false;
    _timer?.cancel();
    _debounce?.cancel();
    _baglantiAbone?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }

  void _zamanla() {
    _timer?.cancel();
    _timer = Timer(_aralik, () {
      simdiSenkronla();
      _zamanla(); // adaptif: her tur kendini yeniden kurar
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && online) simdiSenkronla();
  }

  /// Yazma sonrasi cagir: 2 sn debounce ile tek senkronda topla.
  void yazmaOldu() {
    bekleyen++; // iyimser: UI hemen gorsin
    notifyListeners();
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), simdiSenkronla);
  }

  Future<void> simdiSenkronla() async {
    if (calisiyor) return;
    // GERÇEK erişimi yokla (wifi var ama internet yok -> online=false yapar).
    await _erisimYokla();
    // Erişim yoksa HIC deneme -> tamamen yerel calis.
    if (!online) {
      await _bekleyenGuncelle();
      return;
    }
    calisiyor = true;
    notifyListeners();
    try {
      final r = await SyncWorker.instance.senkronla();
      if (r.ok) sonSenkron = DateTime.now();

      // Adaptif aralik: aktivite oldukca hizli kal, bos turlarda yavasla.
      if (r.degisti) {
        _bosTur = 0;
        _aralik = _min;
      } else {
        _bosTur++;
        if (_bosTur >= 3) {
          _aralik = _max;
        } else if (_bosTur >= 1) {
          _aralik = const Duration(seconds: 45);
        }
      }

      await SyncWorker.instance.budaEski(); // yerel DB'yi kucuk tut
      await _bekleyenGuncelle();
    } finally {
      calisiyor = false;
      notifyListeners();
    }
  }

  Future<void> _bekleyenGuncelle() async {
    try {
      final d = await LocalDb.instance.db;
      final r = await d.rawQuery('SELECT COUNT(*) c FROM outbox');
      bekleyen = (r.first['c'] as int?) ?? 0;
    } catch (_) {
      bekleyen = 0;
    }
  }
}

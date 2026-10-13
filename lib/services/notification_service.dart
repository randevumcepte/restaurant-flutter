import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api.dart';

/// FCM push servisi — ResteOS Patron.
///
/// Tasarım ilkesi: Firebase yapılandırması (google-services.json /
/// GoogleService-Info.plist) YOKSA her şey sessizce no-op olur; uygulama
/// normal çalışmaya devam eder. Böylece push altyapısı kurulmadan da app açılır.
///
/// Akış: login sonrası [baslat] + [tokenKaydet] çağrılır; backend token'ı
/// `/api/bildirim/cihaz-kaydet` ile kaydeder. Çıkışta [tokenSil].
class NotificationService {
  static final NotificationService _i = NotificationService._();
  factory NotificationService() => _i;
  NotificationService._();

  bool _hazir = false;
  bool _firebaseVar = false;
  String? _fcmToken;
  StreamSubscription<String>? _refreshSub;
  StreamSubscription<RemoteMessage>? _foregroundSub;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  static const _kanalId = 'resteos_siparis';

  String? get fcmToken => _fcmToken;

  /// Uygulama açılışında (main) bir kez. Firebase yoksa sessizce geçer.
  Future<void> baslat() async {
    if (_hazir) return;
    _hazir = true;
    try {
      // google-services.json / plist yoksa burası fırlatır -> push kapalı, app çalışır.
      await Firebase.initializeApp();
      _firebaseVar = true;
      FirebaseMessaging.onBackgroundMessage(fcmArkaPlanHandler);
    } catch (e) {
      _firebaseVar = false;
      if (kDebugMode) debugPrint('[FCM] Firebase yapılandırılmamış, push kapalı: $e');
      return;
    }

    try {
      await FirebaseMessaging.instance.requestPermission(alert: true, badge: true, sound: true);
      await _localKur();

      // Ön planda (app açıkken) gelen bildirimi banner olarak göster.
      _foregroundSub = FirebaseMessaging.onMessage.listen(_onPlandaGoster);
      // Token yenilenince backend'e tekrar kaydet.
      _refreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((t) async {
        _fcmToken = t;
        await _backendeKaydet();
      });
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] baslat hata: $e');
    }
  }

  /// Login sonrası çağrılır — token alır ve backend'e kaydeder.
  Future<void> tokenKaydet() async {
    if (!_firebaseVar) return;
    try {
      _fcmToken = await FirebaseMessaging.instance.getToken();
      await _backendeKaydet();
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] tokenKaydet hata: $e');
    }
  }

  Future<void> _backendeKaydet() async {
    final t = _fcmToken;
    if (t == null || t.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final apiToken = sp.getString('token') ?? '';
    if (apiToken.isEmpty) return; // henüz login değil
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await Api.pushTokenKaydet(apiToken, t, platform: platform);
    } catch (e) {
      if (kDebugMode) debugPrint('[FCM] backend kayıt hata: $e');
    }
  }

  /// Çıkışta — backend'den bu cihaz token'ını sil.
  Future<void> tokenSil() async {
    if (!_firebaseVar) return;
    final sp = await SharedPreferences.getInstance();
    final apiToken = sp.getString('token') ?? '';
    final t = _fcmToken ?? '';
    if (apiToken.isEmpty) return;
    try {
      await Api.pushTokenSil(apiToken, fcmToken: t);
    } catch (_) {}
  }

  Future<void> _localKur() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(const InitializationSettings(android: android, iOS: ios));
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _kanalId, 'Sipariş & Çağrı',
          description: 'Yeni sipariş, garson çağrısı, masa taşıma',
          importance: Importance.high,
        ));
  }

  void _onPlandaGoster(RemoteMessage m) {
    final n = m.notification;
    if (n == null) return;
    _local.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _kanalId, 'Sipariş & Çağrı',
          importance: Importance.high, priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  void dispose() {
    _refreshSub?.cancel();
    _foregroundSub?.cancel();
  }
}

/// Arka plan (app kapalı/arkada) mesaj handler — top-level olmak ZORUNDA.
@pragma('vm:entry-point')
Future<void> fcmArkaPlanHandler(RemoteMessage message) async {
  // Bildirim sistemi otomatik gösterir; burada ekstra işlem gerekmiyor.
}

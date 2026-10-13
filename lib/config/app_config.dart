/// WHITE-LABEL yapılandırması.
///
/// Her markalı uygulama (ayrı mağaza listesi) aynı kod tabanından,
/// farklı `--dart-define` değerleriyle derlenir. Örnek:
///
///   flutter build apk \
///     --dart-define=BASE_URL=https://restaurant.webfirmam.com.tr \
///     --dart-define=APP_BUNDLE=com.marka.restoran \
///     --dart-define=MARKA_AD="Marka Restoran"
///
/// Hiçbir define verilmezse aşağıdaki varsayılanlar (ana ResteOS uygulaması)
/// kullanılır — eski davranış birebir korunur.
class AppConfig {
  /// Backend kök adresi (sonunda / YOK).
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://restaurant.webfirmam.com.tr',
  );

  /// Bu markalı uygulamanın bundle/package id'si. Backend login'de şube/marka
  /// eşlemesi ve push token kaydı için kullanılır.
  static const String appBundle = String.fromEnvironment(
    'APP_BUNDLE',
    defaultValue: 'com.resteos.enjula',
  );

  /// Uygulamada gösterilecek varsayılan marka adı. Login sonrası backend'den
  /// gelen `marka.ad` bunu geçersiz kılabilir.
  static const String markaAd = String.fromEnvironment(
    'MARKA_AD',
    defaultValue: 'Enjula Experience',
  );
}

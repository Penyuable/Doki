/// Konfigurasi yang bisa diubah saat build/run.
///
/// Contoh:
/// `flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1`
/// iOS simulator: `http://localhost:8080/api/v1`
/// Device fisik: `http://<IP-LAN>:8080/api/v1`
abstract final class Env {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );

  /// Katalog disegarkan otomatis saat app resume bila sudah lewat interval ini.
  static const Duration catalogRefreshInterval = Duration(minutes: 15);

  static const String appVersion = '1.0.0';
  static const String engineVersion = '1.0.0';
}

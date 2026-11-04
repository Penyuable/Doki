import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Penyimpanan lokal: token di secure storage, preferensi & cache di Hive.
class AppStorage {
  AppStorage._(this._secure, this._settings, this._cache);

  static const _accessKey = 'dokimon.access_token';
  static const _refreshKey = 'dokimon.refresh_token';

  static const String kLocale = 'locale';
  static const String kReduceMotion = 'reduce_motion';
  static const String kHaptics = 'haptics';
  static const String kBatterySaver = 'battery_saver';
  static const String kCatalogPayload = 'catalog.payload';
  static const String kCatalogVersion = 'catalog.version';
  static const String kInventoryPayload = 'inventory.payload';
  static const String kOnboarded = 'onboarded';
  static const String kTableTheme = 'table_theme';

  final FlutterSecureStorage _secure;
  final Box<dynamic> _settings;
  final Box<dynamic> _cache;

  static Future<AppStorage> create() async {
    await Hive.initFlutter();
    final settings = await Hive.openBox<dynamic>('dokimon_settings');
    final cache = await Hive.openBox<dynamic>('dokimon_cache');
    return AppStorage._(
      const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
      settings,
      cache,
    );
  }

  Future<String?> readAccessToken() async {
    try {
      return await _secure.read(key: _accessKey);
    } catch (_) {
      return null;
    }
  }

  Future<String?> readRefreshToken() async {
    try {
      return await _secure.read(key: _refreshKey);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _secure.write(key: _accessKey, value: accessToken);
    await _secure.write(key: _refreshKey, value: refreshToken);
  }

  Future<void> clearTokens() async {
    try {
      await _secure.delete(key: _accessKey);
      await _secure.delete(key: _refreshKey);
    } catch (_) {
      // Token bisa saja sudah tidak ada; tidak perlu menghentikan logout.
    }
  }

  String? get localeCode => _settings.get(kLocale) as String?;

  String? getString(String key) {
    final value = _settings.get(key);
    return value is String ? value : null;
  }

  bool getBool(String key, {bool fallback = false}) {
    final value = _settings.get(key);
    return value is bool ? value : fallback;
  }

  Future<void> setValue(String key, Object? value) async {
    if (value == null) {
      await _settings.delete(key);
    } else {
      await _settings.put(key, value);
    }
  }

  String? cacheString(String key) {
    final value = _cache.get(key);
    return value is String && value.isNotEmpty ? value : null;
  }

  Future<void> writeCache(String key, String value) => _cache.put(key, value);

  Future<void> clearCache() => _cache.clear();
}

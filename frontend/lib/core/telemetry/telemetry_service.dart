import 'dart:async';

import '../network/api_client.dart';

/// Telemetri buffered; tidak pernah mengganggu alur permainan.
/// Nama event dibatasi oleh allowlist backend.
class TelemetryService {
  TelemetryService(this._api);

  static const Set<String> _allowedEvents = <String>{
    'app_open',
    'auth_register',
    'auth_login',
    'catalog_sync',
    'gacha_pull',
    'deck_save',
    'battle_start',
    'battle_end',
    'battle_concede',
    'error',
  };

  static const Set<String> _forbiddenKeys = <String>{
    'password',
    'token',
    'email',
    'authorization',
    'secret',
  };

  final ApiClient _api;
  final List<Map<String, dynamic>> _queue = <Map<String, dynamic>>[];
  bool _flushing = false;

  void track(String name, [Map<String, dynamic>? props]) {
    if (!_allowedEvents.contains(name)) return;
    final safeProps = <String, dynamic>{};
    if (props != null) {
      for (final entry in props.entries) {
        final key = entry.key.toLowerCase();
        if (_forbiddenKeys.any(key.contains)) continue;
        safeProps[entry.key] = entry.value;
      }
    }
    _queue.add(<String, dynamic>{'name': name, 'props': safeProps});
    if (_queue.length >= 10) {
      unawaited(flush());
    }
  }

  Future<void> flush() async {
    if (_flushing || _queue.isEmpty || !_api.hasSession) return;
    _flushing = true;
    final batch = List<Map<String, dynamic>>.from(_queue.take(50));
    _queue.removeRange(0, batch.length);
    try {
      await _api.post(
        '/telemetry/events',
        body: <String, dynamic>{'events': batch},
      );
    } catch (_) {
      // Telemetri bukan fitur kritis; jangan retry agresif.
    } finally {
      _flushing = false;
    }
  }
}

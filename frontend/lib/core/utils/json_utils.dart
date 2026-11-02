/// Parsing JSON defensif. Jangan pernah memakai `!` untuk field dari network.
library;

Map<String, dynamic> asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
  return const <String, dynamic>{};
}

List<dynamic> asJsonList(Object? value) => value is List ? value : const <dynamic>[];

String asString(Object? value, [String fallback = '']) {
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return fallback;
}

String? asStringOrNull(Object? value) {
  if (value is String && value.trim().isNotEmpty) return value;
  return null;
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

int? asIntOrNull(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  if (value is String) return int.tryParse(value);
  return null;
}

double asDouble(Object? value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return fallback;
}

DateTime? asDateTime(Object? value) {
  if (value is String) return DateTime.tryParse(value)?.toLocal();
  return null;
}

extension JsonReader on Map<String, dynamic> {
  Map<String, dynamic> objectOf(String key) => asJsonMap(this[key]);
  List<dynamic> listOf(String key) => asJsonList(this[key]);
  String str(String key, [String fallback = '']) => asString(this[key], fallback);
  String? strOrNull(String key) => asStringOrNull(this[key]);
  int integer(String key, [int fallback = 0]) => asInt(this[key], fallback);
  int? integerOrNull(String key) => asIntOrNull(this[key]);
  double decimal(String key, [double fallback = 0]) => asDouble(this[key], fallback);
  bool boolean(String key, [bool fallback = false]) => asBool(this[key], fallback);
  DateTime? dateTime(String key) => asDateTime(this[key]);
}

/// Enum dari nilai API (case-insensitive). Selalu punya fallback.
T enumFromApi<T extends Enum>(
  Object? raw,
  List<T> values,
  T fallback, {
  String Function(T value)? nameOf,
}) {
  final text = asString(raw).toLowerCase();
  if (text.isEmpty) return fallback;
  for (final value in values) {
    final candidate = (nameOf?.call(value) ?? value.name).toLowerCase();
    if (candidate == text) return value;
  }
  return fallback;
}

extension FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T value) test) {
    for (final value in this) {
      if (test(value)) return value;
    }
    return null;
  }
}

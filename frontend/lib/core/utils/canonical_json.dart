import 'dart:convert';

/// JSON kanonik: key objek diurutkan rekursif, tanpa spasi.
/// Dipakai untuk `logHash` battle agar dua state identik menghasilkan hash sama.
String canonicalJson(Object? value) {
  if (value == null) return 'null';
  if (value is num || value is bool) return jsonEncode(value);
  if (value is String) return jsonEncode(value);
  if (value is List) {
    return '[${value.map(canonicalJson).join(',')}]';
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    final buffer = StringBuffer('{');
    for (var i = 0; i < keys.length; i++) {
      if (i > 0) buffer.write(',');
      final key = keys[i];
      buffer
        ..write(jsonEncode(key))
        ..write(':')
        ..write(canonicalJson(value[key]));
    }
    buffer.write('}');
    return buffer.toString();
  }
  return jsonEncode(value.toString());
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/utils/json_utils.dart';
import 'local_backend.dart';

/// Adapter Dio yang melayani request dari [LocalBackend] alih-alih jaringan.
class LocalHttpAdapter implements HttpClientAdapter {
  LocalHttpAdapter(this._backend);

  final LocalBackend _backend;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final body = asJsonMap(options.data);
    try {
      final data = await _backend.handle(
        options.method.toUpperCase(),
        options.path,
        body,
        options.queryParameters,
      );
      return _json(200, <String, dynamic>{'data': data});
    } on LocalApiError catch (error) {
      return _json(error.status, error.toJson());
    }
  }

  ResponseBody _json(int status, Map<String, dynamic> payload) {
    return ResponseBody.fromString(
      jsonEncode(payload),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

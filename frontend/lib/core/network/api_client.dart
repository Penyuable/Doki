import 'package:dio/dio.dart';

import '../../domain/models/user_model.dart';
import '../config/env.dart';
import '../storage/app_storage.dart';
import '../utils/json_utils.dart';
import 'api_exception.dart';

enum _RefreshOutcome { success, invalid, network }

/// Satu pintu HTTP ke backend. Menangani token, refresh single-flight,
/// dan envelope `{data}` / `{error}`.
class ApiClient {
  ApiClient({required AppStorage storage, Dio? dio})
    : _storage = storage,
      _dio = dio ?? Dio() {
    _dio.options = BaseOptions(
      baseUrl: Env.apiBaseUrl,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 25),
      sendTimeout: const Duration(seconds: 12),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
      headers: const {'Accept': 'application/json'},
    );
  }

  final AppStorage _storage;
  final Dio _dio;

  String? _accessToken;
  String? _refreshToken;
  Future<_RefreshOutcome>? _refreshing;

  /// Dipanggil ketika refresh token ditolak server (sesi benar-benar habis).
  void Function()? onSessionExpired;

  bool get hasSession =>
      _refreshToken != null && _refreshToken!.isNotEmpty;

  Future<void> init() async {
    _accessToken = await _storage.readAccessToken();
    _refreshToken = await _storage.readRefreshToken();
  }

  Future<void> applySession(AuthSession session) async {
    _accessToken = session.accessToken;
    _refreshToken = session.refreshToken;
    await _storage.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
  }

  Future<void> clearSession() async {
    _accessToken = null;
    _refreshToken = null;
    await _storage.clearTokens();
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) {
    return _request('GET', path, query: query, auth: auth);
  }

  Future<Map<String, dynamic>> post(
    String path, {
    Object? body,
    bool auth = true,
  }) {
    return _request('POST', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> patch(
    String path, {
    Object? body,
    bool auth = true,
  }) {
    return _request('PATCH', path, body: body, auth: auth);
  }

  Future<Map<String, dynamic>> put(
    String path, {
    Object? body,
    bool auth = true,
  }) {
    return _request('PUT', path, body: body, auth: auth);
  }

  Future<void> delete(String path, {bool auth = true}) async {
    await _request('DELETE', path, auth: auth);
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    try {
      return await _send(method, path, body: body, query: query, auth: auth);
    } on DioException catch (error) {
      final exception = ApiException.fromDio(error);

      final shouldRefresh =
          auth &&
          !path.startsWith('/auth/') &&
          exception.isAuthExpired &&
          _refreshToken != null &&
          _refreshToken!.isNotEmpty;

      if (!shouldRefresh) throw exception;

      final outcome = await _refresh();
      if (outcome == _RefreshOutcome.success) {
        try {
          return await _send(
            method,
            path,
            body: body,
            query: query,
            auth: auth,
          );
        } on DioException catch (retryError) {
          throw ApiException.fromDio(retryError);
        }
      }

      if (outcome == _RefreshOutcome.invalid) {
        await clearSession();
        onSessionExpired?.call();
      }
      throw exception;
    }
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    required bool auth,
  }) async {
    final headers = <String, dynamic>{
      if (auth && _accessToken != null && _accessToken!.isNotEmpty)
        'Authorization': 'Bearer $_accessToken',
    };

    final response = await _dio.request<dynamic>(
      path,
      data: body,
      queryParameters: query,
      options: Options(method: method, headers: headers),
    );

    final raw = response.data;
    if (raw == null) return <String, dynamic>{};

    final map = asJsonMap(raw);
    final data = map['data'];
    if (data is Map) return asJsonMap(data);
    if (data != null) return <String, dynamic>{'value': data};
    return map;
  }

  Future<_RefreshOutcome> _refresh() {
    final pending = _refreshing;
    if (pending != null) return pending;

    final future = _performRefresh();
    _refreshing = future;
    return future.whenComplete(() {
      if (identical(_refreshing, future)) _refreshing = null;
    });
  }

  Future<_RefreshOutcome> _performRefresh() async {
    final token = _refreshToken;
    if (token == null || token.isEmpty) return _RefreshOutcome.invalid;

    try {
      final response = await _dio.post<dynamic>(
        '/auth/refresh',
        data: <String, dynamic>{'refreshToken': token},
        options: Options(headers: const <String, dynamic>{}),
      );

      final data = asJsonMap(asJsonMap(response.data)['data']);
      final access = data.str('accessToken');
      final refresh = data.str('refreshToken');
      if (access.isEmpty || refresh.isEmpty) return _RefreshOutcome.invalid;

      _accessToken = access;
      _refreshToken = refresh;
      await _storage.saveTokens(accessToken: access, refreshToken: refresh);
      return _RefreshOutcome.success;
    } on DioException catch (error) {
      final exception = ApiException.fromDio(error);
      return exception.isNetwork
          ? _RefreshOutcome.network
          : _RefreshOutcome.invalid;
    } catch (_) {
      return _RefreshOutcome.invalid;
    }
  }
}

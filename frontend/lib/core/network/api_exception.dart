import 'package:dio/dio.dart';

import '../utils/json_utils.dart';

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details,
  });

  final String code;
  final String message;
  final int? statusCode;
  final Object? details;

  bool get isAuthExpired =>
      statusCode == 401 || code == 'TOKEN_EXPIRED' || code == 'UNAUTHORIZED';

  bool get isNetwork => code == 'NETWORK_ERROR';

  bool get isInsufficientFunds => code == 'INSUFFICIENT_FUNDS';

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    }

    final body = asJsonMap(response.data);
    final errorJson = asJsonMap(body['error']);
    final code = errorJson.str('code', 'INTERNAL_ERROR');
    final message = errorJson.str(
      'message',
      _fallbackMessage(response.statusCode),
    );

    return ApiException(
      code: code,
      message: message,
      statusCode: response.statusCode,
      details: errorJson['details'],
    );
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';

  static String _fallbackMessage(int? status) {
    if (status == null) return 'Terjadi kesalahan.';
    if (status >= 500) return 'Server sedang bermasalah. Coba lagi.';
    if (status == 401) return 'Sesi berakhir. Silakan masuk kembali.';
    if (status == 403) return 'Akses ditolak.';
    if (status == 404) return 'Data tidak ditemukan.';
    if (status == 429) return 'Terlalu banyak permintaan. Tunggu sebentar.';
    return 'Permintaan gagal (HTTP $status).';
  }
}

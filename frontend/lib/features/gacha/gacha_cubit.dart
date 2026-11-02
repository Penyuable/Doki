import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/gacha_repository.dart';
import '../../domain/models/gacha_model.dart';
import '../auth/auth_cubit.dart';

sealed class GachaState {
  const GachaState();
}

class GachaLoading extends GachaState {
  const GachaLoading();
}

class GachaReady extends GachaState {
  const GachaReady({
    required this.pity,
    this.rates,
    this.pulling = false,
    this.result,
    this.errorCode,
    this.errorMessage,
  });

  final PityInfo pity;
  final GachaRatesData? rates;
  final bool pulling;
  final GachaPullResponse? result;
  final String? errorCode;
  final String? errorMessage;

  GachaReady copyWith({
    PityInfo? pity,
    GachaRatesData? rates,
    bool? pulling,
    GachaPullResponse? result,
    String? errorCode,
    String? errorMessage,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return GachaReady(
      pity: pity ?? this.pity,
      rates: rates ?? this.rates,
      pulling: pulling ?? this.pulling,
      result: clearResult ? null : (result ?? this.result),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class GachaError extends GachaState {
  const GachaError(this.message);

  final String message;
}

class GachaCubit extends Cubit<GachaState> {
  GachaCubit(this._repository, this._auth) : super(const GachaLoading());

  final GachaRepository _repository;
  final AuthCubit _auth;
  final Uuid _uuid = const Uuid();

  Future<void> init() async {
    emit(const GachaLoading());

    PityInfo? pity;
    GachaRatesData? rates;
    String? authError;

    try {
      pity = await _repository.pity();
    } on ApiException catch (error) {
      if (error.isAuthExpired) authError = error.message;
    } catch (_) {
      // Abaikan: masih bisa memakai pity default.
    }

    try {
      rates = await _repository.rates();
    } catch (_) {
      // Tombol rate akan menampilkan pesan error.
    }

    if (authError != null) {
      emit(GachaError(authError));
      return;
    }
    if (pity == null && rates == null) {
      emit(const GachaError('Gacha tidak tersedia saat ini.'));
      return;
    }

    emit(GachaReady(pity: pity ?? PityInfo.empty, rates: rates));
  }

  Future<GachaPullResponse?> pull({
    required int count,
    required String currency,
  }) async {
    final current = state;
    if (current is! GachaReady || current.pulling) return null;

    emit(current.copyWith(pulling: true, clearError: true));
    try {
      final response = await _repository.pull(
        count: count,
        currency: currency,
        idempotencyKey: _uuid.v4(),
      );
      _auth.applyWallet(response.balance);
      emit(
        current.copyWith(
          pulling: false,
          pity: response.pity,
          result: response,
        ),
      );
      return response;
    } on ApiException catch (error) {
      emit(
        current.copyWith(
          pulling: false,
          errorCode: error.code,
          errorMessage: error.message,
        ),
      );
      return null;
    } catch (_) {
      emit(
        current.copyWith(
          pulling: false,
          errorCode: 'UNKNOWN',
          errorMessage: 'Gacha gagal. Coba lagi.',
        ),
      );
      return null;
    }
  }

  void clearResult() {
    final current = state;
    if (current is GachaReady && current.result != null) {
      emit(current.copyWith(clearResult: true));
    }
  }

  void clearError() {
    final current = state;
    if (current is GachaReady) {
      emit(current.copyWith(clearError: true));
    }
  }

  Future<GachaRatesData?> loadRates() async {
    final current = state;
    if (current is GachaReady && current.rates != null) {
      return current.rates;
    }
    try {
      final rates = await _repository.rates();
      if (!isClosed && state is GachaReady) {
        emit((state as GachaReady).copyWith(rates: rates));
      }
      return rates;
    } catch (_) {
      return null;
    }
  }
}

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/app_storage.dart';
import '../../data/repositories/auth_repository.dart';
import '../../domain/models/user_model.dart';

sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

/// Dipakai saat memulihkan sesi dari token tersimpan (splash).
class AuthRestoring extends AuthState {
  const AuthRestoring();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated({
    required this.user,
    required this.stats,
    this.activeDeckId,
  });

  final UserModel user;
  final UserStats stats;
  final String? activeDeckId;

  AuthAuthenticated copyWith({
    UserModel? user,
    UserStats? stats,
    String? activeDeckId,
  }) {
    return AuthAuthenticated(
      user: user ?? this.user,
      stats: stats ?? this.stats,
      activeDeckId: activeDeckId ?? this.activeDeckId,
    );
  }
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated({this.message, this.sessionExpired = false});

  final String? message;
  final bool sessionExpired;
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required AuthRepository repository,
    required ApiClient api,
    required AppStorage storage,
  }) : _repository = repository,
       _api = api,
       _storage = storage,
       super(const AuthInitial()) {
    _api.onSessionExpired = _onSessionExpired;
  }

  final AuthRepository _repository;
  final ApiClient _api;
  final AppStorage _storage;

  void _onSessionExpired() {
    if (isClosed) return;
    emit(const AuthUnauthenticated(sessionExpired: true));
  }

  Future<void> restore() async {
    emit(const AuthRestoring());
    final refresh = await _storage.readRefreshToken();
    if (refresh == null || refresh.isEmpty) {
      emit(const AuthUnauthenticated());
      return;
    }
    try {
      final me = await _repository.me();
      emit(
        AuthAuthenticated(
          user: me.user,
          stats: me.stats,
          activeDeckId: me.activeDeckId,
        ),
      );
    } on ApiException catch (error) {
      emit(
        AuthUnauthenticated(
          message: error.isNetwork ? error.message : null,
          sessionExpired: error.isAuthExpired,
        ),
      );
    } catch (_) {
      emit(const AuthUnauthenticated());
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    emit(const AuthLoading());
    try {
      final session = await _repository.login(
        email: email,
        password: password,
      );
      emit(
        AuthAuthenticated(
          user: session.user,
          stats: UserStats.empty,
        ),
      );
      await refreshProfile();
      return true;
    } on ApiException catch (error) {
      emit(AuthUnauthenticated(message: error.message));
      return false;
    } catch (_) {
      emit(const AuthUnauthenticated(message: 'Terjadi kesalahan.'));
      return false;
    }
  }

  Future<bool> register({
    required String email,
    required String username,
    required String password,
  }) async {
    emit(const AuthLoading());
    try {
      final session = await _repository.register(
        email: email,
        username: username,
        password: password,
      );
      emit(
        AuthAuthenticated(
          user: session.user,
          stats: UserStats.empty,
        ),
      );
      await refreshProfile();
      return true;
    } on ApiException catch (error) {
      emit(AuthUnauthenticated(message: error.message));
      return false;
    } catch (_) {
      emit(const AuthUnauthenticated(message: 'Terjadi kesalahan.'));
      return false;
    }
  }

  Future<void> refreshProfile() async {
    if (!_api.hasSession) return;
    try {
      final me = await _repository.me();
      emit(
        AuthAuthenticated(
          user: me.user,
          stats: me.stats,
          activeDeckId: me.activeDeckId,
        ),
      );
    } on ApiException catch (error) {
      if (error.isAuthExpired) {
        emit(const AuthUnauthenticated(sessionExpired: true));
      }
      // Error jaringan: pertahankan data terakhir agar UI tidak kosong.
    }
  }

  void applyUser(UserModel user) {
    final current = state;
    if (current is AuthAuthenticated) {
      emit(current.copyWith(user: user));
    }
  }

  /// Menghapus pesan error di halaman auth (mis. saat ganti mode).
  void clearMessage() {
    final current = state;
    if (current is AuthUnauthenticated && current.message != null) {
      emit(AuthUnauthenticated(sessionExpired: current.sessionExpired));
    }
  }

  void applyWallet(WalletModel wallet) {
    final current = state;
    if (current is AuthAuthenticated) {
      emit(current.copyWith(user: current.user.copyWith(
        gold: wallet.gold,
        gems: wallet.gems,
      )));
    }
  }

  Future<void> logout() async {
    final refresh = await _storage.readRefreshToken();
    try {
      await _repository.logout(refresh ?? '');
    } catch (_) {
      await _api.clearSession();
    }
    emit(const AuthUnauthenticated());
  }
}

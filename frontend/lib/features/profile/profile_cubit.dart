import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/user_model.dart';
import '../auth/auth_cubit.dart';

sealed class ProfileState {
  const ProfileState();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileReady extends ProfileState {
  const ProfileReady({required this.profile, this.claimingDaily = false});

  final UserProfile profile;
  final bool claimingDaily;

  ProfileReady copyWith({UserProfile? profile, bool? claimingDaily}) {
    return ProfileReady(
      profile: profile ?? this.profile,
      claimingDaily: claimingDaily ?? this.claimingDaily,
    );
  }
}

class ProfileError extends ProfileState {
  const ProfileError(this.message);

  final String message;
}

/// Sumber tunggal data profil untuk tab Home & Profil.
class ProfileCubit extends Cubit<ProfileState> {
  ProfileCubit(this._repository, this._auth) : super(const ProfileLoading());

  final UserRepository _repository;
  final AuthCubit _auth;

  UserProfile? get profile {
    final current = state;
    return current is ProfileReady ? current.profile : null;
  }

  Future<void> load() async {
    emit(const ProfileLoading());
    try {
      final profile = await _repository.profile();
      _auth.applyUser(profile.user);
      emit(ProfileReady(profile: profile));
    } on ApiException catch (error) {
      emit(ProfileError(error.message));
    } catch (_) {
      emit(const ProfileError('Profil gagal dimuat.'));
    }
  }

  /// Refresh tanpa mengosongkan layar (dipakai setelah battle/gacha).
  Future<void> refresh() async {
    try {
      final profile = await _repository.profile();
      _auth.applyUser(profile.user);
      final current = state;
      if (current is ProfileReady) {
        emit(current.copyWith(profile: profile, claimingDaily: false));
      } else {
        emit(ProfileReady(profile: profile));
      }
    } on ApiException {
      // Pertahankan data lama bila refresh gagal.
    }
  }

  /// Mengembalikan pesan error (null = sukses) agar bisa ditampilkan page.
  Future<String?> claimDaily() async {
    final current = state;
    if (current is! ProfileReady || current.claimingDaily) return null;
    if (!current.profile.daily.canClaim) return null;

    emit(current.copyWith(claimingDaily: true));
    try {
      final result = await _repository.claimDaily();
      _auth.applyWallet(result.balance);
      await refresh();
      return null;
    } on ApiException catch (error) {
      emit(current.copyWith(claimingDaily: false));
      return error.message;
    } catch (_) {
      emit(current.copyWith(claimingDaily: false));
      return 'Hadiah gagal diambil.';
    }
  }
}

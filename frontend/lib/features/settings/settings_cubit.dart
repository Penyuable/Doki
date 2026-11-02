import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/storage/app_storage.dart';

class AppSettings {
  const AppSettings({
    required this.localeCode,
    required this.reduceMotion,
    required this.haptics,
    required this.batterySaver,
  });

  final String localeCode;
  final bool reduceMotion;
  final bool haptics;
  final bool batterySaver;

  static AppSettings fromStorage(AppStorage storage) {
    final code = storage.localeCode;
    return AppSettings(
      localeCode: code == 'en' ? 'en' : 'id',
      reduceMotion: storage.getBool(AppStorage.kReduceMotion),
      haptics: storage.getBool(AppStorage.kHaptics, fallback: true),
      batterySaver: storage.getBool(AppStorage.kBatterySaver),
    );
  }

  AppSettings copyWith({
    String? localeCode,
    bool? reduceMotion,
    bool? haptics,
    bool? batterySaver,
  }) {
    return AppSettings(
      localeCode: localeCode ?? this.localeCode,
      reduceMotion: reduceMotion ?? this.reduceMotion,
      haptics: haptics ?? this.haptics,
      batterySaver: batterySaver ?? this.batterySaver,
    );
  }
}

class SettingsCubit extends Cubit<AppSettings> {
  SettingsCubit(this._storage) : super(AppSettings.fromStorage(_storage));

  final AppStorage _storage;

  Future<void> setLocale(String code) async {
    if (code == state.localeCode) return;
    await _storage.setValue(AppStorage.kLocale, code);
    emit(state.copyWith(localeCode: code));
  }

  Future<void> setReduceMotion(bool value) async {
    await _storage.setValue(AppStorage.kReduceMotion, value);
    emit(state.copyWith(reduceMotion: value));
  }

  Future<void> setHaptics(bool value) async {
    await _storage.setValue(AppStorage.kHaptics, value);
    emit(state.copyWith(haptics: value));
  }

  Future<void> setBatterySaver(bool value) async {
    await _storage.setValue(AppStorage.kBatterySaver, value);
    emit(state.copyWith(batterySaver: value));
  }
}

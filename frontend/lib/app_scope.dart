import 'package:flutter/widgets.dart';

import 'core/network/api_client.dart';
import 'core/storage/app_storage.dart';
import 'data/repositories/repositories.dart';

/// Akses dependency lintas widget tanpa service locator global.
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.api,
    required this.storage,
    required this.repositories,
    required super.child,
  });

  final ApiClient api;
  final AppStorage storage;
  final Repositories repositories;

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope tidak ditemukan di widget tree');
    return scope!;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      api != oldWidget.api ||
      storage != oldWidget.storage ||
      repositories != oldWidget.repositories;
}

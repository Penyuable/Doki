import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_scope.dart';
import 'core/i18n/app_strings.dart';
import 'core/network/api_client.dart';
import 'core/storage/app_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/repositories.dart';
import 'features/auth/auth_cubit.dart';
import 'features/auth/auth_page.dart';
import 'features/catalog/catalog_cubit.dart';
import 'features/settings/settings_cubit.dart';
import 'features/shell/home_shell.dart';
import 'features/shell/splash_page.dart';

class DokimonApp extends StatelessWidget {
  const DokimonApp({
    super.key,
    required this.api,
    required this.storage,
    required this.repositories,
    required this.settings,
  });

  final ApiClient api;
  final AppStorage storage;
  final Repositories repositories;
  final SettingsCubit settings;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      api: api,
      storage: storage,
      repositories: repositories,
      child: BlocProvider<SettingsCubit>.value(
        value: settings,
        child: BlocBuilder<SettingsCubit, AppSettings>(
          builder: (context, settingsState) {
            return MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<AuthCubit>(
                  create: (_) => AuthCubit(
                    repository: repositories.auth,
                    api: api,
                    storage: storage,
                  )..restore(),
                ),
                BlocProvider<CatalogCubit>(
                  create: (_) => CatalogCubit(repositories.catalog)..load(),
                ),
              ],
              child: MaterialApp(
                title: 'Dokimon',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.dark(),
                darkTheme: AppTheme.dark(),
                themeMode: ThemeMode.dark,
                locale: Locale(settingsState.localeCode),
                supportedLocales: AppStrings.supportedLocaleCodes
                    .map(Locale.new)
                    .toList(growable: false),
                localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                  AppStringsDelegate(),
                  GlobalMaterialLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                ],
                home: const RootGate(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const HomeShell();
        }
        if (state is AuthInitial || state is AuthRestoring) {
          return const SplashPage();
        }
        return const AuthPage();
      },
    );
  }
}

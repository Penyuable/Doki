import 'dart:async';

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
                theme: AppTheme.clay(),
                themeMode: ThemeMode.light,
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

class RootGate extends StatefulWidget {
  const RootGate({super.key, this.minSplash = kMinSplashDuration});

  /// Splash tetap tampil minimal selama ini walau sesi sudah pulih.
  final Duration minSplash;

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _splashElapsed = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.minSplash, () {
      if (mounted) setState(() => _splashElapsed = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        final Widget page;
        if (!_splashElapsed || state is AuthInitial || state is AuthRestoring) {
          page = const SplashPage(key: ValueKey<String>('splash'));
        } else if (state is AuthAuthenticated) {
          page = const HomeShell(key: ValueKey<String>('home'));
        } else {
          page = const AuthPage(key: ValueKey<String>('auth'));
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 450),
          child: page,
        );
      },
    );
  }
}

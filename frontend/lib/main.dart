import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/network/api_client.dart';
import 'core/storage/app_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/local/local_backend.dart';
import 'data/local/local_http_adapter.dart';
import 'data/repositories/catalog_repository.dart';
import 'data/repositories/repositories.dart';
import 'features/settings/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Layout game dirancang untuk portrait (Android & iOS).
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  try {
    final storage = await AppStorage.create();
    final api = ApiClient(
      storage: storage,
      dio: Env.offlineMode ? await _offlineDio() : null,
    );
    await api.init();
    final repositories = Repositories.create(api: api, storage: storage);
    final settings = SettingsCubit(storage);

    runApp(
      DokimonApp(
        api: api,
        storage: storage,
        repositories: repositories,
        settings: settings,
      ),
    );
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'dokimon bootstrap',
      ),
    );
    runApp(const _BootstrapErrorApp());
  }
}

/// Dio yang dilayani backend lokal; katalog diambil dari aset bawaan.
Future<Dio> _offlineDio() async {
  final raw = await rootBundle.loadString(CatalogRepository.assetPath);
  final decoded = jsonDecode(raw);
  final catalog = <Map<String, dynamic>>[
    if (decoded is List)
      for (final item in decoded)
        if (item is Map) Map<String, dynamic>.from(item),
  ];
  final backend = await LocalBackend.create(catalog: catalog);
  return Dio()..httpClientAdapter = LocalHttpAdapter(backend);
}

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.clay(),
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.error_outline_rounded, size: 52),
                SizedBox(height: 16),
                Text(
                  'Aplikasi gagal dimuat',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'Penyimpanan lokal tidak dapat dibuka. '
                  'Coba tutup lalu buka kembali aplikasi.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

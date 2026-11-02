import 'package:flutter/material.dart';

import 'app.dart';
import 'core/network/api_client.dart';
import 'core/storage/app_storage.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/repositories.dart';
import 'features/settings/settings_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    final storage = await AppStorage.create();
    final api = ApiClient(storage: storage);
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

class _BootstrapErrorApp extends StatelessWidget {
  const _BootstrapErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
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

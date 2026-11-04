import 'package:dokimon/core/i18n/app_strings.dart';
import 'package:dokimon/features/shell/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppStringsDelegate(),
      ],
      home: child,
    );

void main() {
  testWidgets('splash menunggu durasi minimum lalu selesai di 100%', (
    tester,
  ) async {
    var loaded = 0;
    await tester.pumpWidget(
      _host(
        SplashPage(
          assets: const <String>[],
          minDuration: const Duration(milliseconds: 800),
          onLoaded: () => loaded++,
        ),
      ),
    );
    await tester.pump(); // delegate lokalisasi selesai dimuat
    await tester.pump(const Duration(milliseconds: 400));
    expect(loaded, 0, reason: 'belum boleh selesai sebelum durasi minimum');
    expect(find.text('100%'), findsNothing);

    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(loaded, 1);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text(const AppStrings('en').t('splash.ready')), findsOneWidget);

    // Tidak dipanggil dua kali.
    await tester.pump(const Duration(seconds: 2));
    expect(loaded, 1);
  });

  test('aset splash mencakup semua ilustrasi monster', () {
    final assets = defaultSplashAssets();
    expect(assets, isNotEmpty);
    expect(assets.toSet().length, assets.length);
    expect(assets.every((a) => a.startsWith('assets/creatures/')), isTrue);
  });

  test('teks splash tersedia di id dan en', () {
    for (final code in AppStrings.supportedLocaleCodes) {
      final strings = AppStrings(code);
      for (final key in <String>[
        'splash.step.cards',
        'splash.step.monsters',
        'splash.step.table',
        'splash.ready',
        'splash.tip.0',
        'splash.tip.1',
        'splash.tip.2',
      ]) {
        expect(strings.t(key), isNot(key), reason: '$code $key');
      }
    }
  });
}

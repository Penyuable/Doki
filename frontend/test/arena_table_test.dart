import 'package:dokimon/core/i18n/app_strings.dart';
import 'package:dokimon/core/ui/arena_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nama tema tak dikenal jatuh ke meja kayu', () {
    expect(TableTheme.fromName('cosmic'), TableTheme.cosmic);
    expect(TableTheme.fromName(null), TableTheme.wood);
    expect(TableTheme.fromName('lava'), TableTheme.wood);
  });

  test('setiap tema punya label di id dan en', () {
    for (final code in AppStrings.supportedLocaleCodes) {
      final strings = AppStrings(code);
      expect(strings.t('table.title'), isNot('table.title'));
      for (final theme in TableTheme.values) {
        expect(strings.t(theme.i18nKey), isNot(theme.i18nKey));
      }
    }
  });

  testWidgets('semua tema meja tergambar (miring & datar) tanpa error', (
    tester,
  ) async {
    for (final theme in TableTheme.values) {
      for (final tilt in <bool>[true, false]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 360,
                height: 420,
                child: ArenaTable(
                  theme: theme,
                  tilt: tilt,
                  child: const Center(child: Text('board')),
                ),
              ),
            ),
          ),
        );
        expect(find.text('board'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: '$theme $tilt');
      }
    }
  });
}

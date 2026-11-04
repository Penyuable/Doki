import 'package:dokimon/core/i18n/app_strings.dart';
import 'package:dokimon/core/ui/widgets.dart';
import 'package:dokimon/domain/models/card_model.dart';
import 'package:dokimon/domain/models/gacha_model.dart';
import 'package:dokimon/features/gacha/gacha_reveal_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/card_factory.dart';

Future<void> _pumpReveal(WidgetTester tester, int count) async {
  final results = <GachaPullResult>[
    for (var i = 0; i < count; i++)
      GachaPullResult(
        cardId: 'card_00$i',
        rarity: Rarity.rare,
        isNew: true,
        wasPity: false,
        guaranteedRare: false,
        card: testUnit('card_00$i', name: 'Kartu $i'),
      ),
  ];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        AppStringsDelegate(),
      ],
      home: Scaffold(
        body: GachaRevealDialog(
          results: results,
          reduceMotion: false,
          haptics: false,
        ),
      ),
    ),
  );
  // Biarkan timer reveal & animasi flip selesai.
  for (var i = 0; i < 12 * count + 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('kartu hasil gacha tidak tampil terbalik (bug cermin)', (
    tester,
  ) async {
    await _pumpReveal(tester, 1);
    final tile = find.byType(CardTile);
    expect(tile, findsOneWidget);
    expect(find.text('Kartu 0'), findsOneWidget);

    // Setiap Transform di atas kartu harus punya skala X positif.
    final transforms = tester
        .widgetList<Transform>(
          find.ancestor(of: tile, matching: find.byType(Transform)),
        )
        .toList();
    expect(transforms, isNotEmpty);
    for (final t in transforms) {
      expect(t.transform.entry(0, 0), greaterThan(0.99));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('10 kartu terbuka semua dan tombol akhir jelas', (
    tester,
  ) async {
    await _pumpReveal(tester, 10);
    expect(find.byType(CardTile), findsWidgets);
    // Setelah semua terbuka hanya ada "Pull lagi" & "Selesai".
    const strings = AppStrings('en');
    expect(find.text(strings.t('gacha.skip')), findsNothing);
    expect(find.text(strings.t('common.done')), findsOneWidget);
    expect(find.text(strings.t('gacha.pullAgain')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:dokimon/core/i18n/app_strings.dart';
import 'package:dokimon/domain/models/card_model.dart';
import 'package:dokimon/features/battle/battle_moves.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/card_factory.dart';

const CardAbility _heal = CardAbility(
  name: 'Tidal Mending',
  type: 'heal',
  cost: 1,
  target: 'any_unit',
  power: 20,
  text: 'Restore 20 HP to a unit.',
);

void main() {
  const strings = AppStrings('id');

  test('unit dengan ability: serangan dasar, ability, guard', () {
    final card = testUnit(
      'card_002',
      element: CardElement.water,
      attack: 20,
      ability: _heal,
    );
    final moves = movesFor(card, strings);
    expect(moves.map((m) => m.kind), <MoveKind>[
      MoveKind.strike,
      MoveKind.ability,
      MoveKind.guard,
    ]);
    expect(moves[0].name, 'Semburan Ombak');
    expect(moves[0].power, 20);
    expect(moves[0].cost, 0);
    expect(moves[1].name, 'Tidal Mending');
    expect(moves[1].cost, 1);
    expect(moves[1].power, 20);
  });

  test('ATK unit di board (attackOverride) dipakai untuk serangan dasar', () {
    final card = testUnit('card_001', attack: 22);
    final moves = movesFor(card, strings, attackOverride: 30);
    expect(moves.first.power, 30);
  });

  test('unit tanpa ability hanya punya serangan dasar & guard', () {
    final moves = movesFor(testUnit('card_003'), strings);
    expect(moves.map((m) => m.kind), <MoveKind>[
      MoveKind.strike,
      MoveKind.guard,
    ]);
  });

  test('spell hanya punya ability-nya', () {
    final moves = movesFor(testSpell('card_050', ability: _heal), strings);
    expect(moves.single.kind, MoveKind.ability);
  });

  test('setiap elemen punya nama serangan dasar id & en', () {
    for (final element in CardElement.values) {
      final card = testUnit('card_x', element: element);
      for (final code in AppStrings.supportedLocaleCodes) {
        final name = strikeNameOf(card, AppStrings(code));
        expect(name, isNot(startsWith('move.')), reason: '$code $element');
      }
    }
  });

  testWidgets('SkillOrb: tap terpanggil saat aktif, diam saat nonaktif', (
    tester,
  ) async {
    var taps = 0;
    final move = movesFor(testUnit('card_001'), strings).first;
    Future<void> pump({required bool enabled}) => tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppStringsDelegate(),
            ],
            home: Scaffold(
              body: Center(
                child: SkillOrb(
                  move: move,
                  enabled: enabled,
                  onTap: () => taps++,
                ),
              ),
            ),
          ),
        );

    await pump(enabled: true);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(move.icon));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('Cakar Bara'), findsOneWidget);

    await pump(enabled: false);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(move.icon), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(taps, 1);
  });
}

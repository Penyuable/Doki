import 'dart:math' as math;

import 'package:dokimon/domain/models/card_model.dart';
import 'package:dokimon/features/battle/domain/battle_engine.dart';
import 'package:dokimon/features/battle/domain/battle_models.dart';
import 'package:dokimon/features/battle/domain/bot_ai.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/card_factory.dart';

List<CardModel> variedDeck({required String prefix}) {
  const elements = CardElement.values;
  return <CardModel>[
    for (var i = 0; i < 20; i++)
      testUnit(
        '${prefix}_$i',
        element: elements[i % elements.length],
        cost: i % 4,
        attack: 2 + (i % 5),
        hp: 4 + (i % 4),
        keywords: i % 3 == 0 ? <String>{'charge'} : const <String>{},
        ability: i.isEven
            ? testAbility(
                type: 'attack',
                cost: 1,
                target: 'enemy_unit',
                power: 2 + (i % 3),
              )
            : null,
      ),
  ];
}

void main() {
  const engine = BattleEngine();
  const config = BattleConfig(
    playerHp: 40,
    maxTurns: 20,
    startingHand: 4,
  );

  group('BotAI legalitas', () {
    for (final difficulty in BotDifficulty.values) {
      test('$difficulty selalu memilih aksi legal dan menyelesaikan match', () {
        var state = engine.start(
          playerDeck: variedDeck(prefix: 'player'),
          botDeck: variedDeck(prefix: 'bot'),
          seed: 2026,
          config: config,
        );
        var steps = 0;

        while (!state.isTerminal && steps < 1200) {
          final side = state.activeSide;
          final legal = engine.legalActions(state, side);
          expect(legal, isNotEmpty);

          final bot = BotAI.forDifficulty(
            difficulty,
            engine: engine,
            seed: steps * 31 + 7,
          );
          final action = bot.decide(state, side);

          expect(
            legal.map((candidate) => candidate.signature),
            contains(action.signature),
            reason: 'Langkah $steps menghasilkan aksi ilegal',
          );
          expect(action, isNot(isA<ConcedeAction>()));

          state = engine.apply(state, action);
          steps += 1;
        }

        expect(steps, lessThan(1200));
        expect(state.isTerminal, isTrue);
        expect(state.outcome, isNotNull);
      }, timeout: const Timeout(Duration(minutes: 2)));
    }
  });

  group('BotAI determinisme & performa', () {
    test('seed sama menghasilkan keputusan yang sama', () {
      final state = engine.start(
        playerDeck: variedDeck(prefix: 'player'),
        botDeck: variedDeck(prefix: 'bot'),
        seed: 99,
        config: config,
      );
      final side = state.activeSide;
      final first = BotAI.forDifficulty(
        BotDifficulty.medium,
        seed: 42,
      ).decide(state, side);
      final second = BotAI.forDifficulty(
        BotDifficulty.medium,
        seed: 42,
      ).decide(state, side);
      expect(first.signature, second.signature);
    });

    test('Master p95 < 300 ms pada 40 keputusan', () {
      var state = engine.start(
        playerDeck: variedDeck(prefix: 'player'),
        botDeck: variedDeck(prefix: 'bot'),
        seed: 7,
        config: config,
      );
      final durations = <int>[];
      final rng = math.Random(11);

      for (var i = 0; i < 40; i++) {
        if (state.isTerminal) break;
        final side = state.activeSide;
        final legal = engine.legalActions(state, side);
        if (legal.isEmpty) break;

        final watch = Stopwatch()..start();
        final action = BotAI.forDifficulty(
          BotDifficulty.master,
          seed: 100 + i,
        ).decide(state, side);
        watch.stop();
        durations.add(watch.elapsedMilliseconds);

        if (!legal.any((item) => item.signature == action.signature)) {
          fail('Aksi Master ilegal pada iterasi $i');
        }
        state = engine.apply(state, action);
        if (rng.nextBool()) {
          // Sesekali majukan giliran agar state tidak monoton.
          if (!state.isTerminal) {
            final nextLegal = engine.legalActions(state, state.activeSide);
            if (nextLegal.isNotEmpty) {
              state = engine.apply(state, const EndTurnAction());
            }
          }
        }
      }

      expect(durations, isNotEmpty);
      durations.sort();
      final index = math.min(
        durations.length - 1,
        (durations.length * 0.95).floor(),
      );
      final p95 = durations[index];
      expect(
        p95,
        lessThan(300),
        reason: 'p95=${p95}ms dari ${durations.length} keputusan',
      );
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

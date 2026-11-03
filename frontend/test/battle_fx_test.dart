import 'package:dokimon/domain/models/card_model.dart';
import 'package:dokimon/features/battle/battle_fx.dart';
import 'package:dokimon/features/battle/domain/battle_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/card_factory.dart';

BattleEvent _event(
  String type, {
  BattleSide side = BattleSide.player,
  Map<String, dynamic> data = const <String, dynamic>{},
}) {
  return BattleEvent(
      type: type, turn: 1, message: type, side: side, data: data);
}

void main() {
  group('fxCuesFor (I-05: angka efek berasal dari event)', () {
    test('attack + unit_died → strike lalu faint dengan damage dari event', () {
      final cues = fxCuesFor(<BattleEvent>[
        _event(
          'attack',
          data: <String, dynamic>{
            'attackerId': 'p1',
            'targetId': 'b1',
            'damage': 37,
          },
        ),
        _event(
          'unit_died',
          side: BattleSide.bot,
          data: <String, dynamic>{'unitId': 'b1'},
        ),
      ]);

      expect(cues.map((c) => c.kind), <FxCueKind>[
        FxCueKind.strike,
        FxCueKind.faint,
      ]);
      expect(cues[0].sourceUnitId, 'p1');
      expect(cues[0].targetUnitId, 'b1');
      expect(cues[0].amount, 37);
      expect(cues[1].targetUnitId, 'b1');
    });

    test('face_attack menargetkan wajah lawan', () {
      final cues = fxCuesFor(<BattleEvent>[
        _event(
          'face_attack',
          side: BattleSide.bot,
          data: <String, dynamic>{'unitId': 'b2', 'damage': 12},
        ),
      ]);
      expect(cues.single.kind, FxCueKind.strike);
      expect(cues.single.targetFace, BattleSide.player);
      expect(cues.single.amount, 12);
    });

    test('counter memukul balik attacker dari event attack sebelumnya', () {
      final cues = fxCuesFor(<BattleEvent>[
        _event(
          'attack',
          data: <String, dynamic>{
            'attackerId': 'p1',
            'targetId': 'b1',
            'damage': 5,
          },
        ),
        _event(
          'counter',
          side: BattleSide.bot,
          data: <String, dynamic>{'unitId': 'b1', 'damage': 9},
        ),
      ]);
      expect(cues[1].sourceUnitId, 'b1');
      expect(cues[1].targetUnitId, 'p1');
      expect(cues[1].amount, 9);
    });

    test('ability_damage memakai unit caster dari event ability', () {
      final cues = fxCuesFor(<BattleEvent>[
        _event(
          'ability_damage',
          data: <String, dynamic>{'targetId': 'b1', 'damage': 20},
        ),
        _event(
          'ability_damage',
          data: <String, dynamic>{'targetId': 'b2', 'damage': 18},
        ),
        _event('ability', data: <String, dynamic>{'unitId': 'p3'}),
      ]);
      expect(cues, hasLength(2));
      expect(cues.every((c) => c.kind == FxCueKind.bolt), isTrue);
      expect(cues.every((c) => c.sourceUnitId == 'p3'), isTrue);
      expect(cues.map((c) => c.amount), <int>[20, 18]);
    });

    test('spell ke player berasal dari wajah pemilik spell', () {
      final cues = fxCuesFor(<BattleEvent>[
        _event('ability_damage', data: <String, dynamic>{'damage': 30}),
        _event('spell', data: <String, dynamic>{'cardId': 'card_050'}),
      ]);
      final cue = cues.single;
      expect(cue.sourceUnitId, isNull);
      expect(cue.sourceFace, BattleSide.player);
      expect(cue.sourceCardId, 'card_050');
      expect(cue.targetFace, BattleSide.bot);
    });

    test('heal, burn, summon, dan event non-visual', () {
      final cues = fxCuesFor(<BattleEvent>[
        _event('draw'),
        _event(
          'heal',
          data: <String, dynamic>{'targetId': 'p1', 'amount': 15},
        ),
        _event('burn', data: <String, dynamic>{'unitId': 'p2', 'damage': 4}),
        _event(
          'summon',
          data: <String, dynamic>{'cardId': 'card_001', 'instanceId': 'p9'},
        ),
        _event('end_turn'),
      ]);
      expect(cues.map((c) => c.kind), <FxCueKind>[
        FxCueKind.heal,
        FxCueKind.hit,
        FxCueKind.summon,
      ]);
      expect(cues[0].amount, 15);
      expect(cues[1].amount, 4);
      expect(cues[2].targetUnitId, 'p9');
    });

    test('data rusak tidak membuat crash', () {
      final cues = fxCuesFor(<BattleEvent>[
        _event('attack', data: <String, dynamic>{'damage': 'x'}),
      ]);
      expect(cues.single.amount, 0);
      expect(cues.single.sourceUnitId, isNull);
    });
  });

  testWidgets('BattleFxHost memainkan strike/faint tanpa error lalu diam', (
    tester,
  ) async {
    final hostKey = GlobalKey<BattleFxHostState>();
    await tester.pumpWidget(
      MaterialApp(
        home: BattleFxHost(
          key: hostKey,
          child: const Column(
            children: <Widget>[
              FxAnchor(id: 'face:bot', child: SizedBox(height: 40)),
              FxAnchor(id: 'b1', child: SizedBox(width: 80, height: 120)),
              FxAnchor(id: 'p1', child: SizedBox(width: 80, height: 120)),
            ],
          ),
        ),
      ),
    );

    final attacker = testUnit('card_001', element: CardElement.fire);
    hostKey.currentState!.play(
      <BattleEvent>[
        _event(
          'attack',
          data: <String, dynamic>{
            'attackerId': 'p1',
            'targetId': 'b1',
            'damage': 30,
          },
        ),
        _event(
          'unit_died',
          side: BattleSide.bot,
          data: <String, dynamic>{'unitId': 'b1'},
        ),
        _event('ability_damage', data: <String, dynamic>{'damage': 10}),
      ],
      cardsByUnit: <String, CardModel>{'p1': attacker, 'b1': attacker},
      cardsById: <String, CardModel>{},
    );

    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.takeException(), isNull);
    }
    // Semua efek selesai → ticker berhenti → tidak ada frame terjadwal.
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });
}

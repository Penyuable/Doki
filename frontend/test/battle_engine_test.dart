import 'package:dokimon/features/battle/domain/battle_engine.dart';
import 'package:dokimon/features/battle/domain/battle_models.dart';
import 'package:dokimon/domain/models/card_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/card_factory.dart';

BattleUnit boardUnit(
  CardModel card,
  String id, {
  bool summonedThisTurn = false,
  Stance stance = Stance.ready,
  bool hasActed = false,
  int? hp,
}) {
  final unit = BattleUnit.fromCard(card, id);
  unit.summonedThisTurn = summonedThisTurn;
  unit.stance = stance;
  unit.hasActed = hasActed;
  if (hp != null) unit.hp = hp;
  return unit;
}

BattleState makeState({
  List<BattleUnit> playerBoard = const <BattleUnit>[],
  List<BattleUnit> botBoard = const <BattleUnit>[],
  List<CardModel> playerHand = const <CardModel>[],
  List<CardModel> botHand = const <CardModel>[],
  List<CardModel> playerDeck = const <CardModel>[],
  List<CardModel> botDeck = const <CardModel>[],
  int playerEnergy = 10,
  int botEnergy = 10,
  int playerHp = 200,
  int botHp = 200,
  BattleSide activeSide = BattleSide.player,
  BattleSide firstSide = BattleSide.player,
  int turnNumber = 1,
  BattleConfig config = const BattleConfig(),
}) {
  return BattleState(
    config: config,
    seed: 7,
    firstSide: firstSide,
    activeSide: activeSide,
    turnNumber: turnNumber,
    phase: BattlePhase.action,
    player: BattlePlayerState(
      label: 'player',
      hp: playerHp,
      maxHp: 200,
      maxEnergy: 10,
      energy: playerEnergy,
      board: List<BattleUnit>.from(playerBoard),
      hand: List<CardModel>.from(playerHand),
      deck: List<CardModel>.from(playerDeck),
      discard: <CardModel>[],
    ),
    bot: BattlePlayerState(
      label: 'bot',
      hp: botHp,
      maxHp: 200,
      maxEnergy: 10,
      energy: botEnergy,
      board: List<BattleUnit>.from(botBoard),
      hand: List<CardModel>.from(botHand),
      deck: List<CardModel>.from(botDeck),
      discard: <CardModel>[],
    ),
    log: <BattleEvent>[],
    nextInstanceId: 100,
  );
}

void main() {
  const engine = BattleEngine();

  group('BattleEngine.start', () {
    test('deterministik untuk seed yang sama (I-04)', () {
      final first = engine.start(
        playerDeck: testDeck(),
        botDeck: testDeck(element: CardElement.water),
        seed: 4242,
      );
      final second = engine.start(
        playerDeck: testDeck(),
        botDeck: testDeck(element: CardElement.water),
        seed: 4242,
      );

      expect(first.logHash, second.logHash);
      expect(
        first.player.hand.map((card) => card.id),
        second.player.hand.map((card) => card.id),
      );
      expect(first.activeSide, second.activeSide);
      expect(first.player.deck.map((c) => c.id), second.player.deck.map((c) => c.id));
    });

    test('menolak deck kosong', () {
      expect(
        () => engine.start(
          playerDeck: const <CardModel>[],
          botDeck: testDeck(),
          seed: 1,
        ),
        throwsA(isA<IllegalActionException>()),
      );
    });

    test('logHash berubah setelah aksi', () {
      final state = makeState(
        playerBoard: <BattleUnit>[
          boardUnit(testUnit('atk', attack: 3), 'u1'),
        ],
        botBoard: <BattleUnit>[
          boardUnit(testUnit('def', hp: 20), 'u2'),
        ],
      );
      final next = engine.apply(
        state,
        const AttackAction(attackerId: 'u1', targetId: 'u2'),
      );
      expect(next.logHash, isNot(state.logHash));
    });
  });

  group('Element & damage', () {
    test('siklus elemen: api > udara, air > api', () {
      expect(
        engine.elementMultiplier(CardElement.fire, CardElement.air),
        1.25,
      );
      expect(
        engine.elementMultiplier(CardElement.air, CardElement.fire),
        0.8,
      );
      expect(
        engine.elementMultiplier(CardElement.voidElement, CardElement.fire),
        1.0,
      );
      expect(
        engine.elementMultiplier(CardElement.fire, CardElement.voidElement),
        1.0,
      );
    });

    test('guard memotong damage 50%', () {
      final attacker = boardUnit(
        testUnit('atk', attack: 10, element: CardElement.fire),
        'u1',
      );
      final normal = boardUnit(
        testUnit('def', hp: 50, defense: 2, element: CardElement.air),
        'u2',
      );
      final guarded = boardUnit(
        testUnit('def2', hp: 50, defense: 2, element: CardElement.air),
        'u3',
        stance: Stance.guarding,
      );
      final state = makeState();

      final normalDamage = engine.estimateAttackDamage(
        state,
        attacker,
        normal,
      );
      final guardedDamage = engine.estimateAttackDamage(
        state,
        attacker,
        guarded,
      );

      expect(normalDamage, 12);
      expect(guardedDamage, 6);
    });

    test('counter guard memakai 30% ATK dan elemen', () {
      final defender = boardUnit(
        testUnit('def', attack: 10, element: CardElement.fire),
        'u2',
      );
      final attacker = boardUnit(
        testUnit('atk', attack: 10, element: CardElement.water),
        'u1',
      );
      final state = makeState();
      expect(engine.estimateCounterDamage(state, defender, attacker), 2);
    });
  });

  group('Aksi unit', () {
    test('serangan unit mengurangi HP target dan menandai hasActed', () {
      final attacker = boardUnit(
        testUnit('atk', attack: 10, element: CardElement.fire),
        'u1',
      );
      final defender = boardUnit(
        testUnit('def', hp: 100, element: CardElement.air),
        'u2',
      );
      final state = makeState(
        playerBoard: <BattleUnit>[attacker],
        botBoard: <BattleUnit>[defender],
      );

      final next = engine.apply(
        state,
        const AttackAction(attackerId: 'u1', targetId: 'u2'),
      );

      expect(next.bot.board.single.hp, 87);
      expect(next.player.board.single.hasActed, isTrue);
      expect(next.activeSide, BattleSide.player);
    });

    test('guard menahan damage dan memantulkan counter', () {
      final attacker = boardUnit(
        testUnit('atk', attack: 10, element: CardElement.fire, hp: 12),
        'u1',
      );
      final defender = boardUnit(
        testUnit(
          'def',
          attack: 10,
          hp: 50,
          defense: 2,
          element: CardElement.air,
        ),
        'u2',
        stance: Stance.guarding,
      );
      final state = makeState(
        playerBoard: <BattleUnit>[attacker],
        botBoard: <BattleUnit>[defender],
      );

      final next = engine.apply(
        state,
        const AttackAction(attackerId: 'u1', targetId: 'u2'),
      );

      expect(next.bot.board.single.hp, 44);
      expect(next.player.board.single.hp, 10);
    });

    test('pierce meneruskan overflow damage ke player', () {
      final attacker = boardUnit(
        testUnit('atk', attack: 10, element: CardElement.fire, keywords: <String>{'pierce'}),
        'u1',
      );
      final defender = boardUnit(
        testUnit('def', hp: 2, element: CardElement.air),
        'u2',
      );
      final state = makeState(
        playerBoard: <BattleUnit>[attacker],
        botBoard: <BattleUnit>[defender],
      );

      final next = engine.apply(
        state,
        const AttackAction(attackerId: 'u1', targetId: 'u2'),
      );

      expect(next.bot.board, isEmpty);
      expect(next.bot.hp, 189);
      expect(
        next.log.map((event) => event.type),
        contains('pierce'),
      );
    });

    test('lifesteal memulihkan HP penyerang', () {
      final attacker = boardUnit(
        testUnit('atk', attack: 5, hp: 5, element: CardElement.fire, keywords: <String>{'lifesteal'}),
        'u1',
        hp: 3,
      );
      final defender = boardUnit(
        testUnit('def', hp: 20, element: CardElement.water),
        'u2',
      );
      final state = makeState(
        playerBoard: <BattleUnit>[attacker],
        botBoard: <BattleUnit>[defender],
      );

      final next = engine.apply(
        state,
        const AttackAction(attackerId: 'u1', targetId: 'u2'),
      );

      expect(next.player.board.single.hp, 5);
      expect(next.bot.board.single.hp, 16);
    });

    test('shield menyerap damage lebih dulu', () {
      final defender = boardUnit(
        testUnit('def', hp: 10, element: CardElement.fire),
        'p1',
      );
      defender.applyStatus(BattleStatusKind.shield, 5, 2);
      final attacker = boardUnit(
        testUnit('atk', attack: 5, element: CardElement.water),
        'b1',
      );
      final state = makeState(
        playerBoard: <BattleUnit>[defender],
        botBoard: <BattleUnit>[attacker],
        activeSide: BattleSide.bot,
        firstSide: BattleSide.bot,
      );

      final next = engine.apply(
        state,
        const AttackAction(attackerId: 'b1', targetId: 'p1'),
      );

      expect(next.player.board.single.hp, 9);
      expect(
        next.player.board.single.statusOf(BattleStatusKind.shield),
        isNull,
      );
    });

    test('unit baru tanpa charge tidak bisa menyerang', () {
      final charging = testUnit(
        'charge',
        cost: 1,
        attack: 3,
        keywords: <String>{'charge'},
      );
      final normal = testUnit('normal', cost: 1, attack: 3);
      final state = makeState(
        playerHand: <CardModel>[charging, normal],
        playerDeck: testDeck(count: 5),
      );

      final afterCharge = engine.apply(
        state,
        const PlayCardAction(handIndex: 0),
      );
      final chargeUnit = afterCharge.player.board.single;
      expect(chargeUnit.card.hasCharge, isTrue);
      expect(
        engine
            .legalActions(afterCharge, BattleSide.player)
            .whereType<AttackAction>()
            .any((action) => action.attackerId == chargeUnit.instanceId),
        isTrue,
      );

      final afterNormal = engine.apply(
        state,
        const PlayCardAction(handIndex: 1),
      );
      final normalUnit = afterNormal.player.board.single;
      expect(
        engine
            .legalActions(afterNormal, BattleSide.player)
            .whereType<AttackAction>()
            .any((action) => action.attackerId == normalUnit.instanceId),
        isFalse,
      );
    });

    test('freeze memblokir aksi unit', () {
      final frozen = boardUnit(
        testUnit('frozen', attack: 5),
        'u1',
      );
      frozen.applyStatus(BattleStatusKind.freeze, 1, 2);
      final state = makeState(playerBoard: <BattleUnit>[frozen]);

      final actions = engine.legalActions(state, BattleSide.player);
      expect(actions.whereType<AttackAction>(), isEmpty);
      expect(actions.whereType<UseAbilityAction>(), isEmpty);
      expect(
        () => engine.apply(
          state,
          const AttackAction(attackerId: 'u1'),
        ),
        throwsA(isA<IllegalActionException>()),
      );
    });

    test('board penuh menolak summon', () {
      final cards = <CardModel>[
        testUnit('a'),
        testUnit('b'),
        testUnit('c'),
      ];
      final state = makeState(
        playerBoard: <BattleUnit>[
          boardUnit(cards[0], 'u1'),
          boardUnit(cards[1], 'u2'),
          boardUnit(cards[2], 'u3'),
        ],
        playerHand: <CardModel>[testUnit('extra')],
      );

      expect(
        () => engine.apply(state, const PlayCardAction(handIndex: 0)),
        throwsA(isA<IllegalActionException>()),
      );
    });

    test('energi tidak cukup ditolak', () {
      final state = makeState(
        playerHand: <CardModel>[testUnit('expensive', cost: 5)],
        playerEnergy: 1,
      );

      expect(
        () => engine.apply(state, const PlayCardAction(handIndex: 0)),
        throwsA(isA<IllegalActionException>()),
      );
    });
  });

  group('Status & giliran', () {
    test('burn mengurangi HP saat begin turn', () {
      final burning = boardUnit(testUnit('burn', hp: 10), 'u1');
      burning.applyStatus(BattleStatusKind.burn, 3, 2);
      final state = makeState(
        playerBoard: <BattleUnit>[burning],
        playerDeck: testDeck(count: 6),
        activeSide: BattleSide.bot,
        firstSide: BattleSide.bot,
      );

      final next = engine.apply(state, const EndTurnAction());

      expect(next.player.board.single.hp, 7);
      final burn = next.player.board.single.statusOf(BattleStatusKind.burn);
      expect(burn?.turns, 1);
      expect(next.log.map((event) => event.type), contains('burn'));
    });

    test('deck habis memicu fatigue', () {
      final state = makeState(
        playerDeck: const <CardModel>[],
        activeSide: BattleSide.bot,
        firstSide: BattleSide.player,
        turnNumber: 2,
      );

      final next = engine.apply(state, const EndTurnAction());

      expect(next.player.hp, 180);
      expect(next.player.fatigueCounter, 1);
      expect(next.log.map((event) => event.type), contains('fatigue'));
    });

    test('tangan penuh membakar kartu yang ditarik', () {
      final hand = <CardModel>[
        for (var i = 0; i < 8; i++) testUnit('hand_$i'),
      ];
      final state = makeState(
        playerHand: hand,
        playerDeck: testDeck(count: 5),
        activeSide: BattleSide.bot,
        firstSide: BattleSide.bot,
      );

      final next = engine.apply(state, const EndTurnAction());

      expect(next.player.hand.length, 8);
      expect(next.player.discard.length, 1);
      expect(next.log.map((event) => event.type), contains('hand_burn'));
    });

    test('melewati maxTurns menghasilkan draw', () {
      const config = BattleConfig(maxTurns: 2);
      final state = makeState(
        config: config,
        playerDeck: testDeck(count: 5),
        activeSide: BattleSide.bot,
        firstSide: BattleSide.player,
        turnNumber: 2,
      );

      final next = engine.apply(state, const EndTurnAction());

      expect(next.outcome, BattleOutcome.draw);
      expect(next.phase, BattlePhase.ended);
    });
  });

  group('Hasil pertandingan', () {
    test('serangan langsung mematikan bot menghasilkan win', () {
      final attacker = boardUnit(
        testUnit('atk', attack: 20),
        'u1',
      );
      final state = makeState(
        playerBoard: <BattleUnit>[attacker],
        botHp: 5,
      );

      final next = engine.apply(
        state,
        const AttackAction(attackerId: 'u1'),
      );

      expect(next.outcome, BattleOutcome.win);
      expect(next.bot.hp, lessThanOrEqualTo(0));
    });

    test('concede menghasilkan loss', () {
      final state = makeState(playerDeck: testDeck(count: 5));
      final next = engine.apply(state, const ConcedeAction());
      expect(next.outcome, BattleOutcome.loss);
      expect(next.phase, BattlePhase.ended);
    });

    test('aksi setelah selesai ditolak', () {
      final state = makeState(playerDeck: testDeck(count: 5));
      final ended = engine.apply(state, const ConcedeAction());
      expect(
        () => engine.apply(ended, const EndTurnAction()),
        throwsA(isA<IllegalActionException>()),
      );
    });
  });
}

import 'dart:math' as math;

import '../../../domain/models/card_model.dart';
import 'battle_models.dart';

/// Engine deterministik, pure Dart (tanpa Flutter/I/O/waktu).
/// Semua perubahan state lewat [apply]; UI dan BotAI memakai pintu yang sama.
class BattleEngine {
  const BattleEngine();

  static const Map<CardElement, CardElement> _beats = <CardElement, CardElement>{
    CardElement.fire: CardElement.air,
    CardElement.air: CardElement.earth,
    CardElement.earth: CardElement.water,
    CardElement.water: CardElement.fire,
  };

  double elementMultiplier(CardElement attacker, CardElement defender) {
    if (attacker == CardElement.voidElement || defender == CardElement.voidElement) {
      return 1.0;
    }
    if (_beats[attacker] == defender) return 1.25;
    if (_beats[defender] == attacker) return 0.8;
    return 1.0;
  }

  int estimateAttackDamage(
    BattleState state,
    BattleUnit attacker,
    BattleUnit defender,
  ) {
    final raw =
        attacker.attack *
        elementMultiplier(attacker.card.element, defender.card.element) *
        (1 + attacker.rallyValue / 100);
    var damage = math.max(
      1,
      (raw - defender.defense * state.config.defenseMitigation).round(),
    );
    if (defender.stance == Stance.guarding) {
      damage = math.max(
        1,
        (damage * state.config.guardDamageMultiplier).round(),
      );
    }
    return damage;
  }

  int estimateFaceDamage(BattleState state, BattleUnit attacker) {
    final raw =
        attacker.attack * 0.5 * (1 + attacker.rallyValue / 100);
    return math.max(1, raw.round());
  }

  int estimateCounterDamage(
    BattleState state,
    BattleUnit defender,
    BattleUnit attacker,
  ) {
    final raw =
        defender.attack *
        state.config.guardCounterRatio *
        elementMultiplier(defender.card.element, attacker.card.element);
    return math.max(1, raw.round());
  }

  int estimateAbilityDamage(
    BattleState state,
    CardElement source,
    int power,
    BattleUnit target,
  ) {
    final raw =
        power * elementMultiplier(source, target.card.element);
    return math.max(1, (raw - target.defense * 0.3).round());
  }

  BattleState start({
    required List<CardModel> playerDeck,
    required List<CardModel> botDeck,
    required int seed,
    BattleConfig config = const BattleConfig(),
  }) {
    if (playerDeck.isEmpty || botDeck.isEmpty) {
      throw const IllegalActionException('Deck tidak boleh kosong');
    }

    final rng = math.Random(seed);
    final shuffledPlayer = List<CardModel>.from(playerDeck)..shuffle(rng);
    final shuffledBot = List<CardModel>.from(botDeck)..shuffle(rng);
    final firstSide = rng.nextBool() ? BattleSide.player : BattleSide.bot;

    final player = BattlePlayerState(
      label: 'player',
      hp: config.playerHp,
      maxHp: config.playerHp,
      maxEnergy: 0,
      energy: 0,
      board: <BattleUnit>[],
      hand: <CardModel>[],
      deck: shuffledPlayer,
      discard: <CardModel>[],
    );
    final bot = BattlePlayerState(
      label: 'bot',
      hp: config.playerHp,
      maxHp: config.playerHp,
      maxEnergy: 0,
      energy: 0,
      board: <BattleUnit>[],
      hand: <CardModel>[],
      deck: shuffledBot,
      discard: <CardModel>[],
    );

    final state = BattleState(
      config: config,
      seed: seed,
      firstSide: firstSide,
      activeSide: firstSide,
      turnNumber: 0,
      phase: BattlePhase.upkeep,
      player: player,
      bot: bot,
      log: <BattleEvent>[],
      nextInstanceId: 1,
    );

    _drawInitial(state, BattleSide.player, config.startingHand);
    _drawInitial(state, BattleSide.bot, config.startingHand);
    _beginTurn(state, firstSide);
    return state;
  }

  void _drawInitial(BattleState state, BattleSide side, int count) {
    final player = state.sideState(side);
    for (var i = 0; i < count; i++) {
      if (player.deck.isEmpty) return;
      player.hand.add(player.deck.removeAt(0));
    }
    _log(
      state,
      'opening_hand',
      '${player.label} menarik $count kartu awal',
      side,
      <String, dynamic>{'count': count},
    );
  }

  List<BattleAction> legalActions(BattleState state, BattleSide side) {
    if (state.phase != BattlePhase.action ||
        state.outcome != null ||
        state.activeSide != side) {
      return const <BattleAction>[];
    }

    final me = state.sideState(side);
    final enemy = state.opponentState(side);
    final actions = <BattleAction>[];

    for (var index = 0; index < me.hand.length; index++) {
      final card = me.hand[index];
      if (card.cost > me.energy) continue;

      if (card.isUnit) {
        if (me.board.length >= state.config.boardSlots) continue;
        actions.add(PlayCardAction(handIndex: index));
        continue;
      }

      final ability = card.ability;
      if (ability == null) continue;

      if (_requiresUnitTarget(ability)) {
        final targets = _targetIds(state, side, ability);
        if (targets.isEmpty) continue;
        for (final target in targets) {
          actions.add(
            PlayCardAction(handIndex: index, targetId: target),
          );
        }
      } else {
        actions.add(PlayCardAction(handIndex: index));
      }
    }

    for (final unit in me.board) {
      if (unit.hasActed || unit.isFrozen) continue;

      final ability = unit.card.ability;
      if (ability != null && ability.cost <= me.energy) {
        if (_requiresUnitTarget(ability)) {
          final targets = _targetIds(state, side, ability, caster: unit);
          for (final target in targets) {
            actions.add(
              UseAbilityAction(unitId: unit.instanceId, targetId: target),
            );
          }
        } else {
          actions.add(UseAbilityAction(unitId: unit.instanceId));
        }
      }

      if (_canAttack(unit)) {
        if (enemy.board.isEmpty) {
          actions.add(AttackAction(attackerId: unit.instanceId));
        } else {
          for (final target in enemy.board) {
            actions.add(
              AttackAction(
                attackerId: unit.instanceId,
                targetId: target.instanceId,
              ),
            );
          }
        }
      }

      actions.add(SetGuardAction(unitId: unit.instanceId));
    }

    actions.add(const EndTurnAction());
    return actions;
  }

  bool _canAttack(BattleUnit unit) {
    if (unit.hasActed || unit.isFrozen) return false;
    if (unit.summonedThisTurn && !unit.card.hasCharge) return false;
    return true;
  }

  bool _requiresUnitTarget(CardAbility ability) {
    return ability.target == 'enemy_unit' ||
        ability.target == 'any_unit' ||
        ability.target == 'self';
  }

  List<String?> _targetIds(
    BattleState state,
    BattleSide side,
    CardAbility ability, {
    BattleUnit? caster,
  }) {
    final me = state.sideState(side);
    final enemy = state.opponentState(side);
    switch (ability.target) {
      case 'enemy_unit':
        return enemy.board
            .map<String?>((unit) => unit.instanceId)
            .toList(growable: false);
      case 'any_unit':
        return <String?>[
          ...me.board.map<String?>((unit) => unit.instanceId),
          ...enemy.board.map<String?>((unit) => unit.instanceId),
        ];
      case 'self':
        if (caster != null) return const <String?>[null];
        return me.board
            .map<String?>((unit) => unit.instanceId)
            .toList(growable: false);
      default:
        return const <String?>[null];
    }
  }

  BattleState apply(BattleState state, BattleAction action) {
    if (state.phase == BattlePhase.ended || state.outcome != null) {
      throw const IllegalActionException('Pertandingan sudah selesai');
    }

    final next = state.copy();

    if (action is ConcedeAction) {
      _concede(next);
      return next;
    }

    if (action is EndTurnAction) {
      _endTurn(next);
      return next;
    }

    if (next.phase != BattlePhase.action) {
      throw const IllegalActionException('Belum fase aksi');
    }

    if (action is PlayCardAction) {
      _playCard(next, action);
    } else if (action is UseAbilityAction) {
      _useAbility(next, action);
    } else if (action is AttackAction) {
      _attack(next, action);
    } else if (action is SetGuardAction) {
      _setGuard(next, action);
    } else {
      throw const IllegalActionException('Aksi tidak dikenal');
    }

    return next;
  }

  void _playCard(BattleState state, PlayCardAction action) {
    final side = state.activeSide;
    final me = state.sideState(side);
    if (action.handIndex < 0 || action.handIndex >= me.hand.length) {
      throw const IllegalActionException('Kartu di tangan tidak ditemukan');
    }

    final card = me.hand[action.handIndex];
    if (card.cost > me.energy) {
      throw const IllegalActionException('Energi tidak cukup');
    }

    if (card.isUnit) {
      if (me.board.length >= state.config.boardSlots) {
        throw const IllegalActionException('Slot board penuh');
      }
      if (action.slot != null && action.slot != me.board.length) {
        throw const IllegalActionException('Slot tidak tersedia');
      }

      final unit = BattleUnit.fromCard(
        card,
        'u${state.nextInstanceId++}',
      );
      me.board.add(unit);
      me.energy -= card.cost;
      me.hand.removeAt(action.handIndex);
      _log(
        state,
        'summon',
        '${me.label} memainkan ${card.name}',
        side,
        <String, dynamic>{'cardId': card.id, 'instanceId': unit.instanceId},
      );
      return;
    }

    final ability = card.ability;
    if (ability == null) {
      throw const IllegalActionException('Spell tanpa ability');
    }

    _resolveAbility(
      state,
      side,
      caster: null,
      source: card,
      ability: ability,
      targetId: action.targetId,
    );

    me.energy -= card.cost;
    me.hand.removeAt(action.handIndex);
    me.discard.add(card);
    _log(
      state,
      'spell',
      '${me.label} memainkan spell ${card.name}',
      side,
      <String, dynamic>{'cardId': card.id},
    );

    _removeDeadUnits(state, side.opponent);
    _removeDeadUnits(state, side);
    _evaluateOutcome(state);
  }

  void _useAbility(BattleState state, UseAbilityAction action) {
    final side = state.activeSide;
    final me = state.sideState(side);
    final unit = _findUnit(me.board, action.unitId);
    if (unit == null) {
      throw const IllegalActionException('Unit tidak ada di board');
    }
    if (unit.hasActed) {
      throw const IllegalActionException('Unit sudah melakukan aksi');
    }
    if (unit.isFrozen) {
      throw const IllegalActionException('Unit sedang freeze');
    }

    final ability = unit.card.ability;
    if (ability == null) {
      throw const IllegalActionException('Unit tidak punya ability');
    }
    if (ability.cost > me.energy) {
      throw const IllegalActionException('Energi tidak cukup');
    }

    _resolveAbility(
      state,
      side,
      caster: unit,
      source: unit.card,
      ability: ability,
      targetId: action.targetId,
    );

    me.energy -= ability.cost;
    unit.hasActed = true;
    unit.stance = Stance.tapped;

    _log(
      state,
      'ability',
      '${unit.card.name} memakai ${ability.name}',
      side,
      <String, dynamic>{'unitId': unit.instanceId},
    );

    _removeDeadUnits(state, side.opponent);
    _removeDeadUnits(state, side);
    _evaluateOutcome(state);
  }

  void _attack(BattleState state, AttackAction action) {
    final side = state.activeSide;
    final me = state.sideState(side);
    final enemy = state.opponentState(side);

    final attacker = _findUnit(me.board, action.attackerId);
    if (attacker == null) {
      throw const IllegalActionException('Penyerang tidak ditemukan');
    }
    if (attacker.hasActed) {
      throw const IllegalActionException('Unit sudah melakukan aksi');
    }
    if (attacker.isFrozen) {
      throw const IllegalActionException('Unit sedang freeze');
    }
    if (attacker.summonedThisTurn && !attacker.card.hasCharge) {
      throw const IllegalActionException('Unit baru tidak bisa menyerang');
    }

    if (action.targetId == null) {
      if (enemy.board.isNotEmpty) {
        throw const IllegalActionException(
          'Tidak bisa menyerang player saat masih ada unit',
        );
      }
      final damage = estimateFaceDamage(state, attacker);
      enemy.hp -= damage;
      attacker.hasActed = true;
      attacker.stance = Stance.tapped;
      _log(
        state,
        'face_attack',
        '${attacker.card.name} menyerang langsung $damage damage',
        side,
        <String, dynamic>{'unitId': attacker.instanceId, 'damage': damage},
      );
      _evaluateOutcome(state);
      return;
    }

    final target = _findUnit(enemy.board, action.targetId!);
    if (target == null) {
      throw const IllegalActionException('Target tidak ditemukan');
    }

    final hpBefore = target.hp;
    final rawDamage = estimateAttackDamage(state, attacker, target);
    final dealt = _damageUnit(target, rawDamage);

    _log(
      state,
      'attack',
      '${attacker.card.name} menyerang ${target.card.name} ($dealt)',
      side,
      <String, dynamic>{
        'attackerId': attacker.instanceId,
        'targetId': target.instanceId,
        'damage': dealt,
      },
    );

    if (attacker.card.hasLifesteal && dealt > 0) {
      final healed = math.min(dealt, attacker.maxHp - attacker.hp);
      if (healed > 0) attacker.hp += healed;
    }

    if (target.isDead) {
      final overflow = math.max(0, dealt - hpBefore);
      enemy.board.remove(target);
      enemy.discard.add(target.card);
      _log(
        state,
        'unit_died',
        '${target.card.name} gugur',
        side.opponent,
        <String, dynamic>{'unitId': target.instanceId},
      );
      if (attacker.card.hasPierce && overflow > 0) {
        enemy.hp -= overflow;
        _log(
          state,
          'pierce',
          'Pierce meneruskan $overflow damage ke player',
          side,
          <String, dynamic>{'damage': overflow},
        );
      }
    } else if (target.stance == Stance.guarding) {
      final counter = estimateCounterDamage(state, target, attacker);
      _damageUnit(attacker, counter);
      _log(
        state,
        'counter',
        '${target.card.name} melakukan counter $counter damage',
        side.opponent,
        <String, dynamic>{
          'unitId': target.instanceId,
          'damage': counter,
        },
      );
      if (attacker.isDead) {
        me.board.remove(attacker);
        me.discard.add(attacker.card);
        _log(
          state,
          'unit_died',
          '${attacker.card.name} gugur karena counter',
          side,
          <String, dynamic>{'unitId': attacker.instanceId},
        );
      }
    }

    if (!attacker.isDead) {
      attacker.hasActed = true;
      attacker.stance = Stance.tapped;
    }

    _evaluateOutcome(state);
  }

  void _setGuard(BattleState state, SetGuardAction action) {
    final side = state.activeSide;
    final me = state.sideState(side);
    final unit = _findUnit(me.board, action.unitId);
    if (unit == null) {
      throw const IllegalActionException('Unit tidak ditemukan');
    }
    if (unit.hasActed) {
      throw const IllegalActionException('Unit sudah melakukan aksi');
    }
    if (unit.isFrozen) {
      throw const IllegalActionException('Unit sedang freeze');
    }

    unit.stance = Stance.guarding;
    unit.hasActed = true;
    _log(
      state,
      'guard',
      '${unit.card.name} memasang Guard',
      side,
      <String, dynamic>{'unitId': unit.instanceId},
    );
  }

  void _resolveAbility(
    BattleState state,
    BattleSide side, {
    required BattleUnit? caster,
    required CardModel source,
    required CardAbility ability,
    String? targetId,
  }) {
    final enemy = state.opponentState(side);

    final targets = _resolveTargets(
      state,
      side,
      ability,
      caster: caster,
      targetId: targetId,
    );

    switch (ability.type) {
      case 'attack':
        if (ability.target == 'enemy_player') {
          enemy.hp -= ability.power;
          _log(
            state,
            'ability_damage',
            '${source.name} menembak player $ability.power damage',
            side,
            <String, dynamic>{'damage': ability.power},
          );
          break;
        }
        for (final target in targets) {
          final damage = estimateAbilityDamage(
            state,
            source.element,
            ability.power,
            target,
          );
          final dealt = _damageUnit(target, damage);
          _log(
            state,
            'ability_damage',
            '${source.name} menimpa ${target.card.name} ($dealt)',
            side,
            <String, dynamic>{
              'targetId': target.instanceId,
              'damage': dealt,
            },
          );
        }
      case 'heal':
        for (final target in targets) {
          final before = target.hp;
          target.hp = math.min(target.maxHp, target.hp + ability.power);
          _log(
            state,
            'heal',
            '${target.card.name} pulih ${target.hp - before} HP',
            side,
            <String, dynamic>{
              'targetId': target.instanceId,
              'amount': target.hp - before,
            },
          );
        }
      case 'buff':
        for (final target in targets) {
          target.applyStatus(
            BattleStatusKind.rally,
            ability.status?.value ?? ability.power,
            ability.status?.turns ?? 1,
          );
        }
      case 'control':
        final kind = _statusKindOf(ability.status?.kind);
        for (final target in targets) {
          target.applyStatus(
            kind,
            ability.status?.value ?? ability.power,
            ability.status?.turns ?? 2,
          );
        }
      case 'shield':
        for (final target in targets) {
          target.applyStatus(
            BattleStatusKind.shield,
            ability.status?.value ?? ability.power,
            ability.status?.turns ?? 2,
          );
        }
    }

    final extra = ability.status;
    if (extra != null &&
        ability.type != 'control' &&
        ability.type != 'shield' &&
        ability.type != 'buff') {
      final kind = _statusKindOf(extra.kind);
      for (final target in targets) {
        if (!target.isDead) {
          target.applyStatus(kind, extra.value, extra.turns);
        }
      }
    }
  }

  List<BattleUnit> _resolveTargets(
    BattleState state,
    BattleSide side,
    CardAbility ability, {
    required BattleUnit? caster,
    String? targetId,
  }) {
    final me = state.sideState(side);
    final enemy = state.opponentState(side);

    switch (ability.target) {
      case 'all_enemy_units':
        return List<BattleUnit>.from(enemy.board);
      case 'all_allies':
        return List<BattleUnit>.from(me.board);
      case 'enemy_player':
        return const <BattleUnit>[];
      case 'self':
        if (caster != null) return <BattleUnit>[caster];
        final own = _findUnit(me.board, targetId);
        if (own == null) {
          throw const IllegalActionException('Target self tidak valid');
        }
        return <BattleUnit>[own];
      case 'enemy_unit':
        final target = _findUnit(enemy.board, targetId);
        if (target == null) {
          throw const IllegalActionException('Target musuh tidak valid');
        }
        return <BattleUnit>[target];
      case 'any_unit':
        final target =
            _findUnit(me.board, targetId) ?? _findUnit(enemy.board, targetId);
        if (target == null) {
          throw const IllegalActionException('Target unit tidak valid');
        }
        return <BattleUnit>[target];
      default:
        throw const IllegalActionException('Target ability tidak dikenal');
    }
  }

  BattleStatusKind _statusKindOf(String? raw) {
    return switch (raw) {
      'freeze' => BattleStatusKind.freeze,
      'shield' => BattleStatusKind.shield,
      'rally' => BattleStatusKind.rally,
      _ => BattleStatusKind.burn,
    };
  }

  int _damageUnit(BattleUnit unit, int amount) {
    var remaining = amount;
    final shield = unit.statusOf(BattleStatusKind.shield);
    if (shield != null && shield.value > 0) {
      final absorbed = math.min(shield.value, remaining);
      shield.value -= absorbed;
      remaining -= absorbed;
      if (shield.value <= 0) unit.removeStatus(BattleStatusKind.shield);
    }
    if (remaining > 0) {
      unit.hp -= remaining;
    }
    return remaining;
  }

  void _removeDeadUnits(BattleState state, BattleSide side) {
    final player = state.sideState(side);
    final dead = player.board.where((unit) => unit.isDead).toList();
    for (final unit in dead) {
      player.board.remove(unit);
      player.discard.add(unit.card);
      _log(
        state,
        'unit_died',
        '${unit.card.name} gugur',
        side,
        <String, dynamic>{'unitId': unit.instanceId},
      );
    }
  }

  void _endTurn(BattleState state) {
    final side = state.activeSide;
    final me = state.sideState(side);

    for (final unit in me.board) {
      unit.removeStatus(BattleStatusKind.rally);
      final freeze = unit.statusOf(BattleStatusKind.freeze);
      if (freeze != null) {
        freeze.turns -= 1;
        if (freeze.turns <= 0) unit.removeStatus(BattleStatusKind.freeze);
      }
    }

    if (_evaluateOutcome(state)) return;

    _log(
      state,
      'end_turn',
      '${me.label} mengakhiri giliran',
      side,
      const <String, dynamic>{},
    );

    state.activeSide = side.opponent;
    _beginTurn(state, state.activeSide);
  }

  void _beginTurn(BattleState state, BattleSide side) {
    final player = state.sideState(side);

    if (side == state.firstSide) {
      state.turnNumber += 1;
      if (state.turnNumber > state.config.maxTurns) {
        _finish(state, BattleOutcome.draw);
        return;
      }
    }

    final isFirstTurn = player.maxEnergy == 0;
    player.maxEnergy = isFirstTurn
        ? state.config.startingEnergy
        : math.min(player.maxEnergy + 1, state.config.maxEnergy);
    player.energy = player.maxEnergy;

    for (final unit in player.board) {
      unit.hasActed = false;
      unit.summonedThisTurn = false;
      unit.stance = Stance.ready;
    }

    for (final unit in List<BattleUnit>.from(player.board)) {
      final burn = unit.statusOf(BattleStatusKind.burn);
      if (burn != null && burn.turns > 0 && burn.value > 0) {
        unit.hp -= burn.value;
        _log(
          state,
          'burn',
          '${unit.card.name} terkena Burn ${burn.value}',
          side,
          <String, dynamic>{
            'unitId': unit.instanceId,
            'damage': burn.value,
          },
        );
        burn.turns -= 1;
        if (burn.turns <= 0) unit.removeStatus(BattleStatusKind.burn);
      }

      final shield = unit.statusOf(BattleStatusKind.shield);
      if (shield != null) {
        shield.turns -= 1;
        if (shield.turns <= 0) unit.removeStatus(BattleStatusKind.shield);
      }
    }

    _removeDeadUnits(state, side);
    if (_evaluateOutcome(state)) return;

    final isVeryFirstTurn =
        side == state.firstSide && state.turnNumber == 1;
    if (!isVeryFirstTurn) {
      _drawOne(state, side);
      if (_evaluateOutcome(state)) return;
    }

    state.phase = BattlePhase.action;
    _log(
      state,
      'begin_turn',
      '${player.label} memulai giliran (energi ${player.energy})',
      side,
      <String, dynamic>{
        'energy': player.energy,
        'turn': state.turnNumber,
      },
    );
  }

  void _drawOne(BattleState state, BattleSide side) {
    final player = state.sideState(side);

    if (player.deck.isEmpty) {
      player.fatigueCounter += 1;
      final damage =
          state.config.fatigueBase +
          (player.fatigueCounter - 1) * state.config.fatigueStep;
      player.hp -= damage;
      _log(
        state,
        'fatigue',
        'Deck habis: fatigue $damage damage',
        side,
        <String, dynamic>{'damage': damage},
      );
      return;
    }

    final card = player.deck.removeAt(0);
    if (player.hand.length >= state.config.handLimit) {
      player.discard.add(card);
      _log(
        state,
        'hand_burn',
        'Tangan penuh: ${card.name} di-burn',
        side,
        <String, dynamic>{'cardId': card.id},
      );
      return;
    }

    player.hand.add(card);
    _log(
      state,
      'draw',
      '${player.label} menarik ${card.name}',
      side,
      <String, dynamic>{'cardId': card.id},
    );
  }

  void _concede(BattleState state) {
    _log(
      state,
      'concede',
      '${state.sideState(state.activeSide).label} menyerah',
      state.activeSide,
      const <String, dynamic>{},
    );
    _finish(state, BattleOutcome.loss);
  }

  bool _evaluateOutcome(BattleState state) {
    if (state.outcome != null) return true;

    final playerDead = state.player.hp <= 0;
    final botDead = state.bot.hp <= 0;
    if (!playerDead && !botDead) return false;

    final outcome = playerDead && botDead
        ? BattleOutcome.draw
        : botDead
        ? BattleOutcome.win
        : BattleOutcome.loss;
    _finish(state, outcome);
    return true;
  }

  void _finish(BattleState state, BattleOutcome outcome) {
    state.outcome = outcome;
    state.phase = BattlePhase.ended;
    _log(
      state,
      'battle_end',
      'Pertandingan selesai: ${outcome.name}',
      null,
      <String, dynamic>{
        'outcome': outcome.name,
        'playerHp': state.player.hp,
        'botHp': state.bot.hp,
        'turn': state.turnNumber,
      },
    );
  }

  bool isTerminal(BattleState state) => state.outcome != null;

  String logHash(BattleState state) => state.logHash;

  BattleUnit? _findUnit(List<BattleUnit> board, String? id) {
    if (id == null) return null;
    for (final unit in board) {
      if (unit.instanceId == id) return unit;
    }
    return null;
  }

  void _log(
    BattleState state,
    String type,
    String message,
    BattleSide? side,
    Map<String, dynamic> data,
  ) {
    state.log.add(
      BattleEvent(
        type: type,
        turn: state.turnNumber,
        message: message,
        side: side,
        data: data,
      ),
    );
  }
}

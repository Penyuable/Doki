import 'dart:math' as math;

import 'battle_engine.dart';
import 'battle_models.dart';

enum BotDifficulty {
  easy,
  medium,
  master;

  String get api => name;

  static BotDifficulty fromApi(Object? raw) {
    final text = raw?.toString().toLowerCase();
    for (final value in BotDifficulty.values) {
      if (value.name == text) return value;
    }
    return BotDifficulty.easy;
  }
}

/// Bot hanya memakai `legalActions()` dan state publik.
/// Tidak pernah membaca hand/deck lawan dan tidak mengubah state langsung.
class BotAI {
  BotAI({
    required this.difficulty,
    this.engine = const BattleEngine(),
    int? seed,
  }) : _rng = math.Random(seed ?? 1);

  factory BotAI.forDifficulty(
    BotDifficulty difficulty, {
    int? seed,
    BattleEngine engine = const BattleEngine(),
  }) {
    return BotAI(difficulty: difficulty, engine: engine, seed: seed);
  }

  final BotDifficulty difficulty;
  final BattleEngine engine;
  final math.Random _rng;

  BattleAction decide(BattleState state, BattleSide side) {
    final legal = engine.legalActions(state, side);
    if (legal.isEmpty) return const EndTurnAction();

    return switch (difficulty) {
      BotDifficulty.easy => _easy(legal),
      BotDifficulty.medium => _greedy(state, side, legal),
      BotDifficulty.master => _master(state, side, legal),
    };
  }

  BattleAction _easy(List<BattleAction> legal) {
    if (_rng.nextDouble() < 0.2) return const EndTurnAction();

    final weights = legal.map(_easyWeight).toList(growable: false);
    final total = weights.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return legal[_rng.nextInt(legal.length)];

    var roll = _rng.nextDouble() * total;
    for (var i = 0; i < legal.length; i++) {
      roll -= weights[i];
      if (roll <= 0) return legal[i];
    }
    return legal.last;
  }

  double _easyWeight(BattleAction action) {
    return switch (action) {
      PlayCardAction() => 1.0,
      AttackAction() => 1.0,
      UseAbilityAction() => 0.5,
      SetGuardAction() => 0.3,
      EndTurnAction() => 0.5,
      ConcedeAction() => 0.0,
    };
  }

  BattleAction _greedy(
    BattleState state,
    BattleSide side,
    List<BattleAction> legal,
  ) {
    BattleAction best = const EndTurnAction();
    var bestScore = 0.0;

    for (final action in legal) {
      if (action is EndTurnAction) continue;
      final score = _score(state, side, action);
      if (score > bestScore + 1e-9) {
        bestScore = score;
        best = action;
      }
    }
    return best;
  }

  BattleAction _master(
    BattleState state,
    BattleSide side,
    List<BattleAction> legal,
  ) {
    // Lethal langsung selalu diambil.
    for (final action in legal) {
      final next = _safeApply(state, action);
      if (next?.outcome == BattleOutcome.win) return action;
    }

    // Batas kandidat menjaga p95 < 300 ms tanpa bergantung pada waktu sistem,
    // sehingga keputusan bot tetap deterministik untuk seed yang sama.
    final candidates = <BattleAction>[];
    for (final action in legal) {
      if (candidates.length >= 18) break;
      candidates.add(action);
    }
    if (!candidates.any((action) => action is EndTurnAction)) {
      candidates.add(const EndTurnAction());
    }

    BattleAction best = const EndTurnAction();
    var bestScore = double.negativeInfinity;

    for (final action in candidates) {
      final next = _safeApply(state, action);
      if (next == null) continue;

      var score = _evaluate(next, side);
      if (next.outcome == BattleOutcome.win) {
        score += 100000;
      } else if (next.outcome == BattleOutcome.loss) {
        score -= 100000;
      } else if (next.activeSide == side.opponent) {
        final opponentState = _applyGreedySequence(
          next,
          side.opponent,
          maxActions: 4,
        );
        final opponentEval = _evaluate(opponentState, side.opponent);
        score = 0.7 * score + 0.3 * (-opponentEval);
      }

      if (score > bestScore) {
        bestScore = score;
        best = action;
      }
    }

    return best;
  }

  BattleState _applyGreedySequence(
    BattleState state,
    BattleSide side, {
    required int maxActions,
  }) {
    var current = state;
    for (var i = 0; i < maxActions; i++) {
      if (current.isTerminal || current.activeSide != side) break;
      final legal = engine.legalActions(current, side);
      if (legal.isEmpty) break;
      final action = _greedy(current, side, legal);
      final next = _safeApply(current, action);
      if (next == null) break;
      current = next;
      if (action is EndTurnAction) break;
    }
    return current;
  }

  BattleState? _safeApply(BattleState state, BattleAction action) {
    try {
      return engine.apply(state, action);
    } on IllegalActionException {
      return null;
    }
  }

  double _score(BattleState state, BattleSide side, BattleAction action) {
    final me = state.sideState(side);
    final enemy = state.opponentState(side);

    switch (action) {
      case AttackAction():
        final attacker = _unit(me.board, action.attackerId);
        if (attacker == null) return -1;

        if (action.targetId == null) {
          final damage = engine.estimateFaceDamage(state, attacker);
          final lethal = damage >= enemy.hp;
          return damage * 1.2 + (lethal ? 1000 : 0);
        }

        final target = _unit(enemy.board, action.targetId);
        if (target == null) return -1;

        final damage = engine.estimateAttackDamage(state, attacker, target);
        final kills = damage >= target.hp;
        var score =
            damage.toDouble() + (kills ? 60 + _unitValue(target) : 0);
        score += target.attack * 0.5;

        if (target.stance == Stance.guarding && !kills) {
          final counter = engine.estimateCounterDamage(state, target, attacker);
          if (counter >= attacker.hp) {
            score -= _unitValue(attacker) * 0.6;
          } else {
            score -= counter * 0.2;
          }
        }
        return score;

      case PlayCardAction():
        if (action.handIndex < 0 || action.handIndex >= me.hand.length) {
          return -1;
        }
        final card = me.hand[action.handIndex];
        if (card.isUnit) {
          var score =
              2.0 *
              ((card.attack ?? 0) +
                  (card.hp ?? 0) / 4 -
                  card.cost * 3);
          if (me.board.length < state.config.boardSlots) score += 4;
          if (card.hasCharge) score += 4;
          return score;
        }
        final ability = card.ability;
        if (ability == null) return -1;
        return 1.5 * ability.power + 3 - card.cost * 1.5;

      case UseAbilityAction():
        final unit = _unit(me.board, action.unitId);
        final ability = unit?.card.ability;
        if (unit == null || ability == null) return -1;

        var score = 1.2 * ability.power;
        if (ability.type == 'heal') {
          score = 1.0 * ability.power;
        } else if (ability.type == 'buff') {
          score = 1.4 * ability.power;
        } else if (ability.type == 'shield') {
          score = 0.8 * ability.power;
        }
        if (ability.status != null) score += 10;

        if (ability.type == 'attack' &&
            ability.target != 'enemy_player' &&
            action.targetId != null) {
          final target = _unit(enemy.board, action.targetId);
          if (target != null) {
            final damage = engine.estimateAbilityDamage(
              state,
              unit.card.element,
              ability.power,
              target,
            );
            if (damage >= target.hp) score += 25;
            score -= ability.cost * 1.5;
          }
        }
        return score;

      case SetGuardAction():
        final unit = _unit(me.board, action.unitId);
        if (unit == null) return -1;
        if (unit.hp / unit.maxHp >= 0.4) return 0;
        var maxEnemyAttack = 0;
        for (final hostile in enemy.board) {
          maxEnemyAttack = math.max(maxEnemyAttack, hostile.attack);
        }
        return 8 + 6 * (maxEnemyAttack / 50);

      case EndTurnAction():
        return 0;

      case ConcedeAction():
        return double.negativeInfinity;
    }
  }

  double _evaluate(BattleState state, BattleSide side) {
    final me = state.sideState(side);
    final enemy = state.opponentState(side);

    final hpDiff = me.hp - enemy.hp;
    final attackDiff = me.totalAttack - enemy.totalAttack;
    final boardHpDiff = me.totalHp - enemy.totalHp;
    final unitDiff = me.board.length - enemy.board.length;

    var score =
        3.0 * hpDiff +
        2.0 * attackDiff +
        0.5 * boardHpDiff +
        1.5 * unitDiff -
        1.0 * me.energy;

    if (enemy.hp <= 0) score += 100000;
    if (me.hp <= 0) score -= 100000;
    return score;
  }

  double _unitValue(BattleUnit unit) => unit.attack + unit.hp / 4.0;

  BattleUnit? _unit(List<BattleUnit> board, String? id) {
    if (id == null) return null;
    for (final unit in board) {
      if (unit.instanceId == id) return unit;
    }
    return null;
  }
}

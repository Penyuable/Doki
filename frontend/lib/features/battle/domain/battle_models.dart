import 'dart:convert';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';

import '../../../core/utils/canonical_json.dart';
import '../../../domain/models/card_model.dart';

enum BattlePhase { upkeep, action, ended }

enum BattleSide {
  player,
  bot;

  BattleSide get opponent =>
      this == BattleSide.player ? BattleSide.bot : BattleSide.player;
}

enum Stance { ready, tapped, guarding }

enum BattleOutcome { win, loss, draw }

enum BattleStatusKind { burn, freeze, shield, rally }

class BattleConfig {
  const BattleConfig({
    this.playerHp = 200,
    this.maxEnergy = 10,
    this.startingEnergy = 1,
    this.boardSlots = 3,
    this.startingHand = 4,
    this.handLimit = 8,
    this.guardDamageMultiplier = 0.5,
    this.guardCounterRatio = 0.3,
    this.defenseMitigation = 0.5,
    this.fatigueBase = 20,
    this.fatigueStep = 10,
    this.maxTurns = 50,
  });

  final int playerHp;
  final int maxEnergy;
  final int startingEnergy;
  final int boardSlots;
  final int startingHand;
  final int handLimit;
  final double guardDamageMultiplier;
  final double guardCounterRatio;
  final double defenseMitigation;
  final int fatigueBase;
  final int fatigueStep;
  final int maxTurns;
}

class BattleStatus {
  BattleStatus({
    required this.kind,
    required this.value,
    required this.turns,
  });

  final BattleStatusKind kind;
  int value;
  int turns;

  BattleStatus copy() =>
      BattleStatus(kind: kind, value: value, turns: turns);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'kind': kind.name,
    'value': value,
    'turns': turns,
  };
}

class BattleUnit {
  BattleUnit({
    required this.instanceId,
    required this.card,
    required this.hp,
    required this.maxHp,
    required this.attack,
    required this.defense,
    this.stance = Stance.ready,
    this.hasActed = false,
    this.summonedThisTurn = true,
    List<BattleStatus>? statuses,
  }) : statuses = statuses ?? <BattleStatus>[];

  factory BattleUnit.fromCard(CardModel card, String instanceId) {
    final hp = card.hp ?? 1;
    return BattleUnit(
      instanceId: instanceId,
      card: card,
      hp: hp,
      maxHp: hp,
      attack: card.attack ?? 0,
      defense: card.defense ?? 0,
    );
  }

  final String instanceId;
  final CardModel card;
  int hp;
  final int maxHp;
  final int attack;
  final int defense;
  Stance stance;
  bool hasActed;
  bool summonedThisTurn;
  final List<BattleStatus> statuses;

  bool get isDead => hp <= 0;

  bool get isFrozen =>
      statuses.any((s) => s.kind == BattleStatusKind.freeze && s.turns > 0);

  int get rallyValue {
    var value = 0;
    for (final status in statuses) {
      if (status.kind == BattleStatusKind.rally) {
        value = math.max(value, status.value);
      }
    }
    return value;
  }

  BattleStatus? statusOf(BattleStatusKind kind) {
    for (final status in statuses) {
      if (status.kind == kind) return status;
    }
    return null;
  }

  int shieldValue() => statusOf(BattleStatusKind.shield)?.value ?? 0;

  void applyStatus(BattleStatusKind kind, int value, int turns) {
    final safeTurns = math.max(1, turns);
    final existing = statusOf(kind);
    if (existing == null) {
      statuses.add(
        BattleStatus(kind: kind, value: value, turns: safeTurns),
      );
      return;
    }

    switch (kind) {
      case BattleStatusKind.burn:
      case BattleStatusKind.rally:
        existing.value = math.max(existing.value, value);
        existing.turns = math.max(existing.turns, safeTurns);
      case BattleStatusKind.freeze:
        existing.turns = math.max(existing.turns, safeTurns);
      case BattleStatusKind.shield:
        // Shield distil: jumlahkan value, durasi ambil terpanjang.
        existing.value = math.min(999, existing.value + value);
        existing.turns = math.max(existing.turns, safeTurns);
    }
  }

  void removeStatus(BattleStatusKind kind) {
    statuses.removeWhere((status) => status.kind == kind);
  }

  BattleUnit copy() => BattleUnit(
    instanceId: instanceId,
    card: card,
    hp: hp,
    maxHp: maxHp,
    attack: attack,
    defense: defense,
    stance: stance,
    hasActed: hasActed,
    summonedThisTurn: summonedThisTurn,
    statuses: statuses.map((status) => status.copy()).toList(),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'instanceId': instanceId,
    'cardId': card.id,
    'hp': hp,
    'maxHp': maxHp,
    'attack': attack,
    'defense': defense,
    'stance': stance.name,
    'hasActed': hasActed,
    'summonedThisTurn': summonedThisTurn,
    'statuses': statuses.map((status) => status.toJson()).toList(),
  };
}

class BattlePlayerState {
  BattlePlayerState({
    required this.label,
    required this.hp,
    required this.maxHp,
    required this.maxEnergy,
    required this.energy,
    required this.board,
    required this.hand,
    required this.deck,
    required this.discard,
    this.fatigueCounter = 0,
  });

  final String label;
  int hp;
  final int maxHp;
  int maxEnergy;
  int energy;
  final List<BattleUnit> board;
  final List<CardModel> hand;
  final List<CardModel> deck;
  final List<CardModel> discard;
  int fatigueCounter;

  int get totalAttack =>
      board.fold<int>(0, (sum, unit) => sum + unit.attack);

  int get totalHp => board.fold<int>(0, (sum, unit) => sum + unit.hp);

  BattlePlayerState copy() => BattlePlayerState(
    label: label,
    hp: hp,
    maxHp: maxHp,
    maxEnergy: maxEnergy,
    energy: energy,
    fatigueCounter: fatigueCounter,
    board: board.map((unit) => unit.copy()).toList(),
    hand: List<CardModel>.from(hand),
    deck: List<CardModel>.from(deck),
    discard: List<CardModel>.from(discard),
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'hp': hp,
    'maxHp': maxHp,
    'energy': energy,
    'maxEnergy': maxEnergy,
    'fatigue': fatigueCounter,
    'board': board.map((unit) => unit.toJson()).toList(),
    'hand': hand.map((card) => card.id).toList(),
    'deck': deck.map((card) => card.id).toList(),
    'discard': discard.map((card) => card.id).toList(),
  };
}

class BattleEvent {
  const BattleEvent({
    required this.type,
    required this.turn,
    required this.message,
    this.side,
    this.data = const <String, dynamic>{},
  });

  final String type;
  final int turn;
  final String message;
  final BattleSide? side;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'turn': turn,
    'side': side?.name,
    'message': message,
    'data': data,
  };
}

class BattleState {
  BattleState({
    required this.config,
    required this.seed,
    required this.firstSide,
    required this.activeSide,
    required this.turnNumber,
    required this.phase,
    required this.player,
    required this.bot,
    required this.log,
    required this.nextInstanceId,
    this.outcome,
  });

  final BattleConfig config;
  final int seed;
  final BattleSide firstSide;
  BattleSide activeSide;
  int turnNumber;
  BattlePhase phase;
  final BattlePlayerState player;
  final BattlePlayerState bot;
  final List<BattleEvent> log;
  int nextInstanceId;
  BattleOutcome? outcome;

  bool get isTerminal => outcome != null;

  BattlePlayerState sideState(BattleSide side) =>
      side == BattleSide.player ? player : bot;

  BattlePlayerState opponentState(BattleSide side) =>
      side == BattleSide.player ? bot : player;

  BattleState copy() => BattleState(
    config: config,
    seed: seed,
    firstSide: firstSide,
    activeSide: activeSide,
    turnNumber: turnNumber,
    phase: phase,
    player: player.copy(),
    bot: bot.copy(),
    log: List<BattleEvent>.from(log),
    outcome: outcome,
    nextInstanceId: nextInstanceId,
  );

  /// State kanonik untuk logHash (tanpa objek flutter, urutan stabil).
  Map<String, dynamic> toCanonicalMap() => <String, dynamic>{
    'seed': seed,
    'firstSide': firstSide.name,
    'activeSide': activeSide.name,
    'turn': turnNumber,
    'phase': phase.name,
    'outcome': outcome?.name,
    'player': player.toJson(),
    'bot': bot.toJson(),
    'log': log.map((event) => event.toJson()).toList(),
  };

  String get logHash =>
      sha256.convert(utf8.encode(canonicalJson(toCanonicalMap()))).toString();

  String get prettyJson =>
      const JsonEncoder.withIndent('  ').convert(toCanonicalMap());
}

sealed class BattleAction {
  const BattleAction();

  String get signature;
}

final class PlayCardAction extends BattleAction {
  const PlayCardAction({required this.handIndex, this.slot, this.targetId});

  final int handIndex;
  final int? slot;
  final String? targetId;

  @override
  String get signature => 'play:$handIndex:${slot ?? -1}:${targetId ?? '-'}';
}

final class UseAbilityAction extends BattleAction {
  const UseAbilityAction({required this.unitId, this.targetId});

  final String unitId;
  final String? targetId;

  @override
  String get signature => 'ability:$unitId:${targetId ?? '-'}';
}

final class AttackAction extends BattleAction {
  const AttackAction({required this.attackerId, this.targetId});

  final String attackerId;
  final String? targetId;

  @override
  String get signature => 'attack:$attackerId:${targetId ?? '-'}';
}

final class SetGuardAction extends BattleAction {
  const SetGuardAction({required this.unitId});

  final String unitId;

  @override
  String get signature => 'guard:$unitId';
}

final class EndTurnAction extends BattleAction {
  const EndTurnAction();

  @override
  String get signature => 'end';
}

final class ConcedeAction extends BattleAction {
  const ConcedeAction();

  @override
  String get signature => 'concede';
}

class IllegalActionException implements Exception {
  const IllegalActionException(this.reason);

  final String reason;

  @override
  String toString() => 'IllegalActionException: $reason';
}

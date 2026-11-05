/**
 * Model battle (port `features/battle/domain/battle_models.dart`).
 * Pure TypeScript: tanpa React, tanpa I/O, tanpa waktu sistem (I-04).
 */
import type { Card } from '../domain/card.ts';
import { canonicalJson } from '../core/canonical-json.ts';
import { sha256Hex } from '../core/sha256.ts';

export type BattlePhase = 'upkeep' | 'action' | 'ended';
export type BattleSide = 'player' | 'bot';
export type Stance = 'ready' | 'tapped' | 'guarding';
export type BattleOutcome = 'win' | 'loss' | 'draw';
export type BattleStatusKind = 'burn' | 'freeze' | 'shield' | 'rally';

export const opponentOf = (side: BattleSide): BattleSide => (side === 'player' ? 'bot' : 'player');

export type BattleConfig = {
  readonly playerHp: number;
  readonly maxEnergy: number;
  readonly startingEnergy: number;
  readonly boardSlots: number;
  readonly startingHand: number;
  readonly handLimit: number;
  readonly guardDamageMultiplier: number;
  readonly guardCounterRatio: number;
  readonly defenseMitigation: number;
  readonly fatigueBase: number;
  readonly fatigueStep: number;
  readonly maxTurns: number;
};

export const DEFAULT_BATTLE_CONFIG: BattleConfig = Object.freeze({
  playerHp: 200,
  maxEnergy: 10,
  startingEnergy: 1,
  boardSlots: 3,
  startingHand: 4,
  handLimit: 8,
  guardDamageMultiplier: 0.5,
  guardCounterRatio: 0.3,
  defenseMitigation: 0.5,
  fatigueBase: 20,
  fatigueStep: 10,
  maxTurns: 50,
});

export type BattleStatus = { kind: BattleStatusKind; value: number; turns: number };

export class BattleUnit {
  instanceId: string;
  card: Card;
  hp: number;
  maxHp: number;
  attack: number;
  defense: number;
  stance: Stance;
  hasActed: boolean;
  summonedThisTurn: boolean;
  statuses: BattleStatus[];

  constructor(init: {
    instanceId: string;
    card: Card;
    hp: number;
    maxHp: number;
    attack: number;
    defense: number;
    stance?: Stance;
    hasActed?: boolean;
    summonedThisTurn?: boolean;
    statuses?: BattleStatus[];
  }) {
    this.instanceId = init.instanceId;
    this.card = init.card;
    this.hp = init.hp;
    this.maxHp = init.maxHp;
    this.attack = init.attack;
    this.defense = init.defense;
    this.stance = init.stance ?? 'ready';
    this.hasActed = init.hasActed ?? false;
    this.summonedThisTurn = init.summonedThisTurn ?? true;
    this.statuses = init.statuses ?? [];
  }

  static fromCard(card: Card, instanceId: string): BattleUnit {
    const hp = card.hp ?? 1;
    return new BattleUnit({
      instanceId,
      card,
      hp,
      maxHp: hp,
      attack: card.attack ?? 0,
      defense: card.defense ?? 0,
    });
  }

  get isDead(): boolean {
    return this.hp <= 0;
  }

  get isFrozen(): boolean {
    return this.statuses.some((s) => s.kind === 'freeze' && s.turns > 0);
  }

  get rallyValue(): number {
    let value = 0;
    for (const status of this.statuses) {
      if (status.kind === 'rally') value = Math.max(value, status.value);
    }
    return value;
  }

  statusOf(kind: BattleStatusKind): BattleStatus | null {
    return this.statuses.find((status) => status.kind === kind) ?? null;
  }

  shieldValue(): number {
    return this.statusOf('shield')?.value ?? 0;
  }

  applyStatus(kind: BattleStatusKind, value: number, turns: number): void {
    const safeTurns = Math.max(1, turns);
    const existing = this.statusOf(kind);
    if (!existing) {
      this.statuses.push({ kind, value, turns: safeTurns });
      return;
    }
    switch (kind) {
      case 'burn':
      case 'rally':
        existing.value = Math.max(existing.value, value);
        existing.turns = Math.max(existing.turns, safeTurns);
        break;
      case 'freeze':
        existing.turns = Math.max(existing.turns, safeTurns);
        break;
      case 'shield':
        // Shield ditumpuk: jumlahkan value, durasi ambil terpanjang.
        existing.value = Math.min(999, existing.value + value);
        existing.turns = Math.max(existing.turns, safeTurns);
        break;
    }
  }

  removeStatus(kind: BattleStatusKind): void {
    this.statuses = this.statuses.filter((status) => status.kind !== kind);
  }

  copy(): BattleUnit {
    return new BattleUnit({
      instanceId: this.instanceId,
      card: this.card,
      hp: this.hp,
      maxHp: this.maxHp,
      attack: this.attack,
      defense: this.defense,
      stance: this.stance,
      hasActed: this.hasActed,
      summonedThisTurn: this.summonedThisTurn,
      statuses: this.statuses.map((status) => ({ ...status })),
    });
  }

  toJson(): Record<string, unknown> {
    return {
      instanceId: this.instanceId,
      cardId: this.card.id,
      hp: this.hp,
      maxHp: this.maxHp,
      attack: this.attack,
      defense: this.defense,
      stance: this.stance,
      hasActed: this.hasActed,
      summonedThisTurn: this.summonedThisTurn,
      statuses: this.statuses.map((status) => ({ kind: status.kind, value: status.value, turns: status.turns })),
    };
  }
}

export class BattlePlayerState {
  label: string;
  hp: number;
  maxHp: number;
  maxEnergy: number;
  energy: number;
  board: BattleUnit[];
  hand: Card[];
  deck: Card[];
  discard: Card[];
  fatigueCounter: number;

  constructor(init: {
    label: string;
    hp: number;
    maxHp: number;
    maxEnergy: number;
    energy: number;
    board: BattleUnit[];
    hand: Card[];
    deck: Card[];
    discard: Card[];
    fatigueCounter?: number;
  }) {
    this.label = init.label;
    this.hp = init.hp;
    this.maxHp = init.maxHp;
    this.maxEnergy = init.maxEnergy;
    this.energy = init.energy;
    this.board = init.board;
    this.hand = init.hand;
    this.deck = init.deck;
    this.discard = init.discard;
    this.fatigueCounter = init.fatigueCounter ?? 0;
  }

  get totalAttack(): number {
    return this.board.reduce((sum, unit) => sum + unit.attack, 0);
  }

  get totalHp(): number {
    return this.board.reduce((sum, unit) => sum + unit.hp, 0);
  }

  copy(): BattlePlayerState {
    return new BattlePlayerState({
      label: this.label,
      hp: this.hp,
      maxHp: this.maxHp,
      maxEnergy: this.maxEnergy,
      energy: this.energy,
      fatigueCounter: this.fatigueCounter,
      board: this.board.map((unit) => unit.copy()),
      hand: [...this.hand],
      deck: [...this.deck],
      discard: [...this.discard],
    });
  }

  toJson(): Record<string, unknown> {
    return {
      hp: this.hp,
      maxHp: this.maxHp,
      energy: this.energy,
      maxEnergy: this.maxEnergy,
      fatigue: this.fatigueCounter,
      board: this.board.map((unit) => unit.toJson()),
      hand: this.hand.map((card) => card.id),
      deck: this.deck.map((card) => card.id),
      discard: this.discard.map((card) => card.id),
    };
  }
}

export type BattleEvent = {
  readonly type: string;
  readonly turn: number;
  readonly message: string;
  readonly side: BattleSide | null;
  readonly data: Readonly<Record<string, unknown>>;
};

export class BattleState {
  config: BattleConfig;
  seed: number;
  firstSide: BattleSide;
  activeSide: BattleSide;
  turnNumber: number;
  phase: BattlePhase;
  player: BattlePlayerState;
  bot: BattlePlayerState;
  log: BattleEvent[];
  nextInstanceId: number;
  outcome: BattleOutcome | null;

  constructor(init: {
    config: BattleConfig;
    seed: number;
    firstSide: BattleSide;
    activeSide: BattleSide;
    turnNumber: number;
    phase: BattlePhase;
    player: BattlePlayerState;
    bot: BattlePlayerState;
    log: BattleEvent[];
    nextInstanceId: number;
    outcome?: BattleOutcome | null;
  }) {
    this.config = init.config;
    this.seed = init.seed;
    this.firstSide = init.firstSide;
    this.activeSide = init.activeSide;
    this.turnNumber = init.turnNumber;
    this.phase = init.phase;
    this.player = init.player;
    this.bot = init.bot;
    this.log = init.log;
    this.nextInstanceId = init.nextInstanceId;
    this.outcome = init.outcome ?? null;
  }

  get isTerminal(): boolean {
    return this.outcome !== null;
  }

  sideState(side: BattleSide): BattlePlayerState {
    return side === 'player' ? this.player : this.bot;
  }

  opponentState(side: BattleSide): BattlePlayerState {
    return side === 'player' ? this.bot : this.player;
  }

  copy(): BattleState {
    return new BattleState({
      config: this.config,
      seed: this.seed,
      firstSide: this.firstSide,
      activeSide: this.activeSide,
      turnNumber: this.turnNumber,
      phase: this.phase,
      player: this.player.copy(),
      bot: this.bot.copy(),
      log: [...this.log],
      outcome: this.outcome,
      nextInstanceId: this.nextInstanceId,
    });
  }

  /** State kanonik untuk logHash (urutan stabil, sama dengan Dart). */
  toCanonicalMap(): Record<string, unknown> {
    return {
      seed: this.seed,
      firstSide: this.firstSide,
      activeSide: this.activeSide,
      turn: this.turnNumber,
      phase: this.phase,
      outcome: this.outcome,
      player: this.player.toJson(),
      bot: this.bot.toJson(),
      log: this.log.map((event) => ({
        type: event.type,
        turn: event.turn,
        side: event.side,
        message: event.message,
        data: event.data,
      })),
    };
  }

  canonicalString(): string {
    return canonicalJson(this.toCanonicalMap());
  }

  /** SHA-256 dari JSON kanonik — identik dengan `BattleState.logHash` di Dart. */
  logHash(): string {
    return sha256Hex(this.canonicalString());
  }
}

export type PlayCardAction = { kind: 'play'; handIndex: number; slot?: number | null; targetId?: string | null };
export type UseAbilityAction = { kind: 'ability'; unitId: string; targetId?: string | null };
export type AttackAction = { kind: 'attack'; attackerId: string; targetId?: string | null };
export type SetGuardAction = { kind: 'guard'; unitId: string };
export type EndTurnAction = { kind: 'end' };
export type ConcedeAction = { kind: 'concede' };

export type BattleAction =
  | PlayCardAction
  | UseAbilityAction
  | AttackAction
  | SetGuardAction
  | EndTurnAction
  | ConcedeAction;

export const END_TURN: EndTurnAction = Object.freeze({ kind: 'end' });
export const CONCEDE: ConcedeAction = Object.freeze({ kind: 'concede' });

export function actionSignature(action: BattleAction): string {
  switch (action.kind) {
    case 'play':
      return `play:${action.handIndex}:${action.slot ?? -1}:${action.targetId ?? '-'}`;
    case 'ability':
      return `ability:${action.unitId}:${action.targetId ?? '-'}`;
    case 'attack':
      return `attack:${action.attackerId}:${action.targetId ?? '-'}`;
    case 'guard':
      return `guard:${action.unitId}`;
    case 'end':
      return 'end';
    case 'concede':
      return 'concede';
  }
}

export class IllegalActionError extends Error {
  readonly reason: string;

  constructor(reason: string) {
    super(`IllegalActionException: ${reason}`);
    this.name = 'IllegalActionError';
    this.reason = reason;
  }
}

/**
 * Bot AI (port `features/battle/domain/bot_ai.dart`).
 * Bot hanya memakai `legalActions()` dan state publik; tidak pernah membaca
 * hand/deck lawan dan tidak mengubah state langsung (I-10).
 */
import { DartRandom } from '../core/dart-random.ts';
import { hasKeyword, isUnit } from '../domain/card.ts';
import type { Difficulty } from '../config/game-config.ts';
import { BattleEngine, battleEngine } from './engine.ts';
import {
  type BattleAction,
  type BattleSide,
  type BattleState,
  type BattleUnit,
  END_TURN,
  IllegalActionError,
  opponentOf,
} from './models.ts';

export function difficultyFrom(raw: unknown): Difficulty {
  const text = String(raw ?? '').toLowerCase();
  return text === 'medium' || text === 'master' ? text : 'easy';
}

/** Seed bot dari seed match — sama dengan `start.seed ^ 0x9E3779B9` (int 64-bit) di Dart. */
export function botSeedFor(matchSeed: number): number {
  return (matchSeed ^ 0x9e3779b9) >>> 0;
}

export class BotAI {
  readonly difficulty: Difficulty;
  private readonly engine: BattleEngine;
  private readonly rng: DartRandom;

  constructor(options: { difficulty: Difficulty; seed?: number; engine?: BattleEngine }) {
    this.difficulty = options.difficulty;
    this.engine = options.engine ?? battleEngine;
    this.rng = new DartRandom(options.seed ?? 1);
  }

  decide(state: BattleState, side: BattleSide): BattleAction {
    const legal = this.engine.legalActions(state, side);
    if (legal.length === 0) return END_TURN;
    switch (this.difficulty) {
      case 'easy':
        return this.easy(legal);
      case 'medium':
        return this.greedy(state, side, legal);
      case 'master':
        return this.master(state, side, legal);
    }
  }

  private easy(legal: BattleAction[]): BattleAction {
    if (this.rng.nextDouble() < 0.2) return END_TURN;

    const weights = legal.map(easyWeight);
    const total = weights.reduce((sum, value) => sum + value, 0);
    if (total <= 0) return legal[this.rng.nextInt(legal.length)] as BattleAction;

    let roll = this.rng.nextDouble() * total;
    for (let i = 0; i < legal.length; i += 1) {
      roll -= weights[i] as number;
      if (roll <= 0) return legal[i] as BattleAction;
    }
    return legal[legal.length - 1] as BattleAction;
  }

  private greedy(state: BattleState, side: BattleSide, legal: BattleAction[]): BattleAction {
    let best: BattleAction = END_TURN;
    let bestScore = 0.0;
    for (const action of legal) {
      if (action.kind === 'end') continue;
      const score = this.score(state, side, action);
      if (score > bestScore + 1e-9) {
        bestScore = score;
        best = action;
      }
    }
    return best;
  }

  private master(state: BattleState, side: BattleSide, legal: BattleAction[]): BattleAction {
    // Lethal langsung selalu diambil.
    for (const action of legal) {
      const next = this.safeApply(state, action);
      if (next?.outcome === 'win') return action;
    }

    // Batas kandidat menjaga p95 < 300 ms tanpa bergantung pada waktu sistem.
    const candidates: BattleAction[] = [];
    for (const action of legal) {
      if (candidates.length >= 18) break;
      candidates.push(action);
    }
    if (!candidates.some((action) => action.kind === 'end')) candidates.push(END_TURN);

    let best: BattleAction = END_TURN;
    let bestScore = Number.NEGATIVE_INFINITY;

    for (const action of candidates) {
      const next = this.safeApply(state, action);
      if (!next) continue;

      let score = this.evaluate(next, side);
      if (next.outcome === 'win') {
        score += 100000;
      } else if (next.outcome === 'loss') {
        score -= 100000;
      } else if (next.activeSide === opponentOf(side)) {
        const opponentState = this.applyGreedySequence(next, opponentOf(side), 4);
        const opponentEval = this.evaluate(opponentState, opponentOf(side));
        score = 0.7 * score + 0.3 * -opponentEval;
      }

      if (score > bestScore) {
        bestScore = score;
        best = action;
      }
    }
    return best;
  }

  private applyGreedySequence(state: BattleState, side: BattleSide, maxActions: number): BattleState {
    let current = state;
    for (let i = 0; i < maxActions; i += 1) {
      if (current.isTerminal || current.activeSide !== side) break;
      const legal = this.engine.legalActions(current, side);
      if (legal.length === 0) break;
      const action = this.greedy(current, side, legal);
      const next = this.safeApply(current, action);
      if (!next) break;
      current = next;
      if (action.kind === 'end') break;
    }
    return current;
  }

  private safeApply(state: BattleState, action: BattleAction): BattleState | null {
    try {
      return this.engine.apply(state, action);
    } catch (error) {
      if (error instanceof IllegalActionError) return null;
      throw error;
    }
  }

  private score(state: BattleState, side: BattleSide, action: BattleAction): number {
    const me = state.sideState(side);
    const enemy = state.opponentState(side);

    switch (action.kind) {
      case 'attack': {
        const attacker = findUnit(me.board, action.attackerId);
        if (!attacker) return -1;

        if (action.targetId == null) {
          const damage = this.engine.estimateFaceDamage(state, attacker);
          const lethal = damage >= enemy.hp;
          return damage * 1.2 + (lethal ? 1000 : 0);
        }

        const target = findUnit(enemy.board, action.targetId);
        if (!target) return -1;

        const damage = this.engine.estimateAttackDamage(state, attacker, target);
        const kills = damage >= target.hp;
        let score = damage + (kills ? 60 + unitValue(target) : 0);
        score += target.attack * 0.5;

        if (target.stance === 'guarding' && !kills) {
          const counter = this.engine.estimateCounterDamage(state, target, attacker);
          if (counter >= attacker.hp) {
            score -= unitValue(attacker) * 0.6;
          } else {
            score -= counter * 0.2;
          }
        }
        return score;
      }

      case 'play': {
        if (action.handIndex < 0 || action.handIndex >= me.hand.length) return -1;
        const card = me.hand[action.handIndex];
        if (!card) return -1;
        if (isUnit(card)) {
          let score = 2.0 * ((card.attack ?? 0) + (card.hp ?? 0) / 4 - card.cost * 3);
          if (me.board.length < state.config.boardSlots) score += 4;
          if (hasKeyword(card, 'charge')) score += 4;
          return score;
        }
        const ability = card.ability;
        if (!ability) return -1;
        return 1.5 * ability.power + 3 - card.cost * 1.5;
      }

      case 'ability': {
        const unit = findUnit(me.board, action.unitId);
        const ability = unit?.card.ability;
        if (!unit || !ability) return -1;

        let score = 1.2 * ability.power;
        if (ability.type === 'heal') {
          score = 1.0 * ability.power;
        } else if (ability.type === 'buff') {
          score = 1.4 * ability.power;
        } else if (ability.type === 'shield') {
          score = 0.8 * ability.power;
        }
        if (ability.status) score += 10;

        if (ability.type === 'attack' && ability.target !== 'enemy_player' && action.targetId != null) {
          const target = findUnit(enemy.board, action.targetId);
          if (target) {
            const damage = this.engine.estimateAbilityDamage(state, unit.card.element, ability.power, target);
            if (damage >= target.hp) score += 25;
            score -= ability.cost * 1.5;
          }
        }
        return score;
      }

      case 'guard': {
        const unit = findUnit(me.board, action.unitId);
        if (!unit) return -1;
        if (unit.hp / unit.maxHp >= 0.4) return 0;
        let maxEnemyAttack = 0;
        for (const hostile of enemy.board) maxEnemyAttack = Math.max(maxEnemyAttack, hostile.attack);
        return 8 + 6 * (maxEnemyAttack / 50);
      }

      case 'end':
        return 0;

      case 'concede':
        return Number.NEGATIVE_INFINITY;
    }
  }

  private evaluate(state: BattleState, side: BattleSide): number {
    const me = state.sideState(side);
    const enemy = state.opponentState(side);

    const hpDiff = me.hp - enemy.hp;
    const attackDiff = me.totalAttack - enemy.totalAttack;
    const boardHpDiff = me.totalHp - enemy.totalHp;
    const unitDiff = me.board.length - enemy.board.length;

    let score = 3.0 * hpDiff + 2.0 * attackDiff + 0.5 * boardHpDiff + 1.5 * unitDiff - 1.0 * me.energy;
    if (enemy.hp <= 0) score += 100000;
    if (me.hp <= 0) score -= 100000;
    return score;
  }
}

function easyWeight(action: BattleAction): number {
  switch (action.kind) {
    case 'play':
    case 'attack':
      return 1.0;
    case 'ability':
      return 0.5;
    case 'guard':
      return 0.3;
    case 'end':
      return 0.5;
    case 'concede':
      return 0.0;
  }
}

function unitValue(unit: BattleUnit): number {
  return unit.attack + unit.hp / 4.0;
}

function findUnit(board: readonly BattleUnit[], id: string | null | undefined): BattleUnit | null {
  if (id == null) return null;
  return board.find((unit) => unit.instanceId === id) ?? null;
}

/**
 * Logika presentasi arena (port helper `battle_arena_page.dart` + `battle_moves.dart`).
 * Hanya membaca state/aksi legal engine — tidak menghitung damage sendiri (I-05).
 */
import { elementSlug, isUnit, type Card } from '../domain/card.ts';
import type { BattleEvent, BattleState } from '../battle/models.ts';
import type { BattleSession } from '../battle/session.ts';
import type { Translator } from '../i18n/strings.ts';

export type MoveKind = 'strike' | 'ability' | 'guard';

export type CardMove = {
  kind: MoveKind;
  name: string;
  /** Stat kartu (ATK / power ability) — bukan hasil hitung damage. */
  power: number | null;
  cost: number;
  description: string | null;
  tone: string;
};

export const ABILITY_TONE: Record<string, string> = {
  attack: 'danger',
  heal: 'success',
  buff: 'warning',
  control: 'accent',
  shield: 'info',
};

export const strikeNameOf = (card: Card, t: Translator): string => t(`move.strike.${elementSlug(card.element)}`);

/** Daftar jurus: serangan dasar (unit), ability (bila ada), guard (unit). */
export function movesFor(card: Card, t: Translator, attackOverride?: number): CardMove[] {
  const moves: CardMove[] = [];
  if (isUnit(card)) {
    moves.push({
      kind: 'strike',
      name: strikeNameOf(card, t),
      power: attackOverride ?? card.attack ?? 0,
      cost: 0,
      description: null,
      tone: `el-${elementSlug(card.element)}`,
    });
  }
  if (card.ability) {
    moves.push({
      kind: 'ability',
      name: card.ability.name,
      power: card.ability.power > 0 ? card.ability.power : null,
      cost: card.ability.cost,
      description: card.ability.text,
      tone: ABILITY_TONE[card.ability.type] ?? 'primary',
    });
  }
  if (isUnit(card)) {
    moves.push({ kind: 'guard', name: t('battle.guard'), power: null, cost: 0, description: t('move.guardHint'), tone: 'info' });
  }
  return moves;
}

/** Langkah berikutnya yang disarankan, dari aksi legal engine saat ini. */
export function nextStepHint(session: BattleSession, t: Translator): string | null {
  const { battle, busy } = session.state;
  if (battle.isTerminal) return null;
  if (battle.activeSide !== 'player' || busy) return t('battle.hint.botTurn');
  for (let i = 0; i < battle.player.hand.length; i += 1) {
    if (session.playOptionsForHand(i).length > 0) return t('battle.hint.play');
  }
  for (const unit of battle.player.board) {
    if (session.attackOptionsFor(unit.instanceId).length > 0 || session.abilityOptionsFor(unit.instanceId).length > 0) {
      return t('battle.hint.act');
    }
  }
  return t('battle.hint.endTurn');
}

/** Penjelasan kenapa kartu di tangan tidak bisa dimainkan. */
export function cantPlayReason(battle: BattleState, handIndex: number, t: Translator): string {
  if (battle.activeSide !== 'player') return t('battle.cantPlay.turn');
  const me = battle.player;
  const card = me.hand[handIndex];
  if (!card) return t('battle.noActions');
  if (card.cost > me.energy) return t('battle.cantPlay.energy', { cost: card.cost, energy: me.energy });
  if (isUnit(card) && me.board.length >= battle.config.boardSlots) {
    return t('battle.cantPlay.board', { slots: battle.config.boardSlots });
  }
  return t('battle.cantPlay.target');
}

export function describeTarget(id: string | null | undefined, battle: BattleState, t: Translator): string {
  if (id == null) return t('battle.faceTarget');
  for (const unit of [...battle.bot.board, ...battle.player.board]) {
    if (unit.instanceId === id) return `${unit.card.name} · ${unit.attack}/${unit.hp}`;
  }
  return id;
}

export function uniqueTargets(ids: ReadonlyArray<string | null | undefined>): Array<string | null> {
  const out: Array<string | null> = [];
  for (const id of ids) {
    const value = id ?? null;
    if (!out.includes(value)) out.push(value);
  }
  return out;
}

export type FxKind = 'damage' | 'heal' | 'burn' | 'fatigue';

/** Efek visual turunan dari BattleEvent baru (angka diambil dari event, bukan dihitung UI). */
export type FxItem = {
  key: string;
  kind: FxKind;
  amount: number;
  /** instanceId unit, atau 'hero:player' / 'hero:bot'. */
  anchor: string;
};

export function fxFromEvents(events: readonly BattleEvent[], offset: number): FxItem[] {
  const out: FxItem[] = [];
  events.forEach((event, i) => {
    const key = `${offset + i}`;
    const amount = typeof event.data.damage === 'number' ? event.data.damage : null;
    const side = event.side;
    const enemyHero = side === 'player' ? 'hero:bot' : 'hero:player';
    switch (event.type) {
      case 'attack':
      case 'ability_damage':
        if (amount !== null) {
          const target = typeof event.data.targetId === 'string' ? event.data.targetId : enemyHero;
          out.push({ key, kind: 'damage', amount, anchor: target });
        }
        break;
      case 'face_attack':
      case 'pierce':
        if (amount !== null) out.push({ key, kind: 'damage', amount, anchor: enemyHero });
        break;
      case 'counter': {
        // Counter dipantulkan ke penyerang: cari event attack sebelumnya.
        const attack = [...events.slice(0, i)].reverse().find((e) => e.type === 'attack');
        const attacker = attack && typeof attack.data.attackerId === 'string' ? attack.data.attackerId : null;
        if (amount !== null && attacker) out.push({ key, kind: 'damage', amount, anchor: attacker });
        break;
      }
      case 'burn':
        if (amount !== null && typeof event.data.unitId === 'string') {
          out.push({ key, kind: 'burn', amount, anchor: event.data.unitId });
        }
        break;
      case 'heal':
        if (typeof event.data.amount === 'number' && event.data.amount > 0 && typeof event.data.targetId === 'string') {
          out.push({ key, kind: 'heal', amount: event.data.amount, anchor: event.data.targetId });
        }
        break;
      case 'fatigue':
        if (amount !== null && side) out.push({ key, kind: 'fatigue', amount, anchor: `hero:${side}` });
        break;
      default:
        break;
    }
  });
  return out;
}

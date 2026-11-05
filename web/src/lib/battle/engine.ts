/**
 * Engine battle deterministik (port `features/battle/domain/battle_engine.dart`).
 * Pure TypeScript (I-04): tanpa React/I/O/waktu, RNG hanya dari `seed`.
 * Semua perubahan state lewat `apply`; UI dan BotAI memakai pintu yang sama.
 *
 * Urutan mutasi & pesan log sengaja identik dengan versi Dart agar state akhir
 * (dan `logHash`) sama di mobile maupun web untuk seed + aksi yang sama.
 */
import { DartRandom, dartRound, dartShuffle } from '../core/dart-random.ts';
import type { Card, CardAbility, CardElement } from '../domain/card.ts';
import { hasKeyword, isUnit } from '../domain/card.ts';
import {
  type AttackAction,
  type BattleAction,
  type BattleConfig,
  type BattleOutcome,
  type BattleSide,
  type BattleStatusKind,
  type PlayCardAction,
  type SetGuardAction,
  type UseAbilityAction,
  BattlePlayerState,
  BattleState,
  BattleUnit,
  DEFAULT_BATTLE_CONFIG,
  IllegalActionError,
  opponentOf,
} from './models.ts';

const BEATS: Partial<Record<CardElement, CardElement>> = {
  Fire: 'Air',
  Air: 'Earth',
  Earth: 'Water',
  Water: 'Fire',
};

export class BattleEngine {
  elementMultiplier(attacker: CardElement, defender: CardElement): number {
    if (attacker === 'Void' || defender === 'Void') return 1.0;
    if (BEATS[attacker] === defender) return 1.25;
    if (BEATS[defender] === attacker) return 0.8;
    return 1.0;
  }

  estimateAttackDamage(state: BattleState, attacker: BattleUnit, defender: BattleUnit): number {
    const raw =
      attacker.attack *
      this.elementMultiplier(attacker.card.element, defender.card.element) *
      (1 + attacker.rallyValue / 100);
    let damage = Math.max(1, dartRound(raw - defender.defense * state.config.defenseMitigation));
    if (defender.stance === 'guarding') {
      damage = Math.max(1, dartRound(damage * state.config.guardDamageMultiplier));
    }
    return damage;
  }

  estimateFaceDamage(_state: BattleState, attacker: BattleUnit): number {
    const raw = attacker.attack * 0.5 * (1 + attacker.rallyValue / 100);
    return Math.max(1, dartRound(raw));
  }

  estimateCounterDamage(state: BattleState, defender: BattleUnit, attacker: BattleUnit): number {
    const raw =
      defender.attack *
      state.config.guardCounterRatio *
      this.elementMultiplier(defender.card.element, attacker.card.element);
    return Math.max(1, dartRound(raw));
  }

  estimateAbilityDamage(_state: BattleState, source: CardElement, power: number, target: BattleUnit): number {
    const raw = power * this.elementMultiplier(source, target.card.element);
    return Math.max(1, dartRound(raw - target.defense * 0.3));
  }

  start(input: { playerDeck: readonly Card[]; botDeck: readonly Card[]; seed: number; config?: BattleConfig }): BattleState {
    const config = input.config ?? DEFAULT_BATTLE_CONFIG;
    if (input.playerDeck.length === 0 || input.botDeck.length === 0) {
      throw new IllegalActionError('Deck tidak boleh kosong');
    }

    const rng = new DartRandom(input.seed);
    const shuffledPlayer = dartShuffle([...input.playerDeck], rng);
    const shuffledBot = dartShuffle([...input.botDeck], rng);
    const firstSide: BattleSide = rng.nextBool() ? 'player' : 'bot';

    const makeSide = (label: string, deck: Card[]): BattlePlayerState =>
      new BattlePlayerState({
        label,
        hp: config.playerHp,
        maxHp: config.playerHp,
        maxEnergy: 0,
        energy: 0,
        board: [],
        hand: [],
        deck,
        discard: [],
      });

    const state = new BattleState({
      config,
      seed: input.seed,
      firstSide,
      activeSide: firstSide,
      turnNumber: 0,
      phase: 'upkeep',
      player: makeSide('player', shuffledPlayer),
      bot: makeSide('bot', shuffledBot),
      log: [],
      nextInstanceId: 1,
    });

    this.drawInitial(state, 'player', config.startingHand);
    this.drawInitial(state, 'bot', config.startingHand);
    this.beginTurn(state, firstSide);
    return state;
  }

  private drawInitial(state: BattleState, side: BattleSide, count: number): void {
    const player = state.sideState(side);
    for (let i = 0; i < count; i += 1) {
      const card = player.deck.shift();
      if (!card) return;
      player.hand.push(card);
    }
    this.log(state, 'opening_hand', `${player.label} menarik ${count} kartu awal`, side, { count });
  }

  legalActions(state: BattleState, side: BattleSide): BattleAction[] {
    if (state.phase !== 'action' || state.outcome !== null || state.activeSide !== side) {
      return [];
    }

    const me = state.sideState(side);
    const enemy = state.opponentState(side);
    const actions: BattleAction[] = [];

    me.hand.forEach((card, index) => {
      if (card.cost > me.energy) return;

      if (isUnit(card)) {
        if (me.board.length >= state.config.boardSlots) return;
        actions.push({ kind: 'play', handIndex: index });
        return;
      }

      const ability = card.ability;
      if (!ability) return;

      if (this.requiresUnitTarget(ability)) {
        const targets = this.targetIds(state, side, ability, null);
        for (const target of targets) {
          actions.push({ kind: 'play', handIndex: index, targetId: target });
        }
      } else {
        actions.push({ kind: 'play', handIndex: index });
      }
    });

    for (const unit of me.board) {
      if (unit.hasActed || unit.isFrozen) continue;

      const ability = unit.card.ability;
      if (ability && ability.cost <= me.energy) {
        if (this.requiresUnitTarget(ability)) {
          for (const target of this.targetIds(state, side, ability, unit)) {
            actions.push({ kind: 'ability', unitId: unit.instanceId, targetId: target });
          }
        } else {
          actions.push({ kind: 'ability', unitId: unit.instanceId });
        }
      }

      if (this.canAttack(unit)) {
        if (enemy.board.length === 0) {
          actions.push({ kind: 'attack', attackerId: unit.instanceId });
        } else {
          for (const target of enemy.board) {
            actions.push({ kind: 'attack', attackerId: unit.instanceId, targetId: target.instanceId });
          }
        }
      }

      actions.push({ kind: 'guard', unitId: unit.instanceId });
    }

    actions.push({ kind: 'end' });
    return actions;
  }

  private canAttack(unit: BattleUnit): boolean {
    if (unit.hasActed || unit.isFrozen) return false;
    if (unit.summonedThisTurn && !hasKeyword(unit.card, 'charge')) return false;
    return true;
  }

  private requiresUnitTarget(ability: CardAbility): boolean {
    return ability.target === 'enemy_unit' || ability.target === 'any_unit' || ability.target === 'self';
  }

  private targetIds(state: BattleState, side: BattleSide, ability: CardAbility, caster: BattleUnit | null): Array<string | null> {
    const me = state.sideState(side);
    const enemy = state.opponentState(side);
    switch (ability.target) {
      case 'enemy_unit':
        return enemy.board.map((unit) => unit.instanceId);
      case 'any_unit':
        return [...me.board.map((unit) => unit.instanceId), ...enemy.board.map((unit) => unit.instanceId)];
      case 'self':
        if (caster) return [null];
        return me.board.map((unit) => unit.instanceId);
      default:
        return [null];
    }
  }

  apply(state: BattleState, action: BattleAction): BattleState {
    if (state.phase === 'ended' || state.outcome !== null) {
      throw new IllegalActionError('Pertandingan sudah selesai');
    }

    const next = state.copy();

    if (action.kind === 'concede') {
      this.concede(next);
      return next;
    }
    if (action.kind === 'end') {
      this.endTurn(next);
      return next;
    }
    if (next.phase !== 'action') {
      throw new IllegalActionError('Belum fase aksi');
    }

    switch (action.kind) {
      case 'play':
        this.playCard(next, action);
        break;
      case 'ability':
        this.useAbility(next, action);
        break;
      case 'attack':
        this.attack(next, action);
        break;
      case 'guard':
        this.setGuard(next, action);
        break;
      default:
        throw new IllegalActionError('Aksi tidak dikenal');
    }
    return next;
  }

  private playCard(state: BattleState, action: PlayCardAction): void {
    const side = state.activeSide;
    const me = state.sideState(side);
    if (!Number.isInteger(action.handIndex) || action.handIndex < 0 || action.handIndex >= me.hand.length) {
      throw new IllegalActionError('Kartu di tangan tidak ditemukan');
    }

    const card = me.hand[action.handIndex] as Card;
    if (card.cost > me.energy) {
      throw new IllegalActionError('Energi tidak cukup');
    }

    if (isUnit(card)) {
      if (me.board.length >= state.config.boardSlots) {
        throw new IllegalActionError('Slot board penuh');
      }
      if (action.slot != null && action.slot !== me.board.length) {
        throw new IllegalActionError('Slot tidak tersedia');
      }

      const unit = BattleUnit.fromCard(card, `u${state.nextInstanceId++}`);
      me.board.push(unit);
      me.energy -= card.cost;
      me.hand.splice(action.handIndex, 1);
      this.log(state, 'summon', `${me.label} memainkan ${card.name}`, side, {
        cardId: card.id,
        instanceId: unit.instanceId,
      });
      return;
    }

    const ability = card.ability;
    if (!ability) {
      throw new IllegalActionError('Spell tanpa ability');
    }

    this.resolveAbility(state, side, null, card, ability, action.targetId ?? null);

    me.energy -= card.cost;
    me.hand.splice(action.handIndex, 1);
    me.discard.push(card);
    this.log(state, 'spell', `${me.label} memainkan spell ${card.name}`, side, { cardId: card.id });

    this.removeDeadUnits(state, opponentOf(side));
    this.removeDeadUnits(state, side);
    this.evaluateOutcome(state);
  }

  private useAbility(state: BattleState, action: UseAbilityAction): void {
    const side = state.activeSide;
    const me = state.sideState(side);
    const unit = this.findUnit(me.board, action.unitId);
    if (!unit) throw new IllegalActionError('Unit tidak ada di board');
    if (unit.hasActed) throw new IllegalActionError('Unit sudah melakukan aksi');
    if (unit.isFrozen) throw new IllegalActionError('Unit sedang freeze');

    const ability = unit.card.ability;
    if (!ability) throw new IllegalActionError('Unit tidak punya ability');
    if (ability.cost > me.energy) throw new IllegalActionError('Energi tidak cukup');

    this.resolveAbility(state, side, unit, unit.card, ability, action.targetId ?? null);

    me.energy -= ability.cost;
    unit.hasActed = true;
    unit.stance = 'tapped';

    this.log(state, 'ability', `${unit.card.name} memakai ${ability.name}`, side, { unitId: unit.instanceId });

    this.removeDeadUnits(state, opponentOf(side));
    this.removeDeadUnits(state, side);
    this.evaluateOutcome(state);
  }

  private attack(state: BattleState, action: AttackAction): void {
    const side = state.activeSide;
    const me = state.sideState(side);
    const enemy = state.opponentState(side);

    const attacker = this.findUnit(me.board, action.attackerId);
    if (!attacker) throw new IllegalActionError('Penyerang tidak ditemukan');
    if (attacker.hasActed) throw new IllegalActionError('Unit sudah melakukan aksi');
    if (attacker.isFrozen) throw new IllegalActionError('Unit sedang freeze');
    if (attacker.summonedThisTurn && !hasKeyword(attacker.card, 'charge')) {
      throw new IllegalActionError('Unit baru tidak bisa menyerang');
    }

    if (action.targetId == null) {
      if (enemy.board.length > 0) {
        throw new IllegalActionError('Tidak bisa menyerang player saat masih ada unit');
      }
      const damage = this.estimateFaceDamage(state, attacker);
      enemy.hp -= damage;
      attacker.hasActed = true;
      attacker.stance = 'tapped';
      this.log(state, 'face_attack', `${attacker.card.name} menyerang langsung ${damage} damage`, side, {
        unitId: attacker.instanceId,
        damage,
      });
      this.evaluateOutcome(state);
      return;
    }

    const target = this.findUnit(enemy.board, action.targetId);
    if (!target) throw new IllegalActionError('Target tidak ditemukan');

    const hpBefore = target.hp;
    const rawDamage = this.estimateAttackDamage(state, attacker, target);
    const dealt = this.damageUnit(target, rawDamage);

    this.log(state, 'attack', `${attacker.card.name} menyerang ${target.card.name} (${dealt})`, side, {
      attackerId: attacker.instanceId,
      targetId: target.instanceId,
      damage: dealt,
    });

    if (hasKeyword(attacker.card, 'lifesteal') && dealt > 0) {
      const healed = Math.min(dealt, attacker.maxHp - attacker.hp);
      if (healed > 0) attacker.hp += healed;
    }

    if (target.isDead) {
      const overflow = Math.max(0, dealt - hpBefore);
      removeItem(enemy.board, target);
      enemy.discard.push(target.card);
      this.log(state, 'unit_died', `${target.card.name} gugur`, opponentOf(side), { unitId: target.instanceId });
      if (hasKeyword(attacker.card, 'pierce') && overflow > 0) {
        enemy.hp -= overflow;
        this.log(state, 'pierce', `Pierce meneruskan ${overflow} damage ke player`, side, { damage: overflow });
      }
    } else if (target.stance === 'guarding') {
      const counter = this.estimateCounterDamage(state, target, attacker);
      this.damageUnit(attacker, counter);
      this.log(state, 'counter', `${target.card.name} melakukan counter ${counter} damage`, opponentOf(side), {
        unitId: target.instanceId,
        damage: counter,
      });
      if (attacker.isDead) {
        removeItem(me.board, attacker);
        me.discard.push(attacker.card);
        this.log(state, 'unit_died', `${attacker.card.name} gugur karena counter`, side, {
          unitId: attacker.instanceId,
        });
      }
    }

    if (!attacker.isDead) {
      attacker.hasActed = true;
      attacker.stance = 'tapped';
    }

    this.evaluateOutcome(state);
  }

  private setGuard(state: BattleState, action: SetGuardAction): void {
    const side = state.activeSide;
    const me = state.sideState(side);
    const unit = this.findUnit(me.board, action.unitId);
    if (!unit) throw new IllegalActionError('Unit tidak ditemukan');
    if (unit.hasActed) throw new IllegalActionError('Unit sudah melakukan aksi');
    if (unit.isFrozen) throw new IllegalActionError('Unit sedang freeze');

    unit.stance = 'guarding';
    unit.hasActed = true;
    this.log(state, 'guard', `${unit.card.name} memasang Guard`, side, { unitId: unit.instanceId });
  }

  private resolveAbility(
    state: BattleState,
    side: BattleSide,
    caster: BattleUnit | null,
    source: Card,
    ability: CardAbility,
    targetId: string | null,
  ): void {
    const enemy = state.opponentState(side);
    const targets = this.resolveTargets(state, side, ability, caster, targetId);

    switch (ability.type) {
      case 'attack':
        if (ability.target === 'enemy_player') {
          enemy.hp -= ability.power;
          // Pesan meniru interpolasi Dart `$ability.power` apa adanya agar logHash
          // tetap sama dengan mobile (lihat docs/OPEN_QUESTIONS.md).
          this.log(state, 'ability_damage', `${source.name} menembak player Instance of 'CardAbility'.power damage`, side, {
            damage: ability.power,
          });
          break;
        }
        for (const target of targets) {
          const damage = this.estimateAbilityDamage(state, source.element, ability.power, target);
          const dealt = this.damageUnit(target, damage);
          this.log(state, 'ability_damage', `${source.name} menimpa ${target.card.name} (${dealt})`, side, {
            targetId: target.instanceId,
            damage: dealt,
          });
        }
        break;
      case 'heal':
        for (const target of targets) {
          const before = target.hp;
          target.hp = Math.min(target.maxHp, target.hp + ability.power);
          this.log(state, 'heal', `${target.card.name} pulih ${target.hp - before} HP`, side, {
            targetId: target.instanceId,
            amount: target.hp - before,
          });
        }
        break;
      case 'buff':
        for (const target of targets) {
          target.applyStatus('rally', ability.status?.value ?? ability.power, ability.status?.turns ?? 1);
        }
        break;
      case 'control': {
        const kind = statusKindOf(ability.status?.kind);
        for (const target of targets) {
          target.applyStatus(kind, ability.status?.value ?? ability.power, ability.status?.turns ?? 2);
        }
        break;
      }
      case 'shield':
        for (const target of targets) {
          target.applyStatus('shield', ability.status?.value ?? ability.power, ability.status?.turns ?? 2);
        }
        break;
      default:
        break;
    }

    const extra = ability.status;
    if (extra && ability.type !== 'control' && ability.type !== 'shield' && ability.type !== 'buff') {
      const kind = statusKindOf(extra.kind);
      for (const target of targets) {
        if (!target.isDead) target.applyStatus(kind, extra.value, extra.turns);
      }
    }
  }

  private resolveTargets(
    state: BattleState,
    side: BattleSide,
    ability: CardAbility,
    caster: BattleUnit | null,
    targetId: string | null,
  ): BattleUnit[] {
    const me = state.sideState(side);
    const enemy = state.opponentState(side);

    switch (ability.target) {
      case 'all_enemy_units':
        return [...enemy.board];
      case 'all_allies':
        return [...me.board];
      case 'enemy_player':
        return [];
      case 'self': {
        if (caster) return [caster];
        const own = this.findUnit(me.board, targetId);
        if (!own) throw new IllegalActionError('Target self tidak valid');
        return [own];
      }
      case 'enemy_unit': {
        const target = this.findUnit(enemy.board, targetId);
        if (!target) throw new IllegalActionError('Target musuh tidak valid');
        return [target];
      }
      case 'any_unit': {
        const target = this.findUnit(me.board, targetId) ?? this.findUnit(enemy.board, targetId);
        if (!target) throw new IllegalActionError('Target unit tidak valid');
        return [target];
      }
      default:
        throw new IllegalActionError('Target ability tidak dikenal');
    }
  }

  private damageUnit(unit: BattleUnit, amount: number): number {
    let remaining = amount;
    const shield = unit.statusOf('shield');
    if (shield && shield.value > 0) {
      const absorbed = Math.min(shield.value, remaining);
      shield.value -= absorbed;
      remaining -= absorbed;
      if (shield.value <= 0) unit.removeStatus('shield');
    }
    if (remaining > 0) unit.hp -= remaining;
    return remaining;
  }

  private removeDeadUnits(state: BattleState, side: BattleSide): void {
    const player = state.sideState(side);
    const dead = player.board.filter((unit) => unit.isDead);
    for (const unit of dead) {
      removeItem(player.board, unit);
      player.discard.push(unit.card);
      this.log(state, 'unit_died', `${unit.card.name} gugur`, side, { unitId: unit.instanceId });
    }
  }

  private endTurn(state: BattleState): void {
    const side = state.activeSide;
    const me = state.sideState(side);

    for (const unit of me.board) {
      unit.removeStatus('rally');
      const freeze = unit.statusOf('freeze');
      if (freeze) {
        freeze.turns -= 1;
        if (freeze.turns <= 0) unit.removeStatus('freeze');
      }
    }

    if (this.evaluateOutcome(state)) return;

    this.log(state, 'end_turn', `${me.label} mengakhiri giliran`, side, {});

    state.activeSide = opponentOf(side);
    this.beginTurn(state, state.activeSide);
  }

  private beginTurn(state: BattleState, side: BattleSide): void {
    const player = state.sideState(side);

    if (side === state.firstSide) {
      state.turnNumber += 1;
      if (state.turnNumber > state.config.maxTurns) {
        this.finish(state, 'draw');
        return;
      }
    }

    const isFirstTurn = player.maxEnergy === 0;
    player.maxEnergy = isFirstTurn
      ? state.config.startingEnergy
      : Math.min(player.maxEnergy + 1, state.config.maxEnergy);
    player.energy = player.maxEnergy;

    for (const unit of player.board) {
      unit.hasActed = false;
      unit.summonedThisTurn = false;
      unit.stance = 'ready';
    }

    for (const unit of [...player.board]) {
      const burn = unit.statusOf('burn');
      if (burn && burn.turns > 0 && burn.value > 0) {
        unit.hp -= burn.value;
        this.log(state, 'burn', `${unit.card.name} terkena Burn ${burn.value}`, side, {
          unitId: unit.instanceId,
          damage: burn.value,
        });
        burn.turns -= 1;
        if (burn.turns <= 0) unit.removeStatus('burn');
      }

      const shield = unit.statusOf('shield');
      if (shield) {
        shield.turns -= 1;
        if (shield.turns <= 0) unit.removeStatus('shield');
      }
    }

    this.removeDeadUnits(state, side);
    if (this.evaluateOutcome(state)) return;

    const isVeryFirstTurn = side === state.firstSide && state.turnNumber === 1;
    if (!isVeryFirstTurn) {
      this.drawOne(state, side);
      if (this.evaluateOutcome(state)) return;
    }

    state.phase = 'action';
    this.log(state, 'begin_turn', `${player.label} memulai giliran (energi ${player.energy})`, side, {
      energy: player.energy,
      turn: state.turnNumber,
    });
  }

  private drawOne(state: BattleState, side: BattleSide): void {
    const player = state.sideState(side);

    const card = player.deck.shift();
    if (!card) {
      player.fatigueCounter += 1;
      const damage = state.config.fatigueBase + (player.fatigueCounter - 1) * state.config.fatigueStep;
      player.hp -= damage;
      this.log(state, 'fatigue', `Deck habis: fatigue ${damage} damage`, side, { damage });
      return;
    }

    if (player.hand.length >= state.config.handLimit) {
      player.discard.push(card);
      this.log(state, 'hand_burn', `Tangan penuh: ${card.name} di-burn`, side, { cardId: card.id });
      return;
    }

    player.hand.push(card);
    this.log(state, 'draw', `${player.label} menarik ${card.name}`, side, { cardId: card.id });
  }

  private concede(state: BattleState): void {
    this.log(state, 'concede', `${state.sideState(state.activeSide).label} menyerah`, state.activeSide, {});
    this.finish(state, 'loss');
  }

  private evaluateOutcome(state: BattleState): boolean {
    if (state.outcome !== null) return true;

    const playerDead = state.player.hp <= 0;
    const botDead = state.bot.hp <= 0;
    if (!playerDead && !botDead) return false;

    const outcome: BattleOutcome = playerDead && botDead ? 'draw' : botDead ? 'win' : 'loss';
    this.finish(state, outcome);
    return true;
  }

  private finish(state: BattleState, outcome: BattleOutcome): void {
    state.outcome = outcome;
    state.phase = 'ended';
    this.log(state, 'battle_end', `Pertandingan selesai: ${outcome}`, null, {
      outcome,
      playerHp: state.player.hp,
      botHp: state.bot.hp,
      turn: state.turnNumber,
    });
  }

  isTerminal(state: BattleState): boolean {
    return state.outcome !== null;
  }

  private findUnit(board: readonly BattleUnit[], id: string | null | undefined): BattleUnit | null {
    if (id == null) return null;
    return board.find((unit) => unit.instanceId === id) ?? null;
  }

  private log(
    state: BattleState,
    type: string,
    message: string,
    side: BattleSide | null,
    data: Record<string, unknown>,
  ): void {
    state.log.push({ type, turn: state.turnNumber, message, side, data });
  }
}

function statusKindOf(raw: string | undefined): BattleStatusKind {
  switch (raw) {
    case 'freeze':
      return 'freeze';
    case 'shield':
      return 'shield';
    case 'rally':
      return 'rally';
    default:
      return 'burn';
  }
}

function removeItem<T>(list: T[], item: T): void {
  const index = list.indexOf(item);
  if (index >= 0) list.splice(index, 1);
}

export const battleEngine = new BattleEngine();

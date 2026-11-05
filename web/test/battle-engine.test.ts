/** Port `frontend/test/battle_engine_test.dart` — edge case E-01..E-14 (TECH_SPEC §9). */
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { battleEngine as engine } from '../src/lib/battle/engine.ts';
import {
  BattlePlayerState,
  BattleState,
  BattleUnit,
  CONCEDE,
  DEFAULT_BATTLE_CONFIG,
  END_TURN,
  IllegalActionError,
  type BattleConfig,
  type BattleSide,
  type Stance,
} from '../src/lib/battle/models.ts';
import type { Card, CardElement } from '../src/lib/domain/card.ts';
import { makeCard } from './support/fixtures.ts';

const unit = (id: string, o: { element?: CardElement; attack?: number; hp?: number; defense?: number; cost?: number; keywords?: string[] } = {}): Card =>
  makeCard({ id, name: id, element: o.element ?? 'Fire', attack: o.attack ?? 5, hp: o.hp ?? 5, defense: o.defense ?? 0, cost: o.cost ?? 1, keywords: o.keywords ?? [] });

const testDeck = (count = 20, element: CardElement = 'Fire'): Card[] =>
  Array.from({ length: count }, (_, i) => unit(`deck_${element}_${i}`, { element, attack: 3 + (i % 4), hp: 8 + (i % 5) }));

function boardUnit(card: Card, id: string, o: { summonedThisTurn?: boolean; stance?: Stance; hasActed?: boolean; hp?: number } = {}): BattleUnit {
  const u = BattleUnit.fromCard(card, id);
  u.summonedThisTurn = o.summonedThisTurn ?? false;
  u.stance = o.stance ?? 'ready';
  u.hasActed = o.hasActed ?? false;
  if (o.hp !== undefined) u.hp = o.hp;
  return u;
}

function makeState(o: {
  playerBoard?: BattleUnit[];
  botBoard?: BattleUnit[];
  playerHand?: Card[];
  playerDeck?: Card[];
  playerEnergy?: number;
  botHp?: number;
  activeSide?: BattleSide;
  firstSide?: BattleSide;
  turnNumber?: number;
  config?: BattleConfig;
} = {}): BattleState {
  const side = (label: string, board: BattleUnit[], hand: Card[], deck: Card[], energy: number, hp: number) =>
    new BattlePlayerState({ label, hp, maxHp: 200, maxEnergy: 10, energy, board: [...board], hand: [...hand], deck: [...deck], discard: [] });
  return new BattleState({
    config: o.config ?? DEFAULT_BATTLE_CONFIG,
    seed: 7,
    firstSide: o.firstSide ?? 'player',
    activeSide: o.activeSide ?? 'player',
    turnNumber: o.turnNumber ?? 1,
    phase: 'action',
    player: side('player', o.playerBoard ?? [], o.playerHand ?? [], o.playerDeck ?? [], o.playerEnergy ?? 10, 200),
    bot: side('bot', o.botBoard ?? [], [], [], 10, o.botHp ?? 200),
    log: [],
    nextInstanceId: 100,
  });
}

const isIllegal = (error: unknown): boolean => error instanceof IllegalActionError;

describe('BattleEngine.start', () => {
  test('deterministik untuk seed yang sama (I-04)', () => {
    const player = testDeck();
    const bot = testDeck(20, 'Water');
    const a = engine.start({ playerDeck: player, botDeck: bot, seed: 4242 });
    const b = engine.start({ playerDeck: player, botDeck: bot, seed: 4242 });
    assert.equal(a.logHash(), b.logHash());
    assert.deepEqual(a.player.hand.map((c) => c.id), b.player.hand.map((c) => c.id));
    assert.equal(a.activeSide, b.activeSide);
    assert.deepEqual(a.player.deck.map((c) => c.id), b.player.deck.map((c) => c.id));
  });

  test('menolak deck kosong', () => {
    assert.throws(() => engine.start({ playerDeck: [], botDeck: testDeck(), seed: 1 }), isIllegal);
  });

  test('logHash berubah setelah aksi', () => {
    const state = makeState({
      playerBoard: [boardUnit(unit('atk', { attack: 3 }), 'u1')],
      botBoard: [boardUnit(unit('def', { hp: 20 }), 'u2')],
    });
    const next = engine.apply(state, { kind: 'attack', attackerId: 'u1', targetId: 'u2' });
    assert.notEqual(next.logHash(), state.logHash());
  });

  test('apply tidak memutasi state sebelumnya (immutabilitas)', () => {
    const state = makeState({
      playerBoard: [boardUnit(unit('atk', { attack: 10 }), 'u1')],
      botBoard: [boardUnit(unit('def', { hp: 50 }), 'u2')],
    });
    const before = state.canonicalString();
    engine.apply(state, { kind: 'attack', attackerId: 'u1', targetId: 'u2' });
    assert.equal(state.canonicalString(), before);
  });
});

describe('Element & damage', () => {
  test('siklus elemen: api > udara, air > api, void netral', () => {
    assert.equal(engine.elementMultiplier('Fire', 'Air'), 1.25);
    assert.equal(engine.elementMultiplier('Air', 'Fire'), 0.8);
    assert.equal(engine.elementMultiplier('Void', 'Fire'), 1.0);
    assert.equal(engine.elementMultiplier('Fire', 'Void'), 1.0);
  });

  test('guard memotong damage 50%', () => {
    const attacker = boardUnit(unit('atk', { attack: 10, element: 'Fire' }), 'u1');
    const normal = boardUnit(unit('def', { hp: 50, defense: 2, element: 'Air' }), 'u2');
    const guarded = boardUnit(unit('def2', { hp: 50, defense: 2, element: 'Air' }), 'u3', { stance: 'guarding' });
    const state = makeState();
    assert.equal(engine.estimateAttackDamage(state, attacker, normal), 12);
    assert.equal(engine.estimateAttackDamage(state, attacker, guarded), 6);
  });

  test('counter guard memakai 30% ATK dan elemen', () => {
    const defender = boardUnit(unit('def', { attack: 10, element: 'Fire' }), 'u2');
    const attacker = boardUnit(unit('atk', { attack: 10, element: 'Water' }), 'u1');
    assert.equal(engine.estimateCounterDamage(makeState(), defender, attacker), 2);
  });
});

describe('Aksi unit', () => {
  test('serangan unit mengurangi HP target dan menandai hasActed', () => {
    const state = makeState({
      playerBoard: [boardUnit(unit('atk', { attack: 10, element: 'Fire' }), 'u1')],
      botBoard: [boardUnit(unit('def', { hp: 100, element: 'Air' }), 'u2')],
    });
    const next = engine.apply(state, { kind: 'attack', attackerId: 'u1', targetId: 'u2' });
    assert.equal(next.bot.board[0]?.hp, 87);
    assert.equal(next.player.board[0]?.hasActed, true);
    assert.equal(next.activeSide, 'player');
  });

  test('guard menahan damage dan memantulkan counter', () => {
    const state = makeState({
      playerBoard: [boardUnit(unit('atk', { attack: 10, element: 'Fire', hp: 12 }), 'u1')],
      botBoard: [boardUnit(unit('def', { attack: 10, hp: 50, defense: 2, element: 'Air' }), 'u2', { stance: 'guarding' })],
    });
    const next = engine.apply(state, { kind: 'attack', attackerId: 'u1', targetId: 'u2' });
    assert.equal(next.bot.board[0]?.hp, 44);
    assert.equal(next.player.board[0]?.hp, 10);
  });

  test('pierce meneruskan overflow damage ke player', () => {
    const state = makeState({
      playerBoard: [boardUnit(unit('atk', { attack: 10, element: 'Fire', keywords: ['pierce'] }), 'u1')],
      botBoard: [boardUnit(unit('def', { hp: 2, element: 'Air' }), 'u2')],
    });
    const next = engine.apply(state, { kind: 'attack', attackerId: 'u1', targetId: 'u2' });
    assert.equal(next.bot.board.length, 0);
    assert.equal(next.bot.hp, 189);
    assert.ok(next.log.some((e) => e.type === 'pierce'));
  });

  test('lifesteal memulihkan HP penyerang', () => {
    const state = makeState({
      playerBoard: [boardUnit(unit('atk', { attack: 5, hp: 5, element: 'Fire', keywords: ['lifesteal'] }), 'u1', { hp: 3 })],
      botBoard: [boardUnit(unit('def', { hp: 20, element: 'Water' }), 'u2')],
    });
    const next = engine.apply(state, { kind: 'attack', attackerId: 'u1', targetId: 'u2' });
    assert.equal(next.player.board[0]?.hp, 5);
    assert.equal(next.bot.board[0]?.hp, 16);
  });

  test('shield menyerap damage lebih dulu', () => {
    const defender = boardUnit(unit('def', { hp: 10, element: 'Fire' }), 'p1');
    defender.applyStatus('shield', 5, 2);
    const state = makeState({
      playerBoard: [defender],
      botBoard: [boardUnit(unit('atk', { attack: 5, element: 'Water' }), 'b1')],
      activeSide: 'bot',
      firstSide: 'bot',
    });
    const next = engine.apply(state, { kind: 'attack', attackerId: 'b1', targetId: 'p1' });
    assert.equal(next.player.board[0]?.hp, 9);
    assert.equal(next.player.board[0]?.statusOf('shield'), null);
  });

  test('unit baru tanpa charge tidak bisa menyerang', () => {
    const charging = unit('charge', { cost: 1, attack: 3, keywords: ['charge'] });
    const normal = unit('normal', { cost: 1, attack: 3 });
    const state = makeState({ playerHand: [charging, normal], playerDeck: testDeck(5) });

    const afterCharge = engine.apply(state, { kind: 'play', handIndex: 0 });
    const chargeUnit = afterCharge.player.board[0]!;
    assert.ok(
      engine.legalActions(afterCharge, 'player').some((a) => a.kind === 'attack' && a.attackerId === chargeUnit.instanceId),
    );

    const afterNormal = engine.apply(state, { kind: 'play', handIndex: 1 });
    const normalUnit = afterNormal.player.board[0]!;
    assert.ok(
      !engine.legalActions(afterNormal, 'player').some((a) => a.kind === 'attack' && a.attackerId === normalUnit.instanceId),
    );
    assert.throws(() => engine.apply(afterNormal, { kind: 'attack', attackerId: normalUnit.instanceId }), isIllegal);
  });

  test('freeze memblokir aksi unit', () => {
    const frozen = boardUnit(unit('frozen', { attack: 5 }), 'u1');
    frozen.applyStatus('freeze', 1, 2);
    const state = makeState({ playerBoard: [frozen] });
    const actions = engine.legalActions(state, 'player');
    assert.ok(!actions.some((a) => a.kind === 'attack' || a.kind === 'ability' || a.kind === 'guard'));
    assert.throws(() => engine.apply(state, { kind: 'attack', attackerId: 'u1' }), isIllegal);
  });

  test('board penuh menolak summon', () => {
    const state = makeState({
      playerBoard: [boardUnit(unit('a'), 'u1'), boardUnit(unit('b'), 'u2'), boardUnit(unit('c'), 'u3')],
      playerHand: [unit('extra')],
    });
    assert.throws(() => engine.apply(state, { kind: 'play', handIndex: 0 }), isIllegal);
    assert.ok(!engine.legalActions(state, 'player').some((a) => a.kind === 'play'));
  });

  test('energi tidak cukup ditolak', () => {
    const state = makeState({ playerHand: [unit('expensive', { cost: 5 })], playerEnergy: 1 });
    assert.throws(() => engine.apply(state, { kind: 'play', handIndex: 0 }), isIllegal);
  });

  test('menyerang player saat lawan masih punya unit ditolak', () => {
    const state = makeState({
      playerBoard: [boardUnit(unit('atk', { attack: 10 }), 'u1')],
      botBoard: [boardUnit(unit('def', { hp: 20 }), 'u2')],
    });
    assert.throws(() => engine.apply(state, { kind: 'attack', attackerId: 'u1' }), isIllegal);
  });
});

describe('Status & giliran', () => {
  test('burn mengurangi HP saat begin turn', () => {
    const burning = boardUnit(unit('burn', { hp: 10 }), 'u1');
    burning.applyStatus('burn', 3, 2);
    const state = makeState({ playerBoard: [burning], playerDeck: testDeck(6), activeSide: 'bot', firstSide: 'bot' });
    const next = engine.apply(state, END_TURN);
    assert.equal(next.player.board[0]?.hp, 7);
    assert.equal(next.player.board[0]?.statusOf('burn')?.turns, 1);
    assert.ok(next.log.some((e) => e.type === 'burn'));
  });

  test('deck habis memicu fatigue', () => {
    const state = makeState({ playerDeck: [], activeSide: 'bot', firstSide: 'player', turnNumber: 2 });
    const next = engine.apply(state, END_TURN);
    assert.equal(next.player.hp, 180);
    assert.equal(next.player.fatigueCounter, 1);
    assert.ok(next.log.some((e) => e.type === 'fatigue'));
  });

  test('tangan penuh membakar kartu yang ditarik', () => {
    const hand = Array.from({ length: 8 }, (_, i) => unit(`hand_${i}`));
    const state = makeState({ playerHand: hand, playerDeck: testDeck(5), activeSide: 'bot', firstSide: 'bot' });
    const next = engine.apply(state, END_TURN);
    assert.equal(next.player.hand.length, 8);
    assert.equal(next.player.discard.length, 1);
    assert.ok(next.log.some((e) => e.type === 'hand_burn'));
  });

  test('melewati maxTurns menghasilkan draw', () => {
    const state = makeState({
      config: { ...DEFAULT_BATTLE_CONFIG, maxTurns: 2 },
      playerDeck: testDeck(5),
      activeSide: 'bot',
      firstSide: 'player',
      turnNumber: 2,
    });
    const next = engine.apply(state, END_TURN);
    assert.equal(next.outcome, 'draw');
    assert.equal(next.phase, 'ended');
  });

  test('energi naik +1 per giliran dan dibatasi maxEnergy', () => {
    const state = makeState({ playerDeck: testDeck(5), activeSide: 'bot', firstSide: 'player', turnNumber: 1 });
    state.player.maxEnergy = 10;
    const next = engine.apply(state, END_TURN);
    assert.equal(next.player.maxEnergy, 10);
    assert.equal(next.player.energy, 10);
  });
});

describe('Hasil pertandingan', () => {
  test('serangan langsung mematikan bot menghasilkan win', () => {
    const state = makeState({ playerBoard: [boardUnit(unit('atk', { attack: 20 }), 'u1')], botHp: 5 });
    const next = engine.apply(state, { kind: 'attack', attackerId: 'u1' });
    assert.equal(next.outcome, 'win');
    assert.ok(next.bot.hp <= 0);
  });

  test('concede menghasilkan loss', () => {
    const next = engine.apply(makeState({ playerDeck: testDeck(5) }), CONCEDE);
    assert.equal(next.outcome, 'loss');
    assert.equal(next.phase, 'ended');
  });

  test('aksi setelah selesai ditolak', () => {
    const ended = engine.apply(makeState({ playerDeck: testDeck(5) }), CONCEDE);
    assert.throws(() => engine.apply(ended, END_TURN), isIllegal);
  });
});

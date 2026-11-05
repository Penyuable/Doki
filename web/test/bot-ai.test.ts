/** Port `frontend/test/bot_ai_test.dart`: legalitas 3 level, determinisme, p95 < 300 ms (TECH_SPEC §10). */
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { performance } from 'node:perf_hooks';
import { battleEngine as engine } from '../src/lib/battle/engine.ts';
import { BotAI, botSeedFor, difficultyFrom } from '../src/lib/battle/bot-ai.ts';
import { DEFAULT_BATTLE_CONFIG, END_TURN, actionSignature, type BattleState } from '../src/lib/battle/models.ts';
import { DIFFICULTIES } from '../src/lib/config/game-config.ts';
import { ELEMENTS, type Card } from '../src/lib/domain/card.ts';
import { DartRandom } from '../src/lib/core/dart-random.ts';
import { makeCard } from './support/fixtures.ts';

const config = { ...DEFAULT_BATTLE_CONFIG, playerHp: 40, maxTurns: 20, startingHand: 4 };

function variedDeck(prefix: string): Card[] {
  return Array.from({ length: 20 }, (_, i) =>
    makeCard({
      id: `${prefix}_${i}`,
      name: `${prefix}_${i}`,
      element: ELEMENTS[i % ELEMENTS.length]!,
      cost: i % 4,
      attack: 2 + (i % 5),
      hp: 4 + (i % 4),
      keywords: i % 3 === 0 ? ['charge'] : [],
      ability:
        i % 2 === 0
          ? { name: 'Zap', type: 'attack', cost: 1, target: 'enemy_unit', power: 2 + (i % 3), text: '', status: null }
          : null,
    }),
  );
}

describe('BotAI legalitas', () => {
  for (const difficulty of DIFFICULTIES) {
    test(`${difficulty} selalu memilih aksi legal dan menyelesaikan match`, () => {
      let state: BattleState = engine.start({
        playerDeck: variedDeck('player'),
        botDeck: variedDeck('bot'),
        seed: 2026,
        config,
      });
      let steps = 0;
      while (!state.isTerminal && steps < 1200) {
        const side = state.activeSide;
        const legal = engine.legalActions(state, side);
        assert.ok(legal.length > 0);
        const action = new BotAI({ difficulty, seed: steps * 31 + 7 }).decide(state, side);
        assert.ok(legal.map(actionSignature).includes(actionSignature(action)), `langkah ${steps} ilegal`);
        assert.notEqual(action.kind, 'concede');
        state = engine.apply(state, action);
        steps += 1;
      }
      assert.ok(steps < 1200);
      assert.ok(state.isTerminal);
      assert.notEqual(state.outcome, null);
    });
  }

  // Easy/Medium hanya menilai aksi sendiri. Master (sama dengan versi Dart) mensimulasikan
  // giliran lawan lewat engine.apply pada salinan state, jadi tidak diuji di sini —
  // dicatat di docs/OPEN_QUESTIONS.md (OQ-WEB-02).
  test('easy/medium: hand/deck player yang berbeda tidak mengubah keputusan (I-10)', () => {
    const base = engine.start({ playerDeck: variedDeck('player'), botDeck: variedDeck('bot'), seed: 31, config });
    let state = base;
    while (state.activeSide !== 'bot' && !state.isTerminal) state = engine.apply(state, END_TURN);
    const tampered = state.copy();
    tampered.player.hand = [...tampered.player.hand].reverse();
    tampered.player.deck = [];
    for (const difficulty of ['easy', 'medium'] as const) {
      const a = new BotAI({ difficulty, seed: 5 }).decide(state, 'bot');
      const b = new BotAI({ difficulty, seed: 5 }).decide(tampered, 'bot');
      assert.equal(actionSignature(a), actionSignature(b), difficulty);
    }
  });
});

describe('BotAI determinisme & performa', () => {
  test('seed sama menghasilkan keputusan yang sama', () => {
    const state = engine.start({ playerDeck: variedDeck('player'), botDeck: variedDeck('bot'), seed: 99, config });
    const side = state.activeSide;
    const first = new BotAI({ difficulty: 'medium', seed: 42 }).decide(state, side);
    const second = new BotAI({ difficulty: 'medium', seed: 42 }).decide(state, side);
    assert.equal(actionSignature(first), actionSignature(second));
  });

  test('Master p95 < 300 ms pada 40 keputusan', () => {
    let state = engine.start({ playerDeck: variedDeck('player'), botDeck: variedDeck('bot'), seed: 7, config });
    const durations: number[] = [];
    const rng = new DartRandom(11);
    for (let i = 0; i < 40; i += 1) {
      if (state.isTerminal) break;
      const side = state.activeSide;
      const legal = engine.legalActions(state, side);
      if (legal.length === 0) break;
      const started = performance.now();
      const action = new BotAI({ difficulty: 'master', seed: 100 + i }).decide(state, side);
      durations.push(performance.now() - started);
      assert.ok(legal.some((item) => actionSignature(item) === actionSignature(action)), `iterasi ${i} ilegal`);
      state = engine.apply(state, action);
      if (rng.nextBool() && !state.isTerminal && engine.legalActions(state, state.activeSide).length > 0) {
        state = engine.apply(state, END_TURN);
      }
    }
    assert.ok(durations.length > 0);
    durations.sort((a, b) => a - b);
    const p95 = durations[Math.min(durations.length - 1, Math.floor(durations.length * 0.95))]!;
    assert.ok(p95 < 300, `p95=${p95.toFixed(1)}ms dari ${durations.length} keputusan`);
  });

  test('difficultyFrom & botSeedFor', () => {
    assert.equal(difficultyFrom('MASTER'), 'master');
    assert.equal(difficultyFrom('???'), 'easy');
    // Nilai XOR int 64-bit seperti Dart (bukan int32 bertanda JS).
    assert.equal(botSeedFor(1), Number(1n ^ 0x9e3779b9n));
    assert.equal(botSeedFor(2000000000), Number(2000000000n ^ 0x9e3779b9n));
  });
});

/** Alur sesi battle (port perilaku BattleCubit): giliran bot, concede, kirim hasil + retry. */
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { BattleSession, type SubmitResult } from '../src/lib/battle/session.ts';
import type { BattleResultData, BattleStartData } from '../src/lib/domain/models.ts';
import { goldenBotDeck, starterDeck } from './support/fixtures.ts';

const fakeResult = (outcome: string): BattleResultData => ({
  matchId: 'mat_test',
  alreadyReported: false,
  outcome,
  rewards: { gold: 40, xp: 30, firstWinBonus: false, capped: false },
  levelUp: { levelsGained: 0, gold: 0, gems: 0 },
  stats: { wins: 0, losses: 1, draws: 0, total: 1, winRate: 0 },
  balance: { gold: 1000, gems: 50 },
  user: null,
});

function start(seed: number): BattleStartData {
  return {
    matchId: 'mat_test',
    seed,
    difficulty: 'medium',
    playerDeck: { name: 'Starter', deckId: 'd1', cards: starterDeck() },
    botDeck: { name: 'Bot', deckId: null, cards: goldenBotDeck() },
    catalogVersion: 'test',
    engineVersion: '1.0.0',
    startedAt: null,
  };
}

const flush = () => new Promise((resolve) => setImmediate(resolve));

async function waitFor(predicate: () => boolean, label: string): Promise<void> {
  for (let i = 0; i < 2000; i += 1) {
    if (predicate()) return;
    await flush();
  }
  throw new Error(`timeout menunggu: ${label}`);
}

describe('BattleSession', () => {
  test('aksi pemain diterapkan lewat engine; end turn memicu bot lalu kembali ke pemain', async () => {
    // Cari seed di mana pemain jalan duluan.
    let seed = 1;
    let session = new BattleSession({ start: start(seed), submitResult: async () => fakeResult('win'), delay: async () => {} });
    while (session.battle.activeSide !== 'player') {
      seed += 1;
      session = new BattleSession({ start: start(seed), submitResult: async () => fakeResult('win'), delay: async () => {} });
    }
    const states: number[] = [];
    session.subscribe((s) => states.push(s.battle.log.length));
    session.begin();

    assert.equal(session.endTurn(), null);
    await waitFor(() => !session.state.busy && session.battle.activeSide === 'player', 'giliran kembali ke pemain');
    assert.ok(states.length >= 2, 'UI menerima update state');
    assert.ok(session.battle.log.some((e) => e.side === 'bot' && e.type === 'begin_turn'));
    session.close();
  });

  test('aksi saat bot sedang jalan ditolak dengan pesan', async () => {
    let release: () => void = () => {};
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    let seed = 1;
    const make = () => new BattleSession({ start: start(seed), submitResult: async () => fakeResult('win'), delay: () => gate });
    let session = make();
    while (session.battle.activeSide !== 'bot') {
      seed += 1;
      session = make();
    }
    session.begin();
    assert.equal(session.state.busy, true);
    assert.equal(session.endTurn(), 'Tunggu bot menyelesaikan gilirannya.');
    assert.equal(session.playOptionsForHand(0).length, 0);
    release();
    session.close();
  });

  test('concede → loss dan hasil dikirim sekali dengan turns/durationMs/logHash valid', async () => {
    const calls: Parameters<SubmitResult>[0][] = [];
    let now = 0;
    const session = new BattleSession({
      start: start(42),
      submitResult: async (input) => {
        calls.push(input);
        return fakeResult(input.outcome);
      },
      delay: async () => {},
      clock: () => now,
    });
    now = 120;
    session.concede();
    await waitFor(() => session.state.result !== null, 'hasil terkirim');
    assert.equal(calls.length, 1);
    assert.equal(calls[0]!.outcome, 'loss');
    assert.ok(calls[0]!.turns >= 1 && calls[0]!.turns <= 50);
    assert.ok(calls[0]!.durationMs >= calls[0]!.turns * 500, 'durationMs minimal turns*500 (aturan server)');
    assert.match(calls[0]!.logHash, /^[0-9a-f]{64}$/);
    assert.equal(calls[0]!.logHash, session.battle.logHash());
  });

  test('gagal kirim hasil → submitError, retry berhasil', async () => {
    let attempts = 0;
    const session = new BattleSession({
      start: start(7),
      submitResult: async (input) => {
        attempts += 1;
        if (attempts === 1) throw new Error('Tidak dapat terhubung ke server.');
        return fakeResult(input.outcome);
      },
      delay: async () => {},
    });
    session.concede();
    await waitFor(() => session.state.submitError !== null, 'error tampil');
    assert.equal(session.state.result, null);
    await session.retrySubmit();
    assert.equal(attempts, 2);
    assert.notEqual(session.state.result, null);
    assert.equal(session.state.submitError, null);
  });
});

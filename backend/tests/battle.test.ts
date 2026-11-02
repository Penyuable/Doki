import { beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app, authHeader, ensureCatalog, registerUser } from './helpers.js';

beforeAll(async () => {
  await ensureCatalog();
});

async function startBattle(token: string, difficulty = 'easy') {
  return request(app)
    .post('/api/v1/battles/start')
    .set(authHeader(token))
    .send({ difficulty });
}

describe('FR-07/FR-09 Battle & reward', () => {
  it('start battle memakai deck aktif dan menyusun deck bot 20 kartu', async () => {
    const { token } = await registerUser('batstart');
    const res = await startBattle(token, 'medium');

    expect(res.status).toBe(201);
    expect(res.body.data.matchId).toMatch(/^mat_/);
    expect(res.body.data.playerDeck.cards).toHaveLength(20);
    expect(res.body.data.botDeck.cards).toHaveLength(20);
    expect(res.body.data.seed).toBeGreaterThan(0);
    expect(res.body.data.config.playerHp).toBe(200);
  });

  it('hasil menang memberi reward + first win bonus, dan idempotent', async () => {
    const { token, user } = await registerUser('batwin');
    const start = await startBattle(token, 'easy');
    const matchId = start.body.data.matchId as string;

    const result = await request(app)
      .post(`/api/v1/battles/${matchId}/result`)
      .set(authHeader(token))
      .send({ outcome: 'win', turns: 8, durationMs: 4000, logHash: 'hash-1' });

    expect(result.status).toBe(200);
    expect(result.body.data.rewards.gold).toBe(240); // 40 + 200 first win
    expect(result.body.data.rewards.xp).toBe(30);
    expect(result.body.data.rewards.firstWinBonus).toBe(true);
    expect(result.body.data.balance.gold).toBe(1240);

    const again = await request(app)
      .post(`/api/v1/battles/${matchId}/result`)
      .set(authHeader(token))
      .send({ outcome: 'win', turns: 8, durationMs: 4000 });

    expect(again.status).toBe(200);
    expect(again.body.data.alreadyReported).toBe(true);
    expect(again.body.data.balance.gold).toBe(1240);
    expect(again.body.data.user.id).toBe(user.id);
  });

  it('hasil menang < 2 turn ditolak sebagai mencurigakan', async () => {
    const { token } = await registerUser('batsus');
    const start = await startBattle(token, 'easy');
    const matchId = start.body.data.matchId as string;

    const res = await request(app)
      .post(`/api/v1/battles/${matchId}/result`)
      .set(authHeader(token))
      .send({ outcome: 'win', turns: 1, durationMs: 500 });

    expect(res.status).toBe(422);
    expect(res.body.error.code).toBe('SUSPICIOUS_RESULT');
  });

  it('duration tidak masuk akal → 400', async () => {
    const { token } = await registerUser('batdur');
    const start = await startBattle(token, 'easy');
    const matchId = start.body.data.matchId as string;

    const res = await request(app)
      .post(`/api/v1/battles/${matchId}/result`)
      .set(authHeader(token))
      .send({ outcome: 'win', turns: 8, durationMs: 100 });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('VALIDATION_ERROR');
  });

  it('kalah hanya memberi XP, tanpa gold', async () => {
    const { token } = await registerUser('batlose');
    const start = await startBattle(token, 'master');
    const matchId = start.body.data.matchId as string;

    const res = await request(app)
      .post(`/api/v1/battles/${matchId}/result`)
      .set(authHeader(token))
      .send({ outcome: 'loss', turns: 10, durationMs: 6000 });

    expect(res.status).toBe(200);
    expect(res.body.data.rewards.gold).toBe(0);
    expect(res.body.data.rewards.xp).toBe(10);
    expect(res.body.data.stats.losses).toBe(1);
  });

  it('history menampilkan match yang sudah selesai', async () => {
    const { token } = await registerUser('bathist');
    const start = await startBattle(token, 'easy');
    const matchId = start.body.data.matchId as string;

    await request(app)
      .post(`/api/v1/battles/${matchId}/result`)
      .set(authHeader(token))
      .send({ outcome: 'draw', turns: 50, durationMs: 60_000 });

    const history = await request(app)
      .get('/api/v1/battles/history')
      .set(authHeader(token));

    expect(history.status).toBe(200);
    expect(history.body.data.items).toHaveLength(1);
    expect(history.body.data.items[0].outcome).toBe('draw');
    expect(history.body.data.items[0].turns).toBe(50);
  });
});

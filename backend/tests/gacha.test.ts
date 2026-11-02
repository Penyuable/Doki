import { beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app, authHeader, ensureCatalog, prisma, registerUser } from './helpers.js';

beforeAll(async () => {
  await ensureCatalog();
});

describe('FR-04 Gacha (server-authoritative)', () => {
  it('GET /gacha/rates mengembalikan 6 tier = 100%', async () => {
    const res = await request(app).get('/api/v1/gacha/rates');
    expect(res.status).toBe(200);
    const rates = res.body.data.rates as Array<{ rarity: string; percent: number }>;
    expect(rates).toHaveLength(6);
    expect(rates.reduce((s, r) => s + r.percent, 0)).toBe(100);
    expect(res.body.data.pity.threshold).toBe(50);
  });

  it('10x pull memotong 900 gold dan mencatat 10 hasil', async () => {
    const { token, user } = await registerUser('gacha');
    const res = await request(app)
      .post('/api/v1/gacha/pull')
      .set(authHeader(token))
      .send({ count: 10, currency: 'gold', idempotencyKey: crypto.randomUUID() });

    expect(res.status).toBe(200);
    expect(res.body.data.results).toHaveLength(10);
    expect(res.body.data.balance.gold).toBe(100);
    expect(res.body.data.results.every((r: { card: unknown }) => r.card !== null)).toBe(true);

    const pity = await request(app).get('/api/v1/gacha/pity').set(authHeader(token));
    expect(pity.status).toBe(200);
    expect(pity.body.data.counter).toBeGreaterThanOrEqual(0);
    expect(pity.body.data.counter).toBeLessThanOrEqual(10);

    const pulls = await prisma.gachaPull.count({ where: { userId: user.id } });
    expect(pulls).toBe(10);
  });

  it('idempotencyKey sama tidak memotong saldo dua kali', async () => {
    const { token } = await registerUser('idem');
    const key = crypto.randomUUID();

    const first = await request(app)
      .post('/api/v1/gacha/pull')
      .set(authHeader(token))
      .send({ count: 1, currency: 'gold', idempotencyKey: key });
    expect(first.status).toBe(200);

    const second = await request(app)
      .post('/api/v1/gacha/pull')
      .set(authHeader(token))
      .send({ count: 1, currency: 'gold', idempotencyKey: key });

    expect(second.status).toBe(200);
    expect(second.body.data.replayed).toBe(true);
    expect(second.body.data.balance.gold).toBe(first.body.data.balance.gold);
    expect(second.body.data.results[0].cardId).toBe(first.body.data.results[0].cardId);
  });

  it('saldo kurang → 402 dan tidak ada pull tercatat', async () => {
    const { token, user } = await registerUser('poor');
    await prisma.user.update({ where: { id: user.id }, data: { gold: 50 } });

    const res = await request(app)
      .post('/api/v1/gacha/pull')
      .set(authHeader(token))
      .send({ count: 1, currency: 'gold' });

    expect(res.status).toBe(402);
    expect(res.body.error.code).toBe('INSUFFICIENT_FUNDS');
    expect(await prisma.gachaPull.count({ where: { userId: user.id } })).toBe(0);
  });

  it('pity counter 49 → pull berikutnya dijamin Epic+ dan reset', async () => {
    const { token, user } = await registerUser('pity');
    await prisma.user.update({ where: { id: user.id }, data: { pityCounter: 49 } });

    const res = await request(app)
      .post('/api/v1/gacha/pull')
      .set(authHeader(token))
      .send({ count: 1, currency: 'gold', idempotencyKey: crypto.randomUUID() });

    expect(res.status).toBe(200);
    const result = res.body.data.results[0];
    expect(['Epic', 'Legendary', 'Master']).toContain(result.rarity);
    expect(result.wasPity).toBe(true);
    expect(res.body.data.pity.counter).toBe(0);
  });

  it('10x tanpa Rare+ tetap menghasilkan minimal 1 Rare+', async () => {
    const { token, user } = await registerUser('ten');
    await prisma.user.update({ where: { id: user.id }, data: { gold: 10_000 } });

    for (let i = 0; i < 3; i += 1) {
      const res = await request(app)
        .post('/api/v1/gacha/pull')
        .set(authHeader(token))
        .send({ count: 10, currency: 'gold', idempotencyKey: crypto.randomUUID() });
      expect(res.status).toBe(200);
      const results = res.body.data.results as Array<{ rarity: string }>;
      expect(
        results.some((r) => ['Rare', 'Epic', 'Legendary', 'Master'].includes(r.rarity)),
      ).toBe(true);
    }
  });

  it('inventory bertambah setelah pull', async () => {
    const { token } = await registerUser('inv');
    const before = await request(app).get('/api/v1/inventory').set(authHeader(token));

    await request(app)
      .post('/api/v1/gacha/pull')
      .set(authHeader(token))
      .send({ count: 10, currency: 'gold', idempotencyKey: crypto.randomUUID() });

    const after = await request(app).get('/api/v1/inventory').set(authHeader(token));
    const beforeQty = (before.body.data.items as Array<{ quantity: number }>).reduce(
      (s, i) => s + i.quantity,
      0,
    );
    const afterQty = (after.body.data.items as Array<{ quantity: number }>).reduce(
      (s, i) => s + i.quantity,
      0,
    );
    expect(afterQty).toBe(beforeQty + 10);
  });
});

import { beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app, authHeader, ensureCatalog, registerUser } from './helpers.js';

beforeAll(async () => {
  await ensureCatalog();
});

const starter = [
  { cardId: 'card_001', quantity: 3 },
  { cardId: 'card_002', quantity: 3 },
  { cardId: 'card_003', quantity: 3 },
  { cardId: 'card_004', quantity: 3 },
  { cardId: 'card_005', quantity: 3 },
  { cardId: 'card_006', quantity: 3 },
  { cardId: 'card_007', quantity: 2 },
];

describe('FR-06 Deck builder', () => {
  it('deck 19 kartu → 400 DECK_INVALID', async () => {
    const { token } = await registerUser('deck19');
    const cards = starter.map((c, i) => (i === 0 ? { ...c, quantity: 2 } : c));

    const res = await request(app)
      .post('/api/v1/decks')
      .set(authHeader(token))
      .send({ name: 'Sembilan Belas', cards });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('DECK_INVALID');
    expect(
      res.body.error.details.violations.some(
        (v: { code: string }) => v.code === 'DECK_SIZE',
      ),
    ).toBe(true);
  });

  it('4 copy kartu yang sama → COPY_LIMIT_EXCEEDED', async () => {
    const { token } = await registerUser('deck4');
    const cards = [
      { cardId: 'card_001', quantity: 4 },
      { cardId: 'card_002', quantity: 3 },
      { cardId: 'card_003', quantity: 3 },
      { cardId: 'card_004', quantity: 3 },
      { cardId: 'card_005', quantity: 3 },
      { cardId: 'card_006', quantity: 3 },
      { cardId: 'card_007', quantity: 1 },
    ];

    const res = await request(app)
      .post('/api/v1/decks')
      .set(authHeader(token))
      .send({ name: 'Empat Copy', cards });

    expect(res.status).toBe(400);
    expect(
      res.body.error.details.violations.some(
        (v: { code: string }) => v.code === 'COPY_LIMIT_EXCEEDED',
      ),
    ).toBe(true);
  });

  it('kartu tidak dimiliki → CARD_NOT_OWNED', async () => {
    const { token } = await registerUser('deckown');
    const cards = [...starter.slice(0, 6), { cardId: 'card_025', quantity: 2 }];

    const res = await request(app)
      .post('/api/v1/decks')
      .set(authHeader(token))
      .send({ name: 'Bukan Milikku', cards });

    expect(res.status).toBe(400);
    expect(
      res.body.error.details.violations.some(
        (v: { code: string }) => v.code === 'CARD_NOT_OWNED',
      ),
    ).toBe(true);
  });

  it('create, activate, list, delete', async () => {
    const { token } = await registerUser('deckcrud');

    const created = await request(app)
      .post('/api/v1/decks')
      .set(authHeader(token))
      .send({ name: 'Deck Api', cards: starter });

    expect(created.status).toBe(201);
    const deckId = created.body.data.deck.id as string;
    expect(created.body.data.deck.isValid).toBe(true);
    expect(created.body.data.deck.cardCount).toBe(20);

    const activated = await request(app)
      .put(`/api/v1/decks/${deckId}/activate`)
      .set(authHeader(token));
    expect(activated.status).toBe(200);
    expect(activated.body.data.activeDeckId).toBe(deckId);

    const list = await request(app).get('/api/v1/decks').set(authHeader(token));
    const active = (list.body.data.decks as Array<{ isActive: boolean; id: string }>).filter(
      (d) => d.isActive,
    );
    expect(active).toHaveLength(1);
    expect(active[0]!.id).toBe(deckId);

    const removed = await request(app)
      .delete(`/api/v1/decks/${deckId}`)
      .set(authHeader(token));
    expect(removed.status).toBe(204);

    const after = await request(app).get('/api/v1/decks').set(authHeader(token));
    expect(
      (after.body.data.decks as Array<{ id: string }>).some((d) => d.id === deckId),
    ).toBe(false);
  });

  it('maksimal 10 deck per user', async () => {
    const { token } = await registerUser('deckmax');

    for (let i = 0; i < 9; i += 1) {
      const res = await request(app)
        .post('/api/v1/decks')
        .set(authHeader(token))
        .send({ name: `Deck ${i}`, cards: starter });
      expect(res.status).toBe(201);
    }

    const eleventh = await request(app)
      .post('/api/v1/decks')
      .set(authHeader(token))
      .send({ name: 'Deck ke-11', cards: starter });

    expect(eleventh.status).toBe(400);
    expect(
      eleventh.body.error.details.violations.some(
        (v: { code: string }) => v.code === 'DECK_LIMIT_REACHED',
      ),
    ).toBe(true);
  });
});

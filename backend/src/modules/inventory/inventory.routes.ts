import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../config/prisma.js';
import { RARITIES } from '../../config/economy.js';
import { AppError } from '../../lib/errors.js';
import { wrap } from '../../lib/async.js';
import { authGuard, userIdOf } from '../../middleware/auth.js';
import { parse } from '../../lib/validate.js';
import { getSnapshot } from '../catalog/catalog.service.js';
import { CARD_TYPES, ELEMENTS } from '../catalog/catalog.schema.js';

export const inventoryRouter = Router();
inventoryRouter.use(authGuard);

const querySchema = z
  .object({
    element: z.enum(ELEMENTS).optional(),
    rarity: z.enum(RARITIES).optional(),
    type: z.enum(CARD_TYPES).optional(),
    sort: z.enum(['rarity', 'name', 'recent', 'attack', 'hp']).default('rarity'),
    limit: z.coerce.number().int().min(1).max(100).default(50),
    cursor: z.coerce.number().int().min(0).default(0),
  })
  .strict();

inventoryRouter.get(
  '/',
  wrap(async (req, res) => {
    const q = parse(querySchema, req.query);
    const userId = userIdOf(res);

    const [rows, snapshot] = await Promise.all([
      prisma.inventoryCard.findMany({
        where: { userId },
        orderBy: { firstSeenAt: 'desc' },
      }),
      getSnapshot(),
    ]);

    const items = rows
      .map((row) => {
        const card = snapshot.byId.get(row.cardId);
        if (!card) return null;
        return {
          cardId: row.cardId,
          quantity: row.quantity,
          firstSeenAt: row.firstSeenAt,
          card,
        };
      })
      .filter((x): x is NonNullable<typeof x> => x !== null)
      .filter((x) => (q.element ? x.card.element === q.element : true))
      .filter((x) => (q.rarity ? x.card.rarity === q.rarity : true))
      .filter((x) => (q.type ? x.card.type === q.type : true));

    const rarityIndex = new Map(RARITIES.map((r, i) => [r, i]));

    items.sort((a, b) => {
      switch (q.sort) {
        case 'name':
          return a.card.name.localeCompare(b.card.name);
        case 'recent':
          return b.firstSeenAt.getTime() - a.firstSeenAt.getTime();
        case 'attack':
          return (b.card.attack ?? -1) - (a.card.attack ?? -1);
        case 'hp':
          return (b.card.hp ?? -1) - (a.card.hp ?? -1);
        case 'rarity':
        default: {
          const diff =
            (rarityIndex.get(b.card.rarity) ?? 0) - (rarityIndex.get(a.card.rarity) ?? 0);
          return diff !== 0 ? diff : a.card.name.localeCompare(b.card.name);
        }
      }
    });

    const page = items.slice(q.cursor, q.cursor + q.limit);
    const next = q.cursor + q.limit < items.length ? q.cursor + q.limit : null;

    res.json({
      data: {
        items: page,
        nextCursor: next,
        owned: rows.length,
        total: snapshot.cards.filter((c) => !c.retired).length,
      },
      meta: { requestId: res.locals.requestId, catalogVersion: snapshot.version },
    });
  }),
);

inventoryRouter.get(
  '/:cardId',
  wrap(async (req, res) => {
    const userId = userIdOf(res);
    const cardId = String(req.params.cardId);

    const [row, snapshot] = await Promise.all([
      prisma.inventoryCard.findUnique({
        where: { userId_cardId: { userId, cardId } },
      }),
      getSnapshot(),
    ]);

    const card = snapshot.byId.get(cardId);
    if (!card) throw new AppError('NOT_FOUND', `Kartu ${cardId} tidak ditemukan`);

    res.json({
      data: { cardId, quantity: row?.quantity ?? 0, card },
      meta: { requestId: res.locals.requestId },
    });
  }),
);

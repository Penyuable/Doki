import { Router } from 'express';
import { z } from 'zod';
import { wrap } from '../../lib/async.js';
import { authGuard, userIdOf } from '../../middleware/auth.js';
import { gachaLimiter } from '../../middleware/rateLimit.js';
import { parse } from '../../lib/validate.js';
import { PITY_INFO, RATE_TABLE } from './gacha.math.js';
import * as gacha from './gacha.service.js';

export const gachaRouter = Router();

const pullSchema = z
  .object({
    count: z.union([z.literal(1), z.literal(10)]),
    currency: z.enum(['gold', 'gem']),
    idempotencyKey: z.string().uuid().optional(),
  })
  .strict();

const historyQuery = z
  .object({
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().max(64).optional(),
  })
  .strict();

gachaRouter.get(
  '/rates',
  wrap(async (_req, res) => {
    res.json({
      data: {
        rates: RATE_TABLE,
        pity: {
          threshold: PITY_INFO.threshold,
          bonusWeights: PITY_INFO.bonusWeights,
          note: `Epic+ dijamin pada pull ke-${PITY_INFO.threshold} sejak Epic+ terakhir. 10x pull dijamin minimal 1 Rare+.`,
        },
        guaranteedRarePlusOnTen: true,
      },
      meta: { requestId: res.locals.requestId },
    });
  }),
);

gachaRouter.get(
  '/pity',
  authGuard,
  wrap(async (_req, res) => {
    const data = await gacha.getPity(userIdOf(res));
    res.json({ data, meta: { requestId: res.locals.requestId } });
  }),
);

gachaRouter.post(
  '/pull',
  authGuard,
  gachaLimiter,
  wrap(async (req, res) => {
    const input = parse(pullSchema, req.body);
    const data = await gacha.pull(userIdOf(res), input);
    res.json({ data, meta: { requestId: res.locals.requestId } });
  }),
);

gachaRouter.get(
  '/history',
  authGuard,
  wrap(async (req, res) => {
    const q = parse(historyQuery, req.query);
    const data = await gacha.history(userIdOf(res), q.limit, q.cursor);
    res.json({ data, meta: { requestId: res.locals.requestId } });
  }),
);

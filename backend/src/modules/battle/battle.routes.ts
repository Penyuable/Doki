import { Router } from 'express';
import { z } from 'zod';
import { wrap } from '../../lib/async.js';
import { authGuard, userIdOf } from '../../middleware/auth.js';
import { battleResultLimiter } from '../../middleware/rateLimit.js';
import { parse } from '../../lib/validate.js';
import * as battle from './battle.service.js';

export const battleRouter = Router();
battleRouter.use(authGuard);

const startSchema = z
  .object({
    difficulty: z.enum(['easy', 'medium', 'master']),
    deckId: z.string().min(3).max(40).optional(),
  })
  .strict();

const resultSchema = z
  .object({
    outcome: z.enum(['win', 'loss', 'draw']),
    turns: z.number().int().min(1).max(50),
    durationMs: z.number().int().min(0).max(3 * 60 * 60 * 1000),
    logHash: z.string().max(128).optional(),
    engineVersion: z.string().max(20).optional(),
  })
  .strict();

const historySchema = z
  .object({
    limit: z.coerce.number().int().min(1).max(50).default(20),
    cursor: z.string().max(64).optional(),
  })
  .strict();

battleRouter.post(
  '/start',
  wrap(async (req, res) => {
    const input = parse(startSchema, req.body);
    const data = await battle.startBattle(userIdOf(res), input.difficulty, input.deckId);
    res.status(201).json({ data, meta: { requestId: res.locals.requestId } });
  }),
);

battleRouter.post(
  '/:matchId/result',
  battleResultLimiter,
  wrap(async (req, res) => {
    const input = parse(resultSchema, req.body);
    const data = await battle.reportResult(userIdOf(res), String(req.params.matchId), input);
    res.json({ data, meta: { requestId: res.locals.requestId } });
  }),
);

battleRouter.get(
  '/history',
  wrap(async (req, res) => {
    const q = parse(historySchema, req.query);
    const data = await battle.battleHistory(userIdOf(res), q.limit, q.cursor);
    res.json({ data, meta: { requestId: res.locals.requestId } });
  }),
);

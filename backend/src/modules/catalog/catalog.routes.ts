import { Router } from 'express';
import { z } from 'zod';
import { env } from '../../config/env.js';
import { RARITIES } from '../../config/economy.js';
import { AppError } from '../../lib/errors.js';
import { wrap } from '../../lib/async.js';
import { safeEqual } from '../../lib/jwt.js';
import { parse } from '../../lib/validate.js';
import { ELEMENTS, CARD_TYPES } from './catalog.schema.js';
import * as catalog from './catalog.service.js';

export const catalogRouter = Router();

const listQuery = z
  .object({
    element: z.enum(ELEMENTS).optional(),
    rarity: z.enum(RARITIES).optional(),
    type: z.enum(CARD_TYPES).optional(),
    version: z.string().max(40).optional(),
    includeRetired: z.enum(['true', 'false']).optional(),
  })
  .strict();

catalogRouter.get(
  '/manifest',
  wrap(async (_req, res) => {
    const info = await catalog.getManifestInfo();
    const etag = `"${info.checksum}"`;
    res.setHeader('ETag', etag);
    res.setHeader('Cache-Control', 'public, max-age=300');
    res.json({ data: info, meta: { requestId: res.locals.requestId } });
  }),
);

catalogRouter.get(
  '/cards',
  wrap(async (req, res) => {
    const q = parse(listQuery, req.query);
    const result = await catalog.listCards(
      {
        element: q.element,
        rarity: q.rarity,
        type: q.type,
        includeRetired: q.includeRetired === 'true',
      },
      q.version,
    );

    const etag = `"${result.checksum}:${q.element ?? ''}:${q.rarity ?? ''}:${q.type ?? ''}"`;
    res.setHeader('ETag', etag);
    res.setHeader('Cache-Control', 'public, max-age=300');

    if (req.header('if-none-match') === etag) {
      res.status(304).end();
      return;
    }

    res.json({
      data: { version: result.version, cards: result.cards },
      meta: { requestId: res.locals.requestId, catalogVersion: result.version },
    });
  }),
);

catalogRouter.get(
  '/cards/:id',
  wrap(async (req, res) => {
    const card = await catalog.getCard(String(req.params.id), req.query.version as string | undefined);
    res.json({
      data: { card },
      meta: { requestId: res.locals.requestId },
    });
  }),
);

catalogRouter.post(
  '/internal/sync',
  wrap(async (req, res) => {
    const token = req.header('x-admin-token') ?? '';
    if (!env.ADMIN_TOKEN || !safeEqual(token, env.ADMIN_TOKEN)) {
      throw new AppError('FORBIDDEN', 'Admin token tidak valid');
    }
    const result = await catalog.syncCatalog();
    res.json({ data: result, meta: { requestId: res.locals.requestId } });
  }),
);

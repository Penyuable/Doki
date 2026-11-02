import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../config/prisma.js';
import { wrap } from '../../lib/async.js';
import { authGuard, optionalUserId } from '../../middleware/auth.js';
import { telemetryLimiter } from '../../middleware/rateLimit.js';
import { parse } from '../../lib/validate.js';

export const telemetryRouter = Router();

export const ALLOWED_EVENTS = [
  'app_open',
  'auth_register',
  'auth_login',
  'catalog_sync',
  'gacha_pull',
  'deck_save',
  'battle_start',
  'battle_end',
  'battle_concede',
  'error',
] as const;

const eventSchema = z
  .object({
    name: z.enum(ALLOWED_EVENTS),
    props: z.record(z.unknown()).optional(),
    at: z.string().max(40).optional(),
  })
  .strict();

const batchSchema = z
  .object({
    events: z.array(eventSchema).min(1).max(50),
  })
  .strict();

const FORBIDDEN_PROPS = /password|token|email|authorization|secret/i;

function sanitizeProps(props: Record<string, unknown> | undefined): Record<string, unknown> {
  if (!props) return {};
  const out: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(props)) {
    if (FORBIDDEN_PROPS.test(key)) continue;
    const serialized = JSON.stringify(value ?? null);
    if (serialized.length > 500) continue;
    out[key] = value;
  }
  return out;
}

telemetryRouter.post(
  '/events',
  authGuard,
  telemetryLimiter,
  wrap(async (req, res) => {
    const input = parse(batchSchema, req.body);
    const userId = optionalUserId(res);

    await prisma.telemetryEvent.createMany({
      data: input.events.map((event) => ({
        userId,
        name: event.name,
        props: JSON.stringify(sanitizeProps(event.props)),
      })),
    });

    res.status(202).json({
      data: { accepted: input.events.length },
      meta: { requestId: res.locals.requestId },
    });
  }),
);

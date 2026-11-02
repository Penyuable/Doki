import rateLimit from 'express-rate-limit';
import type { Request, Response } from 'express';
import { env } from '../config/env.js';

const disabled = env.isTest;

const handler = (_req: Request, res: Response) => {
  res.status(429).json({
    error: { code: 'RATE_LIMITED', message: 'Terlalu banyak permintaan, coba lagi nanti' },
    meta: { requestId: res.locals.requestId },
  });
};

export const globalLimiter = rateLimit({
  windowMs: 60_000,
  limit: disabled ? 1_000_000 : 300,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler,
});

export const authLimiter = rateLimit({
  windowMs: 60_000,
  limit: disabled ? 1_000_000 : 10,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler,
});

const byUserOrIp = (req: Request, res: Response) =>
  (res.locals.userId as string | undefined) ?? req.ip ?? 'unknown';

export const gachaLimiter = rateLimit({
  windowMs: 60_000,
  limit: disabled ? 1_000_000 : 30,
  keyGenerator: byUserOrIp,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler,
});

export const battleResultLimiter = rateLimit({
  windowMs: 60_000,
  limit: disabled ? 1_000_000 : 10,
  keyGenerator: byUserOrIp,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler,
});

export const telemetryLimiter = rateLimit({
  windowMs: 60_000,
  limit: disabled ? 1_000_000 : 60,
  keyGenerator: byUserOrIp,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  handler,
});

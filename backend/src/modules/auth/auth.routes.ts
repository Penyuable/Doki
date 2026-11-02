import { Router } from 'express';
import { wrap } from '../../lib/async.js';
import { authGuard, userIdOf } from '../../middleware/auth.js';
import { authLimiter } from '../../middleware/rateLimit.js';
import { parse } from '../../lib/validate.js';
import { loginSchema, refreshSchema, registerSchema } from './auth.schema.js';
import * as auth from './auth.service.js';

export const authRouter = Router();

authRouter.post(
  '/register',
  authLimiter,
  wrap(async (req, res) => {
    const input = parse(registerSchema, req.body);
    const result = await auth.register(input);
    res.status(201).json({
      data: result,
      meta: { requestId: res.locals.requestId },
    });
  }),
);

authRouter.post(
  '/login',
  authLimiter,
  wrap(async (req, res) => {
    const input = parse(loginSchema, req.body);
    const result = await auth.login(input);
    res.json({
      data: result,
      meta: { requestId: res.locals.requestId },
    });
  }),
);

authRouter.post(
  '/refresh',
  authLimiter,
  wrap(async (req, res) => {
    const { refreshToken } = parse(refreshSchema, req.body);
    const result = await auth.refresh(refreshToken);
    res.json({
      data: result,
      meta: { requestId: res.locals.requestId },
    });
  }),
);

authRouter.post(
  '/logout',
  authGuard,
  wrap(async (req, res) => {
    const { refreshToken } = parse(refreshSchema, req.body);
    await auth.logout(refreshToken);
    res.status(204).send();
  }),
);

authRouter.get(
  '/me',
  authGuard,
  wrap(async (_req, res) => {
    const result = await auth.me(userIdOf(res));
    res.json({ data: result, meta: { requestId: res.locals.requestId } });
  }),
);

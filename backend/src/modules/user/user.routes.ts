import { Router } from 'express';
import { wrap } from '../../lib/async.js';
import { authGuard, userIdOf } from '../../middleware/auth.js';
import * as user from './user.service.js';

export const userRouter = Router();
userRouter.use(authGuard);

userRouter.get(
  '/profile',
  wrap(async (_req, res) => {
    const data = await user.getProfile(userIdOf(res));
    res.json({ data, meta: { requestId: res.locals.requestId } });
  }),
);

userRouter.get(
  '/wallet',
  wrap(async (_req, res) => {
    const data = await user.getWallet(userIdOf(res));
    res.json({ data, meta: { requestId: res.locals.requestId } });
  }),
);

userRouter.post(
  '/daily-claim',
  wrap(async (_req, res) => {
    const data = await user.claimDaily(userIdOf(res));
    res.json({ data, meta: { requestId: res.locals.requestId } });
  }),
);

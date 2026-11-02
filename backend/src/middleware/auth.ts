import type { NextFunction, Request, Response } from 'express';
import { AppError } from '../lib/errors.js';
import { verifyAccessToken } from '../lib/jwt.js';

export function authGuard(req: Request, res: Response, next: NextFunction) {
  const header = req.header('authorization') ?? '';
  const [scheme, token] = header.split(' ');

  if (scheme?.toLowerCase() !== 'bearer' || !token) {
    next(new AppError('UNAUTHORIZED', 'Header Authorization Bearer diperlukan'));
    return;
  }

  try {
    const payload = verifyAccessToken(token);
    res.locals.userId = payload.sub;
    next();
  } catch (err) {
    next(err);
  }
}

export function userIdOf(res: Response): string {
  const id = res.locals.userId as string | undefined;
  if (!id) {
    throw new AppError('UNAUTHORIZED', 'Sesi tidak valid');
  }
  return id;
}

export function optionalUserId(res: Response): string | null {
  return (res.locals.userId as string | undefined) ?? null;
}

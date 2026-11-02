import crypto from 'node:crypto';
import jwt from 'jsonwebtoken';
import { env } from '../config/env.js';
import { AppError } from './errors.js';

export type AccessPayload = {
  sub: string;
  type: 'access';
};

export function signAccessToken(userId: string): string {
  const payload: AccessPayload = { sub: userId, type: 'access' };
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    algorithm: 'HS256',
    expiresIn: env.accessTtlSeconds,
    issuer: 'dokimon-api',
    audience: 'dokimon-app',
  });
}

export function verifyAccessToken(token: string): AccessPayload {
  try {
    const decoded = jwt.verify(token, env.JWT_ACCESS_SECRET, {
      algorithms: ['HS256'],
      issuer: 'dokimon-api',
      audience: 'dokimon-app',
    });
    if (typeof decoded === 'string' || decoded.type !== 'access' || !decoded.sub) {
      throw new Error('payload tidak valid');
    }
    return { sub: String(decoded.sub), type: 'access' };
  } catch (err) {
    if (err instanceof jwt.TokenExpiredError) {
      throw new AppError('TOKEN_EXPIRED', 'Access token kedaluwarsa');
    }
    throw new AppError('UNAUTHORIZED', 'Access token tidak valid');
  }
}

/** Refresh token opaque (bukan JWT). Disimpan sebagai hash di DB. */
export function createRefreshToken(): { token: string; tokenHash: string } {
  const token = crypto.randomBytes(48).toString('base64url');
  return { token, tokenHash: hashToken(token) };
}

export function hashToken(token: string): string {
  return crypto.createHash('sha256').update(token).digest('hex');
}

export function newFamilyId(): string {
  return crypto.randomUUID();
}

export function safeEqual(a: string, b: string): boolean {
  const ab = Buffer.from(a);
  const bb = Buffer.from(b);
  if (ab.length !== bb.length) return false;
  return crypto.timingSafeEqual(ab, bb);
}

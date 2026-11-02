import type { Prisma, User } from '@prisma/client';
import { env } from '../../config/env.js';
import { prisma } from '../../config/prisma.js';
import { STARTING_BALANCE, STARTER_DECK } from '../../config/economy.js';
import { AppError } from '../../lib/errors.js';
import { createRefreshToken, hashToken, newFamilyId, signAccessToken } from '../../lib/jwt.js';
import { hashPassword, verifyPassword } from '../../lib/password.js';
import type { LoginInput, RegisterInput } from './auth.schema.js';

export type PublicUser = {
  id: string;
  email: string;
  username: string;
  gold: number;
  gems: number;
  level: number;
  xp: number;
  wins: number;
  losses: number;
  draws: number;
  pityCounter: number;
  createdAt: Date;
};

export function publicUser(user: User): PublicUser {
  return {
    id: user.id,
    email: user.email,
    username: user.username,
    gold: user.gold,
    gems: user.gems,
    level: user.level,
    xp: user.xp,
    wins: user.wins,
    losses: user.losses,
    draws: user.draws,
    pityCounter: user.pityCounter,
    createdAt: user.createdAt,
  };
}

export function statsOf(user: User) {
  const total = user.wins + user.losses + user.draws;
  return {
    wins: user.wins,
    losses: user.losses,
    draws: user.draws,
    total,
    winRate: total === 0 ? null : Number((user.wins / total).toFixed(3)),
  };
}

async function issueTokens(userId: string, familyId: string = newFamilyId()) {
  const { token, tokenHash } = createRefreshToken();
  const expiresAt = new Date(Date.now() + env.refreshTtlMs);

  await prisma.refreshToken.create({
    data: { userId, tokenHash, familyId, expiresAt },
  });

  return {
    accessToken: signAccessToken(userId),
    refreshToken: token,
    expiresIn: env.accessTtlSeconds,
  };
}

function isUniqueViolation(err: unknown): err is Prisma.PrismaClientKnownRequestError {
  return (
    typeof err === 'object' &&
    err !== null &&
    (err as { code?: string }).code === 'P2002'
  );
}

export async function register(input: RegisterInput) {
  const email = input.email.toLowerCase();
  const username = input.username.toLowerCase();

  const existing = await prisma.user.findFirst({
    where: { OR: [{ email }, { username }] },
    select: { email: true, username: true },
  });

  if (existing) {
    if (existing.email === email) {
      throw new AppError('DUPLICATE_EMAIL', 'Email sudah terdaftar');
    }
    throw new AppError('DUPLICATE_USERNAME', 'Username sudah dipakai');
  }

  const passwordHash = await hashPassword(input.password);

  let user: User;
  try {
    user = await prisma.$transaction(async (tx) => {
      const created = await tx.user.create({
        data: {
          email,
          username,
          passwordHash,
          gold: STARTING_BALANCE.gold,
          gems: STARTING_BALANCE.gems,
        },
      });

      await tx.inventoryCard.createMany({
        data: STARTER_DECK.map((c) => ({
          userId: created.id,
          cardId: c.cardId,
          quantity: c.quantity,
        })),
      });

      const deck = await tx.deck.create({
        data: {
          userId: created.id,
          name: 'Starter',
          isActive: true,
          cards: {
            createMany: {
              data: STARTER_DECK.map((c) => ({ cardId: c.cardId, quantity: c.quantity })),
            },
          },
        },
      });

      return tx.user.update({
        where: { id: created.id },
        data: { activeDeckId: deck.id },
      });
    });
  } catch (err) {
    if (isUniqueViolation(err)) {
      const target = String((err.meta as { target?: unknown } | undefined)?.target ?? '');
      if (target.includes('username')) {
        throw new AppError('DUPLICATE_USERNAME', 'Username sudah dipakai');
      }
      throw new AppError('DUPLICATE_EMAIL', 'Email sudah terdaftar');
    }
    throw err;
  }

  const tokens = await issueTokens(user.id);
  return { user: publicUser(user), ...tokens };
}

export async function login(input: LoginInput) {
  const user = await prisma.user.findUnique({ where: { email: input.email.toLowerCase() } });

  // Waktu respons seragam agar tidak membocorkan keberadaan email.
  const valid = user ? await verifyPassword(input.password, user.passwordHash) : false;

  if (!user || !valid) {
    throw new AppError('INVALID_CREDENTIALS', 'Email atau password salah');
  }

  const tokens = await issueTokens(user.id);
  return { user: publicUser(user), ...tokens };
}

export async function refresh(rawToken: string) {
  const tokenHash = hashToken(rawToken);
  const row = await prisma.refreshToken.findUnique({ where: { tokenHash } });

  if (!row) {
    throw new AppError('UNAUTHORIZED', 'Refresh token tidak valid');
  }

  if (row.revokedAt) {
    await prisma.refreshToken.updateMany({
      where: { familyId: row.familyId, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    throw new AppError('REFRESH_REUSED', 'Refresh token sudah dipakai; sesi dicabut');
  }

  if (row.expiresAt.getTime() < Date.now()) {
    await prisma.refreshToken.update({
      where: { id: row.id },
      data: { revokedAt: new Date() },
    });
    throw new AppError('UNAUTHORIZED', 'Refresh token kedaluwarsa');
  }

  const user = await prisma.user.findUnique({ where: { id: row.userId } });
  if (!user) throw new AppError('UNAUTHORIZED', 'User tidak ditemukan');

  await prisma.refreshToken.update({
    where: { id: row.id },
    data: { revokedAt: new Date() },
  });

  const tokens = await issueTokens(user.id, row.familyId);
  return { user: publicUser(user), ...tokens };
}

export async function logout(rawToken: string) {
  const tokenHash = hashToken(rawToken);
  await prisma.refreshToken.updateMany({
    where: { tokenHash, revokedAt: null },
    data: { revokedAt: new Date() },
  });
}

export async function me(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new AppError('NOT_FOUND', 'User tidak ditemukan');
  return {
    user: publicUser(user),
    stats: statsOf(user),
    activeDeckId: user.activeDeckId,
  };
}

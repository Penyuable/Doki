import { prisma } from '../../config/prisma.js';
import { DAILY_REWARDS } from '../../config/economy.js';
import { AppError } from '../../lib/errors.js';
import { isSameWibDay, isYesterdayWib, startOfWibDayUtc, DAY_MS } from '../../lib/time.js';
import { publicUser, statsOf } from '../auth/auth.service.js';
import { listCards } from '../catalog/catalog.service.js';

export async function getProfile(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new AppError('NOT_FOUND', 'User tidak ditemukan');

  const [ownedDistinct, catalog] = await Promise.all([
    prisma.inventoryCard.count({ where: { userId } }),
    listCards().catch(() => null),
  ]);

  const activeDeck = user.activeDeckId
    ? await prisma.deck.findFirst({
        where: { id: user.activeDeckId, userId },
        include: { cards: true },
      })
    : null;

  return {
    user: publicUser(user),
    stats: statsOf(user),
    collection: {
      owned: ownedDistinct,
      total: catalog?.cards.length ?? 0,
    },
    activeDeck: activeDeck
      ? {
          id: activeDeck.id,
          name: activeDeck.name,
          cardCount: activeDeck.cards.reduce((sum, c) => sum + c.quantity, 0),
        }
      : null,
    daily: {
      streak: user.dailyStreak,
      lastClaimAt: user.lastDailyAt,
      canClaim: !isSameWibDay(user.lastDailyAt, new Date()),
    },
  };
}

export async function getWallet(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { gold: true, gems: true, updatedAt: true },
  });
  if (!user) throw new AppError('NOT_FOUND', 'User tidak ditemukan');
  return user;
}

export async function claimDaily(userId: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new AppError('NOT_FOUND', 'User tidak ditemukan');

  const now = new Date();
  if (isSameWibDay(user.lastDailyAt, now)) {
    throw new AppError('ALREADY_CLAIMED', 'Reward harian sudah diambil hari ini', {
      nextClaimAt: new Date(startOfWibDayUtc(now).getTime() + DAY_MS),
    });
  }

  const streak =
    user.lastDailyAt && isYesterdayWib(user.lastDailyAt, now) ? user.dailyStreak + 1 : 1;
  const dayIndex = ((streak - 1) % 7) + 1;
  const reward = DAILY_REWARDS[dayIndex - 1] ?? DAILY_REWARDS[0]!;

  const updated = await prisma.user.update({
    where: { id: userId },
    data: {
      gold: { increment: reward.gold },
      gems: { increment: reward.gems },
      lastDailyAt: now,
      dailyStreak: streak,
    },
  });

  return {
    claimed: true,
    streak,
    day: dayIndex,
    reward: { gold: reward.gold, gems: reward.gems },
    balance: { gold: updated.gold, gems: updated.gems },
    nextClaimAt: new Date(startOfWibDayUtc(now).getTime() + DAY_MS),
  };
}

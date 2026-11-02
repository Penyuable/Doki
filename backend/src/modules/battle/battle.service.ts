import crypto from 'node:crypto';
import type { Match, User } from '@prisma/client';
import { prisma } from '../../config/prisma.js';
import {
  DAILY_REWARDED_MATCH_LIMIT,
  RARITIES,
  applyXp,
  type Rarity,
} from '../../config/economy.js';
import { AppError } from '../../lib/errors.js';
import { isSameWibDay, startOfWibDayUtc } from '../../lib/time.js';
import { getSnapshot } from '../catalog/catalog.service.js';
import type { Card } from '../catalog/catalog.schema.js';
import { getValidatedDeck } from '../deck/deck.service.js';
import { publicUser, statsOf } from '../auth/auth.service.js';
import { baseReward, firstWinBonus, type Difficulty, type Outcome } from './reward.js';

function seededRng(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = Math.imul(state ^ (state >>> 15), 1 | state);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function shuffle<T>(items: T[], rng: () => number): T[] {
  const out = [...items];
  for (let i = out.length - 1; i > 0; i -= 1) {
    const j = Math.floor(rng() * (i + 1));
    const a = out[i]!;
    out[i] = out[j]!;
    out[j] = a;
  }
  return out;
}

const RARITY_CAP: Record<Difficulty, Rarity> = {
  easy: 'Rare',
  medium: 'Epic',
  master: 'Master',
};

const MAX_COPIES = 3;

function fillDeck(
  pool: Card[],
  target: number,
  rng: () => number,
  existing: Card[] = [],
): Card[] {
  if (pool.length === 0) return [...existing];

  const counts = new Map<string, number>();
  for (const card of existing) counts.set(card.id, (counts.get(card.id) ?? 0) + 1);

  const shuffled = shuffle(pool, rng);
  const out = [...existing];

  const tryPush = (card: Card): boolean => {
    if (out.length >= target) return false;
    const used = counts.get(card.id) ?? 0;
    if (used >= MAX_COPIES) return false;
    counts.set(card.id, used + 1);
    out.push(card);
    return true;
  };

  // putaran 1: satu copy tiap kartu (variasi maksimal)
  for (const card of shuffled) if (!tryPush(card)) break;
  // putaran 2..MAX_COPIES: copy tambahan
  for (let copy = 1; copy < MAX_COPIES && out.length < target; copy += 1) {
    for (const card of shuffled) {
      if (out.length >= target) break;
      tryPush(card);
    }
  }

  return out;
}

export function buildBotDeck(snapshotCards: Card[], difficulty: Difficulty, seed: number): Card[] {
  const rng = seededRng(seed);
  const maxIndex = RARITIES.indexOf(RARITY_CAP[difficulty]);

  const pool = snapshotCards.filter(
    (c) => c.obtainable && !c.retired && RARITIES.indexOf(c.rarity as Rarity) <= maxIndex,
  );
  const units = pool.filter((c) => c.type === 'unit');
  const spells = pool.filter((c) => c.type === 'spell');

  let deck = fillDeck(units, 15, rng);
  deck = fillDeck(spells, 20, rng, deck);

  if (deck.length < 20) {
    deck = fillDeck(pool, 20, rng, deck);
  }

  return shuffle(deck, rng).slice(0, 20);
}

export async function startBattle(userId: string, difficulty: Difficulty, deckId?: string) {
  const user = await prisma.user.findUnique({ where: { id: userId } });
  if (!user) throw new AppError('NOT_FOUND', 'User tidak ditemukan');

  const chosenDeckId = deckId ?? user.activeDeckId;
  if (!chosenDeckId) {
    throw new AppError('DECK_INVALID', 'Pilih deck aktif terlebih dahulu');
  }

  const [{ cards, deck, catalogVersion }, snapshot] = await Promise.all([
    getValidatedDeck(userId, chosenDeckId),
    getSnapshot(),
  ]);

  const seed = crypto.randomInt(1, 2_147_483_647);
  const botCards = buildBotDeck(snapshot.cards, difficulty, seed);
  if (botCards.length !== 20) {
    throw new AppError('CATALOG_UNAVAILABLE', 'Katalog tidak cukup untuk menyusun deck bot');
  }

  const matchId = `mat_${crypto.randomUUID().replace(/-/g, '').slice(0, 16)}`;

  const match = await prisma.match.create({
    data: {
      id: matchId,
      userId,
      difficulty,
      seed,
      deckSnapshot: JSON.stringify({
        deckId: deck.id,
        cards: cards.map((c) => c.id),
      }),
    },
  });

  return {
    matchId: match.id,
    seed,
    difficulty,
    startedAt: match.createdAt,
    catalogVersion,
    engineVersion: '1.0.0',
    playerDeck: {
      deckId: deck.id,
      name: deck.name,
      cards,
    },
    botDeck: {
      name: `Bot ${difficulty}`,
      cards: botCards,
    },
    config: {
      playerHp: 200,
      maxEnergy: 10,
      startingEnergy: 1,
      boardSlots: 3,
      startingHand: 4,
      handLimit: 8,
      maxTurns: 50,
    },
  };
}

type ResultInput = {
  outcome: Outcome;
  turns: number;
  durationMs: number;
  logHash?: string;
  engineVersion?: string;
};

function shapeMatch(match: Match) {
  return {
    matchId: match.id,
    difficulty: match.difficulty,
    outcome: match.outcome,
    turns: match.turns,
    durationMs: match.durationMs,
    goldAwarded: match.goldAwarded,
    xpAwarded: match.xpAwarded,
    firstWinBonus: match.firstWinBonus,
    reportedAt: match.reportedAt,
    createdAt: match.createdAt,
  };
}

export async function reportResult(userId: string, matchId: string, input: ResultInput) {
  const now = new Date();

  const outcome = await prisma.$transaction(async (tx) => {
    const match = await tx.match.findFirst({ where: { id: matchId, userId } });
    if (!match) throw new AppError('NOT_FOUND', 'Match tidak ditemukan');

    const user = await tx.user.findUniqueOrThrow({ where: { id: userId } });

    if (match.outcome !== 'pending') {
      return {
        alreadyReported: true,
        match,
        user,
        levelUp: { levelsGained: 0, gold: 0, gems: 0 },
        capped: false,
      };
    }

    if (now.getTime() - match.createdAt.getTime() > 2 * 60 * 60 * 1000) {
      throw new AppError('VALIDATION_ERROR', 'Match sudah kedaluwarsa (lebih dari 2 jam)');
    }

    if (input.turns < 1 || input.turns > 50) {
      throw new AppError('VALIDATION_ERROR', 'turns harus 1..50');
    }
    if (input.durationMs < input.turns * 500 || input.durationMs > 3 * 60 * 60 * 1000) {
      throw new AppError('VALIDATION_ERROR', 'durationMs tidak masuk akal untuk jumlah turn');
    }
    if (input.outcome === 'win' && input.turns < 2) {
      throw new AppError('SUSPICIOUS_RESULT', 'Hasil menang terlalu cepat untuk diverifikasi');
    }

    const dayStart = startOfWibDayUtc(now);
    const rewardedToday = await tx.match.count({
      where: { userId, reportedAt: { gte: dayStart }, goldAwarded: { gt: 0 } },
    });
    const capped = rewardedToday >= DAILY_REWARDED_MATCH_LIMIT;

    const base = baseReward(match.difficulty as Difficulty, input.outcome);
    const gold = capped ? 0 : base.gold;
    const xp = capped ? 0 : base.xp;

    const bonus =
      !capped && input.outcome === 'win' && !isSameWibDay(user.lastFirstWinAt, now)
        ? firstWinBonus
        : 0;

    const xpResult = applyXp(user.level, user.xp, xp);

    const claim = await tx.match.updateMany({
      where: { id: match.id, outcome: 'pending' },
      data: {
        outcome: input.outcome,
        turns: input.turns,
        durationMs: input.durationMs,
        logHash: input.logHash ?? '',
        goldAwarded: gold + bonus,
        xpAwarded: xp,
        firstWinBonus: bonus > 0,
        reportedAt: now,
      },
    });

    if (claim.count === 0) {
      const current = await tx.match.findUniqueOrThrow({ where: { id: match.id } });
      return {
        alreadyReported: true,
        match: current,
        user,
        levelUp: { levelsGained: 0, gold: 0, gems: 0 },
        capped,
      };
    }

    const updatedUser = await tx.user.update({
      where: { id: userId },
      data: {
        gold: { increment: gold + bonus + xpResult.gold },
        gems: { increment: xpResult.gems },
        xp: xpResult.xp,
        level: xpResult.level,
        wins: { increment: input.outcome === 'win' ? 1 : 0 },
        losses: { increment: input.outcome === 'loss' ? 1 : 0 },
        draws: { increment: input.outcome === 'draw' ? 1 : 0 },
        ...(bonus > 0 ? { lastFirstWinAt: now } : {}),
      },
    });

    const updatedMatch = await tx.match.findUniqueOrThrow({ where: { id: match.id } });

    return {
      alreadyReported: false,
      match: updatedMatch,
      user: updatedUser,
      levelUp: {
        levelsGained: xpResult.levelsGained,
        gold: xpResult.gold,
        gems: xpResult.gems,
      },
      capped,
    };
  });

  return {
    matchId: outcome.match.id,
    alreadyReported: outcome.alreadyReported,
    outcome: outcome.match.outcome,
    rewards: {
      gold: outcome.match.goldAwarded,
      xp: outcome.match.xpAwarded,
      firstWinBonus: outcome.match.firstWinBonus,
      capped: outcome.capped,
    },
    levelUp: outcome.levelUp,
    stats: statsOf(outcome.user as User),
    balance: { gold: outcome.user.gold, gems: outcome.user.gems },
    user: publicUser(outcome.user as User),
  };
}

export async function battleHistory(userId: string, limit = 20, cursor?: string) {
  const rows = await prisma.match.findMany({
    where: { userId, outcome: { not: 'pending' } },
    orderBy: { createdAt: 'desc' },
    take: limit + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
  });

  const hasMore = rows.length > limit;
  const page = hasMore ? rows.slice(0, limit) : rows;

  return {
    items: page.map(shapeMatch),
    nextCursor: hasMore ? page[page.length - 1]!.id : null,
  };
}

import type { Prisma } from '@prisma/client';
import { prisma } from '../../config/prisma.js';
import {
  GACHA_PRICE,
  RARITIES,
  TEN_PULL_SIZE,
  type Rarity,
} from '../../config/economy.js';
import { AppError } from '../../lib/errors.js';
import {
  defaultRng,
  fallbackRarity,
  rollRarity,
  tenPullUpgrade,
  uniformPick,
} from './gacha.math.js';
import { getSnapshot, gachaPool } from '../catalog/catalog.service.js';
import type { Card } from '../catalog/catalog.schema.js';

export type PullCurrency = 'gold' | 'gem';
export type PullCount = 1 | 10;

export type PullInput = {
  count: PullCount;
  currency: PullCurrency;
  idempotencyKey?: string;
};

type InternalResult = {
  card: Card;
  rarity: Rarity;
  wasPity: boolean;
  isNew: boolean;
  guaranteedRare: boolean;
  pityBefore: number;
  pityAfter: number;
};

function priceOf(count: PullCount, currency: PullCurrency): number {
  return GACHA_PRICE[count][currency === 'gold' ? 'gold' : 'gem'];
}

function cardIndex(cards: Card[]): Map<Rarity, Card[]> {
  const map = new Map<Rarity, Card[]>();
  for (const rarity of RARITIES) map.set(rarity, []);
  for (const card of cards) {
    const bucket = map.get(card.rarity as Rarity);
    if (bucket) bucket.push(card);
  }
  return map;
}

async function replayIfExists(userId: string, idempotencyKey: string) {
  const first = await prisma.gachaPull.findFirst({
    where: { userId, idempotencyKey },
    select: { batchId: true, catalogVersion: true },
    orderBy: { createdAt: 'asc' },
  });
  if (!first) return null;

  const pulls = await prisma.gachaPull.findMany({
    where: { batchId: first.batchId },
    orderBy: { position: 'asc' },
  });
  if (pulls.length === 0) return null;

  const snapshot = await getSnapshot(first.catalogVersion).catch(() => getSnapshot());
  const byId = snapshot.byId;

  const results = pulls.map((p) => ({
    cardId: p.cardId,
    rarity: p.rarity as Rarity,
    isNew: p.isNew,
    wasPity: p.wasPity,
    guaranteedRare: false,
    card: byId.get(p.cardId) ?? null,
  }));

  const user = await prisma.user.findUniqueOrThrow({
    where: { id: userId },
    select: { gold: true, gems: true, pityCounter: true },
  });

  return {
    batchId: first.batchId,
    results,
    balance: { gold: user.gold, gems: user.gems },
    pity: {
      counter: user.pityCounter,
      threshold: 50,
      guaranteedIn: Math.max(0, 50 - user.pityCounter),
    },
    replayed: true,
  };
}

async function buildResponse(
  userId: string,
  batchId: string,
  results: InternalResult[],
  balance: { gold: number; gems: number },
  pityCounter: number,
) {
  return {
    batchId,
    results: results.map((r) => ({
      cardId: r.card.id,
      rarity: r.rarity,
      isNew: r.isNew,
      wasPity: r.wasPity,
      guaranteedRare: r.guaranteedRare,
      card: r.card,
    })),
    balance,
    pity: {
      counter: pityCounter,
      threshold: 50,
      guaranteedIn: Math.max(0, 50 - pityCounter),
    },
    replayed: false,
  };
}

export async function pull(
  userId: string,
  input: PullInput,
  rng: () => number = defaultRng,
) {
  if (input.idempotencyKey) {
    const replay = await replayIfExists(userId, input.idempotencyKey);
    if (replay) return replay;
  }

  const price = priceOf(input.count, input.currency);
  const snapshot = await getSnapshot();
  const pool = gachaPool(snapshot);
  if (pool.length === 0) {
    throw new AppError('CATALOG_UNAVAILABLE', 'Katalog tidak punya kartu yang bisa di-pull');
  }

  const byRarity = cardIndex(pool);
  const availableRarities = new Set<Rarity>(
    RARITIES.filter((r) => (byRarity.get(r)?.length ?? 0) > 0),
  );

  const batchId = `bat_${cryptoId()}`;

  try {
    const outcome = await prisma.$transaction(async (tx) => {
      const where: Prisma.UserWhereInput =
        input.currency === 'gold'
          ? { id: userId, gold: { gte: price } }
          : { id: userId, gems: { gte: price } };
      const data: Prisma.UserUpdateManyMutationInput =
        input.currency === 'gold'
          ? { gold: { decrement: price } }
          : { gems: { decrement: price } };

      const deducted = await tx.user.updateMany({ where, data });
      if (deducted.count !== 1) {
        const current = await tx.user.findUnique({
          where: { id: userId },
          select: { gold: true, gems: true },
        });
        if (!current) throw new AppError('NOT_FOUND', 'User tidak ditemukan');
        throw new AppError('INSUFFICIENT_FUNDS', 'Saldo tidak cukup', {
          currency: input.currency,
          required: price,
          available: input.currency === 'gold' ? current.gold : current.gems,
        });
      }

      const user = await tx.user.findUniqueOrThrow({
        where: { id: userId },
        select: { pityCounter: true },
      });

      const owned = await tx.inventoryCard.findMany({
        where: { userId },
        select: { cardId: true },
      });
      const ownedSet = new Set(owned.map((o) => o.cardId));
      const usedInBatch = new Set<string>();

      let pity = user.pityCounter;
      const results: InternalResult[] = [];

      for (let i = 0; i < input.count; i += 1) {
        const rolled = rollRarity(pity, rng);
        let rarity = rolled.rarity;
        if (!availableRarities.has(rarity)) {
          rarity = fallbackRarity(rarity, availableRarities);
        }
        const bucket = byRarity.get(rarity) ?? [];
        if (bucket.length === 0) {
          throw new AppError('CATALOG_UNAVAILABLE', `Tidak ada kartu untuk rarity ${rarity}`);
        }
        const card = uniformPick(bucket, rng);
        const isNew = !ownedSet.has(card.id) && !usedInBatch.has(card.id);
        usedInBatch.add(card.id);

        const pityBefore = pity;
        pity = ['Epic', 'Legendary', 'Master'].includes(rarity) ? 0 : pity + 1;

        results.push({
          card,
          rarity,
          wasPity: rolled.wasPity,
          isNew,
          guaranteedRare: false,
          pityBefore,
          pityAfter: pity,
        });
      }

      if (input.count === TEN_PULL_SIZE) {
        const last = results[results.length - 1]!;
        const upgrade = tenPullUpgrade(
          results.map((r) => r.rarity),
          last.wasPity,
          rng,
        );
        if (upgrade.guaranteed) {
          let target = upgrade.rarity;
          if (!availableRarities.has(target)) target = fallbackRarity(target, availableRarities);
          const bucket = byRarity.get(target) ?? [];
          const card = uniformPick(bucket, rng);
          results[results.length - 1] = {
            ...last,
            card,
            rarity: target,
            isNew: !ownedSet.has(card.id) && !usedInBatch.has(card.id),
            guaranteedRare: true,
          };
        }
      }

      await tx.gachaPull.createMany({
        data: results.map((r, index) => ({
          userId,
          batchId,
          idempotencyKey: index === 0 ? (input.idempotencyKey ?? null) : null,
          cardId: r.card.id,
          rarity: r.rarity,
          source: input.currency,
          costAmount: price,
          catalogVersion: snapshot.version,
          pityBefore: r.pityBefore,
          pityAfter: r.pityAfter,
          wasPity: r.wasPity,
          isNew: r.isNew,
          position: index,
        })),
      });

      for (const result of results) {
        await tx.inventoryCard.upsert({
          where: { userId_cardId: { userId, cardId: result.card.id } },
          create: { userId, cardId: result.card.id, quantity: 1 },
          update: { quantity: { increment: 1 } },
        });
      }

      const updated = await tx.user.update({
        where: { id: userId },
        data: { pityCounter: pity },
        select: { gold: true, gems: true, pityCounter: true },
      });

      return { results, updated };
    });

    return buildResponse(userId, batchId, outcome.results, {
      gold: outcome.updated.gold,
      gems: outcome.updated.gems,
    }, outcome.updated.pityCounter);
  } catch (err) {
    if (
      input.idempotencyKey &&
      typeof err === 'object' &&
      err !== null &&
      (err as { code?: string }).code === 'P2002'
    ) {
      const replay = await replayIfExists(userId, input.idempotencyKey);
      if (replay) return replay;
    }
    throw err;
  }
}

function cryptoId(): string {
  return crypto.randomUUID().replace(/-/g, '').slice(0, 12);
}

export async function getPity(userId: string) {
  const user = await prisma.user.findUnique({
    where: { id: userId },
    select: { pityCounter: true },
  });
  if (!user) throw new AppError('NOT_FOUND', 'User tidak ditemukan');
  return {
    counter: user.pityCounter,
    threshold: 50,
    guaranteedIn: Math.max(0, 50 - user.pityCounter),
  };
}

export async function history(userId: string, limit = 20, cursor?: string) {  const rows = await prisma.gachaPull.findMany({
    where: { userId },
    orderBy: { createdAt: 'desc' },
    take: limit + 1,
    ...(cursor ? { cursor: { id: cursor }, skip: 1 } : {}),
  });

  const hasMore = rows.length > limit;
  const page = hasMore ? rows.slice(0, limit) : rows;
  const snapshot = await getSnapshot().catch(() => null);

  return {
    items: page.map((p) => ({
      id: p.id,
      cardId: p.cardId,
      rarity: p.rarity,
      isNew: p.isNew,
      wasPity: p.wasPity,
      batchId: p.batchId,
      createdAt: p.createdAt,
      card: snapshot?.byId.get(p.cardId) ?? null,
    })),
    nextCursor: hasMore ? page[page.length - 1]!.id : null,
  };
}

export const __internal = { cardIndex, priceOf };

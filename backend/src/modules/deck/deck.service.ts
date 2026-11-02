import type { Deck, DeckCard } from '@prisma/client';
import { prisma } from '../../config/prisma.js';
import { MAX_DECKS } from '../../config/economy.js';
import { AppError } from '../../lib/errors.js';
import { getSnapshot } from '../catalog/catalog.service.js';
import type { Card } from '../catalog/catalog.schema.js';
import { validateDeck, type DeckEntry, type DeckValidation } from './deck.rules.js';

export type DeckPayload = {
  name?: string;
  cards?: DeckEntry[];
};

type DeckWithCards = Deck & { cards: DeckCard[] };

function shape(deck: DeckWithCards, cardsById: Map<string, Card>, validation: DeckValidation) {
  return {
    id: deck.id,
    name: deck.name,
    isActive: deck.isActive,
    cardCount: validation.cardCount,
    isValid: validation.valid,
    violations: validation.violations,
    curve: validation.curve,
    updatedAt: deck.updatedAt,
    cards: deck.cards.map((c) => ({
      cardId: c.cardId,
      quantity: c.quantity,
      card: cardsById.get(c.cardId) ?? null,
    })),
  };
}

async function ownedMap(userId: string): Promise<Map<string, number>> {
  const rows = await prisma.inventoryCard.findMany({
    where: { userId },
    select: { cardId: true, quantity: true },
  });
  return new Map(rows.map((r) => [r.cardId, r.quantity]));
}

async function validateEntries(userId: string, entries: DeckEntry[]) {
  const [snapshot, owned] = await Promise.all([getSnapshot(), ownedMap(userId)]);
  const validation = validateDeck(entries, owned, snapshot.byId);
  return { validation, cardsById: snapshot.byId };
}

function rejectInvalid(validation: DeckValidation): void {
  if (!validation.valid) {
    throw new AppError('DECK_INVALID', 'Deck tidak valid', {
      violations: validation.violations,
      cardCount: validation.cardCount,
    });
  }
}

export async function listDecks(userId: string) {
  const [decks, snapshot, owned] = await Promise.all([
    prisma.deck.findMany({
      where: { userId },
      include: { cards: true },
      orderBy: [{ isActive: 'desc' }, { updatedAt: 'desc' }],
    }),
    getSnapshot(),
    ownedMap(userId),
  ]);

  return decks.map((deck) => {
    const validation = validateDeck(deck.cards, owned, snapshot.byId);
    return shape(deck, snapshot.byId, validation);
  });
}

async function deckWithCards(userId: string, deckId: string): Promise<DeckWithCards> {
  const deck = await prisma.deck.findFirst({
    where: { id: deckId, userId },
    include: { cards: true },
  });
  if (!deck) throw new AppError('NOT_FOUND', 'Deck tidak ditemukan');
  return deck;
}

export async function getDeck(userId: string, deckId: string) {
  const [deck, snapshot] = await Promise.all([deckWithCards(userId, deckId), getSnapshot()]);
  const owned = await ownedMap(userId);
  const validation = validateDeck(deck.cards, owned, snapshot.byId);
  return shape(deck, snapshot.byId, validation);
}

/** Dipakai battle start: deck harus valid & milik user. */
export async function getValidatedDeck(userId: string, deckId: string) {
  const [deck, snapshot] = await Promise.all([deckWithCards(userId, deckId), getSnapshot()]);
  const owned = await ownedMap(userId);
  const validation = validateDeck(deck.cards, owned, snapshot.byId);
  if (!validation.valid) {
    throw new AppError('DECK_INVALID', 'Deck aktif tidak valid', {
      violations: validation.violations,
    });
  }
  const cards: Card[] = [];
  for (const entry of deck.cards) {
    const card = snapshot.byId.get(entry.cardId);
    if (!card) {
      throw new AppError('DECK_INVALID', `Kartu ${entry.cardId} tidak ada di katalog`);
    }
    for (let i = 0; i < entry.quantity; i += 1) cards.push(card);
  }
  return { deck, validation, cards, catalogVersion: snapshot.version };
}

export async function createDeck(userId: string, payload: DeckPayload) {
  const name = (payload.name ?? '').trim();
  const entries = payload.cards ?? [];
  const { validation, cardsById } = await validateEntries(userId, entries);
  rejectInvalid(validation);

  const count = await prisma.deck.count({ where: { userId } });
  if (count >= MAX_DECKS) {
    throw new AppError('DECK_INVALID', `Maksimal ${MAX_DECKS} deck per akun`, {
      violations: [
        {
          code: 'DECK_LIMIT_REACHED',
          message: `Maksimal ${MAX_DECKS} deck`,
          limit: MAX_DECKS,
        },
      ],
    });
  }

  try {
    const deck = await prisma.$transaction(async (tx) => {
      const created = await tx.deck.create({
        data: {
          userId,
          name,
          cards: {
            createMany: {
              data: entries.map((c) => ({ cardId: c.cardId, quantity: c.quantity })),
            },
          },
        },
        include: { cards: true },
      });

      if (count === 0) {
        await tx.deck.update({ where: { id: created.id }, data: { isActive: true } });
        await tx.user.update({ where: { id: userId }, data: { activeDeckId: created.id } });
        created.isActive = true;
      }
      return created;
    });

    return shape(deck, cardsById, validation);
  } catch (err) {
    if ((err as { code?: string }).code === 'P2002') {
      throw new AppError('DECK_NAME_TAKEN', 'Nama deck sudah dipakai');
    }
    throw err;
  }
}

export async function updateDeck(userId: string, deckId: string, payload: DeckPayload) {
  const existing = await deckWithCards(userId, deckId);
  const entries = payload.cards;

  let cardsById: Map<string, Card> | null = null;
  if (entries) {
    const result = await validateEntries(userId, entries);
    rejectInvalid(result.validation);
    cardsById = result.cardsById;
  }

  try {
    const deck = await prisma.$transaction(async (tx) => {
      await tx.deck.update({
        where: { id: existing.id },
        data: {
          ...(payload.name ? { name: payload.name.trim() } : {}),
          ...(entries
            ? {
                cards: {
                  deleteMany: {},
                  createMany: {
                    data: entries.map((c) => ({
                      cardId: c.cardId,
                      quantity: c.quantity,
                    })),
                  },
                },
              }
            : {}),
        },
      });

      return tx.deck.findUniqueOrThrow({
        where: { id: existing.id },
        include: { cards: true },
      });
    });

    const snapshot = cardsById ?? (await getSnapshot()).byId;
    const owned = await ownedMap(userId);
    const finalValidation = validateDeck(deck.cards, owned, snapshot);
    return shape(deck, snapshot, finalValidation);
  } catch (err) {
    if ((err as { code?: string }).code === 'P2002') {
      throw new AppError('DECK_NAME_TAKEN', 'Nama deck sudah dipakai');
    }
    throw err;
  }
}

export async function deleteDeck(userId: string, deckId: string) {
  const deck = await deckWithCards(userId, deckId);

  await prisma.$transaction(async (tx) => {
    await tx.deck.delete({ where: { id: deck.id } });
    if (deck.isActive) {
      await tx.user.updateMany({
        where: { id: userId, activeDeckId: deck.id },
        data: { activeDeckId: null },
      });
    }
  });
}

export async function activateDeck(userId: string, deckId: string) {
  await deckWithCards(userId, deckId);

  await prisma.$transaction(async (tx) => {
    await tx.deck.updateMany({ where: { userId }, data: { isActive: false } });
    await tx.deck.update({ where: { id: deckId }, data: { isActive: true } });
    await tx.user.update({ where: { id: userId }, data: { activeDeckId: deckId } });
  });

  return getDeck(userId, deckId);
}

export async function validateOnly(userId: string, entries: DeckEntry[]) {
  const { validation } = await validateEntries(userId, entries);
  return validation;
}

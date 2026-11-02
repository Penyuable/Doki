import {
  DECK_SIZE,
  MAX_COPIES_PER_CARD,
} from '../../config/economy.js';
import type { Card } from '../catalog/catalog.schema.js';

export type DeckEntry = { cardId: string; quantity: number };

export type ViolationCode =
  | 'DECK_SIZE'
  | 'COPY_LIMIT_EXCEEDED'
  | 'CARD_NOT_OWNED'
  | 'CARD_NOT_PLAYABLE'
  | 'CARD_NOT_FOUND'
  | 'DUPLICATE_ENTRY'
  | 'DECK_LIMIT_REACHED';

export type Violation = {
  code: ViolationCode;
  cardId?: string;
  message: string;
  actual?: number;
  limit?: number;
};

export type DeckValidation = {
  valid: boolean;
  cardCount: number;
  violations: Violation[];
  curve: Record<number, number>;
};

export function validateDeck(
  entries: DeckEntry[],
  owned: Map<string, number>,
  catalog: Map<string, Card>,
): DeckValidation {
  const violations: Violation[] = [];
  const seen = new Set<string>();
  const totals = new Map<string, number>();
  const curve: Record<number, number> = {};
  let cardCount = 0;

  for (const entry of entries) {
    const qty = Number(entry.quantity);

    if (seen.has(entry.cardId)) {
      violations.push({
        code: 'DUPLICATE_ENTRY',
        cardId: entry.cardId,
        message: 'Kartu muncul lebih dari satu baris di payload',
      });
    }
    seen.add(entry.cardId);

    if (!Number.isInteger(qty) || qty < 1) {
      violations.push({
        code: 'COPY_LIMIT_EXCEEDED',
        cardId: entry.cardId,
        message: 'Quantity harus minimal 1',
        actual: qty,
        limit: MAX_COPIES_PER_CARD,
      });
      continue;
    }

    const card = catalog.get(entry.cardId);
    if (!card) {
      violations.push({
        code: 'CARD_NOT_FOUND',
        cardId: entry.cardId,
        message: 'Kartu tidak ada di katalog',
      });
      continue;
    }

    if (card.type !== 'unit' && card.type !== 'spell') {
      violations.push({
        code: 'CARD_NOT_PLAYABLE',
        cardId: entry.cardId,
        message: 'Kartu tidak bisa dimainkan di deck',
      });
    }

    totals.set(entry.cardId, (totals.get(entry.cardId) ?? 0) + qty);
    cardCount += qty;
    curve[card.cost] = (curve[card.cost] ?? 0) + qty;
  }

  // Batas copy dihitung dari TOTAL per kartu, bukan per baris,
  // agar payload [2,2] juga tertangkap.
  for (const [cardId, total] of totals) {
    if (total > MAX_COPIES_PER_CARD) {
      violations.push({
        code: 'COPY_LIMIT_EXCEEDED',
        cardId,
        message: `Maksimal ${MAX_COPIES_PER_CARD} copy per kartu`,
        actual: total,
        limit: MAX_COPIES_PER_CARD,
      });
    }

    const ownedQty = owned.get(cardId) ?? 0;
    if (ownedQty < total) {
      violations.push({
        code: 'CARD_NOT_OWNED',
        cardId,
        message: 'Jumlah kartu melebihi yang dimiliki',
        actual: total,
        limit: ownedQty,
      });
    }
  }

  if (cardCount !== DECK_SIZE) {
    violations.push({
      code: 'DECK_SIZE',
      message: `Deck harus tepat ${DECK_SIZE} kartu`,
      actual: cardCount,
      limit: DECK_SIZE,
    });
  }

  return {
    valid: violations.length === 0,
    cardCount,
    violations,
    curve,
  };
}

export function assertValid(validation: DeckValidation): void {
  if (!validation.valid) {
    const err = new Error('Deck tidak valid');
    Object.assign(err, { validation });
    throw err;
  }
}

/**
 * Aturan deck sisi klien (port `domain/deck_rules.dart`) — hanya untuk umpan
 * balik UI. Validasi otoritatif tetap di server / backend lokal (I-03).
 */
import { GameConfig } from '../config/game-config.ts';
import type { Card } from './card.ts';

export type DeckRuleViolation = {
  code: string;
  message: string;
  cardId?: string;
  actual?: number;
  limit?: number;
};

export type DeckValidationResult = {
  valid: boolean;
  cardCount: number;
  violations: DeckRuleViolation[];
  curve: Map<number, number>;
};

export function validateDeck(input: {
  entries: ReadonlyMap<string, number>;
  owned: ReadonlyMap<string, number>;
  catalog: ReadonlyMap<string, Card>;
}): DeckValidationResult {
  const violations: DeckRuleViolation[] = [];
  const curve = new Map<number, number>();
  let cardCount = 0;

  for (const [cardId, quantity] of input.entries) {
    if (quantity <= 0) continue;

    if (quantity > GameConfig.maxCopiesPerCard) {
      violations.push({
        code: 'COPY_LIMIT_EXCEEDED',
        cardId,
        message: `Maksimal ${GameConfig.maxCopiesPerCard} copy per kartu`,
        actual: quantity,
        limit: GameConfig.maxCopiesPerCard,
      });
    }

    const card = input.catalog.get(cardId);
    if (!card) {
      violations.push({ code: 'CARD_NOT_FOUND', cardId, message: 'Kartu tidak ada di katalog' });
      continue;
    }

    if (card.type !== 'unit' && card.type !== 'spell') {
      violations.push({ code: 'CARD_NOT_PLAYABLE', cardId, message: 'Kartu tidak bisa dimainkan' });
    }

    const ownedCount = input.owned.get(cardId) ?? 0;
    if (ownedCount < quantity) {
      violations.push({
        code: 'CARD_NOT_OWNED',
        cardId,
        message: 'Jumlah kartu melebihi yang dimiliki',
        actual: quantity,
        limit: ownedCount,
      });
    }

    cardCount += quantity;
    curve.set(card.cost, (curve.get(card.cost) ?? 0) + quantity);
  }

  if (cardCount !== GameConfig.deckSize) {
    violations.push({
      code: 'DECK_SIZE',
      message: `Deck harus tepat ${GameConfig.deckSize} kartu`,
      actual: cardCount,
      limit: GameConfig.deckSize,
    });
  }

  return { valid: violations.length === 0, cardCount, violations, curve };
}

/** Apakah satu copy lagi boleh ditambahkan? Dipakai UI untuk disable tombol. */
export function canAddCard(input: { entries: ReadonlyMap<string, number>; cardId: string; ownedCount: number }): boolean {
  const current = input.entries.get(input.cardId) ?? 0;
  if (current >= GameConfig.maxCopiesPerCard) return false;
  if (current >= input.ownedCount) return false;
  let total = 0;
  for (const value of input.entries.values()) total += value;
  return total < GameConfig.deckSize;
}

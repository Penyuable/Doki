import { describe, expect, it } from 'vitest';
import { validateDeck, type DeckEntry } from '../src/modules/deck/deck.rules.js';
import type { Card } from '../src/modules/catalog/catalog.schema.js';

function card(id: string, cost = 2, type: 'unit' | 'spell' = 'unit'): Card {
  return {
    id,
    name: id,
    element: 'Fire',
    rarity: 'Common',
    type,
    cost,
    hp: type === 'unit' ? 100 : null,
    attack: type === 'unit' ? 30 : null,
    defense: type === 'unit' ? 20 : null,
    keywords: [],
    ability:
      type === 'spell'
        ? {
            name: 'Test',
            type: 'attack',
            cost: 0,
            target: 'enemy_unit',
            power: 30,
            text: 'Deal 30 damage.',
          }
        : null,
    imageUrl: 'https://example.com/x.webp',
    obtainable: true,
    version: 1,
  };
}

const catalog = new Map<string, Card>([
  ['card_001', card('card_001', 1)],
  ['card_002', card('card_002', 2)],
  ['card_003', card('card_003', 3)],
  ['card_004', card('card_004', 4)],
  ['card_005', card('card_005', 5)],
  ['card_006', card('card_006', 6)],
  ['card_007', card('card_007', 2)],
]);

const owned = new Map<string, number>([
  ['card_001', 3],
  ['card_002', 3],
  ['card_003', 3],
  ['card_004', 3],
  ['card_005', 3],
  ['card_006', 3],
  ['card_007', 3],
]);

const validDeck: DeckEntry[] = [
  { cardId: 'card_001', quantity: 3 },
  { cardId: 'card_002', quantity: 3 },
  { cardId: 'card_003', quantity: 3 },
  { cardId: 'card_004', quantity: 3 },
  { cardId: 'card_005', quantity: 3 },
  { cardId: 'card_006', quantity: 3 },
  { cardId: 'card_007', quantity: 2 },
];

describe('validateDeck', () => {
  it('20 kartu, 3 copy maks → valid', () => {
    const result = validateDeck(validDeck, owned, catalog);
    expect(result.valid).toBe(true);
    expect(result.cardCount).toBe(20);
    expect(result.violations).toHaveLength(0);
    expect(result.curve[1]).toBe(3);
  });

  it('19 kartu → DECK_SIZE', () => {
    const deck = validDeck.map((e, i) => (i === 0 ? { ...e, quantity: 2 } : e));
    const result = validateDeck(deck, owned, catalog);
    expect(result.valid).toBe(false);
    expect(result.violations.map((v) => v.code)).toContain('DECK_SIZE');
    expect(result.violations.find((v) => v.code === 'DECK_SIZE')?.actual).toBe(19);
  });

  it('4 copy → COPY_LIMIT_EXCEEDED', () => {
    const deck = [...validDeck, { cardId: 'card_001', quantity: 1 }];
    const result = validateDeck(deck, owned, catalog);
    expect(result.violations.some((v) => v.code === 'COPY_LIMIT_EXCEEDED')).toBe(true);
  });

  it('kartu tidak dimiliki → CARD_NOT_OWNED', () => {
    const result = validateDeck(
      validDeck,
      new Map([['card_001', 1]]),
      catalog,
    );
    const codes = result.violations.map((v) => v.code);
    expect(codes).toContain('CARD_NOT_OWNED');
    expect(codes).not.toContain('CARD_NOT_FOUND');
  });

  it('kartu tidak ada di katalog → CARD_NOT_FOUND', () => {
    const deck = [...validDeck.slice(0, 6), { cardId: 'card_999', quantity: 2 }];
    const result = validateDeck(deck, owned, catalog);
    expect(result.violations.map((v) => v.code)).toContain('CARD_NOT_FOUND');
  });

  it('entri duplikat terdeteksi', () => {
    const deck = [...validDeck, { cardId: 'card_001', quantity: 1 }];
    const result = validateDeck(deck, owned, catalog);
    expect(result.violations.map((v) => v.code)).toContain('DUPLICATE_ENTRY');
  });
});

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { parseCards, type Card } from '../../src/lib/domain/card.ts';

const seedPath = fileURLToPath(new URL('../../src/data/cards.seed.json', import.meta.url));

export const rawCatalog: unknown[] = JSON.parse(readFileSync(seedPath, 'utf8'));
export const catalog: Card[] = parseCards(rawCatalog);
export const byId = new Map(catalog.map((card) => [card.id, card]));

export const STARTER: Array<[string, number]> = [
  ['card_001', 3],
  ['card_002', 3],
  ['card_003', 3],
  ['card_004', 3],
  ['card_005', 3],
  ['card_006', 3],
  ['card_007', 2],
];

export function starterDeck(): Card[] {
  const out: Card[] = [];
  for (const [id, qty] of STARTER) {
    const card = byId.get(id);
    if (!card) throw new Error(`kartu ${id} tidak ada`);
    for (let i = 0; i < qty; i += 1) out.push(card);
  }
  return out;
}

/** Deck bot golden: 20 kartu katalog mulai indeks 7 (sama dengan skrip Dart referensi). */
export function goldenBotDeck(): Card[] {
  return Array.from({ length: 20 }, (_, i) => catalog[(i + 7) % catalog.length] as Card);
}

let counter = 0;

/** Kartu sintetis untuk edge case engine. */
export function makeCard(overrides: Partial<Card> = {}): Card {
  counter += 1;
  return {
    id: `t_${counter}`,
    name: `Test ${counter}`,
    element: 'Void',
    rarity: 'Common',
    type: 'unit',
    cost: 1,
    hp: 50,
    attack: 20,
    defense: 0,
    keywords: [],
    ability: null,
    flavorText: '',
    imageUrl: '',
    thumbnailUrl: null,
    model3dUrl: null,
    obtainable: true,
    retired: false,
    version: 1,
    ...overrides,
  };
}

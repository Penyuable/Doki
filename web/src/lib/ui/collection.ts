/** Filter & urutan koleksi (port logika `features/collection/collection_cubit.dart`). */
import { rarityIndex, type Card, type CardElement, type CardType, type Rarity } from '../domain/card.ts';

export const COLLECTION_SORTS = ['rarity', 'name', 'newest', 'attack', 'hp'] as const;
export type CollectionSort = (typeof COLLECTION_SORTS)[number];

export type CollectionFilter = {
  element: CardElement | null;
  rarity: Rarity | null;
  type: CardType | null;
  /** null = semua, true = hanya dimiliki, false = hanya belum dimiliki. */
  ownedOnly: boolean | null;
  query: string;
  sort: CollectionSort;
};

export const DEFAULT_FILTER: CollectionFilter = {
  element: null,
  rarity: null,
  type: null,
  ownedOnly: null,
  query: '',
  sort: 'rarity',
};

export const isDefaultFilter = (f: CollectionFilter): boolean =>
  f.element === null && f.rarity === null && f.type === null && f.ownedOnly === null && f.query.trim() === '' && f.sort === 'rarity';

/** Perbandingan per code unit UTF-16 (sama dengan `String.compareTo` Dart). */
export const compareText = (a: string, b: string): number => (a < b ? -1 : a > b ? 1 : 0);

export function applyCollectionFilter(
  cards: readonly Card[],
  filter: CollectionFilter,
  owned: ReadonlyMap<string, number>,
  firstSeen: ReadonlyMap<string, Date | null> = new Map(),
): Card[] {
  const query = filter.query.trim().toLowerCase();
  const result = cards.filter((card) => {
    if (card.retired) return false;
    const quantity = owned.get(card.id) ?? 0;
    if (filter.ownedOnly === true && quantity <= 0) return false;
    if (filter.ownedOnly === false && quantity > 0) return false;
    if (filter.element !== null && card.element !== filter.element) return false;
    if (filter.rarity !== null && card.rarity !== filter.rarity) return false;
    if (filter.type !== null && card.type !== filter.type) return false;
    if (query && !card.name.toLowerCase().includes(query) && !card.id.toLowerCase().includes(query)) return false;
    return true;
  });

  return result.sort((a, b) => {
    switch (filter.sort) {
      case 'rarity': {
        const diff = rarityIndex(b.rarity) - rarityIndex(a.rarity);
        return diff !== 0 ? diff : compareText(a.name, b.name);
      }
      case 'name':
        return compareText(a.name, b.name);
      case 'newest': {
        const aDate = firstSeen.get(a.id) ?? null;
        const bDate = firstSeen.get(b.id) ?? null;
        if (!aDate && !bDate) return compareText(a.name, b.name);
        if (!aDate) return 1;
        if (!bDate) return -1;
        return bDate.getTime() - aDate.getTime();
      }
      case 'attack': {
        const diff = (b.attack ?? 0) - (a.attack ?? 0);
        return diff !== 0 ? diff : compareText(a.name, b.name);
      }
      case 'hp': {
        const diff = (b.hp ?? 0) - (a.hp ?? 0);
        return diff !== 0 ? diff : compareText(a.name, b.name);
      }
    }
  });
}

/** State deck builder murni (port `features/deck/deck_builder_cubit.dart`). */
import { GameConfig } from '../config/game-config.ts';
import { canAddCard, validateDeck, type DeckValidationResult } from '../domain/deck-rules.ts';
import type { Card } from '../domain/card.ts';

export type DeckDraft = {
  deckId: string | null;
  name: string;
  entries: Map<string, number>;
};

export const nameValid = (name: string): boolean => {
  const trimmed = name.trim();
  return trimmed.length >= 3 && trimmed.length <= 24;
};

export const totalCards = (entries: ReadonlyMap<string, number>): number => {
  let total = 0;
  for (const value of entries.values()) total += value;
  return total;
};

export function addCard(draft: DeckDraft, cardId: string, owned: ReadonlyMap<string, number>): DeckDraft | null {
  if (!canAddCard({ entries: draft.entries, cardId, ownedCount: owned.get(cardId) ?? 0 })) return null;
  const entries = new Map(draft.entries);
  entries.set(cardId, (entries.get(cardId) ?? 0) + 1);
  return { ...draft, entries };
}

export function removeCard(draft: DeckDraft, cardId: string): DeckDraft {
  const current = draft.entries.get(cardId) ?? 0;
  if (current <= 0) return draft;
  const entries = new Map(draft.entries);
  if (current === 1) entries.delete(cardId);
  else entries.set(cardId, current - 1);
  return { ...draft, entries };
}

export function validateDraft(
  draft: DeckDraft,
  owned: ReadonlyMap<string, number>,
  catalog: ReadonlyMap<string, Card>,
): DeckValidationResult & { canSave: boolean } {
  const result = validateDeck({ entries: draft.entries, owned, catalog });
  return { ...result, canSave: result.valid && nameValid(draft.name) };
}

/** Kurva biaya 0..7+ untuk grafik. */
export function curveBuckets(curve: ReadonlyMap<number, number>, maxBucket = 7): number[] {
  const buckets = new Array<number>(maxBucket + 1).fill(0);
  for (const [cost, qty] of curve) {
    const index = Math.min(maxBucket, Math.max(0, cost));
    buckets[index] = (buckets[index] ?? 0) + qty;
  }
  return buckets;
}

export const DECK_SIZE = GameConfig.deckSize;

/** Nama default "Deck N" yang belum dipakai (port `_defaultName`). */
export function defaultDeckName(existing: readonly string[]): string {
  const used = new Set(existing.map((name) => name.toLowerCase()));
  let index = existing.length + 1;
  let candidate = `Deck ${index}`;
  while (used.has(candidate.toLowerCase())) {
    index += 1;
    candidate = `Deck ${index}`;
  }
  return candidate;
}

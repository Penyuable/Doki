import crypto from 'node:crypto';
import {
  GACHA_RATES,
  PITY_BONUS_WEIGHTS,
  PITY_THRESHOLD,
  RARITIES,
  type Rarity,
} from '../../config/economy.js';

export type Weighted<T> = { value: T; weight: number };

export const RARITY_ORDER = RARITIES;

export const raritiesOf = (): Rarity[] => [...RARITIES];

export const defaultRng = (): number => crypto.randomInt(0, 1_000_000) / 1_000_000;

export function weightedPick<T>(items: ReadonlyArray<Weighted<T>>, rng: () => number): T {
  const total = items.reduce((sum, i) => sum + i.weight, 0);
  if (total <= 0) throw new Error('weightedPick: total weight harus > 0');

  let roll = rng() * total;
  if (!Number.isFinite(roll) || roll < 0) roll = 0;
  if (roll >= total) roll = total - 1e-9;

  let acc = 0;
  for (const item of items) {
    acc += item.weight;
    if (roll < acc) return item.value;
  }
  return items[items.length - 1]!.value;
}

export function rollRarity(
  pityCounter: number,
  rng: () => number = defaultRng,
): { rarity: Rarity; wasPity: boolean } {
  if (pityCounter >= PITY_THRESHOLD - 1) {
    return {
      rarity: weightedPick(
        PITY_BONUS_WEIGHTS.map((w) => ({ value: w.rarity, weight: w.weight })),
        rng,
      ),
      wasPity: true,
    };
  }
  return {
    rarity: weightedPick(
      GACHA_RATES.map((w) => ({ value: w.rarity, weight: w.weight })),
      rng,
    ),
    wasPity: false,
  };
}

export function uniformPick<T>(items: readonly T[], rng: () => number): T {
  if (items.length === 0) throw new Error('uniformPick: daftar kosong');
  const idx = Math.min(items.length - 1, Math.max(0, Math.floor(rng() * items.length)));
  return items[idx]!;
}

/** Turun satu tier sampai ditemukan rarity yang punya kartu obtainable. */
export function fallbackRarity(rarity: Rarity, available: Set<Rarity>): Rarity {
  let idx = RARITIES.indexOf(rarity);
  while (idx >= 0) {
    const candidate = RARITIES[idx]!;
    if (available.has(candidate)) return candidate;
    idx -= 1;
  }
  return RARITIES[0]!;
}

export function isRarePlus(rarity: Rarity): boolean {
  return RARITIES.indexOf(rarity) >= RARITIES.indexOf('Rare');
}

/**
 * 10x guarantee: bila tidak ada Rare+, hasil terakhir di-upgrade.
 * Mengembalikan rarity final untuk indeks terakhir.
 */
export function tenPullUpgrade(
  rarities: Rarity[],
  wasPityLast: boolean,
  rng: () => number = defaultRng,
): { rarity: Rarity; guaranteed: boolean } {
  if (rarities.some(isRarePlus)) return { rarity: rarities[rarities.length - 1]!, guaranteed: false };

  if (wasPityLast) {
    return {
      rarity: weightedPick(
        PITY_BONUS_WEIGHTS.map((w) => ({ value: w.rarity, weight: w.weight })),
        rng,
      ),
      guaranteed: true,
    };
  }
  return { rarity: 'Rare', guaranteed: true };
}

export const RATE_TABLE = GACHA_RATES.map((r) => ({
  rarity: r.rarity,
  weight: r.weight,
  percent: Number(((r.weight / 10_000) * 100).toFixed(2)),
}));

export const PITY_INFO = {
  threshold: PITY_THRESHOLD,
  bonusWeights: PITY_BONUS_WEIGHTS,
};

/**
 * Satu sumber angka ekonomi & gacha (PRD §6 FR-04, §8).
 * Jangan hardcode angka ini di service/route lain.
 */

export const RARITIES = [
  'Common',
  'Uncommon',
  'Rare',
  'Epic',
  'Legendary',
  'Master',
] as const;

export type Rarity = (typeof RARITIES)[number];

export const GACHA_RATES: ReadonlyArray<{ rarity: Rarity; weight: number }> = [
  { rarity: 'Common', weight: 6000 },
  { rarity: 'Uncommon', weight: 2500 },
  { rarity: 'Rare', weight: 1000 },
  { rarity: 'Epic', weight: 400 },
  { rarity: 'Legendary', weight: 90 },
  { rarity: 'Master', weight: 10 },
];

export const PITY_THRESHOLD = 50;

export const PITY_BONUS_WEIGHTS: ReadonlyArray<{ rarity: Rarity; weight: number }> = [
  { rarity: 'Epic', weight: 800 },
  { rarity: 'Legendary', weight: 180 },
  { rarity: 'Master', weight: 20 },
];

export const GACHA_PRICE = {
  1: { gold: 100, gem: 1 },
  10: { gold: 900, gem: 9 },
} as const;

export const TEN_PULL_SIZE = 10;
export const GUARANTEED_RARE_PLUS_ON_TEN = true;

export const STARTING_BALANCE = { gold: 1000, gems: 50 } as const;

export const BATTLE_REWARDS: Record<
  'easy' | 'medium' | 'master',
  { gold: number; xp: number }
> = {
  easy: { gold: 40, xp: 30 },
  medium: { gold: 80, xp: 60 },
  master: { gold: 150, xp: 120 },
};

export const LOSS_XP = 10;
export const DRAW_XP = 15;
export const FIRST_WIN_BONUS_GOLD = 200;
export const DAILY_REWARDED_MATCH_LIMIT = 40;
export const MAX_DECKS = 10;
export const DECK_SIZE = 20;
export const MAX_COPIES_PER_CARD = 3;

export const DAILY_REWARDS: ReadonlyArray<{ day: number; gold: number; gems: number }> = [
  { day: 1, gold: 100, gems: 0 },
  { day: 2, gold: 150, gems: 0 },
  { day: 3, gold: 200, gems: 0 },
  { day: 4, gold: 250, gems: 0 },
  { day: 5, gold: 300, gems: 0 },
  { day: 6, gold: 400, gems: 0 },
  { day: 7, gold: 400, gems: 1 },
];

export const LEVEL_UP_REWARD = { gold: 200, gems: 5 } as const;

/** XP untuk naik dari `level` ke `level + 1`. */
export function xpToNext(level: number): number {
  return 100 + 50 * (level - 1);
}

/**
 * Terapkan XP dengan carry-over. Murni — tidak menyentuh DB.
 * @returns nilai baru + reward level up (bisa lebih dari satu level).
 */
export function applyXp(
  level: number,
  xp: number,
  amount: number,
): { level: number; xp: number; levelsGained: number; gold: number; gems: number } {
  let nextLevel = level;
  let nextXp = xp + Math.max(0, amount);
  let levelsGained = 0;

  while (nextXp >= xpToNext(nextLevel) && levelsGained < 100) {
    nextXp -= xpToNext(nextLevel);
    nextLevel += 1;
    levelsGained += 1;
  }

  return {
    level: nextLevel,
    xp: nextXp,
    levelsGained,
    gold: levelsGained * LEVEL_UP_REWARD.gold,
    gems: levelsGained * LEVEL_UP_REWARD.gems,
  };
}

export const STARTER_DECK: ReadonlyArray<{ cardId: string; quantity: number }> = [
  { cardId: 'card_001', quantity: 3 },
  { cardId: 'card_002', quantity: 3 },
  { cardId: 'card_003', quantity: 3 },
  { cardId: 'card_004', quantity: 3 },
  { cardId: 'card_005', quantity: 3 },
  { cardId: 'card_006', quantity: 3 },
  { cardId: 'card_007', quantity: 2 },
];

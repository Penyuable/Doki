/**
 * Angka permainan yang mengikat (PRD §6–§9) — cermin dari
 * `frontend/lib/core/config/game_config.dart` dan `backend/src/config/economy.ts`.
 * UI tidak boleh hardcode angka; baca dari sini atau dari respons server (I-06).
 */
export const GameConfig = {
  playerHp: 200,
  maxEnergy: 10,
  startingEnergy: 1,
  boardSlots: 3,
  startingHand: 4,
  handLimit: 8,
  maxTurns: 50,

  deckSize: 20,
  maxCopiesPerCard: 3,
  maxDecks: 10,

  pityThreshold: 50,

  gachaGoldPrice: { 1: 100, 10: 900 } as Record<1 | 10, number>,
  gachaGemPrice: { 1: 1, 10: 9 } as Record<1 | 10, number>,

  battleRewards: {
    easy: { gold: 40, xp: 30 },
    medium: { gold: 80, xp: 60 },
    master: { gold: 150, xp: 120 },
  } as Record<Difficulty, { gold: number; xp: number }>,

  lossXp: 10,
  drawXp: 15,
  firstWinBonusGold: 200,

  dailyRewardGold: [100, 150, 200, 250, 300, 400, 400] as readonly number[],
  dailyRewardGems: [0, 0, 0, 0, 0, 0, 1] as readonly number[],
} as const;

export const DIFFICULTIES = ['easy', 'medium', 'master'] as const;
export type Difficulty = (typeof DIFFICULTIES)[number];

export function xpToNext(level: number): number {
  return 100 + 50 * (level - 1);
}

export function isDifficulty(value: unknown): value is Difficulty {
  return typeof value === 'string' && (DIFFICULTIES as readonly string[]).includes(value);
}

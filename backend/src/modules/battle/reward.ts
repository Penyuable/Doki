import {
  BATTLE_REWARDS,
  DRAW_XP,
  FIRST_WIN_BONUS_GOLD,
  LOSS_XP,
} from '../../config/economy.js';

export type Difficulty = 'easy' | 'medium' | 'master';
export type Outcome = 'win' | 'loss' | 'draw';

export const DIFFICULTIES: Difficulty[] = ['easy', 'medium', 'master'];
export const OUTCOMES: Outcome[] = ['win', 'loss', 'draw'];

export function isDifficulty(value: string): value is Difficulty {
  return (DIFFICULTIES as string[]).includes(value);
}

export function isOutcome(value: string): value is Outcome {
  return (OUTCOMES as string[]).includes(value);
}

export function baseReward(difficulty: Difficulty, outcome: Outcome) {
  if (outcome === 'win') return BATTLE_REWARDS[difficulty];
  return { gold: 0, xp: outcome === 'loss' ? LOSS_XP : DRAW_XP };
}

export const firstWinBonus = FIRST_WIN_BONUS_GOLD;

/**
 * Model respons API (port `domain/models/*.dart`). Semua parser defensif:
 * field yang hilang jatuh ke default aman, tidak pernah melempar.
 */
import { asBool, asDate, asInt, asIntOrNull, asList, asMap, asNumber, asString, asStringOrNull, enumFrom } from '../core/json.ts';
import { DIFFICULTIES, type Difficulty } from '../config/game-config.ts';
import { RARITIES, isRarePlus, parseCard, parseCards, type Card, type Rarity } from './card.ts';

// ------------------------------------------------------------------- user

export type User = {
  id: string;
  email: string;
  username: string;
  gold: number;
  gems: number;
  level: number;
  xp: number;
  wins: number;
  losses: number;
  draws: number;
  pityCounter: number;
  createdAt: Date | null;
};

export function parseUser(raw: unknown): User {
  const j = asMap(raw);
  return {
    id: asString(j.id),
    email: asString(j.email),
    username: asString(j.username),
    gold: asInt(j.gold),
    gems: asInt(j.gems),
    level: asInt(j.level, 1),
    xp: asInt(j.xp),
    wins: asInt(j.wins),
    losses: asInt(j.losses),
    draws: asInt(j.draws),
    pityCounter: asInt(j.pityCounter),
    createdAt: asDate(j.createdAt),
  };
}

export type UserStats = { wins: number; losses: number; draws: number; total: number; winRate: number | null };

export const EMPTY_STATS: UserStats = { wins: 0, losses: 0, draws: 0, total: 0, winRate: null };

export function parseStats(raw: unknown): UserStats {
  const j = asMap(raw);
  return {
    wins: asInt(j.wins),
    losses: asInt(j.losses),
    draws: asInt(j.draws),
    total: asInt(j.total),
    winRate: j.winRate == null ? null : asNumber(j.winRate),
  };
}

export type Wallet = { gold: number; gems: number };

export function parseWallet(raw: unknown): Wallet {
  const j = asMap(raw);
  return { gold: asInt(j.gold), gems: asInt(j.gems) };
}

export type AuthSession = { user: User; accessToken: string; refreshToken: string; expiresIn: number };

export function parseSession(raw: unknown): AuthSession {
  const j = asMap(raw);
  return {
    user: parseUser(j.user),
    accessToken: asString(j.accessToken),
    refreshToken: asString(j.refreshToken),
    expiresIn: asInt(j.expiresIn, 900),
  };
}

export type MeData = { user: User; stats: UserStats; activeDeckId: string | null };

export function parseMe(raw: unknown): MeData {
  const j = asMap(raw);
  return { user: parseUser(j.user), stats: parseStats(j.stats), activeDeckId: asStringOrNull(j.activeDeckId) };
}

export type UserProfile = {
  user: User;
  stats: UserStats;
  collection: { owned: number; total: number };
  daily: { streak: number; canClaim: boolean; lastClaimAt: Date | null };
  activeDeck: { id: string; name: string; cardCount: number } | null;
};

export function parseProfile(raw: unknown): UserProfile {
  const j = asMap(raw);
  const collection = asMap(j.collection);
  const daily = asMap(j.daily);
  const deck = asMap(j.activeDeck);
  return {
    user: parseUser(j.user),
    stats: parseStats(j.stats),
    collection: { owned: asInt(collection.owned), total: asInt(collection.total) },
    daily: { streak: asInt(daily.streak), canClaim: asBool(daily.canClaim), lastClaimAt: asDate(daily.lastClaimAt) },
    activeDeck:
      Object.keys(deck).length === 0
        ? null
        : { id: asString(deck.id), name: asString(deck.name), cardCount: asInt(deck.cardCount) },
  };
}

export type DailyClaimResult = { streak: number; day: number; gold: number; gems: number; balance: Wallet };

export function parseDailyClaim(raw: unknown): DailyClaimResult {
  const j = asMap(raw);
  const reward = asMap(j.reward);
  return {
    streak: asInt(j.streak),
    day: asInt(j.day, 1),
    gold: asInt(reward.gold),
    gems: asInt(reward.gems),
    balance: parseWallet(j.balance),
  };
}

// -------------------------------------------------------------- inventory

export type InventoryItem = { cardId: string; quantity: number; card: Card; firstSeenAt: Date | null };
export type InventoryPage = { items: InventoryItem[]; owned: number; total: number; nextCursor: number | null };

export function parseInventory(raw: unknown): InventoryPage {
  const j = asMap(raw);
  const items: InventoryItem[] = [];
  for (const value of asList(j.items)) {
    const row = asMap(value);
    const card = parseCard(row.card);
    if (!card) continue;
    items.push({ cardId: asString(row.cardId, card.id), quantity: asInt(row.quantity), card, firstSeenAt: asDate(row.firstSeenAt) });
  }
  return { items, owned: asInt(j.owned), total: asInt(j.total), nextCursor: asIntOrNull(j.nextCursor) };
}

// ------------------------------------------------------------------ gacha

export type PityInfo = { counter: number; threshold: number; guaranteedIn: number };

export function parsePity(raw: unknown): PityInfo {
  const j = asMap(raw);
  return { counter: asInt(j.counter), threshold: asInt(j.threshold, 50), guaranteedIn: asInt(j.guaranteedIn, 50) };
}

export const pityProgress = (pity: PityInfo): number =>
  pity.threshold <= 0 ? 0 : Math.min(1, Math.max(0, pity.counter / pity.threshold));

export type GachaPullResult = {
  cardId: string;
  rarity: Rarity;
  isNew: boolean;
  wasPity: boolean;
  guaranteedRare: boolean;
  card: Card | null;
};

export type GachaPullResponse = {
  batchId: string;
  results: GachaPullResult[];
  balance: Wallet;
  pity: PityInfo;
  replayed: boolean;
};

export function parsePullResponse(raw: unknown): GachaPullResponse {
  const j = asMap(raw);
  return {
    batchId: asString(j.batchId),
    results: asList(j.results).map((value) => {
      const r = asMap(value);
      return {
        cardId: asString(r.cardId),
        rarity: enumFrom(r.rarity, RARITIES, 'Common'),
        isNew: asBool(r.isNew),
        wasPity: asBool(r.wasPity),
        guaranteedRare: asBool(r.guaranteedRare),
        card: parseCard(r.card),
      };
    }),
    balance: parseWallet(j.balance),
    pity: parsePity(j.pity),
    replayed: asBool(j.replayed),
  };
}

export const hasRarePlus = (response: GachaPullResponse): boolean => response.results.some((r) => isRarePlus(r.rarity));

export type GachaRate = { rarity: Rarity; weight: number; percent: number };
export type GachaRatesData = { rates: GachaRate[]; pity: PityInfo; guaranteedRarePlusOnTen: boolean };

export function parseRates(raw: unknown): GachaRatesData {
  const j = asMap(raw);
  return {
    rates: asList(j.rates).map((value) => {
      const r = asMap(value);
      return { rarity: enumFrom(r.rarity, RARITIES, 'Common'), weight: asInt(r.weight), percent: asNumber(r.percent) };
    }),
    pity: parsePity(j.pity),
    guaranteedRarePlusOnTen: asBool(j.guaranteedRarePlusOnTen, true),
  };
}

export type GachaHistoryEntry = {
  id: string;
  cardId: string;
  rarity: Rarity;
  isNew: boolean;
  batchId: string;
  card: Card | null;
  createdAt: Date | null;
};

export function parseGachaHistory(raw: unknown): GachaHistoryEntry[] {
  return asList(asMap(raw).items).map((value) => {
    const r = asMap(value);
    return {
      id: asString(r.id),
      cardId: asString(r.cardId),
      rarity: enumFrom(r.rarity, RARITIES, 'Common'),
      isNew: asBool(r.isNew),
      batchId: asString(r.batchId),
      card: parseCard(r.card),
      createdAt: asDate(r.createdAt),
    };
  });
}

// ------------------------------------------------------------------- deck

export type DeckViolation = { code: string; message: string; cardId: string | null; actual: number | null; limit: number | null };
export type DeckCardEntry = { cardId: string; quantity: number; card: Card | null };
export type Deck = {
  id: string;
  name: string;
  isActive: boolean;
  cardCount: number;
  isValid: boolean;
  violations: DeckViolation[];
  curve: Map<number, number>;
  cards: DeckCardEntry[];
  updatedAt: Date | null;
};

export function parseDeck(raw: unknown): Deck {
  const j = asMap(raw);
  const curve = new Map<number, number>();
  for (const [key, value] of Object.entries(asMap(j.curve))) {
    const cost = Number.parseInt(key, 10);
    if (Number.isInteger(cost)) curve.set(cost, asInt(value));
  }
  return {
    id: asString(j.id),
    name: asString(j.name),
    isActive: asBool(j.isActive),
    cardCount: asInt(j.cardCount),
    isValid: asBool(j.isValid),
    violations: asList(j.violations).map((value) => {
      const v = asMap(value);
      return {
        code: asString(v.code),
        message: asString(v.message),
        cardId: asStringOrNull(v.cardId),
        actual: asIntOrNull(v.actual),
        limit: asIntOrNull(v.limit),
      };
    }),
    curve,
    cards: asList(j.cards).map((value) => {
      const e = asMap(value);
      return { cardId: asString(e.cardId), quantity: asInt(e.quantity), card: parseCard(e.card) };
    }),
    updatedAt: asDate(j.updatedAt),
  };
}

export function deckEntries(deck: Deck): Map<string, number> {
  return new Map(deck.cards.map((entry) => [entry.cardId, entry.quantity]));
}

// ----------------------------------------------------------------- battle

export type BattleDeckSnapshot = { name: string; deckId: string | null; cards: Card[] };

export type BattleStartData = {
  matchId: string;
  seed: number;
  difficulty: Difficulty;
  playerDeck: BattleDeckSnapshot;
  botDeck: BattleDeckSnapshot;
  catalogVersion: string;
  engineVersion: string;
  startedAt: Date | null;
};

function parseDeckSnapshot(raw: unknown): BattleDeckSnapshot {
  const j = asMap(raw);
  return { name: asString(j.name), deckId: asStringOrNull(j.deckId), cards: parseCards(j.cards) };
}

export function parseBattleStart(raw: unknown): BattleStartData {
  const j = asMap(raw);
  return {
    matchId: asString(j.matchId),
    seed: asInt(j.seed),
    difficulty: enumFrom(j.difficulty, DIFFICULTIES, 'easy'),
    playerDeck: parseDeckSnapshot(j.playerDeck),
    botDeck: parseDeckSnapshot(j.botDeck),
    catalogVersion: asString(j.catalogVersion),
    engineVersion: asString(j.engineVersion, '1.0.0'),
    startedAt: asDate(j.startedAt),
  };
}

export type BattleResultData = {
  matchId: string;
  alreadyReported: boolean;
  outcome: string;
  rewards: { gold: number; xp: number; firstWinBonus: boolean; capped: boolean };
  levelUp: { levelsGained: number; gold: number; gems: number };
  stats: UserStats;
  balance: Wallet;
  user: User | null;
};

export function parseBattleResult(raw: unknown): BattleResultData {
  const j = asMap(raw);
  const rewards = asMap(j.rewards);
  const levelUp = asMap(j.levelUp);
  const user = asMap(j.user);
  return {
    matchId: asString(j.matchId),
    alreadyReported: asBool(j.alreadyReported),
    outcome: asString(j.outcome, 'draw'),
    rewards: {
      gold: asInt(rewards.gold),
      xp: asInt(rewards.xp),
      firstWinBonus: asBool(rewards.firstWinBonus),
      capped: asBool(rewards.capped),
    },
    levelUp: { levelsGained: asInt(levelUp.levelsGained), gold: asInt(levelUp.gold), gems: asInt(levelUp.gems) },
    stats: parseStats(j.stats),
    balance: parseWallet(j.balance),
    user: Object.keys(user).length === 0 ? null : parseUser(user),
  };
}

export type BattleHistoryItem = {
  matchId: string;
  difficulty: string;
  outcome: string;
  turns: number;
  goldAwarded: number;
  xpAwarded: number;
  reportedAt: Date | null;
};

export function parseBattleHistory(raw: unknown): BattleHistoryItem[] {
  return asList(asMap(raw).items).map((value) => {
    const m = asMap(value);
    return {
      matchId: asString(m.matchId),
      difficulty: asString(m.difficulty),
      outcome: asString(m.outcome),
      turns: asInt(m.turns),
      goldAwarded: asInt(m.goldAwarded),
      xpAwarded: asInt(m.xpAwarded),
      reportedAt: asDate(m.reportedAt),
    };
  });
}

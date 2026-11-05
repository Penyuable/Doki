/**
 * Backend lokal untuk mode offline (port `data/local/local_backend.dart`).
 *
 * Respons memakai bentuk JSON yang sama dengan Express API sehingga repositori
 * & UI tidak perlu tahu sedang offline. Catatan: di mode ini gacha & saldo
 * dihitung di browser, sehingga invarian I-01/I-02 (server otoritatif) sengaja
 * tidak berlaku — sama seperti mode offline aplikasi Flutter.
 */
import { DartRandom, dartShuffle } from '../core/dart-random.ts';
import { asList, asMap, type JsonMap } from '../core/json.ts';
import { GameConfig, isDifficulty, xpToNext, type Difficulty } from '../config/game-config.ts';
import { RARITIES } from '../domain/card.ts';

export class LocalApiError extends Error {
  readonly status: number;
  readonly code: string;
  readonly details: unknown;

  constructor(status: number, code: string, message: string, details?: unknown) {
    super(message);
    this.name = 'LocalApiError';
    this.status = status;
    this.code = code;
    this.details = details;
  }

  toJson(): JsonMap {
    return { error: { code: this.code, message: this.message, ...(this.details !== undefined ? { details: this.details } : {}) } };
  }
}

/** Penyimpanan key-value sinkron (localStorage di browser, Map di test). */
export interface KeyValueStore {
  getItem(key: string): string | null;
  setItem(key: string, value: string): void;
  removeItem(key: string): void;
}

export interface RandomSource {
  /** Bilangan bulat seragam di [0, max). */
  nextInt(max: number): number;
}

/** RNG kriptografis (setara `Random.secure()`), rejection sampling tanpa bias. */
export const secureRandom: RandomSource = {
  nextInt(max: number): number {
    if (!Number.isInteger(max) || max <= 0 || max > 0x100000000) throw new RangeError(`max tidak valid: ${max}`);
    const buffer = new Uint32Array(1);
    const limit = 0x100000000 - (0x100000000 % max);
    for (;;) {
      globalThis.crypto.getRandomValues(buffer);
      const value = buffer[0] as number;
      if (value < limit) return value % max;
    }
  },
};

type Weighted = { rarity: string; weight: number };
type Row = JsonMap;
type State = {
  user: Row;
  inventory: Row[];
  decks: Row[];
  pulls: Row[];
  matches: Row[];
};

export const STARTING_GOLD = 1000;
export const STARTING_GEMS = 50;
export const DAILY_REWARDED_MATCH_LIMIT = 40;
export const LEVEL_UP_GOLD = 200;
export const LEVEL_UP_GEMS = 5;

export const RATES: readonly Weighted[] = [
  { rarity: 'Common', weight: 6000 },
  { rarity: 'Uncommon', weight: 2500 },
  { rarity: 'Rare', weight: 1000 },
  { rarity: 'Epic', weight: 400 },
  { rarity: 'Legendary', weight: 90 },
  { rarity: 'Master', weight: 10 },
];
export const PITY_WEIGHTS: readonly Weighted[] = [
  { rarity: 'Epic', weight: 800 },
  { rarity: 'Legendary', weight: 180 },
  { rarity: 'Master', weight: 20 },
];
export const STARTER_DECK: ReadonlyArray<{ cardId: string; quantity: number }> = [
  { cardId: 'card_001', quantity: 3 },
  { cardId: 'card_002', quantity: 3 },
  { cardId: 'card_003', quantity: 3 },
  { cardId: 'card_004', quantity: 3 },
  { cardId: 'card_005', quantity: 3 },
  { cardId: 'card_006', quantity: 3 },
  { cardId: 'card_007', quantity: 2 },
];

const RARITY_CAP: Record<Difficulty, string> = { easy: 'Rare', medium: 'Epic', master: 'Master' };
const RARITY_LIST: readonly string[] = RARITIES;
const EPIC_PLUS = ['Epic', 'Legendary', 'Master'];
const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;
const DAY_MS = 24 * 60 * 60 * 1000;

const num = (value: unknown): number => (typeof value === 'number' && Number.isFinite(value) ? value : 0);
const str = (value: unknown): string | null => (typeof value === 'string' ? value : null);

export class LocalBackend {
  static readonly STATE_KEY = 'dokimon_offline.state';

  private readonly store: KeyValueStore;
  private readonly catalog: JsonMap[];
  private readonly catalogVersion: string;
  private readonly random: RandomSource;
  private readonly now: () => Date;
  private readonly byId: Map<string, JsonMap>;
  private queue: Promise<unknown> = Promise.resolve();

  constructor(options: {
    catalog: JsonMap[];
    store: KeyValueStore;
    catalogVersion?: string;
    random?: RandomSource;
    now?: () => Date;
  }) {
    this.catalog = options.catalog;
    this.store = options.store;
    this.catalogVersion = options.catalogVersion ?? 'bundled';
    this.random = options.random ?? secureRandom;
    this.now = options.now ?? (() => new Date());
    this.byId = new Map(this.catalog.map((card) => [String(card.id), card]));
  }

  /** Menjalankan request satu per satu (setara transaksi DB berurutan). */
  handle(method: string, path: string, body: JsonMap = {}, query: Record<string, string> = {}): Promise<JsonMap> {
    const result = this.queue.then(() => this.route(method.toUpperCase(), path, body, query));
    this.queue = result.catch(() => undefined);
    return result;
  }

  /** Hapus seluruh progres offline (dipakai menu Pengaturan). */
  reset(): void {
    this.store.removeItem(LocalBackend.STATE_KEY);
  }

  // ---------------------------------------------------------------- state

  private loadState(): State | null {
    let raw: string | null = null;
    try {
      raw = this.store.getItem(LocalBackend.STATE_KEY);
    } catch {
      return null;
    }
    if (!raw) return null;
    try {
      const decoded = asMap(JSON.parse(raw));
      if (Object.keys(asMap(decoded.user)).length === 0) return null;
      return {
        user: asMap(decoded.user),
        inventory: asList(decoded.inventory).map(asMap),
        decks: asList(decoded.decks).map(asMap),
        pulls: asList(decoded.pulls).map(asMap),
        matches: asList(decoded.matches).map(asMap),
      };
    } catch {
      return null;
    }
  }

  private save(state: State): void {
    try {
      this.store.setItem(LocalBackend.STATE_KEY, JSON.stringify(state));
    } catch (error) {
      throw new LocalApiError(507, 'STORAGE_FULL', 'Penyimpanan browser penuh atau diblokir', {
        reason: error instanceof Error ? error.message : String(error),
      });
    }
  }

  private state(): State {
    const existing = this.loadState();
    if (existing) return existing;
    const now = this.iso();
    const deckId = `deck_${this.id()}`;
    const state: State = {
      user: {
        id: `local_${this.id()}`,
        email: 'player@offline.local',
        username: 'player',
        gold: STARTING_GOLD,
        gems: STARTING_GEMS,
        level: 1,
        xp: 0,
        wins: 0,
        losses: 0,
        draws: 0,
        pityCounter: 0,
        createdAt: now,
        dailyStreak: 0,
        lastDailyAt: null,
        lastFirstWinAt: null,
        activeDeckId: deckId,
      },
      inventory: STARTER_DECK.filter((entry) => this.byId.has(entry.cardId)).map((entry) => ({
        cardId: entry.cardId,
        quantity: entry.quantity,
        firstSeenAt: now,
      })),
      decks: [
        {
          id: deckId,
          name: 'Starter',
          isActive: true,
          updatedAt: now,
          cards: STARTER_DECK.map((entry) => ({ cardId: entry.cardId, quantity: entry.quantity })),
        },
      ],
      pulls: [],
      matches: [],
    };
    this.save(state);
    return state;
  }

  private iso(date: Date = this.now()): string {
    return date.toISOString();
  }

  private id(): string {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let out = '';
    for (let i = 0; i < 12; i += 1) out += chars[this.random.nextInt(chars.length)];
    return out;
  }

  // --------------------------------------------------------------- router

  private route(method: string, path: string, body: JsonMap, query: Record<string, string>): JsonMap {
    const segments = path.split('?')[0]!.split('/').filter((s) => s.length > 0);
    const head = segments[0] ?? '';
    const rest = segments.slice(1);
    const key = `${method} ${head}`;

    switch (key) {
      case 'POST auth':
        return this.auth(rest[0] ?? '');
      case 'GET auth':
        if (rest.length === 1 && rest[0] === 'me') return this.me();
        break;
      case 'GET catalog':
        if (rest.length === 1 && rest[0] === 'cards') return { version: this.catalogVersion, cards: this.catalog };
        break;
      case 'GET user':
        if (rest.length === 1 && rest[0] === 'profile') return this.profile();
        if (rest.length === 1 && rest[0] === 'wallet') return this.wallet();
        break;
      case 'POST user':
        if (rest.length === 1 && rest[0] === 'daily-claim') return this.daily();
        break;
      case 'GET inventory':
        return this.inventory(query);
      case 'GET gacha':
        if (rest.length === 1 && rest[0] === 'rates') return this.rates();
        if (rest.length === 1 && rest[0] === 'pity') return this.pityJson(num(this.state().user.pityCounter));
        if (rest.length === 1 && rest[0] === 'history') return this.gachaHistory(query);
        break;
      case 'POST gacha':
        if (rest.length === 1 && rest[0] === 'pull') return this.pull(body);
        break;
      case 'GET decks':
        if (rest.length === 0) return this.listDecks();
        return { deck: this.getDeck(rest[0]!) };
      case 'POST decks':
        if (rest.length === 0) return this.createDeck(body);
        break;
      case 'PATCH decks':
        if (rest.length === 1) return this.updateDeck(rest[0]!, body);
        break;
      case 'PUT decks':
        if (rest.length === 2 && rest[1] === 'activate') return this.activateDeck(rest[0]!);
        break;
      case 'DELETE decks':
        if (rest.length === 1) return this.deleteDeck(rest[0]!);
        break;
      case 'POST battles':
        if (rest.length === 1 && rest[0] === 'start') return this.startBattle(body);
        if (rest.length === 2 && rest[1] === 'result') return this.reportResult(rest[0]!, body);
        break;
      case 'GET battles':
        if (rest.length === 1 && rest[0] === 'history') return this.battleHistory(query);
        break;
      case 'POST telemetry':
        return { accepted: 0 };
      default:
        break;
    }
    throw new LocalApiError(404, 'NOT_FOUND', `Endpoint ${method} ${path} tidak ada`);
  }

  // ----------------------------------------------------------------- auth

  private auth(action: string): JsonMap {
    const state = this.state();
    switch (action) {
      case 'guest':
      case 'login':
      case 'register':
      case 'refresh':
        return { user: this.publicUser(state), accessToken: 'offline', refreshToken: 'offline', expiresIn: 0 };
      case 'logout':
        return {};
      default:
        throw new LocalApiError(404, 'NOT_FOUND', 'Endpoint auth tidak ada');
    }
  }

  private publicUser(state: State): JsonMap {
    const keys = ['id', 'email', 'username', 'gold', 'gems', 'level', 'xp', 'wins', 'losses', 'draws', 'pityCounter', 'createdAt'];
    return Object.fromEntries(keys.map((key) => [key, state.user[key]]));
  }

  private stats(user: Row): JsonMap {
    const wins = num(user.wins);
    const losses = num(user.losses);
    const draws = num(user.draws);
    const total = wins + losses + draws;
    return { wins, losses, draws, total, winRate: total === 0 ? null : Number((wins / total).toFixed(3)) };
  }

  private me(): JsonMap {
    const state = this.state();
    return { user: this.publicUser(state), stats: this.stats(state.user), activeDeckId: state.user.activeDeckId ?? null };
  }

  // ----------------------------------------------------------------- user

  private profile(): JsonMap {
    const state = this.state();
    const user = state.user;
    const active = state.decks.find((deck) => deck.id === user.activeDeckId) ?? null;
    return {
      user: this.publicUser(state),
      stats: this.stats(user),
      collection: { owned: state.inventory.length, total: this.catalog.length },
      activeDeck: active
        ? {
            id: active.id,
            name: active.name,
            cardCount: this.deckEntries(active).reduce((sum, entry) => sum + num(entry.quantity), 0),
          }
        : null,
      daily: {
        streak: num(user.dailyStreak),
        lastClaimAt: user.lastDailyAt ?? null,
        canClaim: !sameWibDay(parseDate(user.lastDailyAt), this.now()),
      },
    };
  }

  private wallet(): JsonMap {
    const user = this.state().user;
    return { gold: user.gold, gems: user.gems, updatedAt: this.iso() };
  }

  private daily(): JsonMap {
    const state = this.state();
    const user = state.user;
    const now = this.now();
    const last = parseDate(user.lastDailyAt);
    const nextClaimAt = new Date(startOfWibDay(now).getTime() + DAY_MS).toISOString();
    if (sameWibDay(last, now)) {
      throw new LocalApiError(409, 'ALREADY_CLAIMED', 'Reward harian sudah diambil hari ini', { nextClaimAt });
    }
    const streak = last && isYesterdayWib(last, now) ? num(user.dailyStreak) + 1 : 1;
    const day = ((streak - 1) % 7) + 1;
    const gold = GameConfig.dailyRewardGold[day - 1] ?? 0;
    const gems = GameConfig.dailyRewardGems[day - 1] ?? 0;
    user.gold = num(user.gold) + gold;
    user.gems = num(user.gems) + gems;
    user.lastDailyAt = now.toISOString();
    user.dailyStreak = streak;
    this.save(state);
    return { claimed: true, streak, day, reward: { gold, gems }, balance: { gold: user.gold, gems: user.gems }, nextClaimAt };
  }

  // ------------------------------------------------------------ inventory

  private inventory(query: Record<string, string>): JsonMap {
    const state = this.state();
    const rows = state.inventory;
    const { element, rarity, type } = query;
    const sort = query.sort ?? 'rarity';
    const limit = toInt(query.limit, 50);
    const cursor = toInt(query.cursor, 0);

    const items: JsonMap[] = [];
    for (const row of rows) {
      const card = this.byId.get(String(row.cardId));
      if (!card) continue;
      if (element && card.element !== element) continue;
      if (rarity && card.rarity !== rarity) continue;
      if (type && card.type !== type) continue;
      items.push({ cardId: row.cardId, quantity: row.quantity, firstSeenAt: row.firstSeenAt, card });
    }

    const cardOf = (item: JsonMap) => asMap(item.card);
    const rarityIdx = (item: JsonMap) => RARITY_LIST.indexOf(String(cardOf(item).rarity));
    const byName = (a: JsonMap, b: JsonMap) => compare(String(cardOf(a).name), String(cardOf(b).name));
    const stat = (item: JsonMap, field: string) => {
      const value = cardOf(item)[field];
      return typeof value === 'number' ? value : -1;
    };

    items.sort((a, b) => {
      switch (sort) {
        case 'name':
          return byName(a, b);
        case 'recent':
          return compare(String(b.firstSeenAt ?? ''), String(a.firstSeenAt ?? ''));
        case 'attack':
          return stat(b, 'attack') - stat(a, 'attack');
        case 'hp':
          return stat(b, 'hp') - stat(a, 'hp');
        default: {
          const diff = rarityIdx(b) - rarityIdx(a);
          return diff !== 0 ? diff : byName(a, b);
        }
      }
    });

    const start = clamp(cursor, 0, items.length);
    const end = clamp(start + limit, 0, items.length);
    return {
      items: items.slice(start, end),
      nextCursor: end < items.length ? end : null,
      owned: rows.length,
      total: this.catalog.filter((card) => card.retired !== true).length,
    };
  }

  // ---------------------------------------------------------------- gacha

  private rates(): JsonMap {
    return {
      rates: RATES.map((r) => ({ rarity: r.rarity, weight: r.weight, percent: Number((r.weight / 100).toFixed(2)) })),
      pity: {
        threshold: GameConfig.pityThreshold,
        bonusWeights: PITY_WEIGHTS.map((w) => ({ rarity: w.rarity, weight: w.weight })),
        note: `Epic+ dijamin pada pull ke-${GameConfig.pityThreshold} sejak Epic+ terakhir. 10x pull dijamin minimal 1 Rare+.`,
      },
      guaranteedRarePlusOnTen: true,
    };
  }

  private pityJson(counter: number): JsonMap {
    return { counter, threshold: GameConfig.pityThreshold, guaranteedIn: Math.max(0, GameConfig.pityThreshold - counter) };
  }

  private weightedPick(items: readonly Weighted[]): string {
    const total = items.reduce((sum, item) => sum + item.weight, 0);
    let roll = this.random.nextInt(total);
    for (const item of items) {
      if (roll < item.weight) return item.rarity;
      roll -= item.weight;
    }
    return items[items.length - 1]!.rarity;
  }

  private fallbackRarity(rarity: string, available: Set<string>): string {
    for (let index = RARITY_LIST.indexOf(rarity); index >= 0; index -= 1) {
      const candidate = RARITY_LIST[index]!;
      if (available.has(candidate)) return candidate;
    }
    return RARITY_LIST[0]!;
  }

  private pull(body: JsonMap): JsonMap {
    const count = body.count;
    const currency = body.currency;
    if ((count !== 1 && count !== 10) || (currency !== 'gold' && currency !== 'gem')) {
      throw new LocalApiError(400, 'VALIDATION_ERROR', 'count harus 1/10 dan currency gold/gem');
    }
    const state = this.state();
    const user = state.user;

    const idempotencyKey = str(body.idempotencyKey);
    if (idempotencyKey) {
      const replay = this.replayPull(state, idempotencyKey);
      if (replay) return replay;
    }

    const price = currency === 'gold' ? GameConfig.gachaGoldPrice[count] : GameConfig.gachaGemPrice[count];
    const walletKey = currency === 'gold' ? 'gold' : 'gems';
    const available = num(user[walletKey]);
    if (available < price) {
      throw new LocalApiError(402, 'INSUFFICIENT_FUNDS', 'Saldo tidak cukup', { currency, required: price, available });
    }

    const pool = this.catalog.filter((card) => card.obtainable === true && card.retired !== true);
    if (pool.length === 0) {
      throw new LocalApiError(503, 'CATALOG_UNAVAILABLE', 'Katalog tidak punya kartu yang bisa di-pull');
    }
    const byRarity = new Map<string, JsonMap[]>();
    for (const card of pool) {
      const bucket = byRarity.get(String(card.rarity)) ?? [];
      bucket.push(card);
      byRarity.set(String(card.rarity), bucket);
    }
    const availableRarities = new Set(byRarity.keys());

    const inventory = state.inventory;
    const owned = new Set(inventory.map((row) => row.cardId));
    const usedInBatch = new Set<unknown>();
    let pity = num(user.pityCounter);
    const results: JsonMap[] = [];

    const pick = (rarity: string): JsonMap => {
      const bucket = byRarity.get(rarity)!;
      return bucket[this.random.nextInt(bucket.length)]!;
    };

    for (let i = 0; i < count; i += 1) {
      const wasPity = pity >= GameConfig.pityThreshold - 1;
      const rarity = this.fallbackRarity(this.weightedPick(wasPity ? PITY_WEIGHTS : RATES), availableRarities);
      const card = pick(rarity);
      const isNew = !owned.has(card.id) && !usedInBatch.has(card.id);
      usedInBatch.add(card.id);
      pity = EPIC_PLUS.includes(rarity) ? 0 : pity + 1;
      results.push({ cardId: card.id, rarity, isNew, wasPity, guaranteedRare: false, card });
    }

    if (count === 10 && !results.some((r) => RARITY_LIST.indexOf(String(r.rarity)) >= RARITY_LIST.indexOf('Rare'))) {
      const last = results[results.length - 1]!;
      const target = this.fallbackRarity(last.wasPity === true ? this.weightedPick(PITY_WEIGHTS) : 'Rare', availableRarities);
      const card = pick(target);
      results[results.length - 1] = {
        ...last,
        cardId: card.id,
        rarity: target,
        card,
        isNew: !owned.has(card.id) && !usedInBatch.has(card.id),
        guaranteedRare: true,
      };
    }

    const now = this.iso();
    const batchId = `bat_${this.id()}`;
    user[walletKey] = available - price;
    user.pityCounter = pity;
    for (const result of results) {
      const existing = inventory.find((row) => row.cardId === result.cardId);
      if (existing) {
        existing.quantity = num(existing.quantity) + 1;
      } else {
        inventory.push({ cardId: result.cardId, quantity: 1, firstSeenAt: now });
      }
    }
    results.forEach((result, index) => {
      state.pulls.push({
        id: `pul_${this.id()}`,
        cardId: result.cardId,
        rarity: result.rarity,
        isNew: result.isNew,
        wasPity: result.wasPity,
        batchId,
        idempotencyKey: index === 0 ? idempotencyKey : null,
        createdAt: now,
      });
    });
    if (state.pulls.length > 500) state.pulls.splice(0, state.pulls.length - 500);
    this.save(state);

    return {
      batchId,
      results,
      balance: { gold: user.gold, gems: user.gems },
      pity: this.pityJson(pity),
      replayed: false,
    };
  }

  private replayPull(state: State, idempotencyKey: string): JsonMap | null {
    const first = state.pulls.find((p) => p.idempotencyKey === idempotencyKey);
    if (!first) return null;
    return {
      batchId: first.batchId,
      results: state.pulls
        .filter((p) => p.batchId === first.batchId)
        .map((p) => ({
          cardId: p.cardId,
          rarity: p.rarity,
          isNew: p.isNew,
          wasPity: p.wasPity,
          guaranteedRare: false,
          card: this.byId.get(String(p.cardId)) ?? null,
        })),
      balance: { gold: state.user.gold, gems: state.user.gems },
      pity: this.pityJson(num(state.user.pityCounter)),
      replayed: true,
    };
  }

  private gachaHistory(query: Record<string, string>): JsonMap {
    const pulls = [...this.state().pulls].reverse();
    return page(query, pulls, (p) => ({
      id: p.id,
      cardId: p.cardId,
      rarity: p.rarity,
      isNew: p.isNew,
      wasPity: p.wasPity,
      batchId: p.batchId,
      createdAt: p.createdAt,
      card: this.byId.get(String(p.cardId)) ?? null,
    }));
  }

  // ---------------------------------------------------------------- decks

  private deckEntries(deck: Row): Row[] {
    return asList(deck.cards).map(asMap);
  }

  private validate(entries: Row[], owned: Map<string, number>): JsonMap {
    const violations: JsonMap[] = [];
    const seen = new Set<string>();
    const totals = new Map<string, number>();
    const curve: Record<string, number> = {};
    let cardCount = 0;

    for (const entry of entries) {
      const cardId = String(entry.cardId);
      const qty = entry.quantity;
      if (seen.has(cardId)) {
        violations.push({ code: 'DUPLICATE_ENTRY', cardId, message: 'Kartu muncul lebih dari satu baris di payload' });
      }
      seen.add(cardId);
      if (typeof qty !== 'number' || !Number.isInteger(qty) || qty < 1) {
        violations.push({ code: 'COPY_LIMIT_EXCEEDED', cardId, message: 'Quantity harus minimal 1', limit: GameConfig.maxCopiesPerCard });
        continue;
      }
      const card = this.byId.get(cardId);
      if (!card) {
        violations.push({ code: 'CARD_NOT_FOUND', cardId, message: 'Kartu tidak ada di katalog' });
        continue;
      }
      if (card.type !== 'unit' && card.type !== 'spell') {
        violations.push({ code: 'CARD_NOT_PLAYABLE', cardId, message: 'Kartu tidak bisa dimainkan di deck' });
      }
      totals.set(cardId, (totals.get(cardId) ?? 0) + qty);
      cardCount += qty;
      const cost = String(card.cost);
      curve[cost] = (curve[cost] ?? 0) + qty;
    }

    for (const [cardId, total] of totals) {
      if (total > GameConfig.maxCopiesPerCard) {
        violations.push({
          code: 'COPY_LIMIT_EXCEEDED',
          cardId,
          message: `Maksimal ${GameConfig.maxCopiesPerCard} copy per kartu`,
          actual: total,
          limit: GameConfig.maxCopiesPerCard,
        });
      }
      const ownedQty = owned.get(cardId) ?? 0;
      if (ownedQty < total) {
        violations.push({ code: 'CARD_NOT_OWNED', cardId, message: 'Jumlah kartu melebihi yang dimiliki', actual: total, limit: ownedQty });
      }
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

  private owned(state: State): Map<string, number> {
    return new Map(state.inventory.map((row) => [String(row.cardId), num(row.quantity)]));
  }

  private shapeDeck(deck: Row, validation: JsonMap): JsonMap {
    return {
      id: deck.id,
      name: deck.name,
      isActive: deck.isActive,
      cardCount: validation.cardCount,
      isValid: validation.valid,
      violations: validation.violations,
      curve: validation.curve,
      updatedAt: deck.updatedAt,
      cards: this.deckEntries(deck).map((entry) => ({
        cardId: entry.cardId,
        quantity: entry.quantity,
        card: this.byId.get(String(entry.cardId)) ?? null,
      })),
    };
  }

  private findDeck(state: State, id: string): Row {
    const deck = state.decks.find((d) => d.id === id);
    if (!deck) throw new LocalApiError(404, 'NOT_FOUND', 'Deck tidak ditemukan');
    return deck;
  }

  private entriesFrom(raw: unknown): Row[] {
    if (!Array.isArray(raw)) throw new LocalApiError(400, 'VALIDATION_ERROR', 'cards wajib list');
    return raw
      .filter((item) => item !== null && typeof item === 'object')
      .map((item) => {
        const row = asMap(item);
        return { cardId: row.cardId, quantity: row.quantity };
      });
  }

  private deckName(raw: unknown): string {
    const name = typeof raw === 'string' ? raw.trim() : '';
    if (name.length < 3 || name.length > 24) throw new LocalApiError(400, 'VALIDATION_ERROR', 'Nama deck 3–24 karakter');
    return name;
  }

  private rejectInvalid(validation: JsonMap): void {
    if (validation.valid !== true) {
      throw new LocalApiError(422, 'DECK_INVALID', 'Deck tidak valid', {
        violations: validation.violations,
        cardCount: validation.cardCount,
      });
    }
  }

  private assertUniqueName(state: State, name: string, exceptId?: string): void {
    if (state.decks.some((d) => d.name === name && d.id !== exceptId)) {
      throw new LocalApiError(409, 'DECK_NAME_TAKEN', 'Nama deck sudah dipakai');
    }
  }

  private listDecks(): JsonMap {
    const state = this.state();
    const owned = this.owned(state);
    const decks = [...state.decks].sort((a, b) => {
      if (a.isActive !== b.isActive) return a.isActive === true ? -1 : 1;
      return compare(String(b.updatedAt ?? ''), String(a.updatedAt ?? ''));
    });
    return { decks: decks.map((deck) => this.shapeDeck(deck, this.validate(this.deckEntries(deck), owned))) };
  }

  private getDeck(id: string): JsonMap {
    const state = this.state();
    const deck = this.findDeck(state, id);
    return this.shapeDeck(deck, this.validate(this.deckEntries(deck), this.owned(state)));
  }

  private createDeck(body: JsonMap): JsonMap {
    const state = this.state();
    const name = this.deckName(body.name);
    const entries = this.entriesFrom(body.cards);
    const validation = this.validate(entries, this.owned(state));
    this.rejectInvalid(validation);
    if (state.decks.length >= GameConfig.maxDecks) {
      throw new LocalApiError(422, 'DECK_INVALID', `Maksimal ${GameConfig.maxDecks} deck per akun`, {
        violations: [{ code: 'DECK_LIMIT_REACHED', message: `Maksimal ${GameConfig.maxDecks} deck`, limit: GameConfig.maxDecks }],
      });
    }
    this.assertUniqueName(state, name);
    const deck: Row = { id: `deck_${this.id()}`, name, isActive: state.decks.length === 0, updatedAt: this.iso(), cards: entries };
    state.decks.push(deck);
    if (deck.isActive === true) state.user.activeDeckId = deck.id;
    this.save(state);
    return { deck: this.shapeDeck(deck, validation) };
  }

  private updateDeck(id: string, body: JsonMap): JsonMap {
    const state = this.state();
    const deck = this.findDeck(state, id);
    if (!('name' in body) && !('cards' in body)) {
      throw new LocalApiError(400, 'VALIDATION_ERROR', 'Kirim minimal satu field: name atau cards');
    }
    if ('cards' in body) {
      const entries = this.entriesFrom(body.cards);
      this.rejectInvalid(this.validate(entries, this.owned(state)));
      deck.cards = entries;
    }
    if ('name' in body) {
      const name = this.deckName(body.name);
      this.assertUniqueName(state, name, id);
      deck.name = name;
    }
    deck.updatedAt = this.iso();
    this.save(state);
    return { deck: this.shapeDeck(deck, this.validate(this.deckEntries(deck), this.owned(state))) };
  }

  private activateDeck(id: string): JsonMap {
    const state = this.state();
    const target = this.findDeck(state, id);
    for (const deck of state.decks) deck.isActive = deck === target;
    state.user.activeDeckId = id;
    this.save(state);
    return { activeDeckId: id, deck: this.shapeDeck(target, this.validate(this.deckEntries(target), this.owned(state))) };
  }

  private deleteDeck(id: string): JsonMap {
    const state = this.state();
    const deck = this.findDeck(state, id);
    state.decks.splice(state.decks.indexOf(deck), 1);
    if (state.user.activeDeckId === id) state.user.activeDeckId = null;
    this.save(state);
    return {};
  }

  // --------------------------------------------------------------- battle

  private fillDeck(pool: JsonMap[], target: number, rng: DartRandom, existing: JsonMap[] = []): JsonMap[] {
    const out = [...existing];
    if (pool.length === 0) return out;
    const counts = new Map<unknown, number>();
    for (const card of existing) counts.set(card.id, (counts.get(card.id) ?? 0) + 1);
    const shuffled = dartShuffle([...pool], rng);
    for (let copy = 0; copy < GameConfig.maxCopiesPerCard; copy += 1) {
      for (const card of shuffled) {
        if (out.length >= target) return out;
        const used = counts.get(card.id) ?? 0;
        if (used > copy || used >= GameConfig.maxCopiesPerCard) continue;
        counts.set(card.id, used + 1);
        out.push(card);
      }
    }
    return out;
  }

  /** Deck bot deterministik dari seed — RNG Dart agar sama dengan mode offline mobile. */
  botDeck(difficulty: Difficulty, seed: number): JsonMap[] {
    const rng = new DartRandom(seed);
    const maxIndex = RARITY_LIST.indexOf(RARITY_CAP[difficulty]);
    const pool = this.catalog.filter(
      (c) => c.obtainable === true && c.retired !== true && RARITY_LIST.indexOf(String(c.rarity)) <= maxIndex,
    );
    let deck = this.fillDeck(pool.filter((c) => c.type === 'unit'), 15, rng);
    deck = this.fillDeck(pool.filter((c) => c.type === 'spell'), GameConfig.deckSize, rng, deck);
    if (deck.length < GameConfig.deckSize) deck = this.fillDeck(pool, GameConfig.deckSize, rng, deck);
    dartShuffle(deck, rng);
    return deck.slice(0, GameConfig.deckSize);
  }

  private startBattle(body: JsonMap): JsonMap {
    const difficulty = body.difficulty;
    if (!isDifficulty(difficulty)) {
      throw new LocalApiError(400, 'VALIDATION_ERROR', 'difficulty harus easy/medium/master');
    }
    const state = this.state();
    const deckId = str(body.deckId) ?? str(state.user.activeDeckId);
    if (!deckId) throw new LocalApiError(422, 'DECK_INVALID', 'Pilih deck aktif terlebih dahulu');
    const deck = this.findDeck(state, deckId);
    const validation = this.validate(this.deckEntries(deck), this.owned(state));
    if (validation.valid !== true) {
      throw new LocalApiError(422, 'DECK_INVALID', 'Deck aktif tidak valid', { violations: validation.violations });
    }
    const cards: JsonMap[] = [];
    for (const entry of this.deckEntries(deck)) {
      const card = this.byId.get(String(entry.cardId))!;
      for (let i = 0; i < num(entry.quantity); i += 1) cards.push(card);
    }

    const seed = 1 + this.random.nextInt(2147483646);
    const botCards = this.botDeck(difficulty, seed);
    if (botCards.length !== GameConfig.deckSize) {
      throw new LocalApiError(503, 'CATALOG_UNAVAILABLE', 'Katalog tidak cukup untuk menyusun deck bot');
    }

    const now = this.iso();
    const matchId = `mat_${this.id()}`;
    state.matches.push({
      id: matchId,
      difficulty,
      seed,
      outcome: 'pending',
      turns: 0,
      durationMs: 0,
      goldAwarded: 0,
      xpAwarded: 0,
      firstWinBonus: false,
      reportedAt: null,
      createdAt: now,
    });
    if (state.matches.length > 200) state.matches.splice(0, state.matches.length - 200);
    this.save(state);

    return {
      matchId,
      seed,
      difficulty,
      startedAt: now,
      catalogVersion: this.catalogVersion,
      engineVersion: '1.0.0',
      playerDeck: { deckId: deck.id, name: deck.name, cards },
      botDeck: { name: `Bot ${difficulty}`, cards: botCards },
      config: {
        playerHp: GameConfig.playerHp,
        maxEnergy: GameConfig.maxEnergy,
        startingEnergy: GameConfig.startingEnergy,
        boardSlots: GameConfig.boardSlots,
        startingHand: GameConfig.startingHand,
        handLimit: GameConfig.handLimit,
        maxTurns: GameConfig.maxTurns,
      },
    };
  }

  private reportResult(matchId: string, body: JsonMap): JsonMap {
    const { outcome, turns, durationMs } = body;
    if (
      (outcome !== 'win' && outcome !== 'loss' && outcome !== 'draw') ||
      typeof turns !== 'number' ||
      !Number.isInteger(turns) ||
      typeof durationMs !== 'number' ||
      !Number.isInteger(durationMs)
    ) {
      throw new LocalApiError(400, 'VALIDATION_ERROR', 'Hasil tidak valid');
    }
    const state = this.state();
    const user = state.user;
    const match = state.matches.find((m) => m.id === matchId);
    if (!match) throw new LocalApiError(404, 'NOT_FOUND', 'Match tidak ditemukan');

    let levelUp: JsonMap = { levelsGained: 0, gold: 0, gems: 0 };
    let capped = false;
    const alreadyReported = match.outcome !== 'pending';

    if (!alreadyReported) {
      if (turns < 1 || turns > GameConfig.maxTurns) throw new LocalApiError(400, 'VALIDATION_ERROR', 'turns harus 1..50');
      const now = this.now();
      const dayStart = startOfWibDay(now);
      const rewardedToday = state.matches.filter((m) => {
        const at = parseDate(m.reportedAt);
        return at !== null && at.getTime() >= dayStart.getTime() && num(m.goldAwarded) > 0;
      }).length;
      capped = rewardedToday >= DAILY_REWARDED_MATCH_LIMIT;

      const difficulty = isDifficulty(match.difficulty) ? match.difficulty : 'easy';
      const base =
        outcome === 'win'
          ? GameConfig.battleRewards[difficulty]
          : { gold: 0, xp: outcome === 'loss' ? GameConfig.lossXp : GameConfig.drawXp };
      const gold = capped ? 0 : base.gold;
      const xp = capped ? 0 : base.xp;
      const bonus = !capped && outcome === 'win' && !sameWibDay(parseDate(user.lastFirstWinAt), now) ? GameConfig.firstWinBonusGold : 0;

      let level = num(user.level) || 1;
      let xpNow = num(user.xp) + xp;
      let gained = 0;
      while (xpNow >= xpToNext(level) && gained < 100) {
        xpNow -= xpToNext(level);
        level += 1;
        gained += 1;
      }
      levelUp = { levelsGained: gained, gold: gained * LEVEL_UP_GOLD, gems: gained * LEVEL_UP_GEMS };

      Object.assign(match, {
        outcome,
        turns,
        durationMs,
        goldAwarded: gold + bonus,
        xpAwarded: xp,
        firstWinBonus: bonus > 0,
        reportedAt: now.toISOString(),
      });

      Object.assign(user, {
        gold: num(user.gold) + gold + bonus + gained * LEVEL_UP_GOLD,
        gems: num(user.gems) + gained * LEVEL_UP_GEMS,
        xp: xpNow,
        level,
        wins: num(user.wins) + (outcome === 'win' ? 1 : 0),
        losses: num(user.losses) + (outcome === 'loss' ? 1 : 0),
        draws: num(user.draws) + (outcome === 'draw' ? 1 : 0),
      });
      if (bonus > 0) user.lastFirstWinAt = now.toISOString();
      this.save(state);
    }

    return {
      matchId,
      alreadyReported,
      outcome: match.outcome,
      rewards: { gold: match.goldAwarded, xp: match.xpAwarded, firstWinBonus: match.firstWinBonus, capped },
      levelUp,
      stats: this.stats(user),
      balance: { gold: user.gold, gems: user.gems },
      user: this.publicUser(state),
    };
  }

  private battleHistory(query: Record<string, string>): JsonMap {
    const rows = this.state()
      .matches.filter((m) => m.outcome !== 'pending')
      .reverse();
    return page(query, rows, (m) => ({
      matchId: m.id,
      difficulty: m.difficulty,
      outcome: m.outcome,
      turns: m.turns,
      durationMs: m.durationMs,
      goldAwarded: m.goldAwarded,
      xpAwarded: m.xpAwarded,
      firstWinBonus: m.firstWinBonus,
      reportedAt: m.reportedAt,
      createdAt: m.createdAt,
    }));
  }
}

// ------------------------------------------------------------------ utils

function page(query: Record<string, string>, rows: Row[], shape: (row: Row) => JsonMap): JsonMap {
  const limit = clamp(toInt(query.limit, 20), 1, 50);
  const cursor = query.cursor;
  let start = 0;
  if (cursor) {
    const index = rows.findIndex((r) => r.id === cursor);
    start = index < 0 ? rows.length : index + 1;
  }
  const slice = rows.slice(start, start + limit);
  const hasMore = start + limit < rows.length;
  return { items: slice.map(shape), nextCursor: hasMore && slice.length > 0 ? slice[slice.length - 1]!.id : null };
}

function toInt(raw: string | undefined, fallback: number): number {
  if (raw === undefined) return fallback;
  const value = Number.parseInt(raw, 10);
  return Number.isInteger(value) ? value : fallback;
}

const clamp = (value: number, min: number, max: number): number => Math.min(max, Math.max(min, value));

/** Perbandingan string per code unit UTF-16 (sama dengan `String.compareTo` Dart). */
function compare(a: string, b: string): number {
  return a < b ? -1 : a > b ? 1 : 0;
}

function parseDate(raw: unknown): Date | null {
  if (typeof raw !== 'string') return null;
  const time = Date.parse(raw);
  return Number.isNaN(time) ? null : new Date(time);
}

const wibDayKey = (date: Date): string => new Date(date.getTime() + WIB_OFFSET_MS).toISOString().slice(0, 10);

export function startOfWibDay(date: Date): Date {
  const wib = new Date(date.getTime() + WIB_OFFSET_MS);
  return new Date(Date.UTC(wib.getUTCFullYear(), wib.getUTCMonth(), wib.getUTCDate()) - WIB_OFFSET_MS);
}

export const sameWibDay = (a: Date | null, b: Date): boolean => a !== null && wibDayKey(a) === wibDayKey(b);

const isYesterdayWib = (previous: Date, now: Date): boolean => wibDayKey(new Date(previous.getTime() + DAY_MS)) === wibDayKey(now);

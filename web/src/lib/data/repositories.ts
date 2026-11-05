/**
 * Repositori (port `data/repositories/*.dart`). Route tipis ke API → model domain.
 * Tidak ada logika bisnis di sini; ekonomi & validasi otoritatif di server.
 */
import { asList, asMap, asString } from '../core/json.ts';
import type { Difficulty } from '../config/game-config.ts';
import { parseCards, type Card } from '../domain/card.ts';
import {
  parseBattleHistory,
  parseBattleResult,
  parseBattleStart,
  parseDailyClaim,
  parseDeck,
  parseGachaHistory,
  parseInventory,
  parseMe,
  parsePity,
  parseProfile,
  parsePullResponse,
  parseRates,
  parseSession,
  parseWallet,
  type InventoryPage,
} from '../domain/models.ts';
import type { ApiClient } from './api-client.ts';
import type { KeyValueStore } from './local-backend.ts';

export type CatalogSource = 'network' | 'cache' | 'bundled';

export type CatalogSnapshot = {
  version: string;
  cards: Card[];
  byId: Map<string, Card>;
  source: CatalogSource;
  fetchedAt: Date | null;
};

const CATALOG_CACHE_KEY = 'dokimon.cache.catalog';
const INVENTORY_CACHE_KEY = 'dokimon.cache.inventory';

function snapshot(version: string, cards: Card[], source: CatalogSource, fetchedAt: Date | null = null): CatalogSnapshot {
  return { version, cards, byId: new Map(cards.map((card) => [card.id, card])), source, fetchedAt };
}

export const playableCards = (catalog: CatalogSnapshot): Card[] => catalog.cards.filter((card) => !card.retired);

function readCache(store: KeyValueStore, key: string): unknown {
  try {
    const raw = store.getItem(key);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

function writeCache(store: KeyValueStore, key: string, value: unknown): void {
  try {
    store.setItem(key, JSON.stringify(value));
  } catch {
    // Cache hanya optimasi; kuota penuh tidak boleh menggagalkan alur utama.
  }
}

export function createRepositories(api: ApiClient, cache: KeyValueStore, bundledCatalog: unknown) {
  const auth = {
    async register(input: { email: string; username: string; password: string }) {
      const data = await api.post('/auth/register', {
        auth: false,
        body: { email: input.email.trim(), username: input.username.trim(), password: input.password },
      });
      const session = parseSession(data);
      api.applySession(session);
      return session;
    },
    async login(input: { email: string; password: string }) {
      const data = await api.post('/auth/login', { auth: false, body: { email: input.email.trim(), password: input.password } });
      const session = parseSession(data);
      api.applySession(session);
      return session;
    },
    /** Mode offline: sesi pemain lokal tanpa kredensial. */
    async guest() {
      const session = parseSession(await api.post('/auth/guest', { auth: false }));
      api.applySession(session);
      return session;
    },
    async me() {
      return parseMe(await api.get('/auth/me'));
    },
    async logout() {
      const token = api.currentRefreshToken;
      try {
        if (token) await api.post('/auth/logout', { body: { refreshToken: token } });
      } finally {
        api.clearSession();
      }
    },
  };

  const catalog = {
    async load(): Promise<CatalogSnapshot> {
      try {
        const data = await api.get('/catalog/cards', { auth: false });
        const cards = parseCards(data.cards);
        if (cards.length === 0) throw new Error('Katalog kosong');
        const version = asString(data.version, 'unknown');
        writeCache(cache, CATALOG_CACHE_KEY, { version, cards: data.cards });
        return snapshot(version, cards, 'network', new Date());
      } catch (error) {
        const cached = asMap(readCache(cache, CATALOG_CACHE_KEY));
        const cachedCards = parseCards(cached.cards);
        if (cachedCards.length > 0) return snapshot(asString(cached.version, 'cache'), cachedCards, 'cache');
        const bundled = parseCards(bundledCatalog);
        if (bundled.length > 0) return snapshot('bundled', bundled, 'bundled');
        throw error;
      }
    },
  };

  const inventory = {
    async load(filters: { element?: string; rarity?: string; type?: string; sort?: string } = {}): Promise<{
      page: InventoryPage;
      offline: boolean;
    }> {
      const query = { limit: 100, sort: filters.sort ?? 'rarity', element: filters.element, rarity: filters.rarity, type: filters.type };
      try {
        const data = await api.get('/inventory', { query });
        writeCache(cache, INVENTORY_CACHE_KEY, data);
        return { page: parseInventory(data), offline: false };
      } catch (error) {
        const cached = readCache(cache, INVENTORY_CACHE_KEY);
        if (cached) return { page: parseInventory(cached), offline: true };
        throw error;
      }
    },
  };

  const gacha = {
    rates: async () => parseRates(await api.get('/gacha/rates', { auth: false })),
    pity: async () => parsePity(await api.get('/gacha/pity')),
    pull: async (input: { count: 1 | 10; currency: 'gold' | 'gem'; idempotencyKey: string }) =>
      parsePullResponse(await api.post('/gacha/pull', { body: input })),
    history: async (limit = 20) => parseGachaHistory(await api.get('/gacha/history', { query: { limit } })),
  };

  const cardsPayload = (cards: ReadonlyMap<string, number>) =>
    [...cards.entries()].filter(([, qty]) => qty > 0).map(([cardId, quantity]) => ({ cardId, quantity }));

  const deck = {
    list: async () => asList((await api.get('/decks')).decks).map(parseDeck),
    get: async (id: string) => parseDeck((await api.get(`/decks/${encodeURIComponent(id)}`)).deck),
    create: async (name: string, cards: ReadonlyMap<string, number>) =>
      parseDeck((await api.post('/decks', { body: { name, cards: cardsPayload(cards) } })).deck),
    update: async (id: string, name: string, cards: ReadonlyMap<string, number>) =>
      parseDeck((await api.patch(`/decks/${encodeURIComponent(id)}`, { name, cards: cardsPayload(cards) })).deck),
    activate: async (id: string) => parseDeck((await api.put(`/decks/${encodeURIComponent(id)}/activate`)).deck),
    remove: (id: string) => api.delete(`/decks/${encodeURIComponent(id)}`),
  };

  const battle = {
    start: async (difficulty: Difficulty, deckId?: string) =>
      parseBattleStart(await api.post('/battles/start', { body: { difficulty, ...(deckId ? { deckId } : {}) } })),
    submitResult: async (input: { matchId: string; outcome: string; turns: number; durationMs: number; logHash: string }) =>
      parseBattleResult(
        await api.post(`/battles/${encodeURIComponent(input.matchId)}/result`, {
          body: {
            outcome: input.outcome,
            turns: input.turns,
            durationMs: input.durationMs,
            logHash: input.logHash,
            engineVersion: '1.0.0',
          },
        }),
      ),
    history: async (limit = 20) => parseBattleHistory(await api.get('/battles/history', { query: { limit } })),
  };

  const user = {
    profile: async () => parseProfile(await api.get('/user/profile')),
    wallet: async () => parseWallet(await api.get('/user/wallet')),
    claimDaily: async () => parseDailyClaim(await api.post('/user/daily-claim')),
  };

  return { auth, catalog, inventory, gacha, deck, battle, user };
}

export type Repositories = ReturnType<typeof createRepositories>;

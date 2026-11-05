/** Port `frontend/test/local_backend_test.dart` + transport/envelope (AC gacha, deck, battle, daily). */
import { beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { DartRandom } from '../src/lib/core/dart-random.ts';
import { GameConfig } from '../src/lib/config/game-config.ts';
import { RARITIES } from '../src/lib/domain/card.ts';
import { asList, asMap, type JsonMap } from '../src/lib/core/json.ts';
import {
  LocalApiError,
  LocalBackend,
  STARTING_GEMS,
  STARTING_GOLD,
  type KeyValueStore,
} from '../src/lib/data/local-backend.ts';
import { ApiClient, ApiError, localTransport, memoryTokenStore } from '../src/lib/data/api-client.ts';
import { createRepositories } from '../src/lib/data/repositories.ts';
import { rawCatalog } from './support/fixtures.ts';

class MemoryStore implements KeyValueStore {
  readonly map = new Map<string, string>();
  getItem(key: string) {
    return this.map.get(key) ?? null;
  }
  setItem(key: string, value: string) {
    this.map.set(key, value);
  }
  removeItem(key: string) {
    this.map.delete(key);
  }
}

let store: MemoryStore;
let clock: Date;
let backend: LocalBackend;

const call = (method: string, path: string, body: JsonMap = {}, query: Record<string, string> = {}) =>
  backend.handle(method, path, body, query);

async function fails(method: string, path: string, body: JsonMap = {}): Promise<LocalApiError> {
  try {
    await call(method, path, body);
  } catch (error) {
    if (error instanceof LocalApiError) return error;
    throw error;
  }
  throw new Error(`${method} ${path} seharusnya gagal`);
}

const rarityIdx = (rarity: unknown) => (RARITIES as readonly string[]).indexOf(String(rarity));

beforeEach(() => {
  store = new MemoryStore();
  clock = new Date('2026-11-06T05:00:00.000Z');
  const rng = new DartRandom(42);
  backend = new LocalBackend({
    catalog: rawCatalog.map(asMap),
    store,
    random: { nextInt: (max) => rng.nextInt(max) },
    now: () => clock,
  });
});

describe('LocalBackend (mode offline)', () => {
  test('pemain baru otomatis (tanpa login): saldo awal + starter deck', async () => {
    const session = await call('POST', '/auth/guest');
    assert.ok(String(session.accessToken).length > 0);
    const me = await call('GET', '/auth/me');
    assert.equal(asMap(me.user).gold, STARTING_GOLD);
    assert.equal(asMap(me.user).gems, STARTING_GEMS);
    const decks = asList((await call('GET', '/decks')).decks).map(asMap);
    assert.equal(decks.length, 1);
    assert.equal(decks[0]!.isValid, true);
    assert.equal(decks[0]!.cardCount, GameConfig.deckSize);
    assert.equal(me.activeDeckId, decks[0]!.id);
  });

  test('state tersimpan: guest kedua memakai pemain yang sama', async () => {
    const first = await call('POST', '/auth/guest');
    const second = await call('POST', '/auth/guest');
    assert.equal(asMap(second.user).id, asMap(first.user).id);
  });

  test('state rusak di storage diganti pemain baru, bukan crash', async () => {
    store.setItem(LocalBackend.STATE_KEY, '{bukan json');
    const me = await call('GET', '/auth/me');
    assert.equal(asMap(me.user).gold, STARTING_GOLD);
  });

  test('pull 10x: potong harga, 10 kartu, minimal 1 Rare+, masuk inventory', async () => {
    const result = await call('POST', '/gacha/pull', { count: 10, currency: 'gold' });
    const results = asList(result.results).map(asMap);
    assert.equal(results.length, 10);
    assert.ok(results.some((r) => rarityIdx(r.rarity) >= rarityIdx('Rare')));
    assert.equal(asMap(result.balance).gold, STARTING_GOLD - GameConfig.gachaGoldPrice[10]);
    const inventory = await call('GET', '/inventory');
    const total = asList(inventory.items).reduce<number>((sum, item) => sum + Number(asMap(item).quantity), 0);
    assert.equal(total, 20 + 10);
  });

  test('10x selalu dijamin Rare+ (100 batch)', async () => {
    const state = JSON.parse((await call('POST', '/auth/guest'), store.getItem(LocalBackend.STATE_KEY)!));
    state.user.gold = 1_000_000;
    store.setItem(LocalBackend.STATE_KEY, JSON.stringify(state));
    for (let i = 0; i < 100; i += 1) {
      const res = await call('POST', '/gacha/pull', { count: 10, currency: 'gold' });
      assert.ok(asList(res.results).some((r) => rarityIdx(asMap(r).rarity) >= rarityIdx('Rare')), `batch ${i}`);
    }
  });

  test('saldo kurang → INSUFFICIENT_FUNDS dan saldo tidak berubah', async () => {
    for (let i = 0; i < 5; i += 1) await call('POST', '/gacha/pull', { count: 10, currency: 'gem' });
    const error = await fails('POST', '/gacha/pull', { count: 10, currency: 'gem' });
    assert.equal(error.code, 'INSUFFICIENT_FUNDS');
    assert.equal(error.status, 402);
    assert.equal((await call('GET', '/user/wallet')).gems, 5);
  });

  test('validasi input pull: count/currency ilegal ditolak', async () => {
    assert.equal((await fails('POST', '/gacha/pull', { count: 5, currency: 'gold' })).code, 'VALIDATION_ERROR');
    assert.equal((await fails('POST', '/gacha/pull', { count: 1, currency: 'usd' })).code, 'VALIDATION_ERROR');
  });

  for (const [counter, expectPity] of [
    [48, false],
    [49, true],
  ] as const) {
    test(`pity: counter ${counter} → wasPity=${expectPity}`, async () => {
      await call('POST', '/auth/guest');
      const state = JSON.parse(store.getItem(LocalBackend.STATE_KEY)!);
      state.user.pityCounter = counter;
      store.setItem(LocalBackend.STATE_KEY, JSON.stringify(state));
      const res = await call('POST', '/gacha/pull', { count: 1, currency: 'gold' });
      const pulled = asMap(asList(res.results)[0]);
      assert.equal(pulled.wasPity, expectPity);
      if (expectPity) {
        assert.ok(['Epic', 'Legendary', 'Master'].includes(String(pulled.rarity)));
        assert.equal(asMap(res.pity).counter, 0);
      }
    });
  }

  test('idempotencyKey yang sama mengembalikan hasil yang sama tanpa potong saldo lagi', async () => {
    const body = { count: 1, currency: 'gold', idempotencyKey: 'key-1' };
    const first = await call('POST', '/gacha/pull', body);
    const second = await call('POST', '/gacha/pull', body);
    assert.equal(second.replayed, true);
    assert.equal(second.batchId, first.batchId);
    assert.equal(asMap(second.balance).gold, asMap(first.balance).gold);
  });

  test('deck ilegal ditolak (I-03)', async () => {
    const error = await fails('POST', '/decks', { name: 'Curang', cards: [{ cardId: 'card_001', quantity: 4 }] });
    assert.equal(error.code, 'DECK_INVALID');
    const codes = new Set(asList(asMap(error.details).violations).map((v) => asMap(v).code));
    assert.ok(codes.has('COPY_LIMIT_EXCEEDED') && codes.has('DECK_SIZE'));
  });

  test('deck dengan kartu tidak dimiliki ditolak (I-03)', async () => {
    const cards = [{ cardId: 'card_025', quantity: 1 }, ...[1, 2, 3, 4, 5, 6].map((n) => ({ cardId: `card_00${n}`, quantity: 3 })), { cardId: 'card_007', quantity: 1 }];
    const error = await fails('POST', '/decks', { name: 'Pinjam', cards });
    const codes = asList(asMap(error.details).violations).map((v) => asMap(v).code);
    assert.ok(codes.includes('CARD_NOT_OWNED'));
  });

  test('CRUD deck: buat, ganti nama, aktifkan, hapus', async () => {
    const cards = [1, 2, 3, 4, 5, 6].map((n) => ({ cardId: `card_00${n}`, quantity: 3 })).concat({ cardId: 'card_007', quantity: 2 });
    const created = asMap((await call('POST', '/decks', { name: 'Kedua', cards })).deck);
    assert.equal(created.isValid, true);
    assert.equal((await fails('POST', '/decks', { name: 'Kedua', cards })).code, 'DECK_NAME_TAKEN');
    const renamed = asMap((await call('PATCH', `/decks/${created.id}`, { name: 'Ganti' })).deck);
    assert.equal(renamed.name, 'Ganti');
    await call('PUT', `/decks/${created.id}/activate`);
    assert.equal((await call('GET', '/auth/me')).activeDeckId, created.id);
    await call('DELETE', `/decks/${created.id}`);
    assert.equal((await call('GET', '/auth/me')).activeDeckId, null);
    assert.equal((await fails('GET', `/decks/${created.id}`)).status, 404);
  });

  test('battle: start 20 vs 20, menang memberi reward + bonus sekali', async () => {
    const start = await call('POST', '/battles/start', { difficulty: 'easy' });
    assert.equal(asList(asMap(start.playerDeck).cards).length, GameConfig.deckSize);
    assert.equal(asList(asMap(start.botDeck).cards).length, GameConfig.deckSize);
    const matchId = String(start.matchId);
    const body = { outcome: 'win', turns: 8, durationMs: 60000 };
    const result = await call('POST', `/battles/${matchId}/result`, body);
    assert.equal(asMap(result.rewards).gold, GameConfig.battleRewards.easy.gold + GameConfig.firstWinBonusGold);
    assert.equal(asMap(result.rewards).firstWinBonus, true);
    assert.equal(asMap(result.stats).wins, 1);
    const again = await call('POST', `/battles/${matchId}/result`, body);
    assert.equal(again.alreadyReported, true);
    assert.equal(asMap(again.stats).wins, 1);
  });

  test('deck bot: maks 3 copy, rarity dibatasi per difficulty, deterministik per seed', () => {
    const rank = (r: unknown) => rarityIdx(r);
    for (const [difficulty, cap] of [['easy', 'Rare'], ['medium', 'Epic'], ['master', 'Master']] as const) {
      const deck = backend.botDeck(difficulty, 12345);
      assert.equal(deck.length, 20);
      const counts = new Map<unknown, number>();
      for (const card of deck) counts.set(card.id, (counts.get(card.id) ?? 0) + 1);
      assert.ok([...counts.values()].every((n) => n <= 3));
      assert.ok(deck.every((card) => rank(card.rarity) <= rank(cap)));
      assert.deepEqual(backend.botDeck(difficulty, 12345).map((c) => c.id), deck.map((c) => c.id));
    }
  });

  test('daily claim hanya sekali per hari (WIB), streak naik keesokan harinya', async () => {
    const claim = await call('POST', '/user/daily-claim');
    assert.equal(claim.day, 1);
    assert.equal(asMap(claim.balance).gold, STARTING_GOLD + GameConfig.dailyRewardGold[0]!);
    assert.equal((await fails('POST', '/user/daily-claim')).code, 'ALREADY_CLAIMED');
    clock = new Date(clock.getTime() + 24 * 60 * 60 * 1000);
    const next = await call('POST', '/user/daily-claim');
    assert.equal(next.streak, 2);
    assert.equal(next.day, 2);
  });

  test('history pull & battle terurut terbaru dulu', async () => {
    await call('POST', '/gacha/pull', { count: 1, currency: 'gold' });
    const history = asList((await call('GET', '/gacha/history', {}, { limit: '5' })).items);
    assert.equal(history.length, 1);
  });
});

describe('ApiClient + localTransport (envelope seperti server)', () => {
  test('envelope {data} dan {error}', async () => {
    const api = new ApiClient({ transport: localTransport(backend), tokens: memoryTokenStore() });
    const wallet = await api.get('/user/wallet');
    assert.equal(wallet.gold, STARTING_GOLD);
    await assert.rejects(api.get('/tidak-ada'), (error: unknown) => {
      assert.ok(error instanceof ApiError);
      assert.equal(error.status, 404);
      assert.equal(error.code, 'NOT_FOUND');
      return true;
    });
  });

  test('repositori mem-parse respons menjadi model domain', async () => {
    const api = new ApiClient({ transport: localTransport(backend), tokens: memoryTokenStore() });
    const repos = createRepositories(api, new MemoryStore(), rawCatalog);
    const session = await repos.auth.guest();
    assert.equal(session.user.gold, STARTING_GOLD);
    assert.ok(api.hasSession);
    const catalog = await repos.catalog.load();
    assert.equal(catalog.cards.length, 25);
    assert.equal(catalog.source, 'network');
    const decks = await repos.deck.list();
    assert.equal(decks[0]!.isValid, true);
    const inv = await repos.inventory.load({ sort: 'name' });
    assert.equal(inv.page.items.length, 7);
    const names = inv.page.items.map((i) => i.card.name);
    assert.deepEqual(names, [...names].sort());
  });
});

describe('ApiClient refresh token (single-flight)', () => {
  test('401 → satu kali refresh untuk banyak request paralel lalu retry', async () => {
    let refreshCalls = 0;
    let valid = 'old';
    const api = new ApiClient({
      tokens: memoryTokenStore(),
      transport: async (req) => {
        if (req.path === '/auth/refresh') {
          refreshCalls += 1;
          await new Promise((r) => setTimeout(r, 5));
          valid = 'new';
          return { status: 200, json: { data: { accessToken: 'new', refreshToken: 'r2' } } };
        }
        if (req.headers.Authorization !== `Bearer ${valid}`) {
          return { status: 401, json: { error: { code: 'TOKEN_EXPIRED', message: 'expired' } } };
        }
        return { status: 200, json: { data: { ok: req.path } } };
      },
    });
    api.applySession({ accessToken: 'stale', refreshToken: 'r1' });
    const results = await Promise.all([api.get('/a'), api.get('/b'), api.get('/c')]);
    assert.deepEqual(results.map((r) => r.ok), ['/a', '/b', '/c']);
    assert.equal(refreshCalls, 1);
  });

  test('refresh ditolak → sesi dibersihkan + onSessionExpired', async () => {
    let expired = false;
    const api = new ApiClient({
      tokens: memoryTokenStore(),
      transport: async (req) =>
        req.path === '/auth/refresh'
          ? { status: 401, json: { error: { code: 'TOKEN_REUSED', message: 'reuse' } } }
          : { status: 401, json: { error: { code: 'TOKEN_EXPIRED', message: 'expired' } } },
    });
    api.onSessionExpired = () => {
      expired = true;
    };
    api.applySession({ accessToken: 'a', refreshToken: 'r' });
    await assert.rejects(api.get('/user/profile'), ApiError);
    assert.equal(expired, true);
    assert.equal(api.hasSession, false);
  });

  test('server tidak terjangkau → NETWORK_ERROR, sesi tetap', async () => {
    const api = new ApiClient({
      tokens: memoryTokenStore(),
      transport: async () => {
        throw new ApiError('NETWORK_ERROR', 'offline');
      },
    });
    api.applySession({ accessToken: 'a', refreshToken: 'r' });
    await assert.rejects(api.get('/user/profile'), (error: unknown) => error instanceof ApiError && error.isNetwork);
    assert.equal(api.hasSession, true);
  });

  test('katalog jatuh ke cache lalu bundled saat server mati', async () => {
    const cache = new MemoryStore();
    const down = new ApiClient({
      tokens: memoryTokenStore(),
      transport: async () => {
        throw new ApiError('NETWORK_ERROR', 'offline');
      },
    });
    const bundled = await createRepositories(down, cache, rawCatalog).catalog.load();
    assert.equal(bundled.source, 'bundled');
    cache.setItem('dokimon.cache.catalog', JSON.stringify({ version: 'v-cache', cards: rawCatalog.slice(0, 3) }));
    const cached = await createRepositories(down, cache, rawCatalog).catalog.load();
    assert.equal(cached.source, 'cache');
    assert.equal(cached.cards.length, 3);
  });
});

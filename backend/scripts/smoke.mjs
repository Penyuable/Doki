#!/usr/bin/env node
/**
 * Smoke test end-to-end terhadap server yang sedang jalan.
 *   node scripts/smoke.mjs [baseUrl]
 * Default: http://localhost:8080/api/v1
 */

const BASE = process.argv[2] ?? 'http://localhost:8080/api/v1';

let accessToken = null;

async function call(method, path, body, { auth = true, expect } = {}) {
  const res = await fetch(`${BASE}${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(auth && accessToken ? { authorization: `Bearer ${accessToken}` } : {}),
    },
    ...(body !== undefined ? { body: JSON.stringify(body) } : {}),
  });

  const text = await res.text();
  let json = null;
  try {
    json = text ? JSON.parse(text) : null;
  } catch {
    json = { raw: text };
  }

  const okStatus = expect ? res.status === expect : res.ok;
  if (!okStatus) {
    console.error(`✗ ${method} ${path} → ${res.status}`);
    console.error(JSON.stringify(json, null, 2));
    process.exit(1);
  }
  return json;
}

const uniq = Date.now().toString(36);
const email = `smoke_${uniq}@example.com`;
const password = 'SmokeTest123';

console.log(`▶ smoke test @ ${BASE}`);

const health = await fetch('http://localhost:8080/healthz').then((r) => r.json());
console.log(`✓ healthz: ${health.status} (catalog ${health.catalogVersion})`);

const reg = await call(
  'POST',
  '/auth/register',
  { email, username: `smoke_${uniq}`.slice(0, 16), password },
  { auth: false, expect: 201 },
);
accessToken = reg.data.accessToken;
console.log(`✓ register: ${reg.data.user.username} (gold ${reg.data.user.gold})`);

const me = await call('GET', '/auth/me');
console.log(`✓ me: level ${me.data.user.level}, deck aktif ${me.data.activeDeckId ? 'ada' : 'tidak ada'}`);

const cards = await call('GET', '/catalog/cards', undefined, { auth: false });
console.log(`✓ catalog: ${cards.data.cards.length} kartu (versi ${cards.data.version})`);

const pityBefore = await call('GET', '/gacha/pity');
const key = crypto.randomUUID();
const pull = await call('POST', '/gacha/pull', {
  count: 10,
  currency: 'gold',
  idempotencyKey: key,
});
console.log(
  `✓ gacha 10x: ${pull.data.results.map((r) => r.rarity).join(', ')} | sisa gold ${pull.data.balance.gold} | pity ${pull.data.pity.counter}`,
);

const replay = await call('POST', '/gacha/pull', {
  count: 10,
  currency: 'gold',
  idempotencyKey: key,
});
if (replay.data.balance.gold !== pull.data.balance.gold) {
  console.error('✗ idempotency gagal: saldo berubah pada retry');
  process.exit(1);
}
console.log(`✓ idempotency: retry tidak memotong saldo (replayed=${replay.data.replayed})`);

const inventory = await call('GET', '/inventory?limit=100');
console.log(`✓ inventory: ${inventory.data.owned} jenis kartu`);

const byId = new Map(inventory.data.items.map((i) => [i.cardId, i.quantity]));
const deckCards = [];
for (const id of ['card_001', 'card_002', 'card_003', 'card_004', 'card_005', 'card_006', 'card_007']) {
  const qty = Math.min(3, byId.get(id) ?? 0);
  if (qty > 0) deckCards.push({ cardId: id, quantity: qty });
}
const total = deckCards.reduce((s, c) => s + c.quantity, 0);
if (total !== 20) {
  deckCards.push({ cardId: 'card_001', quantity: 20 - total });
}

const created = await call(
  'POST',
  '/decks',
  { name: `Smoke Deck ${uniq}`.slice(0, 24), cards: deckCards },
  { expect: 201 },
);
console.log(`✓ deck dibuat: ${created.data.deck.name} (${created.data.deck.cardCount} kartu, valid=${created.data.deck.isValid})`);

await call('PUT', `/decks/${created.data.deck.id}/activate`);
console.log('✓ deck diaktifkan');

const start = await call(
  'POST',
  '/battles/start',
  { difficulty: 'medium', deckId: created.data.deck.id },
  { expect: 201 },
);
console.log(
  `✓ battle start: ${start.data.matchId} | deck pemain ${start.data.playerDeck.cards.length} | deck bot ${start.data.botDeck.cards.length}`,
);

const result = await call('POST', `/battles/${start.data.matchId}/result`, {
  outcome: 'win',
  turns: 9,
  durationMs: 9 * 500 + 500,
  logHash: 'smoke-test',
  engineVersion: '1.0.0',
});
console.log(
  `✓ battle result: ${result.data.outcome} | +${result.data.rewards.gold} gold, +${result.data.rewards.xp} xp | level ${result.data.user.level}`,
);

const replayResult = await call('POST', `/battles/${start.data.matchId}/result`, {
  outcome: 'win',
  turns: 9,
  durationMs: 9 * 500 + 500,
});
if (replayResult.data.rewards.gold !== result.data.rewards.gold) {
  console.error('✗ reward idempotency gagal');
  process.exit(1);
}
console.log(`✓ reward idempotent: alreadyReported=${replayResult.data.alreadyReported}`);

const final = await call('GET', '/user/profile');
console.log(
  `✓ profile akhir: gold ${final.data.user.gold}, gems ${final.data.user.gems}, W/L ${final.data.stats.wins}/${final.data.stats.losses}, koleksi ${final.data.collection.owned}/${final.data.collection.total}`,
);
console.log(`✓ pity sebelum/sesudah: ${pityBefore.data.counter} → ${final.data.user.pityCounter ?? 'n/a'}`);
console.log('✔ SMOKE TEST LULUS');

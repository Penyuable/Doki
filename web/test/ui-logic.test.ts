/** Logika presentasi: filter koleksi, deck rules/builder, l10n, petunjuk arena & FX. */
import { describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { COLLECTION_SORTS, DEFAULT_FILTER, applyCollectionFilter, isDefaultFilter } from '../src/lib/ui/collection.ts';
import { addCard, curveBuckets, nameValid, removeCard, totalCards, validateDraft, type DeckDraft } from '../src/lib/ui/deck-builder.ts';
import { canAddCard, validateDeck } from '../src/lib/domain/deck-rules.ts';
import { cantPlayReason, fxFromEvents, movesFor, uniqueTargets } from '../src/lib/ui/battle-view.ts';
import { allKeys, translator } from '../src/lib/i18n/strings.ts';
import { battleEngine } from '../src/lib/battle/engine.ts';
import type { BattleEvent } from '../src/lib/battle/models.ts';
import { relativeTime } from '../src/lib/ui/time.ts';
import { validEmail, validPassword, validUsername } from '../src/lib/ui/auth-validation.ts';
import { defaultDeckName } from '../src/lib/ui/deck-builder.ts';
import { byId, catalog, goldenBotDeck, starterDeck } from './support/fixtures.ts';

describe('Helper kecil', () => {
  test('relativeTime', () => {
    const t = translator('id');
    const now = new Date('2026-11-06T10:00:00Z');
    assert.equal(relativeTime(new Date('2026-11-06T09:59:40Z'), t, now), 'baru saja');
    assert.equal(relativeTime(new Date('2026-11-06T09:55:00Z'), t, now), '5 menit lalu');
    assert.equal(relativeTime(new Date('2026-11-06T07:00:00Z'), t, now), '3 jam lalu');
    assert.equal(relativeTime(new Date('2026-11-04T09:00:00Z'), t, now), '2 hari lalu');
    assert.equal(relativeTime(null, t, now), '—');
  });

  test('validasi auth sama dengan backend (email, username 3–16, password 8–72)', () => {
    assert.ok(validEmail('a@b.co') && !validEmail('bukan-email'));
    assert.ok(validUsername('dok_1') && !validUsername('ab') && !validUsername('nama spasi'));
    assert.ok(validPassword('12345678') && !validPassword('1234567') && !validPassword('x'.repeat(73)));
  });

  test('defaultDeckName melewati nama yang sudah dipakai', () => {
    assert.equal(defaultDeckName([]), 'Deck 1');
    assert.equal(defaultDeckName(['Starter', 'deck 3']), 'Deck 4');
  });
});

const ownedStarter = new Map([
  ['card_001', 3],
  ['card_002', 3],
  ['card_003', 3],
  ['card_004', 3],
  ['card_005', 3],
  ['card_006', 3],
  ['card_007', 2],
]);

describe('Filter koleksi', () => {
  test('filter elemen + kepemilikan + pencarian', () => {
    const fire = applyCollectionFilter(catalog, { ...DEFAULT_FILTER, element: 'Fire' }, ownedStarter);
    assert.ok(fire.length > 0 && fire.every((c) => c.element === 'Fire'));
    const owned = applyCollectionFilter(catalog, { ...DEFAULT_FILTER, ownedOnly: true }, ownedStarter);
    assert.equal(owned.length, 7);
    const notOwned = applyCollectionFilter(catalog, { ...DEFAULT_FILTER, ownedOnly: false }, ownedStarter);
    assert.equal(notOwned.length, catalog.filter((c) => !c.retired).length - 7);
    const search = applyCollectionFilter(catalog, { ...DEFAULT_FILTER, query: 'ember' }, ownedStarter);
    assert.ok(search.some((c) => c.id === 'card_001'));
  });

  test('urut rarity menurun lalu nama; ATK tertinggi dulu', () => {
    const byRarity = applyCollectionFilter(catalog, DEFAULT_FILTER, ownedStarter);
    assert.equal(byRarity[0]!.rarity, 'Master');
    const byAttack = applyCollectionFilter(catalog, { ...DEFAULT_FILTER, sort: 'attack' }, ownedStarter);
    for (let i = 1; i < byAttack.length; i += 1) assert.ok((byAttack[i - 1]!.attack ?? 0) >= (byAttack[i]!.attack ?? 0));
  });

  test('setiap opsi urutan punya label terjemahan (bukan kunci mentah)', () => {
    for (const locale of ['id', 'en'] as const) {
      const t = translator(locale);
      for (const sort of COLLECTION_SORTS) assert.notEqual(t(`collection.sort.${sort}`), `collection.sort.${sort}`);
    }
    assert.ok(isDefaultFilter(DEFAULT_FILTER));
    assert.ok(!isDefaultFilter({ ...DEFAULT_FILTER, query: 'x' }));
  });
});

describe('DeckRules (I-03)', () => {
  const entries = (pairs: Array<[string, number]>) => new Map(pairs);

  test('deck 20 kartu yang dimiliki dinyatakan valid', () => {
    const result = validateDeck({ entries: new Map(ownedStarter), owned: ownedStarter, catalog: byId });
    assert.equal(result.valid, true);
    assert.equal(result.cardCount, 20);
  });

  test('jumlah bukan 20, copy > 3, tidak dimiliki, di luar katalog → ditolak', () => {
    const codes = (pairs: Array<[string, number]>, owned = ownedStarter) =>
      validateDeck({ entries: entries(pairs), owned, catalog: byId }).violations.map((v) => v.code);
    assert.ok(codes([['card_001', 3]]).includes('DECK_SIZE'));
    assert.ok(codes([['card_001', 4]], new Map([['card_001', 9]])).includes('COPY_LIMIT_EXCEEDED'));
    assert.ok(codes([['card_025', 1]]).includes('CARD_NOT_OWNED'));
    assert.ok(codes([['tidak_ada', 1]]).includes('CARD_NOT_FOUND'));
  });

  test('canAdd: batas copy, kepemilikan, dan ukuran deck', () => {
    assert.equal(canAddCard({ entries: entries([['card_001', 2]]), cardId: 'card_001', ownedCount: 3 }), true);
    assert.equal(canAddCard({ entries: entries([['card_001', 3]]), cardId: 'card_001', ownedCount: 9 }), false);
    assert.equal(canAddCard({ entries: entries([['card_001', 1]]), cardId: 'card_001', ownedCount: 1 }), false);
    assert.equal(canAddCard({ entries: new Map(ownedStarter), cardId: 'card_008', ownedCount: 3 }), false);
  });
});

describe('Deck builder', () => {
  test('tambah/hapus, nama valid, kurva', () => {
    let draft: DeckDraft = { deckId: null, name: 'ab', entries: new Map() };
    for (let i = 0; i < 4; i += 1) draft = addCard(draft, 'card_001', ownedStarter) ?? draft;
    assert.equal(draft.entries.get('card_001'), 3);
    assert.equal(addCard(draft, 'card_025', ownedStarter), null);
    draft = removeCard(draft, 'card_001');
    assert.equal(totalCards(draft.entries), 2);
    assert.equal(nameValid(draft.name), false);
    assert.equal(nameValid('  Deck Api '), true);
    const result = validateDraft({ ...draft, name: 'Deck Api' }, ownedStarter, byId);
    assert.equal(result.canSave, false);
    const full = validateDraft({ deckId: null, name: 'Starter 2', entries: new Map(ownedStarter) }, ownedStarter, byId);
    assert.equal(full.canSave, true);
    const buckets = curveBuckets(full.curve);
    assert.equal(buckets.reduce((a, b) => a + b, 0), 20);
  });
});

describe('l10n', () => {
  test('id dan en punya kunci yang sama persis', () => {
    assert.deepEqual(allKeys('en').sort(), allKeys('id').sort());
  });

  test('interpolasi argumen dan fallback ke kunci', () => {
    const t = translator('en');
    assert.equal(t('battle.cantPlay.energy', { cost: 3, energy: 1 }), 'Not enough energy: needs 3, you have 1.');
    assert.equal(t('kunci.tidak.ada'), 'kunci.tidak.ada');
    assert.equal(translator('id')('help.win.body', { hp: 200 }).includes('200'), true);
  });

  test('teks panduan & petunjuk arena tersedia di id dan en', () => {
    const keys = ['help.collect.title', 'help.deck.body', 'help.summon.body', 'help.moves.body', 'help.win.body', 'battle.hint.play', 'battle.hint.act', 'battle.hint.endTurn'];
    for (const locale of ['id', 'en'] as const) {
      const t = translator(locale);
      for (const key of keys) assert.notEqual(t(key), key, `${locale}:${key}`);
    }
  });
});

describe('Arena: jurus, alasan, FX dari event (I-05)', () => {
  const t = translator('id');

  test('unit punya serangan dasar + guard; ability ditambahkan bila ada', () => {
    const unit = byId.get('card_002')!; // Droplet Sprite, punya ability heal
    const moves = movesFor(unit, t);
    assert.deepEqual(moves.map((m) => m.kind), ['strike', 'ability', 'guard']);
    assert.equal(moves[0]!.name, 'Semburan Ombak');
    assert.equal(moves[0]!.power, unit.attack);
  });

  test('alasan energi menyebut angka sebenarnya', () => {
    const state = battleEngine.start({ playerDeck: starterDeck(), botDeck: goldenBotDeck(), seed: 3 });
    state.activeSide = 'player';
    state.player.energy = 0;
    const index = state.player.hand.findIndex((c) => c.cost > 0);
    const card = state.player.hand[index]!;
    assert.equal(cantPlayReason(state, index, t), `Energi kurang: butuh ${card.cost}, kamu punya 0.`);
    state.activeSide = 'bot';
    assert.equal(cantPlayReason(state, index, t), t('battle.cantPlay.turn'));
  });

  test('target unik mempertahankan urutan; FX memakai angka dari event', () => {
    assert.deepEqual(uniqueTargets(['u1', null, 'u1', undefined, 'u2']), ['u1', null, 'u2']);
    const events: BattleEvent[] = [
      { type: 'attack', turn: 1, side: 'player', message: '', data: { attackerId: 'u1', targetId: 'u9', damage: 12 } },
      { type: 'counter', turn: 1, side: 'bot', message: '', data: { unitId: 'u9', damage: 3 } },
      { type: 'face_attack', turn: 1, side: 'bot', message: '', data: { unitId: 'u9', damage: 7 } },
      { type: 'heal', turn: 1, side: 'player', message: '', data: { targetId: 'u1', amount: 5 } },
    ];
    const fx = fxFromEvents(events, 10);
    assert.deepEqual(
      fx.map((f) => [f.kind, f.amount, f.anchor, f.key]),
      [
        ['damage', 12, 'u9', '10'],
        ['damage', 3, 'u1', '11'],
        ['damage', 7, 'hero:player', '12'],
        ['heal', 5, 'u1', '13'],
      ],
    );
  });
});

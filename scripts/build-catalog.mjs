#!/usr/bin/env node
/**
 * build-catalog.mjs — validasi content/cards/cards.json dan (re)generate manifest.json.
 *
 * Pemakaian:
 *   node scripts/build-catalog.mjs                 # validasi + tulis manifest
 *   node scripts/build-catalog.mjs --check         # validasi + pastikan manifest sinkron (CI)
 *   node scripts/build-catalog.mjs --version 1.2.3 # set catalogVersion eksplisit
 *
 * Tanpa dependency eksternal — sengaja, agar bisa jalan di CI tanpa `npm install`.
 */

import { createHash } from 'node:crypto';
import { readFile, writeFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const CARDS_DIR = path.join(ROOT, 'content', 'cards');
const CARDS_PATH = path.join(CARDS_DIR, 'cards.json');
const MANIFEST_PATH = path.join(CARDS_DIR, 'manifest.json');

const ELEMENTS = ['Fire', 'Water', 'Earth', 'Air', 'Void'];
const RARITIES = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Master'];
const CARD_TYPES = ['unit', 'spell'];
const KEYWORDS = ['charge', 'pierce', 'lifesteal'];
const ABILITY_TYPES = ['attack', 'heal', 'buff', 'control', 'shield'];
const ABILITY_TARGETS = [
  'enemy_unit',
  'any_unit',
  'self',
  'all_enemy_units',
  'all_allies',
  'enemy_player',
];
const STATUS_KINDS = ['burn', 'freeze', 'shield', 'rally'];

const CARD_REQUIRED = [
  'id', 'name', 'element', 'rarity', 'type', 'cost', 'hp', 'attack',
  'defense', 'keywords', 'ability', 'imageUrl', 'obtainable', 'version',
];
const CARD_ALLOWED = new Set([
  ...CARD_REQUIRED, 'flavorText', 'thumbnailUrl', 'model3dUrl', 'retired',
]);
const ABILITY_REQUIRED = ['name', 'type', 'cost', 'target', 'power', 'text'];
const ABILITY_ALLOWED = new Set([...ABILITY_REQUIRED, 'status']);
const STATUS_ALLOWED = new Set(['kind', 'value', 'turns']);

const errors = [];
const warnings = [];

const isInt = (v) => Number.isInteger(v);
const isHttpsUrl = (v) =>
  typeof v === 'string' && v.length >= 12 && v.length <= 500 && /^https:\/\/\S+$/.test(v);

function fail(where, message) {
  errors.push(`${where}: ${message}`);
}

function validateAbility(where, ability, cardType) {
  if (ability === null) {
    if (cardType === 'spell') fail(where, 'spell wajib punya ability');
    return;
  }
  if (typeof ability !== 'object' || Array.isArray(ability)) {
    fail(where, 'ability harus object atau null');
    return;
  }
  for (const key of ABILITY_REQUIRED) {
    if (!(key in ability)) fail(where, `ability.${key} wajib ada`);
  }
  for (const key of Object.keys(ability)) {
    if (!ABILITY_ALLOWED.has(key)) fail(where, `ability.${key} tidak dikenal`);
  }
  if (typeof ability.name === 'string') {
    if (ability.name.length < 2 || ability.name.length > 40) {
      fail(where, 'ability.name harus 2..40 karakter');
    }
  } else {
    fail(where, 'ability.name harus string');
  }
  if (!ABILITY_TYPES.includes(ability.type)) {
    fail(where, `ability.type harus salah satu dari ${ABILITY_TYPES.join('|')}`);
  }
  if (!isInt(ability.cost) || ability.cost < 0 || ability.cost > 10) {
    fail(where, 'ability.cost harus integer 0..10');
  }
  if (!ABILITY_TARGETS.includes(ability.target)) {
    fail(where, `ability.target tidak valid`);
  }
  if (!isInt(ability.power) || ability.power < 0 || ability.power > 300) {
    fail(where, 'ability.power harus integer 0..300');
  }
  if (typeof ability.text !== 'string' || ability.text.length < 5 || ability.text.length > 160) {
    fail(where, 'ability.text harus 5..160 karakter');
  }
  const status = ability.status;
  if (status !== undefined && status !== null) {
    if (typeof status !== 'object' || Array.isArray(status)) {
      fail(where, 'ability.status harus object atau null');
    } else {
      for (const key of Object.keys(status)) {
        if (!STATUS_ALLOWED.has(key)) fail(where, `ability.status.${key} tidak dikenal`);
      }
      if (!STATUS_KINDS.includes(status.kind)) {
        fail(where, `status.kind harus salah satu dari ${STATUS_KINDS.join('|')}`);
      }
      if (!isInt(status.value) || status.value < 0 || status.value > 200) {
        fail(where, 'status.value harus integer 0..200');
      }
      if (!isInt(status.turns) || status.turns < 1 || status.turns > 3) {
        fail(where, 'status.turns harus integer 1..3');
      }
    }
  }
}

function validateCard(card, index) {
  const where = `cards[${index}]${card && card.id ? ` (${card.id})` : ''}`;
  if (typeof card !== 'object' || card === null || Array.isArray(card)) {
    fail(where, 'harus object');
    return;
  }
  for (const key of CARD_REQUIRED) {
    if (!(key in card)) fail(where, `${key} wajib ada`);
  }
  for (const key of Object.keys(card)) {
    if (!CARD_ALLOWED.has(key)) fail(where, `properti "${key}" tidak dikenal`);
  }

  if (typeof card.id !== 'string' || !/^card_[a-z0-9_]{3,32}$/.test(card.id)) {
    fail(where, 'id harus cocok ^card_[a-z0-9_]{3,32}$');
  }
  if (typeof card.name !== 'string' || card.name.length < 1 || card.name.length > 40) {
    fail(where, 'name harus 1..40 karakter');
  }
  if (!ELEMENTS.includes(card.element)) fail(where, `element tidak valid: ${card.element}`);
  if (!RARITIES.includes(card.rarity)) fail(where, `rarity tidak valid: ${card.rarity}`);
  if (!CARD_TYPES.includes(card.type)) fail(where, `type tidak valid: ${card.type}`);
  if (!isInt(card.cost) || card.cost < 0 || card.cost > 10) {
    fail(where, 'cost harus integer 0..10');
  }
  if (!Array.isArray(card.keywords) || card.keywords.length > 3) {
    fail(where, 'keywords harus array maks 3 item');
  } else {
    for (const kw of card.keywords) {
      if (!KEYWORDS.includes(kw)) fail(where, `keyword tidak dikenal: ${kw}`);
    }
  }
  if (!isHttpsUrl(card.imageUrl)) fail(where, 'imageUrl harus URL https');
  if (card.thumbnailUrl !== undefined && !isHttpsUrl(card.thumbnailUrl)) {
    fail(where, 'thumbnailUrl harus URL https');
  }
  if (card.model3dUrl !== undefined && card.model3dUrl !== null && !isHttpsUrl(card.model3dUrl)) {
    fail(where, 'model3dUrl harus URL https atau null');
  }
  if (typeof card.obtainable !== 'boolean') fail(where, 'obtainable harus boolean');
  if (card.retired !== undefined && typeof card.retired !== 'boolean') {
    fail(where, 'retired harus boolean');
  }
  if (!isInt(card.version) || card.version < 1) fail(where, 'version harus integer >= 1');
  if (card.flavorText !== undefined && typeof card.flavorText !== 'string') {
    fail(where, 'flavorText harus string');
  }

  if (card.type === 'unit') {
    for (const stat of ['hp', 'attack', 'defense']) {
      if (!isInt(card[stat]) || card[stat] < 0 || card[stat] > 999) {
        fail(where, `${stat} unit harus integer 0..999`);
      }
    }
    if (isInt(card.hp) && card.hp < 1) fail(where, 'hp unit minimal 1');
  }

  if (card.type === 'spell') {
    for (const stat of ['hp', 'attack', 'defense']) {
      if (card[stat] !== null) fail(where, `${stat} spell harus null`);
    }
  }

  validateAbility(where, card.ability, card.type);
}

function crossValidate(cards) {
  const ids = new Set();
  for (const card of cards) {
    if (typeof card?.id === 'string') {
      if (ids.has(card.id)) errors.push(`id duplikat: ${card.id}`);
      ids.add(card.id);
    }
  }
  const obtainable = cards.filter((c) => c?.obtainable !== false && c?.retired !== true);
  for (const rarity of RARITIES) {
    const count = obtainable.filter((c) => c?.rarity === rarity).length;
    if (count === 0) warnings.push(`rarity ${rarity} tidak punya kartu obtainable (gacha akan fallback)`);
  }
  if (obtainable.length < 6) errors.push('minimal 6 kartu obtainable agar gacha bermakna');
}

function sha256(buffer) {
  return `sha256:${createHash('sha256').update(buffer).digest('hex')}`;
}

function nextVersion(previous, explicit) {
  if (explicit) return explicit;
  const now = new Date();
  const stamp = `${now.getUTCFullYear()}.${String(now.getUTCMonth() + 1).padStart(2, '0')}.${String(
    now.getUTCDate(),
  ).padStart(2, '0')}`;
  if (previous?.catalogVersion?.startsWith(`${stamp}.`)) {
    const patch = Number(previous.catalogVersion.slice(stamp.length + 1));
    return `${stamp}.${Number.isFinite(patch) ? patch + 1 : 1}`;
  }
  return `${stamp}.1`;
}

function readFlag(name) {
  const i = process.argv.indexOf(name);
  return i === -1 ? undefined : process.argv[i + 1];
}
const CHECK_ONLY = process.argv.includes('--check');
const EXPLICIT_VERSION = readFlag('--version');

async function main() {
  const raw = await readFile(CARDS_PATH);
  let cards;
  try {
    cards = JSON.parse(raw.toString('utf8'));
  } catch (err) {
    console.error(`✗ cards.json bukan JSON valid: ${err.message}`);
    process.exit(1);
  }

  if (!Array.isArray(cards)) {
    console.error('✗ cards.json harus array');
    process.exit(1);
  }

  cards.forEach(validateCard);
  crossValidate(cards);

  if (errors.length > 0) {
    console.error(`✗ ${errors.length} error pada katalog:`);
    for (const e of errors) console.error(`  - ${e}`);
    process.exit(1);
  }

  for (const w of warnings) console.warn(`⚠ ${w}`);

  let previous;
  try {
    previous = JSON.parse(await readFile(MANIFEST_PATH, 'utf8'));
  } catch {
    previous = undefined;
  }

  const checksum = sha256(raw);
  const payload = {
    schemaVersion: 1,
    catalogVersion: previous?.catalogVersion ?? nextVersion(previous, EXPLICIT_VERSION),
    updatedAt: previous?.updatedAt ?? new Date().toISOString().replace(/\.\d{3}Z$/, 'Z'),
    cardCount: cards.length,
    checksum,
    baseAssetUrl:
      previous?.baseAssetUrl ??
      process.env.CATALOG_BASE_ASSET_URL ??
      'https://cdn.jsdelivr.net/gh/dokimon/dokimon@main/content/cards/',
  };

  if (CHECK_ONLY) {
    if (!previous) {
      console.error('✗ manifest.json tidak ada. Jalankan tanpa --check untuk membuatnya.');
      process.exit(1);
    }
    if (previous.checksum !== checksum) {
      console.error('✗ manifest.checksum tidak cocok dengan cards.json. Jalankan: node scripts/build-catalog.mjs');
      process.exit(1);
    }
    if (previous.cardCount !== cards.length) {
      console.error('✗ manifest.cardCount tidak cocok.');
      process.exit(1);
    }
    console.log(
      `✓ katalog valid & sinkron — version ${previous.catalogVersion}, ${cards.length} kartu, ${checksum.slice(0, 19)}…`,
    );
    return;
  }

  if (EXPLICIT_VERSION) payload.catalogVersion = EXPLICIT_VERSION;
  payload.updatedAt = new Date().toISOString().replace(/\.\d{3}Z$/, 'Z');

  const changed =
    !previous ||
    previous.checksum !== checksum ||
    previous.catalogVersion !== payload.catalogVersion;

  if (!changed) {
    console.log(`✓ tidak ada perubahan — version ${payload.catalogVersion}`);
    return;
  }

  await writeFile(MANIFEST_PATH, `${JSON.stringify(payload, null, 2)}\n`, 'utf8');

  const distribution = {};
  for (const c of cards) distribution[c.rarity] = (distribution[c.rarity] ?? 0) + 1;

  console.log(`✓ manifest ditulis — version ${payload.catalogVersion}`);
  console.log(`  kartu : ${cards.length} (${Object.entries(distribution).map(([k, v]) => `${k} ${v}`).join(', ')})`);
  console.log(`  sha256: ${checksum}`);
}

main().catch((err) => {
  console.error(`✗ gagal: ${err.stack ?? err.message}`);
  process.exit(1);
});

#!/usr/bin/env node
// Menyalin katalog CMS (content/cards/cards.json) ke katalog bundled web
// (src/data/cards.seed.json) — setara frontend/assets/cards/cards.seed.json.
//
//   node scripts/sync-catalog.mjs          # tulis ulang salinan
//   node scripts/sync-catalog.mjs --check  # CI: gagal bila salinan tidak sinkron
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const source = resolve(here, '../../content/cards/cards.json');
const target = resolve(here, '../src/data/cards.seed.json');

const canonical = (text) => `${JSON.stringify(JSON.parse(text), null, 2)}\n`;

const wanted = canonical(readFileSync(source, 'utf8'));
const current = existsSync(target) ? readFileSync(target, 'utf8') : '';

if (process.argv.includes('--check')) {
  if (current !== wanted) {
    process.stderr.write('cards.seed.json tidak sinkron. Jalankan: npm run catalog:sync\n');
    process.exit(1);
  }
  process.stdout.write('cards.seed.json sinkron dengan content/cards/cards.json\n');
  process.exit(0);
}

mkdirSync(dirname(target), { recursive: true });
writeFileSync(target, wanted);
process.stdout.write(`Tersalin ${JSON.parse(wanted).length} kartu → src/data/cards.seed.json\n`);

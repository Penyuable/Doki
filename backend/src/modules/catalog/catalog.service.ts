import crypto from 'node:crypto';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { env } from '../../config/env.js';
import { prisma } from '../../config/prisma.js';
import { AppError } from '../../lib/errors.js';
import { logger } from '../../lib/logger.js';
import {
  cardCatalogSchema,
  crossValidate,
  manifestSchema,
  type Card,
  type Manifest,
} from './catalog.schema.js';

export type CatalogSource = 'memory' | 'db' | 'local' | 'remote';

export type CatalogSnapshot = {
  version: string;
  checksum: string;
  cards: Card[];
  byId: Map<string, Card>;
  source: CatalogSource;
};

export type SyncResult = {
  changed: boolean;
  version: string;
  checksum: string;
  cardCount: number;
  source: 'remote' | 'unchanged';
};

let cache: CatalogSnapshot | null = null;

const sha256 = (text: string) => `sha256:${crypto.createHash('sha256').update(text).digest('hex')}`;

function snapshotOf(
  version: string,
  checksum: string,
  cards: Card[],
  source: CatalogSource,
): CatalogSnapshot {
  const byId = new Map<string, Card>();
  for (const card of cards) byId.set(card.id, card);
  return { version, checksum, cards, byId, source };
}

function parseCards(raw: string, where: string): Card[] {
  let json: unknown;
  try {
    json = JSON.parse(raw);
  } catch {
    throw new AppError('CATALOG_INVALID', `${where}: bukan JSON valid`);
  }
  const parsed = cardCatalogSchema.safeParse(json);
  if (!parsed.success) {
    throw new AppError('CATALOG_INVALID', `${where}: skema tidak valid`, {
      issues: parsed.error.issues.slice(0, 20).map((i) => ({
        path: i.path.join('.'),
        message: i.message,
      })),
    });
  }
  const problems = crossValidate(parsed.data);
  if (problems.length > 0) {
    throw new AppError('CATALOG_INVALID', `${where}: aturan bisnis dilanggar`, { problems });
  }
  return parsed.data;
}

async function readLocalFiles(): Promise<{ cardsRaw: string; manifest: Manifest }> {
  const cardsPath = path.resolve(env.CATALOG_LOCAL_PATH);
  const manifestPath = path.resolve(env.CATALOG_MANIFEST_LOCAL_PATH);

  let cardsRaw: string;
  try {
    cardsRaw = await readFile(cardsPath, 'utf8');
  } catch {
    throw new AppError('CATALOG_UNAVAILABLE', `File katalog lokal tidak ditemukan: ${cardsPath}`);
  }

  let manifestRaw: string | null = null;
  try {
    manifestRaw = await readFile(manifestPath, 'utf8');
  } catch {
    manifestRaw = null;
  }

  if (!manifestRaw) {
    const cards = parseCards(cardsRaw, 'lokal');
    return {
      cardsRaw,
      manifest: {
        schemaVersion: 1,
        catalogVersion: 'local-1',
        updatedAt: new Date().toISOString(),
        cardCount: cards.length,
        checksum: sha256(cardsRaw),
        baseAssetUrl: 'https://cdn.jsdelivr.net/gh/dokimon/dokimon@main/content/cards/',
      },
    };
  }

  const parsedManifest = manifestSchema.safeParse(JSON.parse(manifestRaw));
  if (!parsedManifest.success) {
    throw new AppError('CATALOG_INVALID', 'manifest lokal tidak valid');
  }
  return { cardsRaw, manifest: parsedManifest.data };
}

export async function loadLocalCatalog(): Promise<CatalogSnapshot> {
  const { cardsRaw, manifest } = await readLocalFiles();
  const cards = parseCards(cardsRaw, 'lokal');
  const checksum = sha256(cardsRaw);

  if (manifest.checksum !== checksum) {
    throw new AppError('CATALOG_INVALID', 'checksum manifest lokal tidak cocok dengan cards.json', {
      expected: manifest.checksum,
      actual: checksum,
    });
  }
  if (manifest.cardCount !== cards.length) {
    throw new AppError('CATALOG_INVALID', 'cardCount manifest lokal tidak cocok');
  }

  logger.info('catalog lokal dimuat', { version: manifest.catalogVersion, cards: cards.length });
  return snapshotOf(manifest.catalogVersion, checksum, cards, 'local');
}

async function persist(snapshot: CatalogSnapshot): Promise<void> {
  const payload = JSON.stringify(snapshot.cards);
  await prisma.$transaction([
    prisma.catalogVersion.updateMany({ where: { isActive: true }, data: { isActive: false } }),
    prisma.catalogVersion.upsert({
      where: { version: snapshot.version },
      create: {
        version: snapshot.version,
        checksum: snapshot.checksum,
        cardCount: snapshot.cards.length,
        payload,
        isActive: true,
      },
      update: {
        checksum: snapshot.checksum,
        cardCount: snapshot.cards.length,
        payload,
        isActive: true,
        fetchedAt: new Date(),
      },
    }),
  ]);
}

async function fromDb(version?: string): Promise<CatalogSnapshot | null> {
  const row = version
    ? await prisma.catalogVersion.findUnique({ where: { version } })
    : (await prisma.catalogVersion.findFirst({ where: { isActive: true } })) ??
      (await prisma.catalogVersion.findFirst({ orderBy: { fetchedAt: 'desc' } }));

  if (!row) return null;

  const cards = parseCards(row.payload, `db:${row.version}`);
  return snapshotOf(row.version, row.checksum, cards, 'db');
}

async function fetchText(url: string): Promise<string> {
  const headers: Record<string, string> = {
    accept: 'application/json',
    'user-agent': 'dokimon-backend/1.0',
  };
  if (env.GITHUB_TOKEN) headers.authorization = `Bearer ${env.GITHUB_TOKEN}`;

  const res = await fetch(url, {
    headers,
    signal: AbortSignal.timeout(env.CATALOG_FETCH_TIMEOUT_MS),
  });
  if (!res.ok) throw new Error(`HTTP ${res.status} untuk ${url}`);
  return res.text();
}

function catalogUrls(): string[] {
  const { GITHUB_OWNER: owner, GITHUB_REPO: repo, GITHUB_REF: ref } = env;
  return [
    `${env.CATALOG_CDN_BASE}/${owner}/${repo}@${ref}/content/cards/manifest.json`,
    `${env.CATALOG_RAW_BASE}/${owner}/${repo}/${ref}/content/cards/manifest.json`,
  ];
}

export async function syncCatalog(): Promise<SyncResult> {
  const urls = catalogUrls();
  let lastError: unknown = null;

  for (const manifestUrl of urls) {
    try {
      const manifestRaw = await fetchText(manifestUrl);
      const parsed = manifestSchema.safeParse(JSON.parse(manifestRaw));
      if (!parsed.success) throw new Error('manifest dari GitHub tidak valid');
      const manifest = parsed.data;

      const cardsUrl = manifestUrl.replace(/manifest\.json$/, 'cards.json');
      const cardsRaw = await fetchText(cardsUrl);
      const checksum = sha256(cardsRaw);

      if (checksum !== manifest.checksum) {
        throw new Error('checksum cards.json tidak cocok dengan manifest');
      }

      const cards = parseCards(cardsRaw, 'remote');
      if (cards.length !== manifest.cardCount) {
        throw new Error('cardCount tidak cocok dengan isi cards.json');
      }

      const current = await getSnapshot().catch(() => null);
      if (current && current.checksum === checksum) {
        logger.info('catalog sync: tidak ada perubahan', { version: current.version });
        return {
          changed: false,
          version: current.version,
          checksum,
          cardCount: cards.length,
          source: 'unchanged',
        };
      }

      const snapshot = snapshotOf(manifest.catalogVersion, checksum, cards, 'remote');
      await persist(snapshot);
      cache = snapshot;

      logger.info('catalog sync berhasil', {
        version: snapshot.version,
        cards: cards.length,
        url: cardsUrl,
      });

      return {
        changed: true,
        version: snapshot.version,
        checksum,
        cardCount: cards.length,
        source: 'remote',
      };
    } catch (err) {
      lastError = err;
      logger.warn('catalog sync gagal pada sumber', {
        url: manifestUrl,
        error: err instanceof Error ? err.message : String(err),
      });
    }
  }

  throw new AppError('CATALOG_UNAVAILABLE', 'Semua sumber katalog gagal diakses', {
    error: lastError instanceof Error ? lastError.message : String(lastError),
  });
}

export async function bootstrapCatalog(): Promise<void> {
  try {
    const active = await fromDb();
    if (active) {
      cache = active;
      logger.info('catalog aktif dimuat dari DB', {
        version: active.version,
        cards: active.cards.length,
      });
    } else {
      const local = await loadLocalCatalog();
      await persist(local);
      cache = local;
      logger.info('catalog bootstrap dari file lokal', { version: local.version });
    }
  } catch (err) {
    logger.error('bootstrap catalog gagal', {
      error: err instanceof Error ? err.message : String(err),
    });
  }

  if (env.catalogSyncEnabled) {
    void syncCatalog().catch((err) => {
      logger.warn('sync awal gagal (memakai katalog tersimpan)', {
        error: err instanceof Error ? err.message : String(err),
      });
    });
  }
}

export async function getSnapshot(version?: string): Promise<CatalogSnapshot> {
  if (!version && cache) return cache;

  const fromDatabase = await fromDb(version);
  if (fromDatabase) {
    if (!version) cache = fromDatabase;
    return fromDatabase;
  }

  if (!version) {
    const local = await loadLocalCatalog();
    cache = local;
    return local;
  }

  throw new AppError('CATALOG_UNAVAILABLE', `Katalog versi ${version} tidak tersedia`);
}

export function peekSnapshot(): CatalogSnapshot | null {
  return cache;
}

export async function getManifestInfo() {
  const snapshot = await getSnapshot();
  const row = await prisma.catalogVersion.findUnique({ where: { version: snapshot.version } });
  return {
    version: snapshot.version,
    checksum: snapshot.checksum,
    cardCount: snapshot.cards.length,
    updatedAt: row?.fetchedAt ?? new Date(),
  };
}

export type CardFilters = {
  element?: string;
  rarity?: string;
  type?: string;
  includeRetired?: boolean;
};

export async function listCards(filters: CardFilters = {}, version?: string) {
  const snapshot = await getSnapshot(version);
  let cards = snapshot.cards;
  if (!filters.includeRetired) cards = cards.filter((c) => !c.retired);
  if (filters.element) cards = cards.filter((c) => c.element === filters.element);
  if (filters.rarity) cards = cards.filter((c) => c.rarity === filters.rarity);
  if (filters.type) cards = cards.filter((c) => c.type === filters.type);
  return { version: snapshot.version, checksum: snapshot.checksum, cards };
}

export async function getCard(id: string, version?: string) {
  const snapshot = await getSnapshot(version);
  const card = snapshot.byId.get(id);
  if (!card) throw new AppError('NOT_FOUND', `Kartu ${id} tidak ditemukan`);
  return card;
}

export function gachaPool(snapshot: CatalogSnapshot): Card[] {
  return snapshot.cards.filter((c) => c.obtainable && !c.retired);
}

/** Untuk test: paksa cache tertentu tanpa DB. */
export function __setCacheForTest(snapshot: CatalogSnapshot | null): void {
  cache = snapshot;
}

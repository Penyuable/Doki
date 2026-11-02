import 'dotenv/config';
import { z } from 'zod';

const boolish = z
  .string()
  .optional()
  .transform((v) => v === '1' || v?.toLowerCase() === 'true');

const schema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().positive().default(8080),
  CORS_ORIGINS: z.string().default('http://localhost:3000'),

  DATABASE_URL: z.string().min(1),
  JWT_ACCESS_SECRET: z.string().min(16),
  JWT_REFRESH_SECRET: z.string().min(16),
  ACCESS_TTL_MINUTES: z.coerce.number().int().positive().default(15),
  REFRESH_TTL_DAYS: z.coerce.number().int().positive().default(30),

  GITHUB_OWNER: z.string().default('dokimon'),
  GITHUB_REPO: z.string().default('dokimon'),
  GITHUB_REF: z.string().default('main'),
  CATALOG_CDN_BASE: z.string().url().default('https://cdn.jsdelivr.net/gh'),
  CATALOG_RAW_BASE: z.string().url().default('https://raw.githubusercontent.com'),
  CATALOG_SYNC_INTERVAL_MS: z.coerce.number().int().min(0).default(900_000),
  CATALOG_FETCH_TIMEOUT_MS: z.coerce.number().int().positive().default(8_000),
  CATALOG_LOCAL_PATH: z.string().default('../content/cards/cards.json'),
  CATALOG_MANIFEST_LOCAL_PATH: z.string().default('../content/cards/manifest.json'),
  GITHUB_TOKEN: z.string().optional(),
  ADMIN_TOKEN: z.string().min(8),

  SUPABASE_URL: z.string().url().optional(),
  SUPABASE_PUBLISHABLE_KEY: z.string().optional(),

  DISABLE_CATALOG_SYNC: boolish,
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
});

const parsed = schema.safeParse(process.env);

if (!parsed.success) {
  console.error('✗ Konfigurasi environment tidak valid:');
  for (const issue of parsed.error.issues) {
    console.error(`  - ${issue.path.join('.')}: ${issue.message}`);
  }
  process.exit(1);
}

const raw = parsed.data;

if (raw.NODE_ENV === 'production') {
  const weak = ['replace_with', 'change_me', 'secret'];
  for (const key of ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET', 'ADMIN_TOKEN'] as const) {
    if (weak.some((w) => raw[key].toLowerCase().includes(w)) || raw[key].length < 24) {
      console.error(`✗ ${key} terlalu lemah untuk production (min 24 char, bukan placeholder).`);
      process.exit(1);
    }
  }
}

export const env = {
  ...raw,
  isProd: raw.NODE_ENV === 'production',
  isTest: raw.NODE_ENV === 'test',
  corsOrigins: raw.CORS_ORIGINS.split(',').map((s) => s.trim()).filter(Boolean),
  accessTtlSeconds: raw.ACCESS_TTL_MINUTES * 60,
  refreshTtlMs: raw.REFRESH_TTL_DAYS * 24 * 60 * 60 * 1000,
  catalogSyncEnabled: !raw.DISABLE_CATALOG_SYNC && raw.CATALOG_SYNC_INTERVAL_MS > 0,
} as const;

export type Env = typeof env;

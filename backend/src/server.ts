import { createApp } from './app.js';
import { env } from './config/env.js';
import { prisma } from './config/prisma.js';
import { logger } from './lib/logger.js';
import { bootstrapCatalog, syncCatalog } from './modules/catalog/catalog.service.js';

async function main() {
  await bootstrapCatalog();

  const app = createApp();
  const server = app.listen(env.PORT, () => {
    logger.info('Dokimon API listening', {
      port: env.PORT,
      env: env.NODE_ENV,
      catalog: `${env.GITHUB_OWNER}/${env.GITHUB_REPO}@${env.GITHUB_REF}`,
    });
  });

  if (env.catalogSyncEnabled && env.CATALOG_SYNC_INTERVAL_MS > 0) {
    const timer = setInterval(() => {
      void syncCatalog().catch((err) => {
        logger.warn('catalog sync terjadwal gagal', {
          error: err instanceof Error ? err.message : String(err),
        });
      });
    }, env.CATALOG_SYNC_INTERVAL_MS);
    timer.unref();
  }

  const shutdown = async (signal: string) => {
    logger.info('shutdown', { signal });
    server.close(() => {
      void prisma.$disconnect().finally(() => process.exit(0));
    });
    setTimeout(() => process.exit(1), 10_000).unref();
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
}

main().catch((err) => {
  logger.error('gagal start server', { error: err instanceof Error ? err.stack : String(err) });
  process.exit(1);
});

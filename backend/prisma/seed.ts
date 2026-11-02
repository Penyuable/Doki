/**
 * Seed opsional: pastikan katalog aktif + akun demo.
 *   npm run db:seed
 * Akun demo: demo@dokimon.app / DemoPass123
 */
import { AppError } from '../src/lib/errors.js';
import { prisma } from '../src/config/prisma.js';
import { logger } from '../src/lib/logger.js';
import { register } from '../src/modules/auth/auth.service.js';
import { bootstrapCatalog } from '../src/modules/catalog/catalog.service.js';

async function main() {
  await bootstrapCatalog();

  try {
    const result = await register({
      email: 'demo@dokimon.app',
      username: 'demo_player',
      password: 'DemoPass123',
    });
    logger.info('akun demo dibuat', { userId: result.user.id, username: result.user.username });
  } catch (err) {
    if (err instanceof AppError && err.code === 'DUPLICATE_EMAIL') {
      logger.info('akun demo sudah ada, dilewati');
    } else {
      throw err;
    }
  }

  const counts = {
    users: await prisma.user.count(),
    decks: await prisma.deck.count(),
    catalogVersions: await prisma.catalogVersion.count(),
  };
  logger.info('seed selesai', counts);
}

main()
  .catch((err) => {
    logger.error('seed gagal', { error: err instanceof Error ? err.stack : String(err) });
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());

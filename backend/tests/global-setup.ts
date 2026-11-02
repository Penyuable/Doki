import { execSync } from 'node:child_process';
import { existsSync, rmSync } from 'node:fs';
import path from 'node:path';

export default function setup() {
  const dbPath = path.resolve(process.cwd(), 'prisma', 'test.db');
  for (const file of [dbPath, `${dbPath}-journal`]) {
    if (existsSync(file)) rmSync(file, { force: true });
  }

  execSync('npx prisma db push --skip-generate --accept-data-loss', {
    cwd: process.cwd(),
    stdio: 'pipe',
    env: { ...process.env, DATABASE_URL: 'file:./test.db' },
  });
}

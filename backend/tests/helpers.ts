import request from 'supertest';
import { createApp } from '../src/app.js';
import { bootstrapCatalog } from '../src/modules/catalog/catalog.service.js';
import { prisma } from '../src/config/prisma.js';

export const app = createApp();

let bootstrapped = false;

export async function ensureCatalog(): Promise<void> {
  if (bootstrapped) return;
  await bootstrapCatalog();
  bootstrapped = true;
}

export function authHeader(token: string) {
  return { Authorization: `Bearer ${token}` };
}

let counter = 0;

export async function registerUser(prefix = 'user') {
  counter += 1;
  const stamp = `${Date.now().toString(36)}${counter}`.slice(-10);
  const username = `${prefix}${stamp}`.slice(0, 16);
  const email = `${username}@example.com`;
  const password = 'Password123';

  const res = await request(app)
    .post('/api/v1/auth/register')
    .send({ email, username, password });

  return {
    res,
    email,
    username,
    password,
    token: res.body?.data?.accessToken as string,
    refreshToken: res.body?.data?.refreshToken as string,
    user: res.body?.data?.user as { id: string; gold: number; gems: number },
  };
}

export async function giveGold(userId: string, amount: number) {
  return prisma.user.update({ where: { id: userId }, data: { gold: { increment: amount } } });
}

export { prisma };

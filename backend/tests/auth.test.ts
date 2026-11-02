import { beforeAll, describe, expect, it } from 'vitest';
import request from 'supertest';
import { app, authHeader, ensureCatalog, registerUser } from './helpers.js';

beforeAll(async () => {
  await ensureCatalog();
});

describe('FR-01 Auth', () => {
  it('register membuat user + starter deck + saldo awal', async () => {
    const { res, token } = await registerUser('reg');
    expect(res.status).toBe(201);
    expect(res.body.data.user.gold).toBe(1000);
    expect(res.body.data.user.gems).toBe(50);
    expect(token).toBeTruthy();

    const decks = await request(app).get('/api/v1/decks').set(authHeader(token));
    expect(decks.status).toBe(200);
    expect(decks.body.data.decks).toHaveLength(1);
    expect(decks.body.data.decks[0].name).toBe('Starter');
    expect(decks.body.data.decks[0].cardCount).toBe(20);
    expect(decks.body.data.decks[0].isValid).toBe(true);
    expect(decks.body.data.decks[0].isActive).toBe(true);
  });

  it('email duplikat → 409 DUPLICATE_EMAIL', async () => {
    const { email, username, password } = await registerUser('dup');
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({ email, username: `${username}x`, password });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('DUPLICATE_EMAIL');
  });

  it('username duplikat → 409 DUPLICATE_USERNAME', async () => {
    const { email, username, password } = await registerUser('dup2');
    const res = await request(app)
      .post('/api/v1/auth/register')
      .send({ email: `x${email}`, username, password });
    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('DUPLICATE_USERNAME');
  });

  it('login salah → 401 INVALID_CREDENTIALS', async () => {
    const { email } = await registerUser('badlogin');
    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email, password: 'WrongPassword1' });
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('INVALID_CREDENTIALS');
  });

  it('login benar → token dan /auth/me bekerja', async () => {
    const { email, password, username } = await registerUser('login');
    const login = await request(app).post('/api/v1/auth/login').send({ email, password });
    expect(login.status).toBe(200);

    const me = await request(app)
      .get('/api/v1/auth/me')
      .set(authHeader(login.body.data.accessToken));
    expect(me.status).toBe(200);
    expect(me.body.data.user.username).toBe(username);
  });

  it('refresh rotation: token lama tidak bisa dipakai dua kali', async () => {
    const { refreshToken } = await registerUser('rot');

    const first = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken });
    expect(first.status).toBe(200);
    expect(first.body.data.refreshToken).not.toBe(refreshToken);

    const reuse = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken });
    expect(reuse.status).toBe(401);
    expect(reuse.body.error.code).toBe('REFRESH_REUSED');

    const after = await request(app)
      .post('/api/v1/auth/refresh')
      .send({ refreshToken: first.body.data.refreshToken });
    expect(after.status).toBe(401);
  });

  it('tanpa token → 401', async () => {
    const res = await request(app).get('/api/v1/auth/me');
    expect(res.status).toBe(401);
    expect(res.body.error.code).toBe('UNAUTHORIZED');
  });

  it('daily claim hanya sekali per hari', async () => {
    const { token } = await registerUser('daily');
    const first = await request(app)
      .post('/api/v1/user/daily-claim')
      .set(authHeader(token));
    expect(first.status).toBe(200);
    expect(first.body.data.reward.gold).toBe(100);

    const second = await request(app)
      .post('/api/v1/user/daily-claim')
      .set(authHeader(token));
    expect(second.status).toBe(409);
    expect(second.body.error.code).toBe('ALREADY_CLAIMED');
  });
});

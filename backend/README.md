# Dokimon Backend (Express + Prisma)

API untuk auth, katalog (GitHub CMS), gacha, inventory, deck, battle, dan telemetry.
**Status: berjalan & teruji — 56 test lulus.**

## Quick start

```bash
cd backend
cp .env.example .env        # isi secret (sudah tersedia .env dev)
npm install
npx prisma db push          # buat SQLite dev.db
npm run dev                 # http://localhost:8080
```

Verifikasi:

```bash
curl http://localhost:8080/healthz
node scripts/smoke.mjs      # E2E: register → gacha → deck → battle → reward
npm test                    # 56 test (unit + integrasi)
```

Akun demo (opsional): `npm run db:seed` → `demo@dokimon.app` / `DemoPass123`.

## Endpoints (`/api/v1`)

| Modul | Endpoint | Auth |
|---|---|---|
| Auth | `POST /auth/register`, `POST /auth/login`, `POST /auth/refresh`, `POST /auth/logout` | – / Bearer |
| Auth | `GET /auth/me` | Bearer |
| User | `GET /user/profile`, `GET /user/wallet`, `POST /user/daily-claim` | Bearer |
| Catalog | `GET /catalog/manifest`, `GET /catalog/cards`, `GET /catalog/cards/:id` | – |
| Catalog | `POST /catalog/internal/sync` | `X-Admin-Token` |
| Gacha | `GET /gacha/rates` | – |
| Gacha | `GET /gacha/pity`, `POST /gacha/pull`, `GET /gacha/history` | Bearer |
| Inventory | `GET /inventory`, `GET /inventory/:cardId` | Bearer |
| Deck | `GET/POST /decks`, `POST /decks/validate`, `GET/PATCH/DELETE /decks/:id`, `PUT /decks/:id/activate` | Bearer |
| Battle | `POST /battles/start`, `POST /battles/:matchId/result`, `GET /battles/history` | Bearer |
| Telemetry | `POST /telemetry/events` | Bearer |

Contoh pull:

```bash
curl -X POST http://localhost:8080/api/v1/gacha/pull \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"count":10,"currency":"gold","idempotencyKey":"8f14e45f-ea8b-4c2a-9d31-6b0f0a1c2d3e"}'
```

Semua response memakai envelope `{data, meta}` / `{error:{code,message,details}}`.

## Database

- **Default dev:** SQLite (`DATABASE_URL="file:./dev.db"`) — zero config.
- **Supabase Postgres:** isi `DATABASE_URL` dengan connection string pooler, lalu:
  ```bash
  npm run db:generate:pg && npm run db:push:pg
  ```
- URL project Supabase & publishable key ada di `.env` (publishable key **aman** untuk client, tetapi **tidak bisa** dipakai backend untuk akses DB — backend butuh connection string berisi password).

Dua schema disediakan agar tipe data identik:
`prisma/schema.prisma` (SQLite) dan `prisma/schema.postgres.prisma` (Postgres).

## Aturan yang ditegakkan server

| Area | Aturan |
|---|---|
| Gacha | Rate 60/25/10/4/0.9/0.1, pity 50, 10x jaminan Rare+, RNG `crypto`, idempotency key, audit `gacha_pulls` |
| Deck | tepat 20 kartu, maks 3 copy/ID, hanya kartu dimiliki, maks 10 deck, nama unik |
| Battle | hasil diverifikasi (umur match, durasi vs turn, menang < 2 turn ditolak), reward idempotent, batas 40 match ber-reward/hari (WIB) |
| Saldo | hanya berubah via transaksi; decrement bersyarat `saldo >= harga` |

## Struktur

```
src/
  config/    env, prisma, economy (semua angka), 
  lib/       errors, jwt, password, time (WIB), validate, logger
  middleware/ auth, error, rateLimit, requestId
  modules/   auth, user, catalog, gacha, inventory, deck, battle, telemetry
tests/       unit (gacha math, deck rules) + integrasi (auth, gacha, deck, battle)
```

## Catatan

- Password memakai **bcrypt cost 12** (fallback yang diizinkan PRD). Ganti ke argon2id saat deploy produksi.
- Katalog bootstrap dari `../content/cards/` lalu sync ke GitHub setiap 15 menit (`CATALOG_SYNC_INTERVAL_MS`).
- Rate limit dinonaktifkan otomatis saat `NODE_ENV=test`.
- `npm run build` menghasilkan `dist/` (ESM), `npm start` menjalankannya.

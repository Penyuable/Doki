# TECH SPEC — Dokimon TCG 3D

> Dokumen ini adalah pasangan teknis dari [`PRD.md`](./PRD.md). Semua nomor AC/FR merujuk ke PRD.
> **Aturan:** bila dokumen ini dan PRD bertentangan, PRD menang untuk perilaku produk, dokumen ini menang untuk detail implementasi. Bila ragu, tulis pertanyaan di `docs/OPEN_QUESTIONS.md` — jangan menebak.

---

## 1. Struktur Repo

```
dokimon/
├── AGENTS.md                     # aturan wajib untuk AI agent
├── README.md
├── docs/
│   ├── PRD.md
│   ├── TECH_SPEC.md
│   ├── AI_AGENT_GUIDE.md
│   └── OPEN_QUESTIONS.md         # (dibuat saat ada ambiguitas)
├── content/cards/                # ← ini yang jadi "CMS" di GitHub
│   ├── manifest.json
│   ├── cards.json
│   ├── schema.json
│   └── README.md                 # konvensi aset
├── scripts/
│   ├── build-catalog.mjs         # validasi + hitung checksum + tulis manifest
│   └── simulate-balance.mjs      # simulasi gacha & match (opsional M6)
├── backend/
│   ├── prisma/schema.prisma
│   ├── prisma/seed.ts
│   ├── src/
│   │   ├── config/{env.ts,prisma.ts,economy.ts,logger.ts}
│   │   ├── middleware/{auth.ts,error.ts,rateLimit.ts,requestId.ts}
│   │   ├── modules/
│   │   │   ├── auth/{auth.routes.ts,auth.service.ts,auth.schema.ts}
│   │   │   ├── user/{user.routes.ts,user.service.ts}
│   │   │   ├── catalog/{catalog.routes.ts,catalog.service.ts,catalog.schema.ts}
│   │   │   ├── gacha/{gacha.routes.ts,gacha.service.ts,gacha.math.ts}
│   │   │   ├── inventory/{inventory.routes.ts,inventory.service.ts}
│   │   │   ├── deck/{deck.routes.ts,deck.service.ts,deck.rules.ts}
│   │   │   ├── battle/{battle.routes.ts,battle.service.ts,reward.ts}
│   │   │   └── telemetry/{telemetry.routes.ts}
│   │   ├── lib/{errors.ts,jwt.ts,password.ts,rng.ts,validate.ts}
│   │   ├── app.ts
│   │   └── server.ts
│   ├── tests/{auth.test.ts,gacha.test.ts,deck.test.ts,catalog.test.ts,helpers.ts}
│   ├── .env.example
│   ├── package.json
│   └── tsconfig.json
├── web/                          # klien web Next.js (lihat §16) — tambahan, Flutter tetap
│   ├── src/app/                  # rute App Router (static export)
│   ├── src/lib/                  # pure TS: battle/, domain/, data/, i18n/, ui/
│   ├── src/components/           # React (clay UI, kreatur SVG, arena)
│   ├── src/data/cards.seed.json  # salinan katalog bundled (scripts/sync-catalog.mjs)
│   └── test/                     # node --test (engine golden vs Dart, bot, backend lokal)
└── frontend/
    ├── lib/
    │   ├── core/
    │   │   ├── config/{env.dart,economy.dart,balance.dart}
    │   │   ├── network/{dio_client.dart,api_exception.dart,auth_interceptor.dart}
    │   │   ├── storage/{secure_store.dart,hive_boxes.dart}
    │   │   ├── theme/{app_theme.dart,rarity_colors.dart}
    │   │   ├── router/app_router.dart
    │   │   ├── l10n/{app_id.arb,app_en.arb}
    │   │   └── widgets/{primary_button.dart,error_view.dart,loading_view.dart}
    │   ├── features/
    │   │   ├── auth/{data,domain,presentation}
    │   │   ├── catalog/{data,domain,presentation}
    │   │   ├── gacha/{data,domain,presentation}
    │   │   ├── inventory/{data,domain,presentation}
    │   │   ├── deck/{data,domain,presentation}
    │   │   ├── battle/{data,domain,presentation}
    │   │   ├── profile/{data,domain,presentation}
    │   │   └── settings/{data,domain,presentation}
    │   ├── shared/models/{card_model.dart,user_model.dart,deck_model.dart}
    │   ├── app.dart
    │   └── main.dart
    ├── assets/{cards/cards.seed.json,images/,audio/}
    ├── test/
    ├── pubspec.yaml
    └── analysis_options.yaml
```

**Konvensi penamaan:** file `snake_case.dart`, kelas `PascalCase`, konstanta `kCamelCase`, tabel DB `snake_case` plural, endpoint `kebab-case`.

---

## 2. Environment & Tooling

| Tool | Versi minimum | Catatan |
|---|---|---|
| Node.js | 20 LTS | ESM (`"type": "module"`) |
| TypeScript | 5.4 | `strict: true`, `noUncheckedIndexedAccess` |
| Prisma | 5.x | SQLite dev, Postgres prod (schema kompatibel) |
| Express | 4.19 | Jangan pakai 5.x |
| Zod | 3.23 | Validasi semua input |
| Vitest + Supertest | terbaru | Test backend |
| Flutter | 3.24+ / Dart 3.4+ | null safety wajib |
| flutter_bloc | 8.x | State management |
| go_router | 14.x | Routing deklaratif |
| dio | 5.x | HTTP + interceptor |
| hive_ce / hive | 2.x | Cache katalog & settings |
| flutter_secure_storage | 9.x | Token |
| model_viewer_plus | 1.7+ | 3D |
| flutter_animate | 4.x | Animasi |
| cached_network_image | 3.x | Gambar |
| freezed + json_serializable | terbaru | Model immutable |
| flutter_localizations + intl | SDK | i18n |

**Perintah standar** (harus ada di README):

```bash
# backend
cd backend && npm i && npx prisma migrate dev && npm run dev   # :8080
npm test

# frontend
cd frontend && flutter pub get && flutter run
flutter test && flutter analyze
```

---

## 3. Backend Architecture

### 3.1 Middleware order (penting)
```
requestId → helmet → cors (whitelist) → json({limit:'64kb'}) → rateLimit(global)
→ route
   → [authGuard] → validate(zod) → controller → service → prisma
→ errorHandler (last)
```

### 3.2 Response envelope

Sukses:
```json
{ "data": { }, "meta": { "requestId": "req_...", "catalogVersion": "2026.11.01.1" } }
```
Error:
```json
{ "error": { "code": "INSUFFICIENT_FUNDS", "message": "Gold tidak cukup", "details": { "required": 900, "available": 400 } }, "meta": { "requestId": "req_..." } }
```

### 3.3 Kode error kanonik

| HTTP | Code | Kapan |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Zod gagal; `details.issues[]` |
| 400 | `DECK_INVALID` | Aturan deck dilanggar; `details.violations[]` |
| 401 | `UNAUTHORIZED` | Tidak ada/rusak Authorization |
| 401 | `TOKEN_EXPIRED` | Access token kadaluarsa (client refresh) |
| 401 | `INVALID_CREDENTIALS` | Login gagal |
| 401 | `REFRESH_REUSED` | Refresh token dipakai ulang → family dicabut |
| 402 | `INSUFFICIENT_FUNDS` | Saldo kurang |
| 403 | `FORBIDDEN` | Akses resource user lain |
| 404 | `NOT_FOUND` | Resource tidak ada |
| 409 | `DUPLICATE_EMAIL` / `DUPLICATE_USERNAME` / `DECK_NAME_TAKEN` | Konflik unik |
| 409 | `CARD_NOT_OWNED` | Deck berisi kartu yang tidak dimiliki |
| 422 | `CATALOG_INVALID` | Snapshot katalog ditolak |
| 429 | `RATE_LIMITED` | Limit; header `Retry-After` |
| 503 | `CATALOG_UNAVAILABLE` | Tidak ada katalog valid sama sekali |

### 3.4 Config env (`.env.example`)

```env
NODE_ENV=development
PORT=8080
DATABASE_URL="file:./dev.db"
JWT_ACCESS_SECRET=change_me_min_32_chars
JWT_REFRESH_SECRET=change_me_min_32_chars
ACCESS_TTL=15m
REFRESH_TTL=30d

GITHUB_OWNER=your-user
GITHUB_REPO=dokimon
GITHUB_REF=main
CATALOG_BASE_URL_CDN=https://cdn.jsdelivr.net/gh
CATALOG_BASE_URL_RAW=https://raw.githubusercontent.com
CATALOG_SYNC_INTERVAL_MS=900000
CATALOG_FETCH_TIMEOUT_MS=8000
GITHUB_TOKEN=            # opsional, hanya untuk private repo / rate limit
ADMIN_TOKEN=change_me

CORS_ORIGINS=http://localhost:3000
LOG_LEVEL=info
```

---

## 4. Database (Prisma)

```prisma
model User {
  id            String   @id @default(cuid())
  email         String   @unique
  username      String   @unique
  passwordHash  String
  gold          Int      @default(1000)
  gems          Int      @default(50)
  level         Int      @default(1)
  xp            Int      @default(0)
  wins          Int      @default(0)
  losses        Int      @default(0)
  draws         Int      @default(0)
  pityCounter   Int      @default(0)   // pull sejak Epic+ terakhir
  lastDailyAt   DateTime?
  dailyStreak   Int      @default(0)
  activeDeckId  String?  @unique
  createdAt     DateTime @default(now())
  updatedAt     DateTime @updatedAt

  inventory     InventoryCard[]
  decks         Deck[]
  pulls         GachaPull[]
  matches       Match[]
  refreshTokens RefreshToken[]
}

model RefreshToken {
  id         String   @id @default(cuid())
  userId     String
  tokenHash  String   @unique      // sha256(token)
  familyId   String
  expiresAt  DateTime
  revokedAt  DateTime?
  createdAt  DateTime @default(now())
  user       User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId])
  @@index([familyId])
}

model InventoryCard {
  userId     String
  cardId     String
  quantity   Int      @default(1)
  firstSeenAt DateTime @default(now())
  user       User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@id([userId, cardId])
}

model GachaPull {
  id             String   @id @default(cuid())
  userId         String
  batchId        String
  idempotencyKey String?
  cardId         String
  rarity         String
  source         String   // gold | gem
  costAmount     Int
  catalogVersion String
  pityBefore     Int
  pityAfter      Int
  wasPity        Boolean  @default(false)
  isNew          Boolean  @default(false)
  createdAt      DateTime @default(now())
  user           User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, idempotencyKey])
  @@index([userId, createdAt])
  @@index([batchId])
}

model Deck {
  id        String   @id @default(cuid())
  userId    String
  name      String
  isActive  Boolean  @default(false)
  createdAt DateTime @default(now())
  updatedAt DateTime @updatedAt
  cards     DeckCard[]
  user      User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@unique([userId, name])
  @@index([userId])
}

model DeckCard {
  deckId   String
  cardId   String
  quantity Int
  deck     Deck   @relation(fields: [deckId], references: [id], onDelete: Cascade)

  @@id([deckId, cardId])
}

model Match {
  id          String   @id @default(cuid())
  userId      String
  difficulty  String   // easy | medium | master
  outcome     String   // win | loss | draw
  turns       Int
  durationMs  Int
  logHash     String
  deckSnapshot Json
  goldAwarded Int      @default(0)
  xpAwarded   Int      @default(0)
  firstWinBonus Boolean @default(false)
  createdAt   DateTime @default(now())
  user        User     @relation(fields: [userId], references: [id], onDelete: Cascade)

  @@index([userId, createdAt])
  @@index([userId, difficulty, createdAt])
}

model CatalogVersion {
  version    String   @id
  checksum   String
  cardCount  Int
  payload    Json
  isActive   Boolean  @default(false)
  fetchedAt  DateTime @default(now())

  @@index([isActive])
}

model TelemetryEvent {
  id        String   @id @default(cuid())
  userId    String?
  name      String
  props     Json
  createdAt DateTime @default(now())

  @@index([name, createdAt])
}
```

Catatan:
- `gold`/`gems` **tidak boleh** diubah lewat `update` biasa tanpa cek ≥ 0. Gunakan `prisma.$transaction` + `updateMany({ where: { id, gold: { gte: cost } }, data: { gold: { decrement: cost } } })` lalu cek `count === 1`.
- `Deck.isActive` + `User.activeDeckId` harus konsisten; aktifkan deck dalam satu transaksi.
- Index `GachaPull(userId, createdAt)` untuk history pagination.

---

## 5. API Contract (`/api/v1`)

### 5.1 Auth

| Method | Path | Auth | Body / Query | Response |
|---|---|---|---|---|
| POST | `/auth/register` | – | `{email, username, password}` | `{user, accessToken, refreshToken}` |
| POST | `/auth/login` | – | `{email, password}` | `{user, accessToken, refreshToken}` |
| POST | `/auth/refresh` | – | `{refreshToken}` | `{accessToken, refreshToken}` |
| POST | `/auth/logout` | Bearer | `{refreshToken}` | `204` |
| GET | `/auth/me` | Bearer | – | `{user, stats, activeDeckId}` |

**Contoh register**
```http
POST /api/v1/auth/register
Content-Type: application/json

{ "email": "ash@example.com", "username": "ash_ketchum", "password": "Pikachu123" }
```
```json
{
  "data": {
    "user": { "id": "usr_1", "email": "ash@example.com", "username": "ash_ketchum",
              "gold": 1000, "gems": 50, "level": 1, "xp": 0 },
    "accessToken": "eyJ...",
    "refreshToken": "rt_..."
  }
}
```
Efek samping: buat 20 kartu starter di inventory + deck "Starter" aktif.

**Aturan refresh rotation:** setiap refresh, token lama `revokedAt = now()`, buat token baru di `familyId` sama. Bila token yang sudah revoked dipakai → cabut semua token `familyId` itu → `401 REFRESH_REUSED`.

### 5.2 User

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/user/profile` | – | `{user, stats, collection:{owned,total}, activeDeck}` |
| GET | `/user/wallet` | – | `{gold, gems, updatedAt}` |
| POST | `/user/daily-claim` | – | `{claimed, streak, reward:{gold,gems}, nextClaimAt}` |

### 5.3 Catalog

| Method | Path | Auth | Query | Response |
|---|---|---|---|---|
| GET | `/catalog/manifest` | – | – | `{version, checksum, cardCount, updatedAt}` |
| GET | `/catalog/cards` | – | `?version=&element=&rarity=&type=` | `{version, cards:[CardModel]}` |
| GET | `/catalog/cards/:id` | – | – | `{card}` |
| POST | `/internal/catalog/sync` | `X-Admin-Token` | – | `{version, changed:boolean}` |

Header cache: `ETag: "<checksum>"`, `Cache-Control: public, max-age=300`. Kirim `304` bila `If-None-Match` cocok.

### 5.4 Gacha

| Method | Path | Auth | Body | Response |
|---|---|---|---|---|
| GET | `/gacha/rates` | – | – | `{rates:[{rarity,percent}], pity:{threshold:50, current?}}` |
| GET | `/gacha/pity` | Bearer | – | `{counter, threshold, guaranteedIn}` |
| POST | `/gacha/pull` | Bearer | `{count:1|10, currency:"gold"|"gem", idempotencyKey}` | `{results:[...], balance, pity}` |
| GET | `/gacha/history` | Bearer | `?cursor=&limit=20` | `{items:[...], nextCursor}` |

**Contoh request/response pull**
```json
// request
{ "count": 10, "currency": "gold", "idempotencyKey": "8f14e45f-ea8b-4c2a-9d31-6b0f0a1c2d3e" }
```
```json
{
  "data": {
    "batchId": "bat_01H...",
    "results": [
      { "cardId": "card_003", "rarity": "Common",   "isNew": true,  "wasPity": false },
      { "cardId": "card_011", "rarity": "Uncommon", "isNew": false, "wasPity": false },
      { "cardId": "card_018", "rarity": "Rare",     "isNew": true,  "wasPity": false }
    ],
    "balance": { "gold": 100, "gems": 50 },
    "pity": { "counter": 7, "threshold": 50 }
  }
}
```
> `results` selalu menyertakan objek kartu **lengkap** pada field `card` (join katalog) supaya client tidak perlu lookup terpisah. Contoh di atas memangkas field tersebut agar ringkas. Client tetap memvalidasi `cardId` ada di katalog lokal.

### 5.5 Inventory

| Method | Path | Query | Response |
|---|---|---|---|
| GET | `/inventory` | `?element=&rarity=&type=&sort=&cursor=&limit=50` | `{items:[{cardId, quantity, firstSeenAt, card}], nextCursor, owned, total}` |
| GET | `/inventory/:cardId` | – | `{cardId, quantity, card}` |

### 5.6 Deck

| Method | Path | Body | Response |
|---|---|---|---|
| GET | `/decks` | – | `{decks:[{id,name,isActive,cardCount,isValid,violations}]}` |
| POST | `/decks` | `{name, cards:[{cardId, quantity}]}` | `201 {deck}` |
| PATCH | `/decks/:id` | `{name?, cards?}` | `{deck}` |
| DELETE | `/decks/:id` | – | `204` |
| PUT | `/decks/:id/activate` | – | `{activeDeckId}` |
| POST | `/decks/validate` | `{cards}` | `{valid, violations, curve:{1:n,...}}` |

**Bentuk violation** (dipakai juga di `DECK_INVALID`):
```json
{ "code": "COPY_LIMIT_EXCEEDED", "cardId": "card_001", "message": "Maksimal 3 copy", "actual": 4, "limit": 3 }
```
Kode violation: `DECK_SIZE`, `COPY_LIMIT_EXCEEDED`, `CARD_NOT_OWNED`, `CARD_NOT_PLAYABLE` (bukan unit/spell), `DUPLICATE_ENTRY`, `DECK_LIMIT_REACHED`.

### 5.7 Battle

| Method | Path | Body | Response |
|---|---|---|---|
| POST | `/battles/start` | `{difficulty:"easy"|"medium"|"master", deckId, seed?}` | `{matchId, seed, botDeck:[CardModel], playerDeck:[CardModel], startedAt}` |
| POST | `/battles/:matchId/result` | `{outcome, turns, durationMs, logHash, engineVersion}` | `{outcome, rewards, stats, levelUp}` |
| GET | `/battles/history` | `?limit=20&cursor=` | `{items, nextCursor}` |

Verifikasi server (v1, trust-but-verify):
- `matchId` milik user, belum pernah di-submit, umur < 2 jam.
- `turns` 1–50, `durationMs ≥ turns × 500` dan `≤ 3 jam`.
- `outcome` valid; bila menang klaim `turns` < 2 → tolak (`422 SUSPICIOUS_RESULT`), catat flag.
- `logHash` = `sha256(JSON.stringify(actionLog))` dikirim client pada build debug; di release minimal `sha256(matchId + outcome + turns + seed)` agar tidak bisa dikarang tanpa seed.
- Reward idempotent: `Match` unik per id; submit kedua → `409 MATCH_ALREADY_REPORTED` atau kembalikan hasil lama (pilih: **kembalikan 200 dengan `alreadyReported: true`**, lebih ramah retry).

**Bot deck** dibuat server dari katalog (pool rarity ≤ Rare untuk Easy, ≤ Epic untuk Medium, semua untuk Master) supaya pemain tidak bisa melihat deck bot sebelumnya dan tidak perlu menyimpan deck bot di client sampai match mulai.

### 5.8 Telemetry

`POST /telemetry/events` (Bearer, batch ≤ 50, body ≤ 32 kb) → `202`. Validasi: nama event dari whitelist, props JSON ≤ 2 kb, tanpa field sensitif (`password`, `token`, `email`).

---

## 6. Algoritma Gacha (eksak, harus diikuti)

Konstanta di `backend/src/config/economy.ts`:

```ts
export const GACHA_RATES = [
  { rarity: 'Common',    weight: 6000 },
  { rarity: 'Uncommon',  weight: 2500 },
  { rarity: 'Rare',      weight: 1000 },
  { rarity: 'Epic',      weight: 400  },
  { rarity: 'Legendary', weight: 90   },
  { rarity: 'Master',    weight: 10   },
] as const;

export const PITY_THRESHOLD = 50;
export const PITY_BONUS_WEIGHTS = [
  { rarity: 'Epic', weight: 800 }, { rarity: 'Legendary', weight: 180 }, { rarity: 'Master', weight: 20 },
];
export const PRICE = {
  single: { gold: 100, gem: 1 },
  ten:    { gold: 900, gem: 9 },
};
export const GUARANTEED_RARE_PLUS_ON_TEN = true;
```

`pull(userId, count, currency, idempotencyKey)`:

1. **Idempotency check.** Cari `GachaPull` dengan `(userId, idempotencyKey)`. Ada → bangun response dari batch itu, **tanpa** potong saldo.
2. **Ambil katalog aktif** (snapshot `CatalogVersion.isActive`). Tidak ada → `503 CATALOG_UNAVAILABLE`.
3. **Hitung biaya** dari `count`. Transaksi:
   - `updateMany` user dengan syarat saldo ≥ biaya → decrement; `count === 0` → transaksi rollback + `402`.
   - Baca `pityCounter` (di dalam transaksi, `SELECT ... FOR UPDATE` bila Postgres; SQLite serialized).
4. **Loop `count` kali**, per pull:
   ```
   if (pityCounter + 1 >= PITY_THRESHOLD) → rarity = weightedPick(PITY_BONUS_WEIGHTS); wasPity = true
   else → rarity = weightedPick(GACHA_RATES)
   ```
   Lalu `card = uniformPick(cards.filter(c => c.rarity === rarity && c.obtainable))`.
   Bila pool rarity kosong → turun satu tier (Epic→Rare→...→Common) dan set `fallbackFrom`.
   Update counter: `rarity ∈ {Epic, Legendary, Master} ? 0 : pityCounter + 1`.
5. **10x guarantee:** bila `count === 10` dan tidak ada hasil `Rare+`, ulang hasil terakhir dengan rarity `Rare` (atau `PITY_BONUS_WEIGHTS` bila `wasPity`), `guaranteedRare = true`.
6. Tulis semua `GachaPull` (satu `batchId`), update `User.pityCounter` dan saldo dalam transaksi yang **sama**.
7. Return results + balance + pity.

**RNG:** `crypto.randomInt(0, totalWeight)` (Node) — jangan `Math.random()`. `weightedPick` harus punya unit test dengan stub RNG agar boundary bisa diuji (mis. `randomInt` mengembalikan 0, 5999, 6000, 9999).

**Tabel batas bobot** (untuk test): cumulative 0–5999 Common, 6000–8499 Uncommon, 8500–9499 Rare, 9500–9899 Epic, 9900–9989 Legendary, 9990–9999 Master.

**Pity boundary truth table:**

| pityCounter sebelum | Hasil |
|---|---|
| 47 | roll normal → counter 48 |
| 48 | roll normal → counter 49 |
| 49 | **dipaksa** Epic+ (`pityCounter + 1 >= 50`), counter reset 0 |
| 0 | roll normal |

> Catatan: definisi "50 tarikan" = pull ke-50 sejak reset. Dengan tabel di atas, pull ke-50 dipaksa. Uji eksplisit 3 kasus ini.

**Distribusi test (Vitest):**
```ts
// 100_000 pull, stub RNG nyata (bukan dipaksa), toleransi ±0.5% absolut per tier
expect(rate('Common')).toBeCloseTo(0.60, 2); // 0.595–0.605
```
Plus chi-square manual terhadap 6 sel.

---

## 7. Catalog Sync (GitHub CMS)

### 7.1 Kontrak file

`content/cards/manifest.json`
```json
{
  "schemaVersion": 1,
  "catalogVersion": "2026.11.01.1",
  "updatedAt": "2026-11-01T10:00:00Z",
  "cardCount": 25,
  "checksum": "sha256:9f2c...",
  "baseAssetUrl": "https://cdn.jsdelivr.net/gh/owner/repo@main/content/cards/"
}
```
`content/cards/cards.json` → array `CardModel` (lihat `content/cards/schema.json`).

`CardModel` (kontrak final):
```ts
type CardModel = {
  id: string;                 // ^card_[a-z0-9_]{3,32}$ , unik
  name: string;               // 1..40
  element: 'Fire'|'Water'|'Earth'|'Air'|'Void';
  rarity: 'Common'|'Uncommon'|'Rare'|'Epic'|'Legendary'|'Master';
  type: 'unit'|'spell';
  cost: number;               // 0..10
  hp: number|null;            // unit: 1..999 ; spell: null
  attack: number|null;        // unit: 0..999 ; spell: null
  defense: number|null;       // unit: 0..999 ; spell: null
  keywords: string[];         // subset: charge|pierce|lifesteal (lihat §8.5a)
  ability: Ability|null;
  flavorText?: string;
  imageUrl: string;           // https
  thumbnailUrl?: string;
  model3dUrl?: string|null;   // .glb https
  obtainable: boolean;        // default true
  retired?: boolean;
  version: number;            // >= 1
};

type Ability = {
  name: string;
  type: 'attack'|'heal'|'buff'|'control'|'shield';
  cost: number;               // 0..10
  target: 'enemy_unit'|'any_unit'|'self'|'all_enemy_units'|'all_allies'|'enemy_player';
  power: number;              // 0..300 (damage/heal value)
  status?: { kind:'burn'|'freeze'|'shield'|'rally'; value:number; turns:number } | null;
  text: string;
};
```

### 7.2 Alur sync service

```
onBoot() + setInterval(15m):
  1. GET {CDN}/{owner}/{repo}@{ref}/content/cards/manifest.json  (timeout 8s, If-None-Match: <checksum>)
  2. 304 → selesai.
  3. GET cards.json
  4. validasi schema.json (ajv/zod) + aturan bisnis (unik, minimal 1 per rarity, semua URL https)
  5. checksum sha256(rawCards) === manifest.checksum ? lanjut : tolak (log error)
  6. upsert CatalogVersion{version, payload}; aktifkan (transaction: isActive lama false)
  7. cache in-memory {version, cards, byId} + log info
  Gagal di langkah mana pun → pertahankan cache & version lama, log warn/error, jangan crash.
```

- **Sumber URL:** CDN dulu; bila gagal (bukan 304), fallback `raw.githubusercontent.com`. Simpan `sourceUsed` di log.
- **Retry:** exponential backoff 3× (1s, 4s, 12s) per siklus, lalu berhenti sampai interval berikutnya.
- **Startup tanpa katalog:** baca `CatalogVersion` terakhir dari DB; bila kosong, serve bundled `content/cards/cards.json` dari repo backend (salin saat build) → `source: "bundled"`.
- **Rate limit:** jsDelivr tidak butuh token; raw butuh token bila private. Jangan panggil API GitHub (`/repos/...`) di jalur kritis.

### 7.3 Rilis konten (dokumentasikan di `content/cards/README.md`)
1. Edit `cards.json` (jangan ubah `id` yang sudah ada).
2. Upload aset: `images/<id>.webp` (512×768, ≤120 KB), `models/<id>.glb` (≤2 MB).
3. `node scripts/build-catalog.mjs` → tulis `manifest.json` + validasi.
4. Commit & push ke `main`.
5. Tunggu ≤ 15 menit (atau `POST /internal/catalog/sync` dengan admin token).
6. Verifikasi `GET /api/v1/catalog/manifest` → `catalogVersion` baru.

---

## 8. Battle Engine (pure Dart)

Lokasi: `frontend/lib/features/battle/domain/`.
**Wajib pure Dart**: tidak impor `flutter`, tidak ada I/O, tidak ada `DateTime.now()`, tidak ada `Random()` tanpa seed. Ini agar bisa diuji dan dipakai bot.

### 8.1 Struktur

```dart
enum BattlePhase { upkeep, action, ended }
enum CardElement { fire, water, earth, air, void }
enum Rarity { common, uncommon, rare, epic, legendary, master }
enum Stance { ready, tapped, guarding }

class BattleConfig {           // semua angka di sini, jangan hardcode
  final int playerHp;          // 200
  final int maxEnergy;         // 10
  final int startingEnergy;    // 1
  final int boardSlots;        // 3
  final int startingHand;      // 4
  final int handLimit;         // 8
  final double guardDamageMultiplier; // 0.5
  final double guardCounterRatio;     // 0.3
  final double defenseMitigation;     // 0.5
  final int fatigueBase;       // 20
  final int fatigueStep;       // 10
  final int maxTurns;          // 50
}

class BattleUnit {
  final String instanceId;     // unik per instance
  final String cardId;
  final CardModel card;
  int hp; int maxHp; int attack; int defense;
  Stance stance;
  bool hasActed;
  bool summonedThisTurn;
  List<StatusEffect> statuses;
}

class BattlePlayerState {
  int hp; int maxHp; int energy; int maxEnergy;
  List<BattleUnit> board;      // maks 3
  List<CardModel> hand;        // maks 8
  List<CardModel> deck;
  List<CardModel> discard;
  int fatigueCounter;
}

class BattleState {
  final BattlePhase phase;
  final BattlePlayerState player;
  final BattlePlayerState bot;
  final bool playerTurn;
  final int turnNumber;
  final List<BattleEvent> log;
  final BattleOutcome? outcome; // null saat berjalan
}
```

### 8.2 API engine (dipakai UI dan BotAI — satu pintu)

```dart
abstract class BattleEngine {
  BattleState start({required List<CardModel> playerDeck, required List<CardModel> botDeck,
                     required int seed, required BattleConfig config});
  List<BattleAction> legalActions(BattleState s, Side side);
  BattleState apply(BattleState s, BattleAction a);        // throw IllegalActionException
  bool isTerminal(BattleState s);
  String logHash(BattleState s);
}
```
`BattleAction` = sealed class: `PlayCard(handIndex, slot?)`, `UseAbility(unitId, targetId?)`, `Attack(attackerId, targetId?)`, `SetGuard(unitId)`, `EndTurn()`, `Concede()`.

**UI tidak boleh memutasi state.** Semua perubahan lewat `apply`.

### 8.3 Urutan turn (implementasi `endTurn`/`beginTurn`)

```
beginTurn(side):
  1. turnNumber++ (bila kembali ke pemain pertama)
  2. maxEnergy = isFirstTurnOfSide(side)
       ? config.startingEnergy                       // 1
       : min(maxEnergy + 1, config.maxEnergy)        // naik DULU
  3. energy = maxEnergy                              // refill penuh, tidak carry over
  4. untuk setiap unit di board side:
       - hasActed = false; summonedThisTurn = false
       - stance = ready (guard berakhir di awal turn pemilik)
       - tick burn: hp -= value; turns--; bila hp<=0 → mati (sebelum bisa aksi)
       - freeze: bila turns>0 → unit tidak bisa aksi turn ini; turns-- di endTurn
       - tick shield: durasi--; bila turns==0 → hapus
  5. draw 1 (kecuali turn pertama pemain pertama)
  6. cek fatigue bila deck kosong (damage 20, +10 setiap draw berikutnya)
  7. phase = action
```
**Catatan kritis:** urutan langkah 2 dan 3 tidak boleh ditukar. Turn ke-2 pemilik energi = 2. Turn pertama tiap pemain tetap 1 (tidak di-increment).

`endTurn`:
```
  1. hapus status rally
  2. unit yang menyerang/ability/guard → stance=tapped, hasActed=true
  3. cek terminal (hp<=0) → outcome
  4. ganti side, beginTurn(side lain)
```

### 8.4 Rumus damage (referensi tunggal — jangan duplikasi di UI)

```
elementMultiplier(attacker, defender):
  if attacker == void || defender == void → 1.0
  beats = {fire: air, air: earth, earth: water, water: fire}
  if beats[attacker] == defender → 1.25
  if beats[defender] == attacker → 0.8
  else 1.0

attackDamage(attacker, defender):
  raw   = attacker.attack * elementMultiplier(...) * (1 + rallyBonus)
  dmg   = max(1, round(raw - defender.defense * 0.5))
  if defender.stance == guarding → dmg = max(1, round(dmg * 0.5))

counterDamage(defender, attacker):
  max(1, round(defender.attack * 0.3 * elementMultiplier(defender, attacker)))

faceDamage(attacker):
  max(1, round(attacker.attack * 0.5 * (1 + rallyBonus)))

abilityDamage(ability, caster, target):
  raw = ability.power * elementMultiplier(caster, target)
  max(1, round(raw - target.defense * 0.3))
```

Pembulatan: `round()` = half away from zero (`(x).round()` di Dart aman untuk nilai positif). Semua angka damage integer.

### 8.5 Status effect

| Status | Efek | Durasi | Stack |
|---|---|---|---|
| `burn` | Damage `value` di awal turn pemilik unit | `turns` turn | Refresh durasi, ambil `value` terbesar |
| `freeze` | Tidak bisa attack/ability/guard | `turns` turn | Refresh durasi |
| `shield` | Serap `value` damage total | `turns` turn | Jumlahkan value, max 3× base |
| `rally` | +`value`% ATK | sampai end turn | Ambil terbesar |

Urutan resolve serangan: cek shield → kurangi hp → cek death → counter (bila target guard & masih hidup) → trigger on-death (tidak ada di MVP).

### 8.5a Keyword (hanya 3 untuk v1)

| Keyword | Efek | Implementasi |
|---|---|---|
| `charge` | Unit boleh menyerang pada turn ia dimainkan | Abaikan cek `summonedThisTurn` di `legalActions` |
| `pierce` | Kelebihan damage setelah target mati diteruskan ke **player lawan** | `overflow = dmg - hpTargetSebelum; playerHp -= max(0, overflow)` |
| `lifesteal` | Unit memulihkan HP sebesar damage yang diberikan (cap `maxHp`) | `unit.hp = min(maxHp, hp + dmg)` setelah damage |

Keyword `taunt` dan `swift` **dicadangkan untuk P1** — jangan diimplementasi atau ditambahkan ke konten v1 (schema akan menolak).

### 8.6 Edge case wajib diuji

| # | Kasus | Ekspektasi |
|---|---|---|
| E-01 | Attack unit yang summoning sickness | `IllegalActionException` |
| E-02 | Attack saat target field kosong | Boleh → face damage |
| E-03 | Face attack saat lawan punya unit | Ditolak |
| E-04 | Play card dengan energy kurang | Ditolak |
| E-05 | Board penuh (3) lalu summon | Ditolak |
| E-06 | Hand penuh (8) saat draw | Kartu di-burn, log event `hand_burn` |
| E-07 | Deck kosong saat draw | Fatigue 20, lalu 30, 40... |
| E-08 | Unit mati karena burn di upkeep | Mati sebelum bisa aksi, slot bebas |
| E-09 | Guard counter membunuh penyerang | Penyerang mati, counter tetap terjadi |
| E-10 | Kedua HP ≤ 0 bersamaan | hasil `draw` (jarang; harus deterministik) |
| E-11 | Turn > 50 | `draw` |
| E-12 | Concede saat giliran bot | Langsung `loss` |
| E-13 | Ability cost 0 | Tetap memakai aksi unit |
| E-14 | Freeze + Guard | Freeze menang, tidak bisa guard |

### 8.7 Determinisme

- `Random(seed)` dibuat sekali di `start()`, disimpan di state (atau `ShuffleBag` deterministik).
- Urutan iterasi `Map` harus stabil (pakai `List`/`LinkedHashMap`).
- `logHash` = SHA-256 dari JSON kanonik (`jsonEncode` dengan key berurutan → gunakan `sortKeys` helper).
- Golden test: `golden/match_001.json` berisi state akhir untuk seed 42; bandingkan string kanonik.

---

## 9. Bot AI

Interface:
```dart
enum BotDifficulty { easy, medium, master }

abstract class BotAI {
  BotAction decide(BattleState state, BattleSide side);
}

factory BotAI.forDifficulty(BotDifficulty d, {int? seed});
```
Bot **hanya** memakai `legalActions()` + state publik. Untuk mencegah kebocoran, berikan `BattleView` (tanpa `deck` lawan) ke bot.

### 9.1 Easy
```
aksi = legalActions()
if (aksi kosong) return EndTurn
if (rng.nextDouble() < 0.2) return EndTurn          // 20% skip
pilih acak dari aksi (bobot: PlayCard 1.0, Attack 1.0, Ability 0.5, Guard 0.3)
```
Tidak mengejar lethal, boleh attack target acak.

### 9.2 Medium (greedy)
Skor tiap aksi, ambil tertinggi; ulangi sampai tidak ada aksi bernilai > 0 (maks 12 aksi/turn):
```
score(Attack) = 60*bunuhTarget
              + 1.0*damageEfektif
              + (target.attack*0.5 jika target ancaman)
              - 0.6*nilaiUnitSendiriJikaMatiKarenaCounter
              + 20*jikaFaceDanLethal
score(PlayCard) = 2.0*(attack + hp/4 - cost*3) + 15 jika menutup kurva energi
score(Ability)  = 1.2*power + 25 jika kill + 10 jika status Burn/Freeze
score(Guard)    = 8 + 6*(ancamanMusuhTerbesar/50)  (hanya bila hp unit < 40%)
```
Aturan tambahan: selalu ambil lethal bila tersedia; jangan trade unit bernilai tinggi untuk unit bernilai rendah (kecuali memicu lethal).

### 9.3 Master
1. **Generate candidate plans** (beam width 8): urutan aksi legal yang bermakna (bukan semua permutasi — batasi 12 aksi, dedup by signature).
2. **Simulasi** tiap plan dengan `apply()` pada clone state → skor state akhir:
   ```
   eval(s) = 3.0*(hpSendiri - hpLawan)
           + 2.0*(totalAtkBoardSendiri - totalAtkBoardLawan)
           + 0.5*(totalHpBoardSendiri - totalHpBoardLawan)
           + 1.5*(jumlahUnitSendiri - jumlahUnitLawan)
           + 8*(energiTersisaEfisien)
           + 25*jikaLethalTersedia
           - 40*jikaMatiTurnDepan
   ```
3. **Opponent response:** 1 ply balasan greedy lawan → `eval` setelahnya; pilih plan dengan `0.7*evalOwn + 0.3*(-evalOpp)`.
4. **Time budget:** `Stopwatch` 250 ms; bila habis → fallback ke plan terbaik yang sudah dievaluasi (selalu ada ≥ 1).
5. **Tie-break:** stabil (indeks aksi), supaya replay deterministik.

Optimasi: clone state murah (immutable-ish copy), cache `legalActions` per node, jangan alokasi string di loop.

### 9.4 Test harness
`frontend/test/battle/bot_simulation_test.dart`:
- Jalankan 200 match (bukan 1000 di CI default; 1000 lewat `--tags slow`) Master vs Medium, Medium vs Easy, Master vs Easy.
- Assert rentang win-rate di PRD AC-08.1 dengan toleransi.
- Assert tidak ada match > 60 turn dan tidak ada exception.
- Assert p95 decision time < 300 ms.

---

## 10. Flutter Architecture

### 10.1 Lapisan & dependency rule
```
presentation → domain ← data
     ↓            ↑
   widgets      entities/usecases
```
- `domain` tidak boleh impor `data` atau `presentation`.
- `data` mengimplementasikan repository interface yang dideklarasikan di `domain`.
- Model jaringan (`CardDto`) dipisah dari entity domain (`Card`) — mapping eksplisit, parsing defensif (`as String?` + default, jangan `!`).

### 10.2 State management
- **flutter_bloc (Cubit)** untuk semua fitur. Satu Cubit per layar, state `sealed class`.
- Contoh: `GachaState` = `GachaIdle | GachaLoading | GachaRevealing(results, index) | GachaSuccess(results) | GachaFailure(message, code)`.
- Jangan taruh `BuildContext` di Cubit. Jangan panggil API langsung dari widget.
- Dependency injection: manual via `RepositoryProvider`/constructor (hindari get_it di MVP, atau pakai get_it konsisten — **pilih satu**: gunakan constructor injection + `MultiRepositoryProvider`).

### 10.3 Networking
```dart
Dio(BaseOptions(baseUrl: Env.apiBaseUrl, connectTimeout: 10s, receiveTimeout: 15s))
```
- `AuthInterceptor`: sisipkan `Authorization: Bearer`, pada 401 `TOKEN_EXPIRED` lakukan refresh **single-flight** (pakai `Completer` agar 5 request paralel tidak refresh 5×), retry request asli sekali.
- `ApiException` memetakan envelope error → `code`, `message`, `details`; UI menampilkan pesan lokal berdasarkan `code`, bukan `message` server mentah.
- Retry otomatis hanya untuk GET (maks 2×, backoff 500 ms), **tidak** untuk POST gacha/battle (risiko dobel — idempotency key sudah ada, tapi tetap jangan auto-retry).

### 10.4 Cache & offline
- `hive_boxes.dart`: `catalogBox` (key `manifest`, `cards`), `settingsBox`, `battleBox` (suspend match).
- Alur katalog: memory → Hive (cek `version` + TTL 24 j) → network → bundled asset.
- Simpan katalog dalam **satu** entry JSON string + `version`, bukan 25 box entries (lebih cepat & atomik).
- Gambar: `cached_network_image` + `memCacheWidth` sesuai ukuran grid.
- Model 3D: unduh ke `getApplicationSupportDirectory()/models/<id>.glb` dengan `dio.download`, LRU max 3 file / 40 MB.

### 10.5 3D
- `model_viewer_plus` butuh WebView → **hanya** di halaman detail/gacha reveal, jangan di list.
- Attribute: `autoRotate`, `cameraControls`, `disableZoom=false`, `ar=false`, `backgroundColor` transparan.
- Preload: `precache` model kartu hasil gacha setelah reveal selesai (best-effort, jangan blocking).
- Fallback: `onError`/timeout 5 s → `Image.network(thumbnailUrl)`.
- Arena: **bukan** WebView. Gunakan `Stack` + `AnimatedPositioned`/`AnimationController` + `CustomPainter` untuk efek. Partikel dimatikan saat battery saver.

### 10.6 Animasi gacha
Timeline 10x (total ≤ 4 s):
```
0 ms     : kartu tertutup (back artwork) masuk berurutan 60 ms stagger
600 ms   : shake 300 ms
900 ms   : flip 3D (Transform + perspective, 450 ms) per kartu berurutan
4500 ms  : ringkasan grid + tombol "Selesai"
```
Rarity tinggi → tambahan glow, confetti, haptic (`HapticFeedback.heavyImpact`), SFX khusus.
Semua animasi harus bisa di-skip (`skip()` → state `GachaSuccess`) dan menghormati `reduceMotion`.

### 10.7 Error UX
| Code | Pesan user | Aksi |
|---|---|---|
| `INSUFFICIENT_FUNDS` | "Gold tidak cukup" | Buka opsi pakai Gem |
| `UNAUTHORIZED`/`TOKEN_EXPIRED` | – | Refresh diam-diam, gagal → login |
| `DECK_INVALID` | "Deck belum valid" | Tampilkan violations |
| `CATALOG_UNAVAILABLE` | "Katalog belum tersedia" | Pakai cache/bundled |
| Network timeout | "Koneksi lambat" | Tombol coba lagi |
| `RATE_LIMITED` | "Terlalu banyak percobaan" | Disable tombol + countdown |

---

## 11. Security Checklist

- [ ] Password argon2id (`memoryCost 19456, timeCost 2, parallelism 1`), tidak pernah di-log.
- [ ] JWT `iss`, `aud`, `exp`, `sub`; secret ≥ 32 char; algoritma dipaksa HS256 (tolak `none`).
- [ ] Refresh token disimpan **hash** (sha256), bukan plaintext.
- [ ] Rotasi refresh + deteksi reuse (cabut family).
- [ ] Rate limit: global 100 req/menit/IP; auth 10/menit/IP; gacha 30/menit/user; battle result 10/menit/user.
- [ ] Zod validate body/query/params; tolak properti tak dikenal (`strict()`).
- [ ] Cek kepemilikan resource (`deck.userId === req.user.id`) di setiap route ber-`:id`.
- [ ] Tidak ada `$queryRaw` dengan interpolasi string.
- [ ] CORS whitelist; helmet; body limit 64 kb.
- [ ] Token tidak pernah masuk log/telemetry/crash report.
- [ ] Endpoint internal butuh `X-Admin-Token` (bandingkan `timingSafeEqual`).
- [ ] Semua uang & inventory berubah hanya via service yang bertransaksi.
- [ ] Client tidak menyimpan secret apa pun (cek `--dart-define` tidak berisi token rahasia).
- [ ] Web: hanya `NEXT_PUBLIC_OFFLINE` & `NEXT_PUBLIC_API_BASE_URL` yang dibundel; token sesi web di `localStorage` (lihat §16.5 & Q-07).

---

## 12. Testing Strategy

| Level | Tool | Cakupan wajib |
|---|---|---|
| Backend unit | Vitest | `gacha.math` boundary, `deck.rules`, XP curve, damage tidak relevan (di Dart) |
| Backend integration | Supertest + SQLite temp | AC-01.*, AC-03.5, AC-04.1–04.4, AC-06.4, AC-09.1 |
| Contract | Zod schema test | `cards.json` seed valid terhadap `schema.json` |
| Flutter unit | `flutter test` | BattleEngine edge cases E-01..E-14, BotAI legalitas, deck rules client |
| Flutter golden | `matchesGoldenFile` | Layar utama (home, gacha result, arena) di 2 ukuran |
| Flutter widget | `bloc_test` + `mocktail` | State transitions gacha, deck counter, filter inventory |
| Simulasi | Dart script | 1.000 match bot, distribusi 100k gacha |
| Load | k6 | p95 pull < 600 ms @ 50 rps |
| Manual | Checklist | Offline, airplane mode, background/resume, low battery |

**CI (GitHub Actions):**
```
jobs: backend (lint, typecheck, test, prisma validate)
      frontend (flutter analyze, flutter test --coverage)
      catalog (node scripts/build-catalog.mjs --check)
```
Block merge bila salah satu gagal. Coverage minimum: `gacha.math` & `battle/domain` **90%**.

---

## 13. Performance Budget

| Metrik | Budget | Cara ukur |
|---|---|---|
| Cold start | < 3 s (mid-range) | `flutter run --profile` + DevTools |
| Frame build | < 16 ms p95 di arena | DevTools timeline |
| Gacha 10x total | < 4 s (animasi), < 600 ms (network) | Stopwatch + log |
| Memori | < 350 MB saat battle | DevTools |
| Ukuran app | < 60 MB | `flutter build appbundle` |
| Model 3D | ≤ 2 MB/model, ≤ 8k tris | gltf-report |
| API p95 | < 300 ms | k6 |

---

## 14. Release Checklist

- [ ] Semua AC PRD punya test otomatis (lihat §15 PRD).
- [ ] `flutter analyze` 0 warning, `npm run lint` bersih.
- [ ] Tidak ada `print`/`console.log` sisa debug (kecuali logger terstruktur).
- [ ] `.env` tidak masuk repo; `dart-define` production terisi.
- [ ] Migrasi DB diuji di salinan DB produksi.
- [ ] Backup DB otomatis harian + retensi 7 hari.
- [ ] Monitoring: health check, error rate, log agregasi.
- [ ] Rate card gacha tampil & sesuai server (ambil dari `/gacha/rates`).
- [ ] Kebijakan privasi + rating store (loot box disclosure).
- [ ] Uji di 1 device low-end Android & 1 iPhone.
- [ ] Rollback plan: image sebelumnya tersedia, migrasi backward-compatible.

---

## 15. Definition of Done (per task)

1. Kode mengikuti struktur & gaya di dokumen ini.
2. Test untuk perilaku baru ada dan lulus; tidak ada test yang di-skip tanpa alasan tertulis.
3. `flutter analyze` / `tsc --noEmit` bersih.
4. Tidak ada TODO tanpa issue/komentar `// TODO(phase): ...`.
5. Semua string UI lewat l10n (id/en).
6. Error path ditangani (bukan hanya happy path).
7. Perubahan kontrak API/CMS didokumentasikan di dokumen ini **dan** PRD bila menyentuh perilaku.
8. PR description menyebut AC yang dipenuhi (mis. `AC-04.3`).

---

## 16. Web Client (Next.js)

Versi web adalah **klien tambahan** di `web/`; aplikasi Flutter (`frontend/`) tetap klien mobile utama dan tidak diubah. Kontrak API, aturan battle, ekonomi, dan konten identik — web adalah port, bukan desain ulang aturan.

### 16.1 Stack

| Hal | Pilihan | Catatan |
|---|---|---|
| Framework | Next.js 15 (App Router) + React 19 + TypeScript strict | `output: 'export'` → situs statis di `web/out/`, bisa di-host di CDN mana pun |
| State | React context (`AppProvider`) + kelas pure TS yang di-subscribe (`BattleSession`) | Tanpa library state tambahan |
| Gaya | CSS token (`globals.css`, `components.css`) — palet clay dari `app_theme.dart` | Tanpa framework CSS |
| Kreatur | SVG + animasi CSS; spesies & palet = `creature_avatar.dart` (`speciesOf`, `creatureSeed`) | Bob/kedip mati saat "Kurangi animasi" |
| Test | `node --test` (TypeScript native Node ≥ 22.18) | Tanpa dependency test |

### 16.2 Pemetaan modul Flutter → web

| Flutter | Web |
|---|---|
| `features/battle/domain/battle_engine.dart`, `battle_models.dart` | `src/lib/battle/engine.ts`, `models.ts` |
| `features/battle/domain/bot_ai.dart` | `src/lib/battle/bot-ai.ts` |
| `features/battle/battle_cubit.dart` | `src/lib/battle/session.ts` (+ hook `use-battle-session.ts`) |
| `dart:math` `Random(seed)` + `List.shuffle` | `src/lib/core/dart-random.ts` (port bit-per-bit) |
| `core/utils/canonical_json.dart` + `package:crypto` | `src/lib/core/canonical-json.ts` + `sha256.ts` |
| `data/local/local_backend.dart` (Hive) | `src/lib/data/local-backend.ts` (localStorage) |
| `core/network/api_client.dart` (Dio) | `src/lib/data/api-client.ts` (fetch, transport bisa ditukar) |
| `data/repositories/*` | `src/lib/data/repositories.ts` |
| `domain/deck_rules.dart`, `domain/models/*` | `src/lib/domain/deck-rules.ts`, `models.ts`, `card.ts` |
| `core/i18n/app_strings.dart` | `src/lib/i18n/base-strings.ts` (dihasilkan) + `web-strings.ts` |
| `core/config/game_config.dart` | `src/lib/config/game-config.ts` |

### 16.3 Determinisme lintas platform (I-04)

- Engine & bot web memakai RNG **identik** dengan Dart VM: seed di-mix dengan Thomas Wang 64-bit (`uint64`, shift logis), state MWC `A = 0xffffda61`, diputar 4× saat konstruksi; `nextInt`, `nextDouble`, `nextBool`, dan `shuffle` mengikuti urutan pemanggilan Dart.
- `double.round()` Dart (setengah menjauhi nol) → `dartRound()`; Math.round JS tidak dipakai langsung.
- Seed bot = `seed ^ 0x9E3779B9` sebagai int 64-bit (`>>> 0` di JS).
- Pesan log engine disalin persis (termasuk teks Indonesia) karena masuk ke `logHash`.
- **Golden test** `web/test/battle-golden.test.ts`: 15 pertandingan bot-vs-bot penuh (5 seed × 3 level) harus menghasilkan `logHash` yang sama dengan engine Dart. Bila engine Dart berubah, regenerasi angka golden dari Dart dan perbarui test di PR yang sama.

### 16.4 Mode offline vs server

| | Offline (default, `NEXT_PUBLIC_OFFLINE=true`) | Server (`NEXT_PUBLIC_OFFLINE=false`) |
|---|---|---|
| Login | Pemain lokal otomatis | `/login` (register/login), refresh token single-flight |
| Data | `LocalBackend` di browser, key `dokimon_offline.state` | Express API `NEXT_PUBLIC_API_BASE_URL` |
| Invarian I-01/I-02 | Sengaja tidak berlaku (sama dengan offline mobile) | Server otoritatif |
| CORS | – | Origin web harus ada di `CORS_ORIGINS` backend (default `http://localhost:3000`) |

Katalog: network → cache `localStorage` (`dokimon.cache.catalog`) → bundled `src/data/cards.seed.json`. Salinan bundled dijaga sinkron dengan `content/cards/cards.json` oleh `npm run catalog:sync` / `catalog:check` (CI).

### 16.5 Penyimpanan di browser

| Key | Isi |
|---|---|
| `dokimon.settings` | bahasa, kurangi animasi, hemat baterai, getaran, tema meja, flag panduan |
| `dokimon.session` | `accessToken` + `refreshToken` (mode server saja) |
| `dokimon_offline.state` | progres mode offline |
| `dokimon.cache.catalog`, `dokimon.cache.inventory` | cache fallback |

Web tidak punya padanan `flutter_secure_storage`; token disimpan di `localStorage` origin app sehingga rentan bila terjadi XSS. Mitigasi saat ini: tanpa `dangerouslySetInnerHTML`, tanpa skrip pihak ketiga selain Google Fonts CSS. Opsi lebih aman (refresh token di cookie `HttpOnly`) butuh perubahan backend → Q-07.

### 16.6 Perbedaan yang disengaja dari mobile

- Arena di rute `/arena/` memegang match di memori; reload = sesi berakhir (sama dengan menutup app; resume belum ada di mobile juga).
- Viewer 3D tidak ditautkan (keputusan PO Q-06); kreatur SVG 2D.
- Pintasan keyboard `E` = akhiri giliran.
- Getaran hanya di perangkat yang mendukung `navigator.vibrate` dan setelah ada gestur pengguna.

### 16.7 Perintah

```bash
cd web
npm install
npm run dev              # http://localhost:3000 (offline default)
npm run typecheck && npm test && npm run build   # build → web/out/
npm run catalog:check    # CI: salinan katalog sinkron
```

# AI AGENT GUIDE — Panduan Membangun Dokimon TCG 3D

> Dokumen ini dipakai **bersama** [`PRD.md`](./PRD.md) dan [`TECH_SPEC.md`](./TECH_SPEC.md).
> Setiap prompt di bawah dirancang untuk **satu sesi agent** (satu fase). Jangan gabung dua fase dalam satu sesi — hasilnya dangkal.

---

## 0. Cara pakai (penting, baca sebelum prompt pertama)

1. **Buka repo di agent** (Cursor/Claude Code/OpenCode) dengan root = folder `dokimon/`.
2. Pastikan agent membaca, berurutan: `AGENTS.md` → `docs/PRD.md` → `docs/TECH_SPEC.md` → bagian fase yang relevan.
3. **Copy satu prompt** dari §3, tempel apa adanya, lalu tambahkan `File yang sudah ada: ...` bila perlu.
4. Setelah agent selesai: jalankan **Definition of Done** (§4) + test. Jangan lanjut fase berikutnya bila AC fase ini merah.
5. Bila agent mengubah kontrak (field JSON, endpoint, rumus), **wajib** update `TECH_SPEC.md` di PR yang sama.
6. Simpan riwayat: satu branch per fase (`feat/m1-auth`, `feat/m2-catalog`, ...), satu PR per fase.

**Aturan emas:** agent tidak boleh "menyederhanakan" aturan bisnis (pity, validasi deck, server-authoritative gacha) tanpa persetujuan. Kalau ragu, agent harus bertanya, bukan menebak.

---

## 1. Pre-flight checklist (manual, sekali)

- [ ] Node 20 + npm terpasang; `node -v`
- [ ] Flutter 3.24+; `flutter doctor` bersih untuk Android (dan iOS bila punya macOS)
- [ ] Git repo dibuat, remote GitHub terhubung
- [ ] Repo GitHub diset **public** (agar jsDelivr/raw bisa diakses tanpa token) — kalau private, siapkan `GITHUB_TOKEN` di backend
- [ ] File `content/cards/*` + `scripts/build-catalog.mjs` sudah ada (sudah disiapkan di repo ini)
- [ ] `.env` backend dibuat dari `.env.example`; secret diganti
- [ ] Emulator/device Android tersedia untuk uji

**Smoke test katalog di GitHub (setelah push):**
```bash
curl -s https://cdn.jsdelivr.net/gh/<owner>/<repo>@main/content/cards/manifest.json | head
```

---

## 2. Ringkasan fase & dependency

| Fase | Nama | Prasyarat | Output utama | AC PRD |
|---|---|---|---|---|
| P0 | Bootstrap monorepo | – | struktur, CI, app "hello", healthz | – |
| P1 | Backend auth + wallet | P0 | register/login/refresh, starter deck | AC-01.*, AC-02.1 |
| P2 | Katalog & sync GitHub | P0 | catalog service, endpoints | AC-03.* |
| P3 | Gacha engine | P1, P2 | pull server, pity, audit, test distribusi | AC-04.* |
| P4 | Inventory & deck API | P3 | inventory, deck CRUD, validasi | AC-06.4, AC-05.1 |
| P5 | Battle result & reward | P4 | start/result, XP, gold, daily | AC-09.*, AC-02.2 |
| P6 | Flutter shell | P0 | theme, router, dio, auth flow | AC-01.4, 01.5 |
| P7 | Flutter catalog layer | P2, P6 | CardModel, repository, Hive cache | AC-03.2, 03.3 |
| P8 | Gacha UI + flip 3D | P3, P7 | layar gacha, animasi, odds modal | AC-04.5, 04.6 |
| P9 | Collection + deck builder | P4, P7 | grid, filter, builder | AC-05.*, AC-06.1–03 |
| P10 | Battle engine (pure Dart) | – | engine + 14 edge case test | AC-07.2, 07.4 |
| P11 | Bot AI 3 level | P10 | Easy/Medium/Master + harness | AC-08.* |
| P12 | Arena UI + integration | P5, P9, P11 | layar battle, reward flow | AC-07.1, 07.5, 07.6 |
| P13 | Polish (audio, i18n, a11y, 3D arena) | P12 | NFR + settings | AC-10.* |
| P14 | Hardening & rilis | semua | load test, security, store | Checklist §14 |

**Paralel yang aman:** backend (P1–P5) bisa jalan paralel dengan battle engine (P10–P11) karena engine pure Dart dan tidak butuh API.

---

## 3. Prompt pack (copy-paste)

> Semua prompt ditulis dalam bahasa instruksi yang eksplisit. Ganti `<...>` sebelum dipakai.

### P0 — Bootstrap Monorepo

```
Kamu adalah senior engineer yang membangun "Dokimon TCG 3D".

BACA DULU: AGENTS.md, docs/PRD.md (§1–§6), docs/TECH_SPEC.md (§1–§3).

TUGAS: siapkan kerangka monorepo yang bisa dijalankan, TANPA fitur bisnis.
1. Buat struktur folder persis seperti TECH_SPEC §1 (backend, frontend, content, docs, scripts).
2. backend: Express + TypeScript ESM, endpoint GET /healthz → {status:"ok", version, catalogVersion:null};
   middleware requestId, helmet, cors, json 64kb, error handler dengan envelope TECH_SPEC §3.2;
   lib/errors.ts (AppError + kode error kanonik), lib/validate.ts (zod helper), config/env.ts (validasi env dengan zod, gagal cepat bila kurang).
3. backend: prisma init + schema.prisma kosong (hanya generator + datasource), script npm: dev, build, start, test, lint, typecheck.
4. frontend: flutter create dengan org com.dokimon, tambahkan dependency di TECH_SPEC §2, aktifkan l10n (id default, en),
   theme dasar (dark, warna per rarity di core/theme/rarity_colors.dart), go_router dengan 1 route "/" yang menampilkan "Dokimon TCG 3D" + versi.
5. scripts/build-catalog.mjs: baca content/cards/cards.json, validasi terhadap content/cards/schema.json,
   hitung sha256 file, tulis content/cards/manifest.json (catalogVersion argumen --version, default tanggal lokal),
   exit code 1 bila invalid. Sediakan flag --check (tidak menulis file).
6. .github/workflows/ci.yml: backend (install, typecheck, test, prisma validate) + frontend (flutter analyze, flutter test) + catalog (node scripts/build-catalog.mjs --check).
7. README.md: cara menjalankan backend & frontend, cara menambah kartu.

ATURAN:
- Jangan implementasi auth/gacha/battle di fase ini.
- TypeScript strict, tidak ada `any` tanpa alasan.
- Jangan hardcode secret; pakai process.env + .env.example.

SELESAI BILA: `cd backend && npm run typecheck && npm test` lulus, `cd frontend && flutter analyze && flutter test` lulus,
`node scripts/build-catalog.mjs --check` lulus, dan README menjelaskan 3 perintah di atas.
```

### P1 — Backend Auth + Wallet + Starter Deck

```
Lanjutkan repo Dokimon. BACA: docs/PRD.md FR-01, FR-02, FR-09; docs/TECH_SPEC.md §3, §4, §5.1, §5.2, §11.

TUGAS: implementasi autentikasi, profil, wallet, dan grant awal.
1. Prisma: model User, RefreshToken sesuai TECH_SPEC §4. Migrasi dev + seed 0 user.
2. Auth service:
   - register: validasi zod (email, username regex, password >= 8), cek unik case-insensitive,
     hash argon2id, buat user + 1000 gold + 50 gems, buat starter deck (lihat aturan di bawah),
     terbitkan access (15m) + refresh (30d) token.
   - login: verifikasi, terbitkan token, catat percobaan gagal untuk rate limit.
   - refresh: rotasi (revoke lama, terbitkan baru, familyId sama); token revoked dipakai lagi → cabut seluruh family + 401 REFRESH_REUSED.
   - logout: revoke token yang dikirim.
3. Middleware authGuard: verifikasi HS256, tolak alg lain, sisipkan req.user.
4. Endpoint: POST /auth/register, /auth/login, /auth/refresh, /auth/logout; GET /auth/me; GET /user/profile; GET /user/wallet; POST /user/daily-claim.
5. Starter deck: 7 kartu unik dari katalog (Common/Uncommon, komposisi 3/3/3/3/3/3/2 = 20),
   grant ke inventory, buat deck "Starter" aktif. Bila katalog belum tersedia → gunakan fallback bundled, jangan gagal register.
6. Helper XP: xpToNext(level)=100+50*(level-1), addXp(user, amount) dengan carry-over + level up reward (200 gold, 5 gems) dan flag levelUp di response.
7. Test (Supertest + SQLite temp): AC-01.1, 01.2, 01.3, 01.6, 02.1; refresh rotation & reuse detection; password tidak pernah muncul di response/log.

ATURAN:
- Response envelope & kode error persis TECH_SPEC §3.2–3.3.
- Jangan pernah mengembalikan passwordHash.
- Semua perubahan saldo lewat service, bukan langsung di controller.

SELESAI BILA: semua test lulus, `npm run typecheck` bersih, dan endpoint terdokumentasi di docs/TECH_SPEC.md bila ada tambahan.
```

### P2 — Catalog Service (GitHub CMS)

```
Lanjutkan repo Dokimon. BACA: docs/PRD.md FR-03; docs/TECH_SPEC.md §4 (CatalogVersion), §5.3, §7.

TUGAS: sinkronisasi katalog kartu dari GitHub + API katalog.
1. catalog.schema.ts: zod schema CardModel + Ability persis TECH_SPEC §7.1 (strict, validasi URL https, cost 0..10, minimal 1 kartu per rarity, id unik).
2. catalog.service.ts:
   - fetch manifest + cards dari CDN (jsDelivr) lalu fallback raw.githubusercontent.com; timeout 8s; If-None-Match.
   - verifikasi checksum sha256 file cards.json terhadap manifest; mismatch → tolak.
   - upsert CatalogVersion (payload Json), aktifkan dalam transaksi (versi lama isActive=false).
   - cache in-memory {version, cards, byId}; getActiveCatalog() mengembalikan cache atau versi DB terakhir atau bundled.
   - jangan pernah crash bila fetch gagal: log error terstruktur, pertahankan versi lama.
3. Scheduler: sync saat boot + setInterval(CATALOG_SYNC_INTERVAL_MS). Flag env untuk mematikan scheduler di test.
4. Endpoint: GET /catalog/manifest, /catalog/cards (filter element/rarity/type + ETag/304), /catalog/cards/:id,
   POST /internal/catalog/sync (X-Admin-Token, timingSafeEqual).
5. Test: manifest valid, checksum mismatch ditolak, JSON rusak ditolak & versi lama tetap aktif, filter benar, 304 bekerja.
   Gunakan fixture lokal (mock fetch), bukan network nyata.

ATURAN:
- Tidak ada panggilan ke GitHub API /repos/* di jalur kritis.
- Kartu `retired: true` tetap ada di database tapi tidak masuk pool gacha.
- Semua log menyertakan version & source (cdn/raw/bundled).

SELESAI BILA: AC-03.5, 03.6 lulus; `POST /internal/catalog/sync` idempotent (tidak membuat versi duplikat bila checksum sama).
```

### P3 — Gacha Engine (server) + Pity + Audit

```
Lanjutkan repo Dokimon. BACA: docs/PRD.md FR-04; docs/TECH_SPEC.md §6 (ikuti algoritma persis), §4, §5.4, §11.

TUGAS: implementasi gacha server-authoritative.
1. config/economy.ts: GACHA_RATES, PITY_THRESHOLD=50, PITY_BONUS_WEIGHTS, PRICE, GUARANTEED_RARE_PLUS_ON_TEN — persis TECH_SPEC §6.
2. gacha.math.ts (PURE, tanpa I/O):
   - weightedPick(weights, rng: () => number): number  — pakai crypto.randomInt di produksi, injeksi rng untuk test.
   - rollRarity(pityCounter, rng) → {rarity, wasPity}
   - applyTenPullGuarantee(results)
   - Fungsi harus deterministik terhadap rng yang diinjeksi.
3. gacha.service.ts: pull() mengikuti 7 langkah TECH_SPEC §6 dalam SATU transaksi Prisma
   (potong saldo dengan updateMany bersyarat, baca/update pity, tulis GachaPull per hasil, batchId, idempotencyKey unik per user).
4. Endpoint: GET /gacha/rates (persen + pity), GET /gacha/pity (auth), POST /gacha/pull (count 1|10, currency gold|gem, idempotencyKey wajib UUID),
   GET /gacha/history (cursor pagination).
5. Response pull menyertakan objek kartu lengkap (join katalog) + isNew (bandingkan inventory sebelum batch) + balance + pity.
6. Test WAJIB:
   - unit: boundary bobot (0, 5999, 6000, 8499, 8500, 9499, 9500, 9899, 9900, 9989, 9990, 9999).
   - pity: counter 48 → normal (49), 49 → dipaksa Epic+ & reset, 50 tidak pernah tersimpan.
   - 10x guarantee: 10× Common dari rng stub → hasil terakhir minimal Rare.
   - integrasi: saldo kurang → 402 tanpa pull tercatat; idempotencyKey sama 2× → saldo hanya potong sekali & hasil identik.
   - distribusi: 100.000 pull dengan rng nyata, chi-square α=0.01 terhadap 6 tier (tag `slow`, dijalankan di CI nightly).
7. docs/TECH_SPEC.md §6: tambahkan tabel hasil test aktual (rate observed ± toleransi).

ATURAN:
- Math.random() DILARANG.
- Jangan pernah memotong saldo di luar transaksi yang menulis GachaPull.
- Jangan mengembalikan rarity yang tidak ada di katalog aktif.

SELESAI BILA: AC-04.1–04.4, 04.7 lulus; test cepat < 20 detik.
```

### P4 — Inventory + Deck API

```
Lanjutkan repo Dokimon. BACA: docs/PRD.md FR-05, FR-06; docs/TECH_SPEC.md §4, §5.5, §5.6.

TUGAS: inventory read API + deck CRUD dengan validasi server.
1. deck.rules.ts (PURE): validateDeck(cards, ownedQuantities) → {valid, violations[], curve} dengan kode violation TECH_SPEC §5.6.
   Aturan: tepat 20, maks 3 per cardId, hanya kartu dimiliki, hanya type unit/spell, tidak ada entri duplikat.
2. inventory.service: list dengan filter element/rarity/type, sort (rarity/name/recent/attack/hp), cursor pagination, quantity, owned/total.
3. deck.service: list/create/patch/delete/activate/validate; maks 10 deck; nama unik per user (3..24 char);
   aktivasi dalam transaksi (User.activeDeckId + Deck.isActive konsisten); hapus deck aktif → activeDeckId=null.
4. Endpoint persis TECH_SPEC §5.6.
5. Test: AC-06.4 (payload invalid ditolak 400 DECK_INVALID dengan violations), AC-06.5 (persist setelah reload),
   aturan 20/3, deck milik user lain → 403/404, maks 10 deck, aktivasi idempotent.

ATURAN:
- Validasi di server adalah otoritatif; jangan percaya `isValid` dari client.
- Jangan menyimpan `quantity` > yang dimiliki.
- Response deck selalu menyertakan cardCount, isValid, violations.

SELESAI BILA: semua test lulus + contoh curl di README backend.
```

### P5 — Battle Start/Result, Reward, Statistik

```
Lanjutkan repo Dokimon. BACA: docs/PRD.md FR-07 (setup), FR-08, FR-09; docs/TECH_SPEC.md §5.7, §8.1.

TUGAS: endpoint match + reward, TANPA engine battle (engine di Flutter).
1. POST /battles/start: validasi difficulty + deckId (milik user, valid), simpan snapshot deck,
   buat matchId + seed acak (int32), pilih bot deck dari katalog (Easy: rarity <= Rare; Medium: <= Epic; Master: semua),
   komposisi 20 kartu maks 3 copy, return player deck, bot deck, seed, startedAt.
2. POST /battles/:matchId/result: verifikasi TECH_SPEC §5.7 (kepemilikan, belum dilaporkan, umur < 2 jam, turns 1..50, durationMs masuk akal),
   hitung reward (gold/XP per difficulty), first-win-of-day +200 gold (kalender WIB), batas 40 match ber-reward/hari,
   update stats, idempotent (submit kedua → 200 with alreadyReported:true, tanpa reward tambahan).
3. GET /battles/history (cursor, limit 20, filter difficulty).
4. util waktu: helper `startOfDayWib()` yang bisa diinjeksi clock untuk test.
5. Test: AC-09.1 (double submit), AC-09.2 (reset harian), AC-09.3 (50 match konsistensi), reward per difficulty, deck invalid → 400, match user lain → 403/404.

ATURAN:
- Reward dihitung SERVER, client hanya mengirim outcome.
- Jangan simpan log aksi penuh di DB (hanya hash + jumlah turn) untuk hemat.
- Semua timestamp disimpan UTC; perhitungan harian memakai WIB.

SELESAI BILA: test lulus dan skema reward terdokumentasi di PRD §8 bila berubah.
```

### P6 — Flutter Shell: Theme, Router, Network, Auth Flow

```
Lanjutkan repo Dokimon (folder frontend). BACA: docs/PRD.md FR-01, FR-02, FR-10, §7; docs/TECH_SPEC.md §5.1, §5.2, §10.1–10.4, §10.7.

TUGAS: kerangka app + alur auth lengkap.
1. core/config/env.dart: baseUrl via --dart-define (default http://10.0.2.2:8080/api/v1 untuk emulator Android).
2. core/network: Dio + AuthInterceptor (single-flight refresh, retry sekali), ApiException (code/message/details), mapping kode error ke pesan l10n.
3. core/storage: SecureStore (flutter_secure_storage) untuk access/refresh token; Hive init untuk settingsBox.
4. AuthRepository + AuthCubit (sealed state: unknown/authenticated/unauthenticated/loading/failure), splash mengecek token → refresh bila perlu → route.
5. Layar: Splash, Login, Register (validasi inline, loading, error server per field), Home (placeholder saldo/level/deck aktif + tombol Gacha/Collection/Deck/Battle),
   Profile (data dari /user/profile), Settings (bahasa id/en, hapus cache, logout).
6. go_router dengan redirect berbasis AuthCubit; route terproteksi.
7. l10n: semua teks di ARB (id + en), minimal 40 string.
8. Widget test: login sukses → Home; login 401 → pesan; token expired → refresh dipanggil sekali untuk 3 request paralel (mock).

ATURAN:
- Tidak ada BuildContext di Cubit; tidak ada panggilan Dio dari widget.
- Simpan token HANYA di secure storage, jangan di Hive/SharedPreferences.
- Jangan log token.

SELESAI BILA: AC-01.4, 01.5, 02.1 lulus (manual di emulator + widget test), `flutter analyze` bersih.
```

### P7 — Catalog di Flutter (Model, Repository, Hive Cache, Offline)

```
Lanjutkan repo Dokimon (folder frontend). BACA: docs/PRD.md FR-03, FR-05; docs/TECH_SPEC.md §7.1, §10.4.

TUGAS: lapisan katalog + cache offline 3 lapis.
1. shared/models/card_model.dart: freezed + json_serializable, parsing DEFENSIF (field hilang/tipe salah → nilai default + log warn, jangan throw saat satu kartu rusak; lewati kartu invalid).
2. domain: CardRepository (interface) + entity Card (tanpa dependensi Flutter).
3. data: CatalogRemoteDataSource (Dio: GET /catalog/manifest, /catalog/cards dengan If-None-Match), CatalogLocalDataSource (Hive: satu entry JSON + version + fetchedAt).
4. Alur getCatalog(): memory → Hive (TTL 24 jam, version cocok) → network → assets/cards/cards.seed.json. Return CatalogResult{cards, version, source: memory|hive|network|bundled, stale}.
5. UI: banner "Offline — data mungkin tertinggal" bila source bundled/hive stale; tombol refresh manual.
6. Salin content/cards/cards.json ke assets/cards/cards.seed.json dan daftarkan di pubspec.
7. Test: parsing JSON valid & rusak; fallback berurutan; TTL; filter helper; widget banner.

ATURAN:
- Jangan pakai `!` pada hasil JSON.
- Jangan menyimpan 25 entry terpisah di Hive — satu blob JSON.
- Tidak ada model `CardModel` di layer domain (pakai entity Card).

SELESAI BILA: AC-03.2, 03.3 lulus manual (airplane mode) + unit test fallback hijau.
```

### P8 — Gacha Screen + Animasi Flip 3D

```
Lanjutkan repo Dokimon (frontend). BACA: docs/PRD.md FR-04, §7; docs/TECH_SPEC.md §5.4, §10.5, §10.6, §10.7.

TUGAS: layar gacha lengkap + reveal animasi.
1. GachaCubit: loadRates, loadPity, pull(count, currency) dengan idempotencyKey (uuid v4 dibuat sekali per tap, disimpan sampai selesai),
   state sealed: idle/loading/revealing(index)/success/failure. Animasi tidak boleh memblokir logika saldo.
2. Layar Gacha: saldo gold/gem, pity counter ("Epic+ dalam X pull"), tombol 1x & 10x dengan harga, modal "Lihat Peluang" (tabel rate dari /gacha/rates + penjelasan pity — wajib aksesibel sebelum pull pertama).
3. Modal pilih mata uang bila gold tidak cukup tapi gem cukup; bila keduanya kurang → arahkan ke Home/Battle.
4. Reveal: kartu tertutup → shake → flip 3D (Transform perspective, 450ms) berurutan 60ms stagger, glow/confetti/haptic per rarity,
   tombol Skip (langsung ke grid hasil), total <= 4 detik. Hormati reduce-motion (fade saja).
5. Detail kartu hasil: tap → bottom sheet dengan artwork + tombol "Putar 3D" (model_viewer_plus, timeout 5s fallback gambar).
6. Update saldo & pity dari response (jangan hitung lokal), refresh inventory.
7. Test: 10x menampilkan 10 kartu, skip bekerja, insufficient funds menampilkan opsi gem, a11y label pada kartu hasil.

ATURAN:
- Client TIDAK boleh menghitung rarity/hasil. Hanya menampilkan.
- Idempotency key harus stabil selama retry manual (tombol retry memakai key yang sama).
- Jangan render 10 WebView 3D sekaligus — hanya 1 di detail.

SELESAI BILA: AC-04.5, 04.6 lulus di device nyata (ukur durasi dengan Stopwatch log), tidak ada jank > 100ms di profile mode.
```

### P9 — Collection Screen + Deck Builder

```
Lanjutkan repo Dokimon (frontend). BACA: docs/PRD.md FR-05, FR-06, §7; docs/TECH_SPEC.md §5.5, §5.6, §10.4.

TUGAS: koleksi + deck builder.
1. Collection: grid 3 kolom (GridView.builder + cached_network_image), search, filter chips (elemen, rarity, tipe), sort dropdown,
   counter "x/total" (total dari katalog, jangan hardcode), badge ×N, silhouette untuk kartu belum dimiliki, pull-to-refresh, empty state.
2. Card Detail: stat, ability, keyword chips dengan tooltip penjelasan, rarity styling, tombol 3D (reuse dari P8), tombol "Tambah ke deck".
3. Deck List: kartu deck + valid/invalid badge + violations, aktif badge, create/rename/duplicate/delete (konfirmasi), maks 10 deck.
4. Deck Builder: 2 panel (koleksi tersaring ↔ deck saat ini), counter 20/20 + validasi real-time (client rule mirror dari server),
   badge copy 3/3, kurva energi mini bar, warning bila < 20, tombol simpan disabled bila invalid, optimistic update + rollback saat server menolak.
5. DeckCubit + InventoryCubit; semua mutasi lewat API.
6. Test: AC-06.1 (kartu ke-21 ditolak), 06.2 (copy ke-4), 06.3 (19/20 disabled), 05.1 (kombinasi filter), 05.2 (scroll 200 item tanpa rebuild berlebih).

ATURAN:
- Aturan validasi client harus IDENTIK dengan deck.rules.ts (tulis tabel aturan di komentar, sebut sumbernya).
- Jangan menyimpan state deck hanya di memori; selalu sinkron ke server setelah simpan.
- Semua teks lewat l10n.

SELESAI BILA: semua AC di atas lulus (widget test + manual), dan deck bisa dipakai memulai battle lewat API start.
```

### P10 — Battle Engine (Pure Dart) + Test

```
Lanjutkan repo Dokimon (frontend). BACA: docs/PRD.md FR-07; docs/TECH_SPEC.md §8 SELURUHNYA.

TUGAS: implementasi engine battle pure Dart di lib/features/battle/domain/. Tanpa import flutter, tanpa I/O.
1. Model: BattleConfig (semua konstanta §8.1), BattleUnit, BattlePlayerState, BattleState, BattleAction (sealed), BattleEvent, StatusEffect, BattleOutcome.
2. BattleEngine: start/legalActions/apply/isTerminal/logHash sesuai §8.2. UI dilarang memutasi state.
3. Turn flow persis §8.3: maxEnergy naik SEBELUM refill; turn pertama pemain pertama tidak draw; hand burn; fatigue 20/30/40; guard berakhir di awal turn pemilik; freeze; burn tick.
4. Damage persis §8.4 (element 1.25/0.8/1.0, defense*0.5, guard*0.5, counter 30%, face*0.5, ability -def*0.3). Implementasi di SATU file `damage.dart`, dipakai semua tempat.
5. Determinisme: Random(seed) tunggal, urutan iterasi stabil, logHash sha256 dari JSON kanonik (sort keys).
6. Test WAJIB: E-01 s/d E-14 di §8.6 (satu test per baris, nama test menyebut kode E-xx),
   plus golden test: seed 42, 12 turn, state akhir sama persis dengan file golden/match_001.json.
7. Fuzz test: 2.000 aksi acak legal dari 50 seed — tidak boleh ada exception selain IllegalActionException, tidak boleh ada HP < 0 atau hand > 8.

ATURAN:
- DILARANG DateTime.now(), Math.random tanpa seed, dan akses ke widget.
- Jangan menambahkan aturan yang tidak ada di spec (mis. kartu "taunt" belum diimplementasi — catat sebagai TODO P1).
- Semua angka di BattleConfig, tidak boleh tersebar.

SELESAI BILA: 14 edge case + golden + fuzz hijau, coverage domain ≥ 90%, `dart test` < 10 detik.
```

### P11 — Bot AI Easy / Medium / Master

```
Lanjutkan repo Dokimon (frontend). BACA: docs/PRD.md FR-08; docs/TECH_SPEC.md §9.

TUGAS: implementasi BotAI 3 level + simulation harness.
1. Interface BotAI + factory forDifficulty(d, seed). Bot melihat BattleView (tanpa deck lawan).
2. Easy: 20% skip, pilih acak dengan bobot §9.1.
3. Medium: greedy scoring §9.2, ulangi sampai tidak ada aksi bernilai > 0 (maks 12 aksi/turn), selalu ambil lethal.
4. Master: beam width 8, lookahead 1 ply balasan greedy, eval §9.3, time budget 250ms dengan Stopwatch + fallback plan, tie-break stabil.
5. Aksi harus selalu diambil dari legalActions(); bot dilarang mengubah state.
6. Harness test (tag slow untuk 1000 match):
   - Master vs Medium win-rate 55–80%, Easy vs Medium 10–40%.
   - p95 decision time Master < 300ms (Stopwatch).
   - 0 exception, 0 match > 60 turn, 0 aksi ilegal.
7. Script opsional scripts/simulate-balance.dart: jalankan N match per pasangan, cetak win-rate + rata-rata turn + distribusi pemenang.

ATURAN:
- Jangan memberi bot informasi tersembunyi atau resource tambahan.
- Jangan tuning angka eval untuk "menang cantik" tanpa data; laporkan hasil simulasi di PR.
- Waktu pikir harus diukur di engine murni (tanpa animasi).

SELESAI BILA: tabel win-rate aktual dilampirkan di PR + AC-08.1..08.3 lulus.
```

### P12 — Arena UI + Integrasi Battle End-to-End

```
Lanjutkan repo Dokimon (frontend). BACA: docs/PRD.md FR-07, FR-08, FR-09, §7; docs/TECH_SPEC.md §5.7, §8, §10.5.

TUGAS: layar battle yang memakai engine P10 + BotAI P11 + API P5.
1. BattleSetup: pilih difficulty (preview reward & level bot), pilih deck (hanya valid), tombol Start → POST /battles/start (loading, error handling).
2. ArenaScreen + BattleCubit: state dari engine, animasi via AnimatedPositioned/AnimationController (bukan WebView),
   elemen: HP bar 2 sisi, energy pips, board 3×2, hand fan (scrollable), tombol End Turn, Concede (konfirmasi), log aksi (collapsible, 3 baris terakhir).
3. Alur giliran: setelah pemain End Turn → animasi bot berpikir 400–800ms → bot.decide() loop sampai EndTurn → kembali ke pemain.
   Setiap aksi lewat satu method `perform(action)` untuk animasi + delay.
4. Feedback damage: floating number, shake unit, flash merah; status icon (burn/freeze/shield/rally) di kartu unit; keyword tooltip.
5. Suspend: simpan state engine (JSON) ke battleBox saat app background; resume → restore; tombol "Menyerah" tetap ada.
6. Result overlay: menang/kalah/seri, reward breakdown dari API (gold, xp, first win bonus), XP bar animasi, tombol Rematch (start baru) & Home.
7. Kirim POST /battles/:matchId/result sekali (idempotent), tangani alreadyReported.
8. Test: widget test alur 1 turn penuh dengan engine seed tetap; integration manual: menang Easy → saldo bertambah.

ATURAN:
- UI tidak boleh menghitung damage sendiri — ambil dari BattleEvent.
- Jangan panggil bot di main isolate untuk Master bila > 16ms; gunakan `compute`/Isolate hanya jika perlu (ukur dulu).
- Animasi tidak boleh mengubah state; state machine dulu, animasi menyusul.

SELESAI BILA: AC-07.1, 07.5, 07.6 lulus di device; match penuh bisa diselesaikan tanpa restart.
```

### P13 — Polish: Audio, i18n, A11y, 3D Arena

```
Lanjutkan repo Dokimon (frontend). BACA: docs/PRD.md FR-10, §9; docs/TECH_SPEC.md §10.5–10.7, §13.

TUGAS: polish produksi.
1. Audio service (audioplayers): BGM loop + SFX (draw, summon, attack, hit, win, rare reveal); volume BGM/SFX terpisah di settings, mute; hentikan BGM saat background.
2. i18n: audit semua string, lengkapi id + en, format angka/tanggal via intl, tidak ada hardcoded text.
3. Aksesibilitas: Semantics label untuk kartu/HP/energy, tap target 44px, contrast check, toggle "Reduce motion" yang mematikan flip & shake.
4. 3D opsional di arena: hanya 1 model aktif (hero/unit unggulan), auto-rotate saat idle, matikan saat battle berjalan untuk hemat; fallback 2D.
5. Battery saver: kurangi partikel/glow, hentikan animasi idle.
6. Performance pass: profile mode, pastikan frame build < 16ms; perbaiki rebuild berlebih (const, RepaintBoundary, BlocSelector).
7. Test: widget a11y (semantics), reduce motion, settings persist setelah restart.

ATURAN:
- Tidak menambah fitur baru. Fokus kualitas.
- Semua aset audio ≤ 200KB/file, format ogg/mp3.

SELESAI BILA: checklist NFR PRD §9 tercentang dengan bukti (screenshot timeline / hasil ukur).
```

### P14 — Hardening, Load Test, Rilis

```
Lanjutkan repo Dokimon. BACA: docs/PRD.md §9–§12; docs/TECH_SPEC.md §11–§15.

TUGAS: siapkan rilis.
1. Security review menyeluruh terhadap checklist §11; perbaiki temuan; tulis laporan singkat di docs/SECURITY_REVIEW.md.
2. Load test k6: skenario login → gacha pull 10x → deck list, 50 rps 5 menit; laporkan p50/p95/p99, error rate; target p95 < 600ms, error < 1%.
3. Uji chaos katalog: matikan network backend → app tetap jalan dengan cache; cards.json invalid → versi lama tetap aktif.
4. Migrasi DB: uji pada salinan DB berisi data; pastikan backward-compatible.
5. Backup & monitoring: script backup harian SQLite/Postgres, healthcheck, log rotation.
6. Build release: appbundle + ipa (bila macOS), shrunk, obfuscated, dart-define production; ukur ukuran app.
7. Store assets: ikon, screenshot 5, deskripsi, rating, privacy policy, disclosure loot box (rate gacha).
8. docs/RELEASE_NOTES.md + rollback plan.

ATURAN:
- Jangan menaikkan versi dependency mayor di fase ini.
- Semua temuan keamanan kritis harus diperbaiki, bukan didokumentasikan sebagai risiko.

SELESAI BILA: checklist §14 TECH_SPEC tercentang semua, load test lulus, build release terpasang & bisa menyelesaikan 1 match penuh.
```

---

## 4. Definition of Done (dipakai setiap fase)

Agent **tidak boleh** bilang "selesai" bila:

- [ ] Test untuk AC fase tersebut belum ada / masih merah.
- [ ] `flutter analyze` atau `tsc --noEmit` masih ada error.
- [ ] Ada `print`/`console.log` debug, `TODO` tanpa penanda fase, atau `catch (_) {}` kosong.
- [ ] String UI hardcoded (bukan l10n).
- [ ] Error path tidak ditangani (hanya happy path).
- [ ] Kontrak API/JSON berubah tapi dokumen belum diperbarui.
- [ ] Perubahan menyentuh aturan bisnis (pity, deck, reward, damage) tanpa test eksplisit.

**Format laporan akhir agent (wajib):**
```
## Ringkasan
<2–4 kalimat>

## File
- created: ...
- modified: ...

## AC yang dipenuhi
- AC-xx.y — <bukti test/manual>

## Perintah verifikasi
<perintah + hasil singkat>

## Catatan / risiko
- ...

## Belum dikerjakan
- ...
```

---

## 5. Prompt tambahan (situasional)

### 5.1 Review kode sebelum merge
```
Review perubahan di branch ini terhadap docs/PRD.md dan docs/TECH_SPEC.md.
Fokus, urut prioritas:
1. Pelanggaran prinsip arsitektur (A-01..A-06): apakah ada logika bisnis di client? saldo dihitung client? secret bocor?
2. Aturan bisnis yang salah/berbeda dari spec (pity, deck 20/3, damage, reward, element multiplier).
3. Error path & transaksi DB (race condition saldo, idempotency).
4. Test yang hilang untuk AC terkait.
5. Kualitas: duplikasi rumus, hardcode angka, akses state tersembunyi oleh bot.
Output: daftar temuan dengan file:line, severity (blocker/major/minor), dan patch yang disarankan.
Jangan menulis ulang seluruh file; tunjukkan diff minimal.
```

### 5.2 Debug test yang gagal
```
Test berikut gagal: <tempel output>.
1. Jelaskan penyebab akar (bukan gejala) dalam <= 5 baris.
2. Tunjukkan apakah bug ada di kode produksi atau di ekspektasi test (rujuk spec PRD/TECH_SPEC bagian mana).
3. Berikan patch minimal. Jangan mengubah test agar lulus bila spec mengatakan kode yang salah.
4. Jalankan ulang test terkait dan tempel hasilnya.
```

### 5.3 Menambah kartu baru (konten, bukan kode)
```
Tambah 5 kartu baru ke content/cards/cards.json mengikuti content/cards/schema.json.
Aturan:
- id unik format card_xxx, jangan ubah kartu lama.
- Distribusi: 2 Common, 1 Uncommon, 1 Rare, 1 Epic; sebar antar elemen.
- Stat mengikuti kurva: cost 1 => atk 20-25/hp 60-70; cost 3 => atk 40-45/hp 100-110; cost 5 => atk 55-65/hp 140-160.
- ability wajib punya name/type/cost/target/power/text, status hanya bila relevan.
- imageUrl & model3dUrl memakai baseAssetUrl yang sama dengan kartu lain (boleh menunjuk placeholder yang sudah ada).
- Nama & flavorText bahasa Inggris, konsisten dengan kartu lain.
Setelah itu jalankan `node scripts/build-catalog.mjs` dan laporkan catalogVersion baru + hasil validasi.
```

### 5.4 Menyeimbangkan ulang (balance pass)
```
Jalankan scripts/simulate-balance (atau test tag slow) untuk 200 match per pasangan bot.
Laporkan tabel: pasangan, win-rate, rata-rata turn, rata-rata durasi keputusan.
Usulkan perubahan HANYA pada konstanta di BattleConfig / scoring BotAI (bukan rumus),
sertakan prediksi dampak dan jalankan ulang simulasi untuk membuktikan.
Jangan mengubah drop rate gacha tanpa persetujuan (menyentuh ekonomi).
```

### 5.5 Menyiapkan repo GitHub sebagai CMS
```
Bantu saya menyiapkan repo GitHub sebagai headless CMS:
1. Pastikan content/cards/cards.json + manifest.json valid (`node scripts/build-catalog.mjs --check`).
2. Tulis content/cards/README.md: struktur folder, konvensi nama file aset (images/<id>.webp 512x768 <=120KB, models/<id>.glb <=2MB),
   langkah rilis konten, cara rollback, dan larangan mengubah id lama.
3. Tulis .github/workflows/catalog.yml: validasi katalog setiap PR yang menyentuh content/cards/**,
   dan komentar otomatis berisi catalogVersion + jumlah kartu.
4. Jelaskan cara menguji endpoint backend setelah push (curl manifest + sync manual).
```

---

## 6. Anti-pattern yang harus ditolak di review

| Anti-pattern | Kenapa berbahaya | Ganti dengan |
|---|---|---|
| Roll gacha di Flutter | Bisa dimanipulasi, ekonomi rusak | Server roll + idempotency |
| Saldo dihitung dari `sum(pulls)` di client | Tidak sinkron, bisa negatif | Selalu baca `wallet` dari server |
| `DateTime.now()` di engine battle | Replay & test tidak deterministik | Seed + turn counter |
| Rumus damage diulang di widget | Angka berbeda antar layar | Satu `damage.dart` |
| 20 entry Hive terpisah untuk katalog | Lambat, tidak atomik | Satu blob + version |
| `WebView` untuk arena | FPS drop, sulit sinkron state | Flutter native + animasi |
| Bot membaca deck lawan | Curang, tidak fair | `BattleView` tanpa informasi tersembunyi |
| Hardcode harga/rate di UI | Tidak konsisten dengan server | Ambil `/gacha/rates` + config |
| `catch (e) {}` | Bug tersembunyi | Log + state error + pesan user |
| Menghapus kartu dari `cards.json` | Inventory pemain rusak | `retired: true` |

---

## 7. Handoff checklist (akhir proyek)

- [ ] `docs/PRD.md`, `docs/TECH_SPEC.md`, `docs/AI_AGENT_GUIDE.md` sinkron dengan implementasi.
- [ ] Semua AC punya test; coverage domain ≥ 90%, gacha math ≥ 90%.
- [ ] Tabel win-rate bot & rate gacha aktual terdokumentasi.
- [ ] `.env.example` lengkap; README bisa diikuti orang baru dalam < 15 menit.
- [ ] Prosedur rilis konten (GitHub) dan rilis app terdokumentasi.
- [ ] Tidak ada kredensial di repo (`git log -S "secret" --all` bersih).
- [ ] Build release terpasang di 1 device Android & 1 iOS, menyelesaikan 1 match penuh.

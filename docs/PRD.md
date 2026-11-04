# PRD — Dokimon TCG 3D (Flutter + Express.js + GitHub CMS)

| Field | Value |
|---|---|
| Nama produk | **Dokimon TCG 3D** |
| Versi dokumen | 1.0 |
| Tanggal | 2026-11-01 |
| Status | Approved for build (v1 MVP) |
| Pemilik | Product Owner |
| Target rilis | Android & iOS, PvE only |
| Dokumen terkait | [`TECH_SPEC.md`](./TECH_SPEC.md) · [`AI_AGENT_GUIDE.md`](./AI_AGENT_GUIDE.md) · [`../AGENTS.md`](../AGENTS.md) |

---

## 0. Perubahan dari Draft (baca dulu)

Draft awal sudah benar arahnya. Tabel ini merangkum keputusan yang saya kunci supaya agent AI tidak menebak-nebak.

| # | Draft | Keputusan v1.0 | Alasan |
|---|---|---|---|
| 1 | Gacha dihitung di Flutter | **Roll 100% di server** (`POST /api/v1/gacha/pull`). Flutter hanya memutar animasi hasil. | Kalau roll di client, saldo & rarity bisa dimanipulasi. Ini tidak bisa ditawar. |
| 2 | Pool kartu dibaca langsung Flutter dari GitHub | Flutter baca katalog **via backend** (yang mem-fetch + cache GitHub). Flutter tetap punya cache lokal + bundled fallback. | GitHub raw punya rate limit & tidak bisa memfilter/validasi. Backend jadi satu-satunya sumber kebenaran. |
| 3 | Field `skill` di JSON | Diganti `ability` (satu skema untuk unit & spell), plus field wajib `type`, `cost`, `keywords`, `obtainable`. | `skill` di draft tidak punya cost summon, tipe kartu, dan tidak bisa dipakai untuk spell. |
| 4 | HP musuh tidak disebut | **Player HP = 200**, board 3 slot, energy cap 10. | Skala stat contoh (ATK 60 / HP 150) tidak cocok dengan HP 30. |
| 5 | "Defense & Counter Phase" | Diimplementasikan sebagai **stance `Guard`** per unit (damage taken ×0.5 + counter 30% ATK), bukan phase terpisah. | Turn-based 1 pemain vs bot lebih enak dibaca sebagai aksi, bukan phase baru. |
| 6 | 20 kartu per deck | Dipertahankan, + **maks 3 copy per card ID**, hanya kartu yang dimiliki, hanya tipe `unit`/`spell`. | Standar TCG, mencegah deck 20 kartu Master. |
| 7 | Tidak ada pity detail | Hard pity **50 pull** sejak Epic+ terakhir, counter **per user**, dan 10x pull dijamin minimal 1× Rare+. | Spec harus eksak agar bisa di-unit-test. |
| 8 | 3D pakai "model_viewer_plus / WebView Three.js" | **model_viewer_plus (GLB)** untuk inspection; arena battle pakai **Flutter CustomPainter/Stack + animasi 2.5D**, bukan WebView penuh. | WebView di arena = FPS drop + sulit sync dengan state game. |
| 9 | Auth tanpa detail token | Access token JWT 15 menit + **refresh token rotasi 30 hari** di `flutter_secure_storage`. | Standar keamanan mobile. |
| 10 | Monetisasi tidak disebut | **Tanpa pembelian uang nyata di MVP.** Gem didapat dari progres. | Menghindari kewajiban regulasi loot box berbayar di awal. |

---

## 1. Ringkasan Eksekutif

**Dokimon TCG 3D** adalah game *turn-based trading card game* single-player (PvE) untuk Android & iOS. Pemain mengoleksi monster lewat gacha, menyusun deck 20 kartu, lalu bertarung melawan bot pada tiga tingkat kesulitan. Setiap kartu punya model 3D yang bisa diputar/di-zoom, animasi *card flip* saat gacha, dan arena pertarungan dengan efek status (Burn, Freeze, Shield, Rally).

**Yang membuat produk ini berbeda:**
1. **Konten digerakkan GitHub** — desainer konten cukup push `cards.json` + aset ke repo; aplikasi otomatis sinkron tanpa rilis ulang.
2. **Gacha adil & transparan** — drop rate ditampilkan di UI, pity terlihat, roll diaudit di server.
3. **Bot yang benar-benar bermain** — Master bot memakai heuristik + lookahead, bukan sekadar random.

**Stack:** Flutter (Dart 3) · Express.js (Node 20) · Prisma + SQLite (dev) / Postgres (prod) · GitHub repo sebagai headless CMS.

**Definisi sukses MVP:** pemain baru bisa register → dapat starter deck → menang melawan bot Easy → pull gacha → membuka pack dengan animasi 3D → menyusun deck → menang melawan Master, semuanya tanpa crash dan tanpa intervensi manual.

---

## 2. Tujuan & Non-Tujuan

### 2.1 Tujuan (v1)
- G-01: Loop inti lengkap: **Auth → Gacha → Collection → Deck → Battle → Reward**.
- G-02: Ekonomi & gacha **server-authoritative** dan tidak bisa di-cheat dari client.
- G-03: Katalog kartu bisa di-update **tanpa rebuild aplikasi** (≤ 15 menit propagasi).
- G-04: Battle engine deterministik, bisa di-replay, dan di-unit-test.
- G-05: Bot AI 3 level dengan perbedaan perilaku yang terasa.
- G-06: Performa: 60 FPS di device mid-range, cold start < 3 detik.

### 2.2 Non-tujuan (v1) — jangan dikerjakan agent
- PvP real-time / multiplayer.
- Trading / marketplace antar pemain.
- Pembelian uang nyata (IAP), iklan, battle pass.
- Web admin panel (cukup Postman/HTTP file + GitHub).
- Cross-device cloud save battle in progress (resume match tidak didukung).
- Lokalisasi selain Indonesia & Inggris.

---

## 3. Target Pengguna

| Persona | Deskripsi | Kebutuhan utama |
|---|---|---|
| **Kolektor Kasual** (utama) | 16–30 th, main 10–20 menit/hari, suka Pokemon/HS | Animasi gacha memuaskan, koleksi rapi, progres jelas |
| **Taktisi** | Suka deck building & optimasi | Deck builder enak dipakai, bot Master menantang, statistik jelas |
| **Pemain Baru TCG** | Belum pernah main TCG | Tutorial singkat, tooltip keyword, bot Easy yang memaafkan |

Device target: Android 8.0+ (RAM ≥ 3 GB), iOS 14+. Prioritas uji: Snapdragon 6xx/7xx dan iPhone 11.

---

## 4. Arsitektur Sistem

```
┌──────────────────────────────┐        ┌──────────────────────────────┐
│  Flutter App (Android/iOS)   │        │  GitHub Repository (CMS)     │
│  ├─ Presentation (BLoC)      │        │  content/cards/cards.json    │
│  ├─ Domain (BattleEngine,    │        │  content/cards/manifest.json │
│  │   BotAI, DeckValidator)   │        │  content/cards/images/*.webp │
│  └─ Data (Dio, Hive, Secure) │        │  content/cards/models/*.glb  │
└───────────┬──────────────────┘        └──────────────▲───────────────┘
            │ HTTPS / JSON (JWT)                        │ fetch + ETag
            ▼                                           │ (jsDelivr / raw)
┌───────────────────────────────────────────────────────┴───────────────┐
│  Express.js API (/api/v1)                                            │
│  ├─ Auth (JWT + refresh rotation)                                    │
│  ├─ CatalogService  ← cache 15 mnt + snapshot versi di DB            │
│  ├─ GachaService    ← RNG server, pity, audit log, idempotency       │
│  ├─ DeckService     ← validasi aturan deck                            │
│  ├─ BattleService   ← start match, verifikasi hasil, reward          │
│  └─ Prisma ORM → SQLite (dev) / Postgres (prod)                      │
└───────────────────────────────────────────────────────────────────────┘
```

### 4.1 Prinsip arsitektur (WAJIB dipatuhi agent)

| ID | Prinsip | Konsekuensi teknis |
|---|---|---|
| A-01 | **Server adalah sumber kebenaran** untuk saldo, inventory, pity, dan hasil gacha. | Client tidak boleh punya endpoint untuk menulis saldo. |
| A-02 | **Battle dieksekusi di client** (offline-friendly) tapi hasilnya diverifikasi server. | Engine harus pure Dart, deterministic, dan menghasilkan `logHash`. |
| A-03 | **Katalog immutable per versi.** Gacha memakai snapshot versi tertentu. | Tabel `CatalogVersion` + `GachaPull.catalogVersion`. |
| A-04 | **No secret di app bundle.** Tidak ada GitHub token / DB URL di Flutter. | Aset publik boleh; API key tidak. |
| A-05 | **Graceful degradation.** Katalog offline → pakai cache Hive → bundled asset. | 3 lapis fallback. |
| A-06 | **Konten = data, bukan kode.** Menambah kartu tidak boleh perlu ubah Dart/TS. | Semua perilaku kartu dipetakan dari enum di `cards.json`. |

---

## 5. Model Data Inti

Entitas & kepemilikan:

| Entitas | Pemilik | Catatan |
|---|---|---|
| `User` | Server | email unik, username unik, password hash argon2 |
| `Wallet` | Server | gold, gems (integer, tidak pernah negatif) |
| `PlayerStats` | Server | level, xp, wins, losses, streak |
| `InventoryCard` | Server | `(userId, cardId)` unik + `quantity` |
| `PityState` | Server | counter Epic+ per user (kolom `pityCounter` pada `User`) |
| `GachaPull` | Server | audit log per kartu hasil (immutable) |
| `Deck` / `DeckCard` | Server | max 10 deck/user, 1 aktif |
| `Match` | Server | hasil + verifikasi, untuk reward idempotent |
| `CatalogVersion` | Server | snapshot katalog yang dipakai gacha |
| `CardModel` | CMS (GitHub) | tidak disimpan permanen, hanya cache |

Aturan integritas:
- `quantity` inventory ≥ 0. Gacha menambah, tidak pernah mengurangi (kecuali fitur crafting P1).
- Deck hanya boleh berisi `cardId` dengan `quantity ≥ 1`.
- Total kartu dalam deck **tepat 20**; per `cardId` **≤ 3**.
- Satu user hanya punya **satu** deck aktif; menghapus deck aktif → tidak ada deck aktif (harus pilih lagi sebelum battle).
- Semua nominal uang integer (tanpa float) untuk menghindari rounding.

---

## 6. Spesifikasi Fungsional

Format tiap fitur: **Deskripsi → Aturan bisnis → Acceptance Criteria (AC)**. AC bernomor untuk dirujuk di test & prompt agent.

### FR-01 Autentikasi & Sesi

**Deskripsi.** Registrasi & login email+password. Token JWT akses singkat + refresh token rotasi. Sesi bertahan setelah app ditutup.

**Aturan bisnis.**
- Email harus valid & unik (case-insensitive), password minimal 8 karakter, maksimal 72 byte.
- Username 3–16 karakter, `[a-zA-Z0-9_]`, unik.
- Password di-hash **argon2id** (fallback bcrypt cost 12).
- Access token 15 menit; refresh token 30 hari, **rotasi setiap refresh**, token lama langsung dicabut (deteksi reuse → revoke seluruh family).
- Login gagal 5× dalam 10 menit per IP+email → 429 selama 15 menit.
- Tidak ada endpoint "lupa password" di MVP (dicatat sebagai P2).

**AC.**
- AC-01.1 Register sukses → 201, mengembalikan `user`, `accessToken`, `refreshToken`, saldo awal 1.000 Gold / 50 Gems, dan starter deck otomatis.
- AC-01.2 Register email duplikat → 409 `DUPLICATE_EMAIL`.
- AC-01.3 Login salah → 401 `INVALID_CREDENTIALS` (pesan tidak membocorkan mana yang salah).
- AC-01.4 Access token kedaluwarsa → client otomatis refresh sekali; bila refresh gagal → logout bersih ke halaman login.
- AC-01.5 Setelah app restart, user tetap login tanpa input ulang.
- AC-01.6 Logout mencabut refresh token di server.

### FR-02 Profil & Progresi

**Deskripsi.** Halaman profil: username, avatar, level, XP bar, Gold, Gems, win/loss vs bot per difficulty, koleksi (x/total), deck aktif.

**Aturan bisnis.**
- XP: menang Easy 30, Medium 60, Master 120; kalah 10; seri 15.
- `xpToNext(level) = 100 + 50 × (level − 1)`; kelebihan XP carry over.
- Naik level → +5 Gems, +200 Gold, dan max energy di battle **tidak** berubah (jaga balance).
- Statistik menang/kalah dihitung per difficulty dan total.

**AC.**
- AC-02.1 Level & XP konsisten setelah restart (diambil dari server).
- AC-02.2 Naik level memicu dialog reward sekali saja (idempotent per level).
- AC-02.3 Win rate = `wins / (wins + losses)`, ditampilkan 1 desimal, `—` bila belum ada match.

### FR-03 Katalog Kartu via GitHub CMS

**Deskripsi.** Konten kartu hidup di repo GitHub (`content/cards/`). Backend menyinkronkan, memvalidasi skema, menyimpan snapshot ber-versi. Flutter mengambil katalog dari backend dan menyimpannya di Hive untuk offline.

**Aturan bisnis.**
- Sumber: `manifest.json` + `cards.json` dari **jsDelivr** (`https://cdn.jsdelivr.net/gh/<owner>/<repo>@<ref>/content/cards/...`), fallback `raw.githubusercontent.com`.
- Sinkronisasi backend: saat startup + setiap 15 menit + endpoint manual admin (`POST /internal/catalog/sync`, header `X-Admin-Token`).
- Validasi wajib sebelum snapshot dipakai: skema JSON valid, `id` unik, `rarity` ∈ 6 tier, `element` ∈ 5 elemen, `cost` 0–10, semua URL aset `https://`, minimal 1 kartu per rarity.
- File tidak valid → **tolak snapshot baru**, pertahankan versi lama, kirim alert log level `error`. Game tetap jalan.
- Checksum `sha256` file dicek terhadap manifest; mismatch → tolak.
- Flutter: cache Hive dengan `catalogVersion` + TTL 24 jam; bila fetch gagal pakai cache; bila cache kosong pakai `assets/cards/cards.seed.json` (bundled).
- Perubahan kartu harus **backward compatible** (jangan hapus `id` yang sudah dimiliki pemain; gunakan `"retired": true`).

**AC.**
- AC-03.1 App pertama kali dibuka dengan internet → katalog tampil < 2 detik setelah login.
- AC-03.2 Mode pesawat + cache tersedia → koleksi, deck, dan detail kartu tetap terbuka.
- AC-03.3 Mode pesawat + tanpa cache (install baru) → katalog bundled tampil, banner "Offline — data mungkin tertinggal".
- AC-03.4 Push `cards.json` baru ke `main` → dalam ≤ 15 menit (atau setelah app resume + refresh manual) kartu baru muncul, tanpa update aplikasi.
- AC-03.5 `cards.json` rusak di repo → API tetap menyajikan versi terakhir yang valid.
- AC-03.6 Gacha setelah katalog berubah mencatat `catalogVersion` yang dipakai pada setiap hasil.

**Lihat** [`TECH_SPEC.md` §7](./TECH_SPEC.md) untuk kontrak file dan prosedur rilis konten.

### FR-04 Gacha

**Deskripsi.** Single pull & 10x pull dengan animasi flip kartu 3D. Drop rate transparan, pity 50, hasil diproses server.

**Aturan bisnis — drop rate (per pull):**

| Rarity | Rate | Warna | Bobot |
|---|---|---|---|
| Common | 60.0% | Abu | 6000 |
| Uncommon | 25.0% | Hijau | 2500 |
| Rare | 10.0% | Biru | 1000 |
| Epic | 4.0% | Ungu | 400 |
| Legendary | 0.9% | Emas | 90 |
| Master | 0.1% | Merah | 10 |
| **Total** | **100%** | | **10000** |

- Pemilihan kartu: roll rarity (bobot di atas) → pilih **uniform** di antara kartu `obtainable: true` pada rarity tersebut. Bila rarity kosong, fallback ke rarity terdekat di bawahnya.
- **Pity:** setiap Epic/Legendary/Master men-*reset* counter ke 0. Bila counter sudah **49** (artinya 49 pull beruntun tanpa Epic+), pull berikutnya — yaitu **pull ke-50** — dipaksa Epic+ dengan distribusi ternormalisasi: **Epic 80%, Legendary 18%, Master 2%**. Counter lalu reset.
- **10x guarantee:** bila 10 hasil tidak mengandung Rare+, hasil ke-10 di-*upgrade* menjadi Rare (mengikuti aturan pity bila pity aktif).
- **Biaya:** 1 pull = 100 Gold atau 1 Gem; 10x = 900 Gold atau 9 Gem. Bila Gold tidak cukup → tawarkan Gem, jangan pernah saldo negatif.
- **Idempotency:** client mengirim `idempotencyKey` (UUID v4). Key sama dalam 24 jam → kembalikan hasil yang sama, tidak memotong saldo dua kali.
- **Audit:** setiap kartu hasil dicatat (`gacha_pulls`) termasuk `catalogVersion`, `rarity`, `pityBefore`, `pityAfter`, `source` (`gold`/`gem`).
- **Odds disclosure:** tombol "Lihat Peluang" menampilkan tabel rate + penjelasan pity. Wajib terlihat sebelum pull pertama.

**AC.**
- AC-04.1 Saldo berkurang **setelah** hasil dibuat, dalam satu transaksi DB (atomic).
- AC-04.2 Saldo tidak cukup → 402 `INSUFFICIENT_FUNDS`, tidak ada pull tercatat.
- AC-04.3 Pull ke-50 tanpa Epic+ sejak counter 0 → dijamin Epic+ dan counter reset (counter 49 + pull berikutnya).
- AC-04.4 Counter pity terlihat di UI gacha (`Epic+ dalam X pull`).
- AC-04.5 Animasi flip selesai ≤ 4 detik untuk 10x, bisa di-*skip* ke hasil akhir.
- AC-04.6 Duplikat menambah `quantity` (tidak error), badge "NEW" hanya untuk ID yang belum dimiliki.
- AC-04.7 Distribusi 100.000 simulasi lolos uji chi-square (α=0.01) terhadap tabel rate.

**Catatan balancing.** Dengan Epic+ 5%, ekspektasi pity trigger ≈ 8,1% pull. Ekspektasi biaya 1 kartu Epic+ ≈ 20 pull (≈2.000 Gold). Bot Master memberi 150 Gold → ~13 menang per Epic+. Ini disengaja agar grind terasa, tapi pantau di telemetry (lihat §12).

### FR-05 Inventory

**Deskripsi.** Koleksi kartu pemain, grid/gallery, filter & sort, detail kartu dengan viewer 3D.

**Aturan bisnis.**
- Filter: elemen (Fire/Water/Earth/Air/Void), rarity (6), tipe (unit/spell), status (owned/not-owned).
- Sort: rarity ↓, nama A–Z, terbaru, ATK ↓, HP ↓.
- Kartu yang belum dimiliki tampil *silhouette* + nama rarity (untuk tease), tidak bisa dipakai di deck.
- Detail kartu: artwork, stat, ability, keyword tooltip, tombol "Putar 3D".
  - *Update 2026-11-04 (Q-06):* tombol "Putar 3D" disembunyikan atas permintaan PO; karakter ditampilkan sebagai ilustrasi kartun 2D.
- Mode 3D: `model_viewer_plus` dengan auto-rotate, pinch-zoom; ada tombol kembali & fallback gambar bila model gagal/`model3dUrl` null.
- Preload model hanya untuk kartu yang dibuka (bukan semua), maks 3 model di cache LRU.

**AC.**
- AC-05.1 Filter elemen + rarity bisa dikombinasikan dan hasilnya benar.
- AC-05.2 Grid 3 kolom tetap 60 FPS saat scroll 200+ item (gunakan `GridView.builder` + cached image).
- AC-05.3 Model 3D gagal dimuat ≤ 5 detik → tampilkan gambar statis + pesan singkat, tidak crash.
- AC-05.4 Kartu duplikat menampilkan badge `×N`.

### FR-06 Deck Builder

**Deskripsi.** Buat/ubah/hapus beberapa deck, validasi real-time, pilih deck aktif.

**Aturan bisnis.**
- Persis **20 kartu**; maks **3 kartu dengan `id` sama**; hanya kartu yang dimiliki; hanya `type` `unit`/`spell`.
- Maks **10 deck** per user; nama 3–24 karakter, unik per user (case-insensitive).
- Validasi dilakukan di **client (instan, UX)** dan **server (otoritatif, saat save & saat battle start)**. Server menolak deck tidak valid dengan detail pelanggaran.
- Deck aktif wajib ada untuk memulai battle; bila tidak ada, arahkan ke deck builder.
- Mengubah deck yang sedang aktif langsung berlaku untuk battle berikutnya (tidak ada battle berjalan yang terpengaruh karena match sudah membaca snapshot deck).
- Hapus deck → konfirmasi; bila deck aktif dihapus, `activeDeckId = null`.

**AC.**
- AC-06.1 Menambah kartu ke-21 ditolak dengan pesan jelas, tombol tambah disabled.
- AC-06.2 Copy ke-4 dari ID sama ditolak, badge `3/3` tampil.
- AC-06.3 Deck 19 kartu → tombol "Simpan" disabled + indikator `19/20`.
- AC-06.4 Server menolak payload deck invalid (400 `DECK_INVALID`) meskipun client dimanipulasi.
- AC-06.5 Deck tersimpan muncul di daftar setelah restart (server-backed).

### FR-07 Pertarungan vs Bot

**Deskripsi.** Match turn-based pemain vs bot dengan fase Draw → Energy → Action → Combat, status effect, dan victory/defeat.

**Setup.**
- Player HP **200**, bot HP **200**. Board maks **3 unit** per sisi.
- Deck 20 kartu (snapshot saat match start). Hand awal **4** kartu. Hand cap **8** (kelebihan di-*burn*).
- Coin flip menentukan giliran pertama; pemain pertama **tidak** draw di turn pertamanya.
- Energy: mulai **1**, +1 setiap awal turn sendiri, cap **10**, **refill penuh** setiap turn (sisa tidak carry over).

**Urutan turn.**
1. **Upkeep** — refill energy; tick durasi status; trigger Burn; unit yang di-*freeze* dilewati; draw 1 (kecuali turn pertama pemain pertama).
2. **Action** — mainkan kartu (unit → slot kosong; spell → langsung resolve); gunakan ability unit; set stance Guard; serang.
3. **End** — status `Rally` berakhir, unit yang menyerang/guard ditandai *tapped* sampai turn berikutnya; giliran berpindah.

**Aturan combat.**
- Unit baru tidak bisa menyerang di turn yang sama kecuali punya keyword `charge`.
- Setiap unit punya 1 aksi per turn: **attack**, **ability**, **guard**, atau diam.
- **Guard**: unit menerima damage ×0,5 dan melakukan *counter* sebesar 30% ATK (setelah modifier elemen) ke penyerang. Guard aktif sampai awal turn pemiliknya berikutnya.
- **Target:** unit hanya bisa menyerang unit musuh. Serangan langsung ke **player HP** hanya bila field musuh **kosong**.
- **Damage** (detail rumus di [`TECH_SPEC.md` §8.4](./TECH_SPEC.md)):
  `dmg = max(1, round(ATK × elemMult × buff − DEF × 0,5))`, lalu `×0,5` bila target Guard.
- **Elemen:** Fire → Air → Earth → Water → Fire (advantage ×1,25; disadvantage ×0,8). Void netral ×1,0 ke/dari semua.
- **Status:** Burn (DoT di awal turn), Freeze (tidak bisa aksi N turn), Shield (menyerap X damage), Rally (+ATK sampai akhir turn).
- **Deck habis:** bukan langsung kalah — *fatigue* 20 damage, +10 setiap draw berikutnya.
- **Menang:** HP lawan ≤ 0. **Seri:** turn ke-50 → draw. **Concede** kapan saja (dihitung loss, tanpa reward).
- **Determinisme:** engine menerima `seed`; RNG apa pun (mis. shuffle) harus dari seeded PRNG. Tidak ada `DateTime.now()` di dalam engine.

**AC.**
- AC-07.1 Pemain bisa menyelesaikan match penuh di device low-end tanpa frame drop > 100 ms.
- AC-07.2 Semua aksi ilegal (energy kurang, unit sudah aksi, slot penuh, target invalid) ditolak engine dengan alasan.
- AC-07.3 Status effect berjalan sesuai durasi & tidak stack duplikat (refresh durasi, ambil nilai terbesar).
- AC-07.4 Match yang sama dengan seed sama menghasilkan state akhir identik (golden test).
- AC-07.5 Concede → langsung kalah, statistik bertambah, tidak ada reward.
- AC-07.6 App di-background saat battle → state tersimpan lokal, match di-*suspend*; kembali → lanjut (bukan reset), atau user bisa menyerah.

### FR-08 Bot AI

**Deskripsi.** Tiga level kesulitan dengan perilaku berbeda dan dapat diuji.

| Level | Perilaku | Target win-rate vs pemain rata-rata | Waktu pikir |
|---|---|---|---|
| **Easy** | Legal move acak; 20% skip; sering salah target | ≤ 25% | < 50 ms |
| **Medium** | Greedy: mainkan kartu termahal yang terjangkau, serang unit dengan trade terbaik, kejar lethal | ≈ 50% | < 120 ms |
| **Master** | Greedy + lookahead 2 ply, threat assessment, hemat removal, mainkan ability optimal | ≥ 70% | ≤ 300 ms |

**Aturan bisnis.**
- Bot memakai **API engine yang sama** dengan pemain (`legalActions(state, player)`); dilarang membaca state tersembunyi (isi deck lawan) atau mengubah state langsung.
- Bot tidak boleh curang: tidak ada energy/hand tambahan.
- Easy memakai `seed` acak per match; Medium & Master deterministik terhadap seed.
- Bot tidak boleh menyebabkan game stuck: bila tidak ada aksi legal → end turn.

**AC.**
- AC-08.1 Simulasi 1.000 match per level: Easy < 40%, Master > 65% terhadap bot Medium (sanity check).
- AC-08.2 Bot Master tidak pernah melebihi 300 ms per keputusan pada device mid-range.
- AC-08.3 Bot selalu menghasilkan aksi legal (fuzz test 10.000 state acak).

### FR-09 Reward & Progresi Match

- Menang: Gold 40/80/150 (Easy/Medium/Master) + XP 30/60/120.
- Kalah/seri: XP 10/15, tanpa Gold.
- First win of the day bonus: **+200 Gold** (sekali per hari kalender WIB, dihitung server).
- Reward hanya diberikan sekali per `matchId` (idempotent).
- Batas anti-abuse: maks 40 match ber-reward per hari per user; setelah itu boleh main tapi tanpa reward (tetap dapat XP? tidak — tanpa XP juga, tampilkan pesan).

**AC.** AC-09.1 Submit hasil dua kali → reward hanya sekali. AC-09.2 Reward harian reset 00:00 WIB. AC-09.3 Statistik & saldo konsisten setelah 50 match (integration test).

### FR-10 Settings, Audio, i18n, Aksesibilitas

- Bahasa: `id` (default) & `en`. Semua string lewat `AppLocalizations` (ARB).
- Audio: BGM (loop, mute-able), SFX (draw, summon, attack, gacha rare reveal). Volume terpisah, disimpan lokal.
- Haptics: getar halus saat rare pull & serangan (bisa dimatikan).
- Aksesibilitas: minimal tap target 44×44, contrast AA, semua gambar punya `semanticLabel`, opsi "kurangi animasi" (skip flip 3D → fade).
- Battery saver: kurangi partikel & auto-rotate 3D.

**AC.** AC-10.1 Mengubah bahasa langsung berlaku tanpa restart. AC-10.2 Reduce motion mematikan animasi flip 3D tapi hasil tetap tampil.

### FR-11 Telemetri & Analytics

Event minimum (nama + properti): `app_open`, `auth_register`, `auth_login`, `catalog_sync{failed,version}`, `gacha_pull{count,source,rarity_results,pity_before}`, `deck_save{valid}`, `battle_start{difficulty,deck_id}`, `battle_end{outcome,turns,duration,difficulty}`, `battle_concede`, `error{code,screen}`.
- Di MVP: kirim ke endpoint backend `POST /api/v1/telemetry/events` (batch ≤ 50) → log file/DB. Tidak perlu third-party SDK.
- Tidak boleh mengirim email/password/token. `userId` di-hash.

---

## 7. UX Flow & Screen Inventory

```
Splash ─► Login/Register ─► Home
                              ├─► Gacha ─► Result (flip 3D) ─► Add to collection
                              ├─► Collection ─► Card Detail ─► 3D Viewer
                              ├─► Deck List ─► Deck Builder
                              ├─► Battle Setup (difficulty + deck) ─► Arena ─► Result
                              └─► Profile / Settings
```

| Screen | Elemen wajib |
|---|---|
| Splash | Logo, cek token, sync katalog (timeout 3 s) |
| Login/Register | Validasi inline, error server, loading state |
| Home | Saldo, level/XP, deck aktif, tombol Battle & Gacha, banner event |
| Gacha | Rate teaser, pity counter, tombol 1x/10x, modal odds |
| Gacha Result | Flip 3D berurutan, skip, badge NEW, tombol "Pull lagi" |
| Collection | Search, filter chips, grid, counter `x/y` |
| Card Detail | Stat, ability, keyword chips, 3D button, "Tambah ke deck" |
| Deck List | Kartu deck + validitas, aktif badge, create/duplicate/delete |
| Deck Builder | 2 panel (koleksi ↔ deck), counter 20/20, kurva energi, warning copy limit |
| Battle Setup | Pilih difficulty (reward preview), pilih deck (valid only) |
| Arena | HP bar, energy pips, hand fan, board 3×2, log aksi, end turn, concede |
| Result | Menang/kalah, reward breakdown, XP bar animasi, "Rematch" |

**Wireframe ringkas Arena:**

```
┌────────────────────────────────────────────┐
│ BOT  HP ████████████░░ 160/200   ⚡ 6/10   │
│  [Unit][Unit][  ]        (board bot)       │
│  ─────────── VS ───────────                │
│  [Unit][Unit][Unit]      (board player)    │
│ PLAYER HP ██████████░░ 180/200  ⚡ 4/10    │
│  Hand: [c][c][c][c]   [End Turn] [Concede] │
└────────────────────────────────────────────┘
```

---

## 8. Ekonomi

| Sumber (faucet) | Jumlah | Batas |
|---|---|---|
| Saldo awal | 1.000 Gold, 50 Gems | sekali |
| Menang Easy / Medium / Master | 40 / 80 / 150 Gold | 40 match/hari |
| First win of day | +200 Gold | 1×/hari |
| Naik level | +200 Gold, +5 Gems | per level |
| Daily login (7 hari) | 100,150,200,250,300,400, +1 Gem | harian |

| Sink | Biaya |
|---|---|
| Single pull | 100 Gold / 1 Gem |
| 10x pull | 900 Gold / 9 Gem |
| (P1) Craft kartu | Dust sesuai rarity |

**Target ekonomi:** pemain aktif 30 menit/hari mendapat **≈ 600–900 Gold** (≈ 6–9 pull) dan **1 Epic+ per 2–3 hari**. Semua angka ada di `backend/src/config/economy.ts` + `frontend/lib/core/config/economy.dart` (satu sumber, jangan hardcode di UI).

---

## 9. Non-Functional Requirements

| Kategori | Requirement | Cara verifikasi |
|---|---|---|
| Performa app | 60 FPS scroll & battle; cold start < 3 s (mid-range) | DevTools timeline, profile build |
| Latensi API | p95 < 300 ms (regional), gacha pull < 600 ms | k6/artillery |
| Ukuran app | ≤ 60 MB unduhan awal (tanpa model 3D) | Build release |
| Aset 3D | 1 model ≤ 2 MB, total ≤ 40 MB diunduh on-demand | Script ukur |
| Offline | Katalog + deck + detail kartu bisa dibuka | Manual + integration test |
| Keamanan | Argon2id, JWT rotation, rate limit, validasi Zod, SQL injection & XSS aman | Review checklist §11 TECH_SPEC |
| Privasi | Tidak ada data pribadi selain email; hapus akun (P1) | Review |
| Aksesibilitas | Target 44 px, contrast AA, reduce motion | Manual |
| Observability | Structured log + request id + error code | Log review |
| Kompatibilitas | Android 8+, iOS 14+ | Matrix device |

---

## 10. Metrik Keberhasilan (KPI)

| KPI | Target MVP | Sumber |
|---|---|---|
| Crash-free sessions | ≥ 99,5% | Error log |
| D1 retention | ≥ 30% | `app_open` |
| Tutorial→first battle completion | ≥ 70% | funnel event |
| Rata-rata match selesai | 8–12 turn, 3–7 menit | `battle_end` |
| Deck valid rate | ≥ 85% save sukses | `deck_save` |
| Gacha conversion harian | ≥ 55% DAU pull ≥ 1× | `gacha_pull` |
| Win rate Master bot | 55–75% (bukan 100%) | `battle_end` |
| Pity rata-rata | 18–22 pull per Epic+ | `gacha_pulls` |

---

## 11. Roadmap & Milestone

| Milestone | Scope | Exit criteria | Estimasi |
|---|---|---|---|
| **M0** Bootstrap | Monorepo, CI, env, `AGENTS.md`, skema konten | `npm test` & `flutter test` hijau, app "hello" jalan | 1–2 hari |
| **M1** Auth | Register/login/refresh/logout, profil, wallet, starter deck | AC-01.*, AC-02.* lulus | 3–4 hari |
| **M2** Katalog | Sync GitHub, snapshot versi, endpoint katalog, cache Hive | AC-03.* lulus, offline OK | 3 hari |
| **M3** Gacha + Inventory | Roll server, pity, 10x, audit, UI flip 3D, koleksi | AC-04.*, AC-05.* lulus + uji distribusi | 5–6 hari |
| **M4** Deck | CRUD deck, validasi 2 sisi, UI builder | AC-06.* lulus | 3 hari |
| **M5** Battle + AI | Engine, 3 bot, arena UI, reward, statistik | AC-07.*, AC-08.*, AC-09.* lulus | 8–10 hari |
| **M6** Polish | 3D arena, audio, i18n, settings, aksesibilitas | NFR performa terpenuhi | 4–5 hari |
| **M7** Hardening & rilis | Load test, security review, store assets, beta | Checklist rilis §14 TECH_SPEC | 3–4 hari |

Total ≈ 30–37 hari kerja untuk 1 developer + agent AI.

---

## 12. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| GitHub/jsDelivr down atau rate limited | Katalog tidak update | Cache backend + snapshot DB + bundled asset + fallback raw URL |
| Aset 3D terlalu berat | FPS drop, ukuran app besar | GLB ≤ 2 MB, lazy download, LRU cache 3 model, fallback 2D |
| Gacha dirasa tidak adil | Churn, review buruk | Rate ditampilkan, pity terlihat, audit log, uji distribusi otomatis |
| Ekonomi inflasi/defisit | Progres terlalu cepat/lambat | Semua angka di config, telemetry faucet/sink, tuning mingguan |
| Bot Master terlalu kuat/lemah | Frustrasi | Simulasi 1.000 match di CI, target win-rate eksplisit |
| Cheat saldo/hasil match | Ekonomi rusak | Server-authoritative wallet & gacha, verifikasi hasil match, rate limit |
| Kebijakan store soal loot box | Penolakan rilis | Tanpa IAP di MVP, odds disclosure, rating sesuai (12+/Teen) |
| Scope creep (PvP, trading) | Tidak selesai | Non-goals §2.2 ditegakkan di review |

---

## 13. Keputusan Terbuka (butuh konfirmasi PO)

| # | Pertanyaan | Default bila tidak dijawab |
|---|---|---|
| Q-01 | Apakah butuh crafting duplikat → Dust di MVP? | **Tidak** (P1) |
| Q-02 | Reset harian pakai WIB atau UTC? | **WIB (UTC+7)** |
| Q-03 | Battle boleh dilanjutkan setelah app ditutup? | **Ya, suspend lokal**, tidak lintas device |
| Q-04 | Perlu akun tamu (guest) sebelum register? | **Dijawab 2026-11-03:** build default berjalan **offline tanpa login** (pemain lokal dibuat otomatis, progres disimpan di perangkat). Di mode ini gacha/saldo dihitung di perangkat, jadi invarian I-01/I-02 hanya berlaku untuk mode server (`OFFLINE=false`). |
| Q-05 | Nama repo/owner GitHub final? | `<owner>/<repo>`, dikonfigurasi via env |

---

## 14. Glosarium

| Istilah | Arti |
|---|---|
| **Pity** | Jaminan mendapat rarity minimal tertentu setelah N pull tanpa hasil tersebut |
| **Roll** | Proses RNG menentukan rarity lalu kartu |
| **Guard** | Stance bertahan: damage ×0,5 + counter |
| **Tapped** | Unit sudah memakai aksinya di turn ini |
| **Fatigue** | Damage meningkat saat deck habis |
| **Snapshot** | Salinan katalog immutable pada versi tertentu |
| **Idempotency key** | Kunci unik agar request yang sama tidak dobel efek |
| **Lookahead** | Bot mensimulasikan beberapa langkah ke depan |

---

## 15. Lampiran — Traceability

| FR | Milestone | Test wajib |
|---|---|---|
| FR-01/02 | M1 | Integration: register→login→refresh→me; unit: XP curve |
| FR-03 | M2 | Contract test skema katalog; chaos: JSON rusak |
| FR-04 | M3 | Chi-square 100k; pity boundary 49/50/51; idempotency |
| FR-05 | M3 | Widget test filter kombinasi; cache model |
| FR-06 | M4 | Unit: rules 20/3; server reject invalid; widget counter |
| FR-07 | M5 | Golden determinism; fuzz illegal actions; 50-match stat |
| FR-08 | M5 | Simulasi 1.000 match/level; perf budget |
| FR-09 | M5 | Double submit; daily reset |
| FR-10/11 | M6 | Widget a11y; event schema |

> Semua AC di dokumen ini adalah **kontrak**. Agent AI tidak boleh menandai task selesai bila AC terkait belum punya test.

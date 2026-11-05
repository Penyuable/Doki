# Dokimon TCG 3D

Game **turn-based TCG single-player (vs bot)** untuk Android & iOS.
Flutter (Dart) · Express.js + Prisma · **GitHub sebagai headless CMS** untuk kartu & aset 3D.

> Status repo: **dokumen, konten, backend, dan aplikasi Flutter selesai diimplementasikan.**
> Backend 56 test lulus; frontend `flutter analyze` bersih dan 42 test lulus; APK release sudah bisa dibangun.

---

## What's New — v1.0.0

**Rilis pertama** (`1.0.0+1`) — game lengkap dari onboarding sampai pertarungan vs bot,
bisa dimainkan **offline tanpa server** atau **online dengan akun**.

### Fitur utama

| Area | Yang tersedia di v1 |
|---|---|
| **Onboarding** | Splash animasi (kartu → monster → meja arena), tips loading, dan panduan **Cara Bermain** 5 langkah |
| **Akun** | Register, login, refresh token, logout; **mode offline** default tanpa login (data di perangkat) |
| **Katalog** | 25 kartu (5 elemen, unit & spell), fallback 3 lapis: memory → cache Hive → aset bundled |
| **Gacha** | Pull 1x/10x dengan Gold atau Gem, rate transparan, **pity Epic+ di pull ke-50**, jaminan 10x minimal Rare+, animasi reveal + riwayat pull |
| **Koleksi** | Filter elemen/rarity/tipe/kepemilikan, pencarian, detail kartu, dan **viewer kartu 3D** |
| **Deck** | Builder tepat 20 kartu, maks 3 copy per kartu, validasi server, maks 10 deck, kurva biaya |
| **Battle** | 3 tingkat bot (**Mudah / Sedang / Master**), engine Dart deterministik, jurus per elemen, status (burn/freeze/shield/rally), Guard + counter, log pertarungan |
| **Progresi** | HP 200, energi 1→10, reward Gold & XP, first-win bonus, level up, statistik win rate |
| **Hadiah harian** | Klaim harian + streak, batas reward harian |
| **Tampilan** | Ilustrasi kreatur kartun, 4 tema meja arena (Kayu, Hutan, Laut, Kosmik), efek partikel & getaran |
| **Pengaturan** | Bahasa **Indonesia/English**, kurangi animasi, hemat baterai, getaran, tema meja |
| **Build & CI** | APK release, workflow iOS unsigned (GitHub Actions + Codemagic) untuk IPA tanpa Mac |

### Catatan rilis

- **Audio belum tersedia** di v1 (menu Audio menampilkan status "Belum tersedia").
- Rilis iOS memakai build *unsigned*; distribusi TestFlight/App Store butuh Apple Developer Program.
- Placeholder `dokimon/dokimon` pada URL aset **wajib diganti** sebelum publikasi (lihat bagian Konten kartu).
- APK release masih ditandatangani debug keystore — cukup untuk sideload/internal.

---

## Dokumen

| Dokumen | Isi | Untuk siapa |
|---|---|---|
| [`docs/PRD.md`](docs/PRD.md) | Visi, fitur FR-01…FR-11, acceptance criteria, ekonomi, NFR, roadmap, risiko | PO / QA / agent |
| [`docs/TECH_SPEC.md`](docs/TECH_SPEC.md) | Struktur repo, skema DB, kontrak API, algoritma gacha, rumus battle, Bot AI, strategi test | Engineer |
| [`docs/AI_AGENT_GUIDE.md`](docs/AI_AGENT_GUIDE.md) | 15 prompt siap-tempel per fase + Definition of Done + anti-pattern | Kamu + AI agent |
| [`AGENTS.md`](AGENTS.md) | Aturan mengikat untuk agent (invarian, konvensi, larangan) | AI agent |
| [`content/cards/README.md`](content/cards/README.md) | Cara merilis kartu/aset lewat GitHub, rollback, kurva stat | Content designer |

**Baca berurutan:** `AGENTS.md` → `PRD.md` → `TECH_SPEC.md` → prompt fase terkait.

---

## Konten kartu (sudah siap)

`content/cards/cards.json` berisi **25 kartu** yang sudah lolos validasi skema:

| Rarity | Jumlah | Drop rate |
|---|---|---|
| Common | 9 | 60% |
| Uncommon | 6 | 25% |
| Rare | 5 | 10% |
| Epic | 3 | 4% |
| Legendary | 1 | 0.9% |
| Master | 1 | 0.1% |

5 elemen (Fire, Water, Earth, Air, Void), 2 tipe (`unit`, `spell`), 3 keyword (`charge`, `pierce`, `lifesteal`).

```bash
node scripts/build-catalog.mjs            # validasi + regenerate manifest.json
node scripts/build-catalog.mjs --check    # dipakai CI
```

Manifest saat ini: `catalogVersion 2026.11.01.1` · `sha256:1795e085…` · 25 kartu.

> **Ganti owner/repo sebelum rilis.** Semua `imageUrl`/`model3dUrl` dan `baseAssetUrl` memakai placeholder `dokimon/dokimon`.
> Ganti dengan `https://cdn.jsdelivr.net/gh/<owner>/<repo>@main/content/cards/...`, lalu jalankan ulang
> `node scripts/build-catalog.mjs --version <versi-baru>` agar checksum manifest ikut diperbarui.

---

## Angka kunci (satu sumber, jangan hardcode di UI)

| Parameter | Nilai |
|---|---|
| Deck | tepat 20 kartu, maks 3 copy per `cardId`, maks 10 deck/user |
| HP pemain | 200 |
| Board | 3 unit per sisi, hand maks 8, hand awal 4 |
| Energi | mulai 1, +1/turn, cap 10, refill penuh tiap turn |
| Damage | `max(1, round(ATK × elemMult − DEF × 0,5))`, Guard ×0,5 + counter 30% |
| Elemen | Fire → Air → Earth → Water → Fire (×1,25 / ×0,8), Void netral |
| Gacha | 100 Gold / 1 Gem; 10x = 900 Gold / 9 Gem |
| Pity | Epic+ dijamin pada pull ke-50 sejak Epic+ terakhir |
| Reward menang | 40 / 80 / 150 Gold (Easy/Medium/Master) + first win 200 Gold |
| Starter | 1.000 Gold, 50 Gems, deck 20 kartu |

Semua angka ada di `backend/src/config/economy.ts` + `frontend/lib/core/config/game_config.dart` — PRD §8 dan TECH_SPEC §6/§8 adalah rujukan nilainya.

---

## Arsitektur singkat

```
Flutter ──HTTPS/JWT──► Express API ──fetch 15 mnt──► GitHub (content/cards)
   │                        │
   ├─ Hive cache            └─ Prisma (SQLite dev / Postgres prod)
   └─ Battle engine (pure Dart) + Bot AI (client-side, hasil diverifikasi server)
```

- **Gacha & wallet di server** (tidak bisa di-cheat).
- **Battle di client** (offline-friendly, deterministik) + verifikasi hasil di server.
- **Katalog 3 lapis fallback**: memory → Hive → aset bundled.

---

## Quick start

```bash
# 1. Backend
cd backend
cp .env.example .env          # isi secret (dev: sudah tersedia .env)
npm install
npx prisma db push            # buat SQLite dev.db
npm run dev                   # http://localhost:8080/healthz
npm run db:seed               # opsional: akun demo@dokimon.app / DemoPass123

# 2. Frontend
cd frontend
flutter pub get
flutter analyze && flutter test

# Default: mode OFFLINE tanpa login & tanpa backend (data di perangkat)
flutter run

# Mode server (login + backend). Emulator Android (10.0.2.2 = localhost host)
flutter run --dart-define=OFFLINE=false --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1

# Device fisik: ganti dengan IP LAN mesin backend
flutter run --dart-define=OFFLINE=false --dart-define=API_BASE_URL=http://192.168.1.14:8080/api/v1
```

> Perintah `flutter`/`dart` di mesin ini ada di `C:\flutter\bin` (belum masuk PATH).
> Gunakan `C:\flutter\bin\flutter.bat ...`.

### Ikon aplikasi

Ikon Android (legacy + adaptive) dan iOS digambar dari kode (tile clay + kreatur),
sama dengan logo di aplikasi. Setelah mengubah logo/kreatur, generate ulang:

```bash
cd frontend
flutter test tool/generate_app_icon_test.dart
```

### Karakter kreatur

Karakter kartu adalah chibi yang **digambar dengan kode** (`frontend/lib/core/ui/creature_avatar.dart`):
13 spesies (dipilih dari nama kartu), gaya cel-shading + garis luar, tanpa aset gambar.
Semua kreatur memakai satu jam animasi bersama (`CreatureClock`, ±30 fps) yang hanya
berjalan selama ada kreatur di layar, dan berhenti total bila "Kurangi animasi" aktif.

### Unduh aplikasi iOS (.ipa)

**[⬇️ Unduh dokimon-unsigned.ipa](https://github.com/Penyuable/Doki/releases/download/ios-latest/dokimon-unsigned.ipa)**
· [halaman release](https://github.com/Penyuable/Doki/releases/tag/ios-latest)

File ini diperbarui otomatis oleh GitHub Actions setiap ada push ke `main` yang mengubah `frontend/`.
IPA **belum ditandatangani**: pasang ke iPhone dari Windows/Mac dengan **Sideloadly** atau **AltStore**
memakai Apple ID (Apple ID gratis: app harus ditandatangani ulang tiap 7 hari).

### Build iOS

iOS **tidak bisa** di-build dari Windows — butuh macOS + Xcode. Dua jalur:

1. **Codemagic (tanpa Mac, direkomendasikan):** konfigurasi ada di `codemagic.yaml`
   (root repo), berisi workflow `ios-unsigned` (IPA) dan `android-release` (APK & AAB).
   Penyiapan sekali saja:
   - Masuk ke https://codemagic.io dengan akun GitHub.
   - *Add application* → pilih repo `Penyuable/Doki` → tipe **Flutter App (via codemagic.yaml)**.
   - *Start new build* → pilih branch dan workflow `ios-unsigned`.
   - Setelah selesai, unduh `dokimon-unsigned.ipa` dari halaman build (*Artifacts*).
   Build berikutnya berjalan otomatis setiap push ke `main` atau `feat/*`.
2. **GitHub Actions (tanpa Mac):** workflow `.github/workflows/ios-build.yml` berjalan
   otomatis saat push ke `main` (atau manual lewat tab *Actions → iOS build → Run workflow*).
   Hasilnya artifact `dokimon-ios-unsigned` berisi `dokimon-unsigned.ipa`; build dari `main`
   juga diterbitkan ke release `ios-latest` (link unduhan di atas).
3. **Mac + Xcode:**

```bash
cd frontend
flutter build ios --release
# atau buka ios/Runner.xcworkspace di Xcode, pilih Team, lalu Run ke iPhone
```

Distribusi ke banyak pengguna (TestFlight/App Store) butuh Apple Developer Program.
Aplikasi dikunci ke orientasi portrait; ikon iOS dihasilkan tanpa kanal alpha
(syarat App Store) oleh `tool/generate_app_icon_test.dart`.

### Build APK release

```bash
cd frontend
# Offline tanpa login (default) — langsung bisa dimainkan tanpa server
flutter build apk --release

# Mode server + login
flutter build apk --release --dart-define=OFFLINE=false \
  --dart-define=API_BASE_URL=http://192.168.1.14:8080/api/v1

# hasil: frontend/build/app/outputs/flutter-apk/app-release.apk
```

APK release ditandatangani dengan debug keystore (cukup untuk sideload/internal).
Ganti `signingConfig` di `android/app/build.gradle.kts` sebelum publikasi ke Play Store.
Manifest utama sudah memuat `INTERNET` dan `usesCleartextTraffic="true"` agar bisa
menghubungi backend HTTP lokal; hapus cleartext bila backend sudah HTTPS.

> `pubspec.yaml` mem-pin `path_provider_android: 2.2.17` lewat `dependency_overrides`.
> Versi 2.3.x menarik plugin `jni` yang mewajibkan NDK/CMake; build APK tetap jalan
> tanpa NDK dengan versi 2.2.x. Hapus override bila toolchain NDK sudah lengkap.

---

## Cara memakai AI agent di repo ini

1. Buka repo di agent (Cursor / Claude Code / OpenCode).
2. Minta agent membaca `AGENTS.md`, `docs/PRD.md`, `docs/TECH_SPEC.md`.
3. Salin **satu** prompt fase dari `docs/AI_AGENT_GUIDE.md §3`, jangan gabung fase.
4. Review hasil dengan prompt review (`§5.1`) sebelum merge.
5. Jangan lanjut fase bila AC fase sebelumnya masih merah.

---

## Lisensi & aset

Kode: tentukan lisensi sebelum publikasi.
Aset (gambar/model 3D) **belum disertakan** — `content/cards/images/` dan `models/` masih kosong. Gunakan aset milik sendiri atau berlisensi jelas; URL placeholder di `cards.json` harus diganti sebelum rilis.

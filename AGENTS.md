# AGENTS.md — Aturan Wajib untuk AI Coding Agent

Repo: **Dokimon TCG 3D** (Flutter + Express.js + GitHub CMS, PvE vs bot).
Sebelum menulis kode, baca berurutan:

1. `docs/PRD.md` — perilaku produk & acceptance criteria (AC) yang mengikat.
2. `docs/TECH_SPEC.md` — kontrak API, DB, rumus battle, algoritma gacha.
3. `docs/AI_AGENT_GUIDE.md` — prompt per fase + Definition of Done.

Bila dokumen bertentangan: **PRD menang untuk perilaku**, **TECH_SPEC menang untuk implementasi**, **AC menang atas keduanya**. Bila masih ambigu: tulis pertanyaan di `docs/OPEN_QUESTIONS.md` dan **jangan menebak** aturan bisnis.

---

## 1. Peta repo

```
content/cards/        # CMS: cards.json + manifest.json + schema.json + aset
scripts/              # build-catalog.mjs (validasi + checksum)
backend/              # Express + TypeScript + Prisma (belum di-scaffold)
frontend/             # Flutter (belum di-scaffold)
docs/                 # PRD, TECH_SPEC, AI_AGENT_GUIDE
```

## 2. Perintah standar (target setelah P0)

```bash
# konten
node scripts/build-catalog.mjs            # validasi + tulis manifest
node scripts/build-catalog.mjs --check    # CI: pastikan manifest sinkron

# backend
cd backend && npm run dev                 # http://localhost:8080
npm run typecheck && npm run lint && npm test

# frontend
cd frontend && flutter analyze && flutter test
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
```

Jangan menambah script baru tanpa mendokumentasikannya di README.

---

## 3. Invarian yang tidak boleh dilanggar

| # | Invarian | Konsekuensi bila dilanggar |
|---|---|---|
| I-01 | Roll gacha **hanya** di server. Client tidak pernah menentukan rarity. | Ekonomi bisa di-cheat |
| I-02 | Saldo, XP, inventory, pity **hanya** diubah server, selalu dalam transaksi DB. | Saldo negatif / duplikasi reward |
| I-03 | Deck: tepat 20 kartu, maks 3 per `cardId`, hanya kartu dimiliki, hanya `unit`/`spell`. Validasi server otoritatif. | Deck ilegal masuk battle |
| I-04 | Battle engine **pure Dart**: tanpa `flutter`, tanpa I/O, tanpa `DateTime.now()`, RNG dari `seed`. | Tidak bisa dites, replay tidak deterministik |
| I-05 | UI **tidak** menghitung damage/state sendiri; baca dari `BattleEvent`/engine. | Angka berbeda antar layar |
| I-06 | Rate & harga diambil dari config/server, tidak hardcode di widget. | UI tidak sinkron dengan server |
| I-07 | `content/cards/*` adalah kontrak; ubah schema = ubah `schema.json` + `TECH_SPEC §7.1` + PRD bila perlu. | Snapshot ditolak / app crash |
| I-08 | Jangan mengubah `id` kartu lama; gunakan `retired: true`. | Inventory pemain yatim |
| I-09 | Tidak ada secret di bundle Flutter. Token hanya di `flutter_secure_storage`. | Kebocoran kredensial |
| I-10 | Bot melihat state publik saja (`BattleView`), tidak boleh membaca deck lawan. | Bot curang, tidak fair |

---

## 4. Konvensi kode

**Umum**
- Bahasa komentar & commit: Indonesia boleh, identifier & API bahasa Inggris.
- Tidak ada `print`, `console.log`, `debugger`, `TODO` tanpa penanda fase (`// TODO(P11): ...`).
- Tidak ada `catch (_) {}` kosong — log + state error + pesan user.
- Satu PR = satu fase/scope. Jangan campur refactor besar dengan fitur.

**Backend (TypeScript)**
- ESM, `strict: true`, `noUncheckedIndexedAccess`.
- Validasi semua input dengan Zod (`strict()`), error lewat `AppError` + kode kanonik `TECH_SPEC §3.3`.
- Route tipis → service → Prisma. Jangan query DB dari controller.
- Response selalu envelope `{data}` / `{error}`, JANGAN mengembalikan array telanjang.
- Uang = integer. Tidak ada float untuk gold/gem.

**Frontend (Dart/Flutter)**
- `flutter_bloc` (Cubit) + state `sealed class`. Tidak ada `BuildContext` di Cubit.
- `domain` tidak boleh impor `data`/`presentation`; entity domain dipisah dari DTO.
- Parsing JSON defensif: jangan `!` untuk field dari network.
- Semua teks UI lewat l10n (`id` default + `en`). Tidak ada string hardcode.
- Widget besar dipecah; pakai `const` dan `RepaintBoundary` di area animasi.
- Nama file `snake_case.dart`, kelas `PascalCase`.

**Konten (`content/cards`)**
- Jalankan `node scripts/build-catalog.mjs` setiap mengubah `cards.json`.
- Aset: `images/<id>.webp` (512×768, ≤120KB), `models/<id>.glb` (≤2MB).
- Jangan edit `manifest.json` manual.

---

## 5. Strategi test minimum

| Area | Wajib |
|---|---|
| `gacha.math` | boundary bobot, pity 48/49/50, 10x guarantee, chi-square 100k (tag slow) |
| `deck.rules` | 20 kartu, maks 3 copy, kartu tidak dimiliki, tipe salah |
| Auth | register/login/refresh rotation/reuse detection |
| Battle engine | 14 edge case `E-01..E-14` + golden seed + fuzz legal actions |
| Bot AI | 3 level, selalu aksi legal, p95 < 300 ms, simulasi win-rate |
| UI | widget test state transitions + filter deck/collection |
| Konten | `build-catalog.mjs --check` lulus di CI |

Coverage minimum: `battle/domain` dan `gacha/math` **90%**.

---

## 6. Definition of Done (tidak bisa dinegosiasikan)

Sebuah task **belum selesai** bila:
- [ ] AC terkait di PRD belum punya test yang lulus.
- [ ] `flutter analyze` / `tsc --noEmit` masih error.
- [ ] Error path belum ditangani (hanya happy path).
- [ ] String UI hardcode / belum masuk l10n.
- [ ] Kontrak berubah tapi `PRD.md` / `TECH_SPEC.md` belum diperbarui.
- [ ] Ada perilaku baru tanpa test yang menyebut AC-nya.

**Laporan akhir wajib** (format di `AI_AGENT_GUIDE.md §4`): ringkasan, file created/modified, AC yang dipenuhi + bukti, perintah verifikasi + hasil, risiko, dan yang belum dikerjakan.

---

## 7. Yang dilarang tanpa persetujuan eksplisit

- Mengubah drop rate, pity, harga gacha, atau reward (menyentuh ekonomi).
- Mengubah rumus damage atau urutan fase battle.
- Menambah dependency berat baru (state management, DB, 3D engine).
- Menghapus/mengganti file yang bukan buatanmu tanpa investigasi.
- Menjalankan `git push --force`, menghapus branch, atau reset hard pada kerja orang lain.
- Commit `.env`, token, atau kredensial apa pun.
- Menandai fitur "selesai" dengan test di-skip.

---

## 8. Format commit

```
<tipe>(<scope>): <ringkasan imperatif>

<opsional: alasan / AC yang dipenuhi>
```
Tipe: `feat`, `fix`, `refactor`, `test`, `docs`, `chore`, `content`.
Contoh: `feat(gacha): server-side pull dengan pity 50 (AC-04.3)`

---

## 9. Urutan kerja yang disarankan

P0 bootstrap → P1 auth → P2 catalog → P3 gacha → P4 deck → P5 battle API
(paralel: P10 battle engine → P11 bot) → P6–P9 UI → P12 arena → P13 polish → P14 rilis.

Detail prompt tiap fase ada di `docs/AI_AGENT_GUIDE.md §3`. Jangan lompat fase kecuali diminta.

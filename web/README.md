# Dokimon Web (Next.js)

Versi web Dokimon TCG — port dari aplikasi Flutter di [`../frontend`](../frontend).
Fitur, aturan battle, ekonomi, dan kontrak API sama; Flutter tetap klien mobile.

## Menjalankan

Butuh Node.js ≥ 22.18 (test memakai TypeScript native di Node).

```bash
cd web
npm install
npm run dev            # http://localhost:3000 — mode OFFLINE (default)
```

Mode server (login + Express API):

```bash
# terminal 1 — backend (lihat ../backend/README.md)
cd backend && npm run dev                      # http://localhost:8080

# terminal 2 — web
cd web
cp .env.example .env.local                     # lalu set NEXT_PUBLIC_OFFLINE=false
npm run dev
```

Origin web harus terdaftar di `CORS_ORIGINS` backend (default sudah memuat `http://localhost:3000`).

## Script

| Perintah | Fungsi |
|---|---|
| `npm run dev` | Dev server di port 3000 |
| `npm run build` | Static export ke `out/` (bisa di-host di CDN / GitHub Pages / Netlify) |
| `npm start` | Menyajikan `out/` secara lokal di port 3000 |
| `npm run typecheck` | `tsc --noEmit` |
| `npm test` | `node --test` — engine, bot, backend lokal, API client, logika UI |
| `npm run catalog:sync` | Salin `content/cards/cards.json` → `src/data/cards.seed.json` |
| `npm run catalog:check` | CI: gagal bila salinan katalog tidak sinkron |

Setelah mengubah `content/cards/cards.json`, jalankan `node scripts/build-catalog.mjs` (root) **dan** `npm run catalog:sync` (web).

## Struktur

```
src/
├── app/                 # rute: / collection deck gacha battle arena profile settings login
├── components/          # UI clay, kreatur SVG, arena, gacha reveal
├── data/cards.seed.json # katalog bundled (fallback terakhir)
└── lib/                 # pure TypeScript — bisa dites tanpa browser
    ├── battle/          # engine.ts, bot-ai.ts, session.ts (port Dart)
    ├── core/            # dart-random.ts, canonical-json.ts, sha256.ts, json.ts
    ├── data/            # api-client.ts, local-backend.ts, repositories.ts
    ├── domain/          # card.ts, deck-rules.ts, models.ts
    ├── i18n/            # base-strings.ts (dihasilkan dari app_strings.dart) + web-strings.ts
    └── ui/              # logika presentasi: filter koleksi, deck builder, petunjuk arena
```

## Paritas dengan Flutter

- `DartRandom` adalah port bit-per-bit `math.Random` Dart VM, jadi seed yang sama menghasilkan
  urutan kartu, giliran pertama, dan keputusan bot yang sama.
- `test/battle-golden.test.ts` menjalankan 15 pertandingan bot-vs-bot penuh dan membandingkan
  `logHash` dengan angka yang dihasilkan engine Dart. Ubah engine/bot = ubah Dart & TS bersamaan.
- Teks UI diambil dari `frontend/lib/core/i18n/app_strings.dart` (id/en). Bila tabel Dart berubah,
  regenerasi `src/lib/i18n/base-strings.ts`.

Detail arsitektur: [TECH_SPEC §16](../docs/TECH_SPEC.md#16-web-client-nextjs).

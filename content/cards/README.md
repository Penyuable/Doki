# GitHub sebagai Headless CMS — Konten Kartu

Folder ini adalah **satu-satunya sumber kebenaran** untuk data kartu. Aplikasi tidak perlu dirilis ulang saat konten berubah: backend menyinkronkan file di sini setiap 15 menit (atau dipicu manual).

```
content/cards/
├── cards.json      # data semua kartu (array CardModel)
├── manifest.json   # metadata + checksum (DIBUAT OTOMATIS, jangan edit manual)
├── schema.json     # JSON Schema — kontrak validasi
├── images/         # <id>.webp (512×768) + <id>_thumb.webp (256×384)
└── models/         # <id>.glb  (≤ 2 MB, ≤ 8k tris)
```

> Folder `images/` dan `models/` belum berisi aset. Nama file **wajib** sama dengan `id` kartu. Sampai aset tersedia, gunakan URL placeholder apa pun yang `https://` — aplikasi akan fallback ke gambar statis/thumbnail bila model gagal dimuat.

---

## 1. Alur rilis konten (5 menit)

1. **Edit `cards.json`** — tambah kartu baru di akhir array. **Jangan pernah** mengubah `id` kartu yang sudah ada (inventory pemain mereferensikan `id`). Untuk "menghapus" kartu, set `"retired": true` dan `"obtainable": false`.
2. **Upload aset**
   - `images/card_xxx.webp` — 512×768, ≤ 120 KB, WebP kualitas 80.
   - `images/card_xxx_thumb.webp` — 256×384, ≤ 40 KB.
   - `models/card_xxx.glb` — ≤ 2 MB, ≤ 8.000 triangle, 1 material, tekstur ≤ 1024².
3. **Validasi + generate manifest**
   ```bash
   node scripts/build-catalog.mjs            # validasi, tulis manifest.json
   # atau dengan versi eksplisit:
   node scripts/build-catalog.mjs --version 2026.11.15.1
   ```
   Script akan gagal (exit 1) bila ada field salah, `id` duplikat, URL bukan `https`, atau stat di luar rentang.
4. **Commit & push** `cards.json`, `manifest.json`, dan aset ke `main`.
5. **Tunggu propagasi** (≤ 15 menit) atau paksa sinkron:
   ```bash
   curl -X POST https://<api-host>/api/v1/internal/catalog/sync \
        -H "X-Admin-Token: $ADMIN_TOKEN"
   ```
6. **Verifikasi**
   ```bash
   curl -s https://<api-host>/api/v1/catalog/manifest
   # → catalogVersion harus versi baru
   ```

---

## 2. Urutan validasi backend (tidak bisa dilewati)

```
fetch manifest → fetch cards.json → cek sha256 vs manifest → validasi schema.json
→ cek aturan bisnis (id unik, ≥1 kartu per rarity) → upsert CatalogVersion → aktifkan
```
Bila salah satu gagal → **snapshot lama tetap dipakai**, error dicatat, game tetap jalan.

---

## 3. Aturan konten

| Aturan | Nilai |
|---|---|
| Format `id` | `card_[a-z0-9_]{3,32}` (contoh `card_001`, `card_fire_drake`) |
| Jumlah kartu per rarity | minimal 1 (agar gacha tidak fallback terus) |
| `cost` | 0–10 (energi summon/play) |
| `ability.cost` | 0–10 (energi aktivasi; 0 = hanya memakai aksi unit) |
| Durasi status | 1–3 turn |
| `model3dUrl` | boleh `null` → UI fallback ke gambar |
| `version` | naikkan 1 setiap kali kartu diubah |
| `retired` | `true` = tidak masuk pool gacha, tetap tampil di koleksi pemilik |

### Kurva stat (panduan balancing)

| Cost | ATK | HP | DEF | Peran |
|---|---|---|---|---|
| 0–1 | 18–25 | 55–70 | 5–15 | Tempo awal, trade murah |
| 2 | 26–32 | 75–90 | 10–20 | Isi kurva |
| 3 | 32–45 | 95–120 | 15–30 | Value / utilitas |
| 4 | 40–55 | 120–150 | 20–40 | Ancaman utama |
| 5 | 45–60 | 140–160 | 25–45 | Finisher |
| 6 | 55–75 | 170–190 | 35–55 | Bomb, harus dijawab |

Damage dihitung `max(1, round(ATK × elemMult − DEF × 0,5))` — DEF 40 memotong 20 damage. Naikkan DEF hanya bila kartu memang bertema defensif (Guard/counter).

---

## 4. Rollback

```bash
git revert <commit-yang-merusak-konten>
node scripts/build-catalog.mjs --version <versi-lama>
git push
```
Backend akan memakai snapshot versi lama lagi. **Jangan** rollback dengan menghapus kartu — inventory pemain bisa yatim.

---

## 5. Yang dilarang

- ❌ Mengedit `manifest.json` manual (checksum akan mismatch → snapshot ditolak).
- ❌ Mengubah `id` atau `name` kartu yang sudah dimiliki pemain tanpa migrasi.
- ❌ Menaruh URL non-`https` (mixed content diblokir WebView 3D).
- ❌ Menambah field baru tanpa memperbarui `schema.json` + `docs/TECH_SPEC.md` §7.1.
- ❌ Menaruh model > 2 MB (memori & waktu unduh membengkak).
- ❌ Menaruh data sensitif (token, email) di repo ini — repo bersifat publik.

---

## 6. Menambah rarity baru? Jangan.

Enam tier (Common → Master) adalah kontrak dengan drop rate, UI, dan pity. Menambah tier memerlukan perubahan PRD, backend, dan klien sekaligus.

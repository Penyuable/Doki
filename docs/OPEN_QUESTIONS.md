# Open Questions

Catatan ambiguitas yang ditemukan saat implementasi. **Jangan menebak aturan bisnis** — tambahkan baris di sini, pilih default di PRD §13 bila ada, dan lanjutkan hanya bagian yang tidak terblokir.

| # | Tanggal | Fase | Pertanyaan | Dampak bila salah | Usulan / default | Status |
|---|---|---|---|---|---|---|
| Q-01 | 2026-11-01 | – | Crafting duplikat → Dust masuk MVP? | Ekonomi & UI inventory | Tidak (P1) | menunggu PO |
| Q-02 | 2026-11-01 | P1 | Reset harian WIB atau UTC? | Reward & streak | WIB (UTC+7) | asumsi dipakai |
| Q-03 | 2026-11-01 | P12 | Battle boleh resume setelah app ditutup? | UX & penyimpanan | Ya, suspend lokal (tidak lintas device) | asumsi dipakai |
| Q-04 | 2026-11-01 | P1 | Guest account sebelum register? | Funnel onboarding | Tidak | dijawab (2026-11-03): build default = **mode offline tanpa login** (pemain lokal otomatis, data di perangkat). Mode server + login tetap ada via `--dart-define=OFFLINE=false`. |
| Q-05 | 2026-11-01 | P2 | Owner/repo GitHub final? | `baseAssetUrl`, CORS aset | Isi via env saat setup | terbuka |
| Q-06 | 2026-11-04 | P13 | Karakter kartu 3D (model_viewer) atau ilustrasi? | FR-05 AC-05.3, ukuran app | — | dijawab (2026-11-04): PO meminta karakter **kartun 2D**, bukan 3D. Tombol "Putar 3D" disembunyikan; `CardViewer3DPage` tetap ada tapi tidak ditautkan. Update 2026-11-05: karakter berupa chibi gambar-kode (cel-shading), tanpa aset ilustrasi. |

**Cara menutup pertanyaan:** ubah Status menjadi `dijawab (tanggal)` + ringkasan keputusan, lalu perbarui PRD/TECH_SPEC di PR yang sama.

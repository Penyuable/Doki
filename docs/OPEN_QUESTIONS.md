# Open Questions

Catatan ambiguitas yang ditemukan saat implementasi. **Jangan menebak aturan bisnis** — tambahkan baris di sini, pilih default di PRD §13 bila ada, dan lanjutkan hanya bagian yang tidak terblokir.

| # | Tanggal | Fase | Pertanyaan | Dampak bila salah | Usulan / default | Status |
|---|---|---|---|---|---|---|
| Q-01 | 2026-11-01 | – | Crafting duplikat → Dust masuk MVP? | Ekonomi & UI inventory | Tidak (P1) | menunggu PO |
| Q-02 | 2026-11-01 | P1 | Reset harian WIB atau UTC? | Reward & streak | WIB (UTC+7) | asumsi dipakai |
| Q-03 | 2026-11-01 | P12 | Battle boleh resume setelah app ditutup? | UX & penyimpanan | Ya, suspend lokal (tidak lintas device) | asumsi dipakai |
| Q-04 | 2026-11-01 | P1 | Guest account sebelum register? | Funnel onboarding | Tidak | asumsi dipakai |
| Q-05 | 2026-11-01 | P2 | Owner/repo GitHub final? | `baseAssetUrl`, CORS aset | Isi via env saat setup | terbuka |

**Cara menutup pertanyaan:** ubah Status menjadi `dijawab (tanggal)` + ringkasan keputusan, lalu perbarui PRD/TECH_SPEC di PR yang sama.

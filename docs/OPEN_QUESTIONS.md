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

| Q-07 | 2026-11-06 | Web | Token sesi web disimpan di mana? Browser tidak punya padanan `flutter_secure_storage`. | Refresh token bisa dicuri lewat XSS | Sementara `localStorage` (TECH_SPEC §16.5). Lebih aman: refresh token di cookie `HttpOnly; Secure; SameSite` — butuh perubahan backend (`/auth/*` set-cookie + CSRF). | terbuka |
| Q-08 | 2026-11-06 | Web | Bot **Master** mensimulasikan giliran lawan dengan `engine.apply` pada salinan state penuh (termasuk hand/deck pemain). Apakah ini melanggar I-10? | Fairness bot | Perilaku identik dengan `bot_ai.dart` dan diport apa adanya; Easy/Medium terbukti tidak terpengaruh hand/deck pemain (test). Bila ingin ketat: simulasi Master memakai hand lawan yang disamarkan — ubah Dart & TS bersamaan (golden test ikut berubah). | terbuka |
| Q-09 | 2026-11-06 | Web | Pesan log `ability_damage` target `enemy_player` di Dart memakai `$ability.power` → tercetak `Instance of 'CardAbility'.power`. | Teks log aneh di UI (belum ada kartu yang memicunya) | Web meniru teks persis demi paritas `logHash`. Perbaikan (`${ability.power}`) harus dilakukan di Dart & TS dalam satu PR. | terbuka |

**Cara menutup pertanyaan:** ubah Status menjadi `dijawab (tanggal)` + ringkasan keputusan, lalu perbarui PRD/TECH_SPEC di PR yang sama.

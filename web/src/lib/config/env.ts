/**
 * Konfigurasi build/run (setara `frontend/lib/core/config/env.dart`).
 * Hanya NEXT_PUBLIC_* yang sampai ke browser — tidak ada secret di sini (I-09).
 */
export const Env = {
  apiBaseUrl: (process.env.NEXT_PUBLIC_API_BASE_URL ?? 'http://localhost:8080/api/v1').replace(/\/+$/, ''),
  /** Default aktif: tanpa login & tanpa server, data di localStorage. */
  offlineMode: (process.env.NEXT_PUBLIC_OFFLINE ?? 'true').toLowerCase() !== 'false',
  catalogRefreshIntervalMs: 15 * 60 * 1000,
  appVersion: '1.0.0',
  engineVersion: '1.0.0',
} as const;

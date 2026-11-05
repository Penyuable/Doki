/**
 * Komposisi layanan di browser (setara `app_scope.dart` + `main.dart`):
 * storage → (LocalBackend | fetch) → ApiClient → repositori.
 */
import bundledCatalog from '../../data/cards.seed.json';
import { asMap } from '../core/json.ts';
import { Env } from '../config/env.ts';
import { ApiClient, fetchTransport, localTransport } from '../data/api-client.ts';
import { LocalBackend } from '../data/local-backend.ts';
import { createRepositories, type Repositories } from '../data/repositories.ts';
import { createSafeStore, createTokenStore, type SafeStore } from './storage.ts';

export type Services = {
  offline: boolean;
  store: SafeStore;
  api: ApiClient;
  repos: Repositories;
  backend: LocalBackend | null;
};

let instance: Services | null = null;

export function getServices(): Services {
  if (instance) return instance;
  const store = createSafeStore();
  const offline = Env.offlineMode;
  const catalog = (bundledCatalog as unknown[]).map(asMap);
  const backend = offline ? new LocalBackend({ catalog, store }) : null;
  const api = new ApiClient({
    transport: backend ? localTransport(backend) : fetchTransport(Env.apiBaseUrl),
    tokens: createTokenStore(store),
  });
  instance = { offline, store, api, backend, repos: createRepositories(api, store, bundledCatalog) };
  return instance;
}

/** Membuat id idempotensi (setara `Uuid().v4()`). */
export function newIdempotencyKey(): string {
  const webCrypto: Crypto = globalThis.crypto;
  if (typeof webCrypto.randomUUID === 'function') return webCrypto.randomUUID();
  // randomUUID hanya ada di konteks aman (HTTPS/localhost); akses via IP LAN memakai fallback.
  const bytes = new Uint8Array(16);
  webCrypto.getRandomValues(bytes);
  return [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('');
}

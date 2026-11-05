/**
 * Satu pintu HTTP ke backend (port `core/network/api_client.dart`):
 * token, refresh single-flight, dan envelope `{data}` / `{error}`.
 *
 * Transport bisa ditukar: `fetchTransport` (Express API) atau
 * `localTransport` (LocalBackend, mode offline) — bentuk respons sama.
 */
import { asMap, asString, type JsonMap } from '../core/json.ts';
import { LocalApiError, type LocalBackend } from './local-backend.ts';

export class ApiError extends Error {
  readonly code: string;
  readonly status: number | null;
  readonly details: unknown;

  constructor(code: string, message: string, status: number | null = null, details?: unknown) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.status = status;
    this.details = details;
  }

  get isAuthExpired(): boolean {
    return this.status === 401 || this.code === 'TOKEN_EXPIRED' || this.code === 'UNAUTHORIZED';
  }

  get isNetwork(): boolean {
    return this.code === 'NETWORK_ERROR';
  }

  get isInsufficientFunds(): boolean {
    return this.code === 'INSUFFICIENT_FUNDS';
  }
}

export function fallbackMessage(status: number | null): string {
  if (status === null) return 'Terjadi kesalahan.';
  if (status >= 500) return 'Server sedang bermasalah. Coba lagi.';
  if (status === 401) return 'Sesi berakhir. Silakan masuk kembali.';
  if (status === 403) return 'Akses ditolak.';
  if (status === 404) return 'Data tidak ditemukan.';
  if (status === 429) return 'Terlalu banyak permintaan. Tunggu sebentar.';
  return `Permintaan gagal (HTTP ${status}).`;
}

export type TransportRequest = {
  method: string;
  path: string;
  body?: JsonMap;
  query?: Record<string, string>;
  headers: Record<string, string>;
};

export type TransportResponse = { status: number; json: unknown };

/** Melempar `ApiError('NETWORK_ERROR')` bila server tidak terjangkau. */
export type Transport = (request: TransportRequest) => Promise<TransportResponse>;

export function fetchTransport(baseUrl: string, timeoutMs = 25_000): Transport {
  return async (request) => {
    const url = new URL(`${baseUrl}${request.path}`);
    for (const [key, value] of Object.entries(request.query ?? {})) url.searchParams.set(key, value);
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    let response: Response;
    try {
      response = await fetch(url, {
        method: request.method,
        headers: {
          Accept: 'application/json',
          ...(request.body !== undefined ? { 'Content-Type': 'application/json' } : {}),
          ...request.headers,
        },
        body: request.body !== undefined ? JSON.stringify(request.body) : undefined,
        signal: controller.signal,
      });
    } catch {
      throw new ApiError('NETWORK_ERROR', 'Tidak dapat terhubung ke server. Periksa koneksi internet.');
    } finally {
      clearTimeout(timer);
    }
    let json: unknown = null;
    const text = await response.text();
    if (text.length > 0) {
      try {
        json = JSON.parse(text);
      } catch {
        json = null;
      }
    }
    return { status: response.status, json };
  };
}

/** Transport offline: request dilayani LocalBackend, dibungkus envelope seperti server. */
export function localTransport(backend: LocalBackend): Transport {
  return async (request) => {
    try {
      const data = await backend.handle(request.method, request.path, request.body ?? {}, request.query ?? {});
      return { status: 200, json: { data } };
    } catch (error) {
      if (error instanceof LocalApiError) return { status: error.status, json: error.toJson() };
      return {
        status: 500,
        json: { error: { code: 'INTERNAL_ERROR', message: error instanceof Error ? error.message : 'Kesalahan lokal' } },
      };
    }
  };
}

export type SessionTokens = { accessToken: string; refreshToken: string };

/** Penyimpanan token (I-09: tidak pernah di bundle; lihat TECH_SPEC §12 untuk catatan web). */
export interface TokenStore {
  read(): SessionTokens | null;
  save(tokens: SessionTokens): void;
  clear(): void;
}

export const memoryTokenStore = (): TokenStore => {
  let tokens: SessionTokens | null = null;
  return {
    read: () => tokens,
    save: (next) => {
      tokens = next;
    },
    clear: () => {
      tokens = null;
    },
  };
};

type RefreshOutcome = 'success' | 'invalid' | 'network';

export class ApiClient {
  private readonly transport: Transport;
  private readonly tokens: TokenStore;
  private accessToken: string | null = null;
  private refreshToken: string | null = null;
  private refreshing: Promise<RefreshOutcome> | null = null;

  /** Dipanggil ketika refresh token ditolak server (sesi benar-benar habis). */
  onSessionExpired: (() => void) | null = null;

  constructor(options: { transport: Transport; tokens: TokenStore }) {
    this.transport = options.transport;
    this.tokens = options.tokens;
    const stored = this.tokens.read();
    this.accessToken = stored?.accessToken ?? null;
    this.refreshToken = stored?.refreshToken ?? null;
  }

  get hasSession(): boolean {
    return !!this.refreshToken;
  }

  get currentRefreshToken(): string {
    return this.refreshToken ?? '';
  }

  applySession(tokens: SessionTokens): void {
    this.accessToken = tokens.accessToken;
    this.refreshToken = tokens.refreshToken;
    this.tokens.save(tokens);
  }

  clearSession(): void {
    this.accessToken = null;
    this.refreshToken = null;
    this.tokens.clear();
  }

  get(path: string, options: { query?: Record<string, string | number | undefined>; auth?: boolean } = {}) {
    return this.request('GET', path, { query: options.query, auth: options.auth });
  }

  post(path: string, options: { body?: JsonMap; auth?: boolean } = {}) {
    return this.request('POST', path, { body: options.body ?? {}, auth: options.auth });
  }

  patch(path: string, body: JsonMap) {
    return this.request('PATCH', path, { body });
  }

  put(path: string, body: JsonMap = {}) {
    return this.request('PUT', path, { body });
  }

  async delete(path: string): Promise<void> {
    await this.request('DELETE', path, {});
  }

  async request(
    method: string,
    path: string,
    options: { body?: JsonMap; query?: Record<string, string | number | undefined>; auth?: boolean },
  ): Promise<JsonMap> {
    const auth = options.auth ?? true;
    const query: Record<string, string> = {};
    for (const [key, value] of Object.entries(options.query ?? {})) {
      if (value !== undefined) query[key] = String(value);
    }

    try {
      return await this.send(method, path, options.body, query, auth);
    } catch (error) {
      if (!(error instanceof ApiError)) throw error;
      const shouldRefresh = auth && !path.startsWith('/auth/') && error.isAuthExpired && !!this.refreshToken;
      if (!shouldRefresh) throw error;

      const outcome = await this.refresh();
      if (outcome === 'success') return this.send(method, path, options.body, query, auth);
      if (outcome === 'invalid') {
        this.clearSession();
        this.onSessionExpired?.();
      }
      throw error;
    }
  }

  private async send(
    method: string,
    path: string,
    body: JsonMap | undefined,
    query: Record<string, string>,
    auth: boolean,
  ): Promise<JsonMap> {
    const headers: Record<string, string> = {};
    if (auth && this.accessToken) headers.Authorization = `Bearer ${this.accessToken}`;

    const response = await this.transport({ method, path, body, query, headers });
    if (response.status < 200 || response.status >= 300) {
      const errorJson = asMap(asMap(response.json).error);
      throw new ApiError(
        asString(errorJson.code, 'INTERNAL_ERROR'),
        asString(errorJson.message, fallbackMessage(response.status)),
        response.status,
        errorJson.details,
      );
    }

    const map = asMap(response.json);
    const data = map.data;
    if (data !== null && typeof data === 'object' && !Array.isArray(data)) return data as JsonMap;
    if (data !== undefined && data !== null) return { value: data };
    return map;
  }

  private refresh(): Promise<RefreshOutcome> {
    if (this.refreshing) return this.refreshing;
    const pending = this.performRefresh().finally(() => {
      if (this.refreshing === pending) this.refreshing = null;
    });
    this.refreshing = pending;
    return pending;
  }

  private async performRefresh(): Promise<RefreshOutcome> {
    const token = this.refreshToken;
    if (!token) return 'invalid';
    try {
      const data = await this.send('POST', '/auth/refresh', { refreshToken: token }, {}, false);
      const access = asString(data.accessToken);
      const refresh = asString(data.refreshToken);
      if (!access || !refresh) return 'invalid';
      this.applySession({ accessToken: access, refreshToken: refresh });
      return 'success';
    } catch (error) {
      return error instanceof ApiError && error.isNetwork ? 'network' : 'invalid';
    }
  }
}

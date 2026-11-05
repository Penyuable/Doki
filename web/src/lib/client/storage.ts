/**
 * Akses localStorage yang aman: bila diblokir (mode privat / cookie dimatikan)
 * jatuh ke Map in-memory agar app tetap jalan, dan menandai `blocked`.
 */
import type { KeyValueStore } from '../data/local-backend.ts';
import type { SessionTokens, TokenStore } from '../data/api-client.ts';
import { isLocale, type Locale } from '../i18n/strings.ts';

class MemoryStore implements KeyValueStore {
  private readonly map = new Map<string, string>();
  getItem(key: string) {
    return this.map.get(key) ?? null;
  }
  setItem(key: string, value: string) {
    this.map.set(key, value);
  }
  removeItem(key: string) {
    this.map.delete(key);
  }
}

export type SafeStore = KeyValueStore & { readonly blocked: boolean };

export function createSafeStore(): SafeStore {
  try {
    const probe = '__dokimon_probe__';
    window.localStorage.setItem(probe, '1');
    window.localStorage.removeItem(probe);
    const ls = window.localStorage;
    return {
      blocked: false,
      getItem: (key) => ls.getItem(key),
      setItem: (key, value) => ls.setItem(key, value),
      removeItem: (key) => ls.removeItem(key),
    };
  } catch {
    const memory = new MemoryStore();
    return {
      blocked: true,
      getItem: (key) => memory.getItem(key),
      setItem: (key, value) => memory.setItem(key, value),
      removeItem: (key) => memory.removeItem(key),
    };
  }
}

const SESSION_KEY = 'dokimon.session';

/**
 * Token sesi (mode server). Web tidak punya secure storage setara Keychain/Keystore;
 * token disimpan di localStorage origin ini — risiko XSS dicatat di TECH_SPEC §12
 * dan docs/OPEN_QUESTIONS.md (OQ-WEB-01).
 */
export function createTokenStore(store: KeyValueStore): TokenStore {
  return {
    read(): SessionTokens | null {
      try {
        const raw = store.getItem(SESSION_KEY);
        if (!raw) return null;
        const parsed = JSON.parse(raw) as Partial<SessionTokens>;
        if (typeof parsed.accessToken !== 'string' || typeof parsed.refreshToken !== 'string') return null;
        return { accessToken: parsed.accessToken, refreshToken: parsed.refreshToken };
      } catch {
        return null;
      }
    },
    save(tokens) {
      try {
        store.setItem(SESSION_KEY, JSON.stringify(tokens));
      } catch {
        // Kuota penuh: sesi tetap hidup di memori untuk tab ini.
      }
    },
    clear() {
      try {
        store.removeItem(SESSION_KEY);
      } catch {
        // Diabaikan: tidak ada yang bisa dihapus.
      }
    },
  };
}

export const TABLE_THEMES = ['wood', 'forest', 'ocean', 'cosmic'] as const;
export type TableTheme = (typeof TABLE_THEMES)[number];

export type AppSettings = {
  locale: Locale;
  reduceMotion: boolean;
  haptics: boolean;
  batterySaver: boolean;
  tableTheme: TableTheme;
  seenHowToPlay: boolean;
};

export const DEFAULT_SETTINGS: AppSettings = {
  locale: 'id',
  reduceMotion: false,
  haptics: true,
  batterySaver: false,
  tableTheme: 'wood',
  seenHowToPlay: false,
};

const SETTINGS_KEY = 'dokimon.settings';

export function readSettings(store: KeyValueStore): AppSettings {
  try {
    const raw = store.getItem(SETTINGS_KEY);
    if (!raw) return DEFAULT_SETTINGS;
    const parsed = JSON.parse(raw) as Record<string, unknown>;
    return {
      locale: isLocale(parsed.locale) ? parsed.locale : DEFAULT_SETTINGS.locale,
      reduceMotion: parsed.reduceMotion === true,
      haptics: parsed.haptics !== false,
      batterySaver: parsed.batterySaver === true,
      tableTheme: (TABLE_THEMES as readonly unknown[]).includes(parsed.tableTheme)
        ? (parsed.tableTheme as TableTheme)
        : DEFAULT_SETTINGS.tableTheme,
      seenHowToPlay: parsed.seenHowToPlay === true,
    };
  } catch {
    return DEFAULT_SETTINGS;
  }
}

export function writeSettings(store: KeyValueStore, settings: AppSettings): void {
  try {
    store.setItem(SETTINGS_KEY, JSON.stringify(settings));
  } catch {
    // Pengaturan tetap berlaku untuk sesi ini walau tidak tersimpan.
  }
}

'use client';

/**
 * State global app (port AuthCubit + SettingsCubit + CatalogCubit Flutter).
 * Komponen membaca lewat `useApp()`; tidak ada saldo/rarity yang dihitung di sini.
 */
import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState, type ReactNode } from 'react';
import { Env } from '@/lib/config/env.ts';
import { ApiError } from '@/lib/data/api-client.ts';
import type { CatalogSnapshot } from '@/lib/data/repositories.ts';
import { EMPTY_STATS, type User, type UserStats, type Wallet } from '@/lib/domain/models.ts';
import { translator, type Locale, type Translator } from '@/lib/i18n/strings.ts';
import { getServices, type Services } from '@/lib/client/services.ts';
import { DEFAULT_SETTINGS, readSettings, writeSettings, type AppSettings } from '@/lib/client/storage.ts';

export type AuthStatus = 'booting' | 'signedOut' | 'signedIn' | 'error';

type AppContextValue = {
  services: Services;
  t: Translator;
  locale: Locale;
  settings: AppSettings;
  updateSettings: (patch: Partial<AppSettings>) => void;

  status: AuthStatus;
  bootError: string | null;
  user: User | null;
  stats: UserStats;
  activeDeckId: string | null;
  sessionExpired: boolean;

  catalog: CatalogSnapshot | null;
  catalogError: string | null;
  reloadCatalog: () => Promise<void>;

  login: (email: string, password: string) => Promise<void>;
  register: (email: string, username: string, password: string) => Promise<void>;
  logout: () => Promise<void>;
  refreshMe: () => Promise<void>;
  retryBoot: () => void;
  applyUser: (user: User) => void;
  applyWallet: (wallet: Wallet) => void;
  setActiveDeckId: (id: string | null) => void;
  resetOffline: () => Promise<void>;
};

const AppContext = createContext<AppContextValue | null>(null);

export function errorMessage(error: unknown, t: Translator): string {
  if (error instanceof ApiError) return error.isNetwork ? t('error.network') : error.message;
  if (error instanceof Error && error.message) return error.message;
  return t('error.unknown');
}

export function AppProvider({ children }: { children: ReactNode }) {
  const services = useMemo(() => getServices(), []);
  const [settings, setSettings] = useState<AppSettings>(DEFAULT_SETTINGS);
  const [status, setStatus] = useState<AuthStatus>('booting');
  const [bootError, setBootError] = useState<string | null>(null);
  const [user, setUser] = useState<User | null>(null);
  const [stats, setStats] = useState<UserStats>(EMPTY_STATS);
  const [activeDeckId, setActiveDeckId] = useState<string | null>(null);
  const [sessionExpired, setSessionExpired] = useState(false);
  const [catalog, setCatalog] = useState<CatalogSnapshot | null>(null);
  const [catalogError, setCatalogError] = useState<string | null>(null);
  const [bootNonce, setBootNonce] = useState(0);
  const catalogLoadedAt = useRef(0);

  const t = useMemo(() => translator(settings.locale), [settings.locale]);

  // Pengaturan dibaca setelah mount (localStorage tidak ada saat prerender).
  useEffect(() => {
    setSettings(readSettings(services.store));
  }, [services]);

  useEffect(() => {
    document.documentElement.lang = settings.locale;
    document.documentElement.dataset.motion = settings.reduceMotion ? 'reduce' : 'full';
  }, [settings.locale, settings.reduceMotion]);

  const updateSettings = useCallback(
    (patch: Partial<AppSettings>) => {
      setSettings((current) => {
        const next = { ...current, ...patch };
        writeSettings(services.store, next);
        return next;
      });
    },
    [services],
  );

  const reloadCatalog = useCallback(async () => {
    try {
      const snapshot = await services.repos.catalog.load();
      setCatalog(snapshot);
      setCatalogError(null);
      catalogLoadedAt.current = Date.now();
    } catch (error) {
      setCatalogError(errorMessage(error, translator('id')));
    }
  }, [services]);

  const applyMe = useCallback((me: { user: User; stats: UserStats; activeDeckId: string | null }) => {
    setUser(me.user);
    setStats(me.stats);
    setActiveDeckId(me.activeDeckId);
  }, []);

  const refreshMe = useCallback(async () => {
    const me = await services.repos.auth.me();
    applyMe(me);
  }, [services, applyMe]);

  // Bootstrap: katalog + sesi (offline → pemain lokal otomatis).
  useEffect(() => {
    let cancelled = false;
    services.api.onSessionExpired = () => {
      setSessionExpired(true);
      setUser(null);
      setStatus('signedOut');
    };
    void (async () => {
      setStatus('booting');
      setBootError(null);
      const catalogTask = reloadCatalog();
      try {
        if (services.offline) {
          await services.repos.auth.guest();
          applyMe(await services.repos.auth.me());
          if (!cancelled) setStatus('signedIn');
        } else if (services.api.hasSession) {
          applyMe(await services.repos.auth.me());
          if (!cancelled) setStatus('signedIn');
        } else if (!cancelled) {
          setStatus('signedOut');
        }
      } catch (error) {
        if (cancelled) return;
        if (error instanceof ApiError && error.isAuthExpired) {
          services.api.clearSession();
          setStatus('signedOut');
        } else {
          setBootError(errorMessage(error, translator('id')));
          setStatus('error');
        }
      }
      await catalogTask;
    })();
    return () => {
      cancelled = true;
    };
  }, [services, reloadCatalog, applyMe, bootNonce]);

  // Segarkan katalog saat tab kembali aktif bila sudah lewat interval (setara app resume).
  useEffect(() => {
    const onVisible = () => {
      if (document.visibilityState === 'visible' && Date.now() - catalogLoadedAt.current > Env.catalogRefreshIntervalMs) {
        void reloadCatalog();
      }
    };
    document.addEventListener('visibilitychange', onVisible);
    return () => document.removeEventListener('visibilitychange', onVisible);
  }, [reloadCatalog]);

  const login = useCallback(
    async (email: string, password: string) => {
      const session = await services.repos.auth.login({ email, password });
      setUser(session.user);
      setSessionExpired(false);
      applyMe(await services.repos.auth.me());
      setStatus('signedIn');
    },
    [services, applyMe],
  );

  const register = useCallback(
    async (email: string, username: string, password: string) => {
      const session = await services.repos.auth.register({ email, username, password });
      setUser(session.user);
      setSessionExpired(false);
      applyMe(await services.repos.auth.me());
      setStatus('signedIn');
    },
    [services, applyMe],
  );

  const logout = useCallback(async () => {
    try {
      await services.repos.auth.logout();
    } finally {
      setUser(null);
      setStats(EMPTY_STATS);
      setActiveDeckId(null);
      setStatus('signedOut');
    }
  }, [services]);

  const resetOffline = useCallback(async () => {
    if (!services.backend) return;
    services.backend.reset();
    await services.repos.auth.guest();
    applyMe(await services.repos.auth.me());
  }, [services, applyMe]);

  const value: AppContextValue = {
    services,
    t,
    locale: settings.locale,
    settings,
    updateSettings,
    status,
    bootError,
    user,
    stats,
    activeDeckId,
    sessionExpired,
    catalog,
    catalogError,
    reloadCatalog,
    login,
    register,
    logout,
    refreshMe,
    retryBoot: () => setBootNonce((n) => n + 1),
    applyUser: setUser,
    applyWallet: (wallet) => setUser((current) => (current ? { ...current, gold: wallet.gold, gems: wallet.gems } : current)),
    setActiveDeckId,
    resetOffline,
  };

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp(): AppContextValue {
  const value = useContext(AppContext);
  if (!value) throw new Error('useApp harus dipakai di dalam <AppProvider>');
  return value;
}

export function useT(): Translator {
  return useApp().t;
}

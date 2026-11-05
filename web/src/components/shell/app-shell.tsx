'use client';

import Link from 'next/link';
import { usePathname, useRouter } from 'next/navigation';
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import type { Card } from '@/lib/domain/card.ts';
import { Creature } from '../cards/creature';
import { useApp } from '../providers/app-provider';
import { Icon, type IconName } from '../ui/icon';
import { HowToPlay } from './how-to-play';

const NAV: Array<{ href: string; key: string; icon: IconName }> = [
  { href: '/', key: 'nav.home', icon: 'home' },
  { href: '/collection/', key: 'nav.collection', icon: 'cards' },
  { href: '/deck/', key: 'nav.deck', icon: 'deck' },
  { href: '/gacha/', key: 'nav.gacha', icon: 'gift' },
  { href: '/profile/', key: 'nav.profile', icon: 'user' },
];

/** Rute tanpa navigasi/gate: halaman login & arena layar penuh. */
const BARE_ROUTES = ['/login'];

const normalize = (path: string) => (path.endsWith('/') ? path : `${path}/`);

export function isActive(pathname: string, href: string): boolean {
  if (href === '/') return pathname === '/';
  return normalize(pathname).startsWith(href);
}

export function Logo({ size = 40 }: { size?: number }) {
  const { catalog } = useApp();
  const mascot = catalog?.byId.get('card_001');
  return (
    <span className="logo clay" data-tone="primary" style={{ width: size, height: size }}>
      {mascot ? <Creature card={mascot} animate={false} /> : <Icon name="cards" size={size * 0.55} />}
    </span>
  );
}

export function WalletPills() {
  const { user, t } = useApp();
  if (!user) return null;
  return (
    <span className="wallet" aria-label={t('home.wallet')}>
      <span className="pill" data-tone="gold">
        <Icon name="coin" size={14} /> {user.gold.toLocaleString()}
      </span>
      <span className="pill" data-tone="gem">
        <Icon name="gem" size={14} /> {user.gems.toLocaleString()}
      </span>
    </span>
  );
}

function Splash({ step }: { step: number }) {
  const { catalog, t, bootError, retryBoot, status } = useApp();
  const parade: Card[] = useMemo(
    () => (catalog ? ['card_001', 'card_002', 'card_003', 'card_004'].map((id) => catalog.byId.get(id)).filter((c): c is Card => !!c) : []),
    [catalog],
  );
  const steps = ['splash.step.cards', 'splash.step.monsters', 'splash.step.table'];
  return (
    <main className="splash">
      <Logo size={72} />
      <h1 style={{ fontSize: 34, fontWeight: 900, letterSpacing: -0.6 }}>{t('app.name')}</h1>
      <p className="muted">{t('app.tagline')}</p>
      {parade.length > 0 && (
        <div className="splash-creatures" aria-hidden>
          {parade.map((card) => (
            <Creature key={card.id} card={card} />
          ))}
        </div>
      )}
      {status === 'error' ? (
        <div className="stack" style={{ justifyItems: 'center' }}>
          <p className="banner" data-tone="danger">
            {bootError ?? t('error.unknown')}
          </p>
          <button type="button" className="btn squish" onClick={retryBoot}>
            <Icon name="refresh" size={18} /> {t('common.retry')}
          </button>
        </div>
      ) : (
        <>
          <div className="spinner" aria-hidden />
          <p className="muted small">{t(steps[Math.min(step, steps.length - 1)]!)}</p>
          <p className="muted small" style={{ maxWidth: 360 }}>
            {t(`splash.tip.${step % 3}`)}
          </p>
        </>
      )}
    </main>
  );
}

export function AppShell({ children }: { children: ReactNode }) {
  const app = useApp();
  const { t, status, services, settings, updateSettings } = app;
  const pathname = usePathname() ?? '/';
  const router = useRouter();
  const [splashStep, setSplashStep] = useState(0);
  const [helpOpen, setHelpOpen] = useState(false);
  const bare = BARE_ROUTES.some((route) => normalize(pathname).startsWith(normalize(route)));
  const fullscreen = normalize(pathname).startsWith('/arena/');

  useEffect(() => {
    if (status !== 'booting') return;
    const timer = window.setInterval(() => setSplashStep((s) => s + 1), 700);
    return () => window.clearInterval(timer);
  }, [status]);

  // Gate auth (mode server): belum masuk → /login.
  useEffect(() => {
    if (status === 'signedOut' && !bare) router.replace('/login/');
    if (status === 'signedIn' && bare) router.replace('/');
  }, [status, bare, router]);

  // Panduan muncul sekali untuk pemain baru.
  useEffect(() => {
    if (status === 'signedIn' && !settings.seenHowToPlay && !bare) {
      setHelpOpen(true);
      updateSettings({ seenHowToPlay: true });
    }
  }, [status, settings.seenHowToPlay, bare, updateSettings]);

  if (bare) return <>{children}</>;
  if (status === 'booting' || status === 'error') return <Splash step={splashStep} />;
  if (status !== 'signedIn') return <Splash step={0} />;

  if (fullscreen) return <>{children}</>;

  return (
    <div className="shell">
      <nav className="bottom-nav clay" aria-label={t('web.mainNav')}>
        <div className="nav-brand brand">
          <Logo />
          {t('app.name')}
        </div>
        {NAV.map((item) => (
          <Link key={item.href} href={item.href} className="nav-item" aria-current={isActive(pathname, item.href) ? 'page' : undefined}>
            <span className="nav-ico">
              <Icon name={item.icon} size={22} />
            </span>
            {t(item.key)}
          </Link>
        ))}
      </nav>
      <div>
        <header className="topbar">
          <Link href="/" className="brand" aria-label={t('nav.home')}>
            <Logo />
            <span className="brand-name">{t('app.name')}</span>
          </Link>
          {services.offline && (
            <span className="pill offline-badge" data-tone="high" title={t('web.offlineHint')}>
              {t('web.offlineBadge')}
            </span>
          )}
          <span className="grow" />
          <WalletPills />
          <button type="button" className="icon-btn" aria-label={t('help.title')} onClick={() => setHelpOpen(true)}>
            <Icon name="help" />
          </button>
          <Link href="/settings/" className="icon-btn" aria-label={t('settings.title')}>
            <Icon name="settings" />
          </Link>
        </header>
        {services.store.blocked && (
          <div style={{ padding: '0 var(--gutter)' }}>
            <p className="banner" data-tone="warning">
              {t('web.storageBlocked')}
            </p>
          </div>
        )}
        {children}
      </div>
      <HowToPlay open={helpOpen} onClose={() => setHelpOpen(false)} />
    </div>
  );
}

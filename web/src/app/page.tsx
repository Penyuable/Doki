'use client';

import Link from 'next/link';
import { useState } from 'react';
import { GameConfig, xpToNext } from '@/lib/config/game-config.ts';
import { ApiError } from '@/lib/data/api-client.ts';
import { CardTile } from '@/components/cards/card-visuals';
import { Creature } from '@/components/cards/creature';
import { useResource } from '@/components/hooks/use-resource';
import { errorMessage, useApp } from '@/components/providers/app-provider';
import { Icon, type IconName } from '@/components/ui/icon';
import { ErrorState, Loading, ProgressBar } from '@/components/ui/states';
import { useToast } from '@/components/ui/toast';

const QUICK: Array<{ href: string; key: string; icon: IconName; tone: string }> = [
  { href: '/battle/', key: 'home.battleCta', icon: 'sword', tone: 'danger' },
  { href: '/gacha/', key: 'home.gachaCta', icon: 'gift', tone: 'pink' },
  { href: '/deck/', key: 'home.deckCta', icon: 'deck', tone: 'accent' },
];

export default function HomePage() {
  const { t, user, services, applyWallet, catalog } = useApp();
  const toast = useToast();
  const [claiming, setClaiming] = useState(false);
  const profile = useResource(() => services.repos.user.profile(), [user?.id]);
  const inventory = useResource(() => services.repos.inventory.load({ sort: 'rarity' }), [user?.id]);

  if (!user) return null;
  const next = xpToNext(user.level);

  const claim = async () => {
    setClaiming(true);
    try {
      const result = await services.repos.user.claimDaily();
      applyWallet(result.balance);
      toast(t('home.dailyClaimedToast'));
      await profile.reload(true);
    } catch (error) {
      if (error instanceof ApiError && error.code === 'ALREADY_CLAIMED') {
        toast(t('home.dailyClaimed'));
        await profile.reload(true);
      } else {
        toast(t('home.dailyClaimFailed', { message: errorMessage(error, t) }));
      }
    } finally {
      setClaiming(false);
    }
  };

  const heroCards = (inventory.data?.page.items ?? []).slice(0, 3).map((item) => item.card);
  const stats = profile.data?.stats;

  return (
    <main className="page">
      <section className="hero-card clay" aria-labelledby="hero-title">
        <div className="row">
          <div className="grow">
            <p className="muted small">{t('home.greeting', { name: user.username })}</p>
            <h1 id="hero-title" style={{ fontSize: 26, fontWeight: 900 }}>
              {t('home.heroTitle')}
            </h1>
          </div>
          <span className="pill" data-tone="primary">
            {t('home.level', { level: user.level })}
          </span>
        </div>
        <div className="stack" style={{ gap: 6, maxWidth: 420 }}>
          <ProgressBar value={user.xp / next} label={t('home.xp', { current: user.xp, next })} />
          <span className="muted small">{t('home.xp', { current: user.xp, next })}</span>
        </div>
        <p className="muted" style={{ maxWidth: '52%' }}>
          {t('home.heroBody')}
        </p>
        <div>
          <Link href="/battle/" className="btn squish" data-tone="danger">
            <Icon name="sword" size={20} /> {t('home.quickPlay')}
          </Link>
        </div>
        {heroCards.length > 0 && (
          <div className="hero-creatures" aria-hidden>
            {heroCards.map((card) => (
              <div key={card.id} style={{ width: '33%' }}>
                <Creature card={card} animate={false} />
              </div>
            ))}
          </div>
        )}
      </section>

      <div className="quick-grid">
        {QUICK.map((item) => (
          <Link key={item.href} href={item.href} className="quick clay squish" data-tone={item.tone}>
            <span className="quick-ico">
              <Icon name={item.icon} />
            </span>
            <span style={{ color: 'var(--ink)' }}>{t(item.key)}</span>
          </Link>
        ))}
      </div>

      <div className="two-col">
        <section className="clay card-pad stack" aria-labelledby="daily-title">
          <div className="row">
            <span className="logo clay" data-tone="gold" style={{ color: '#fff' }}>
              <Icon name="calendar" />
            </span>
            <div className="grow">
              <h2 id="daily-title" className="section-title">
                {t('home.daily')}
              </h2>
              <p className="muted small">{t('home.dailyStreak', { streak: profile.data?.daily.streak ?? 0 })}</p>
            </div>
            <button
              type="button"
              className="btn small squish"
              data-tone="gold"
              disabled={claiming || !profile.data?.daily.canClaim}
              onClick={claim}
            >
              {profile.data && !profile.data.daily.canClaim ? t('home.dailyClaimed') : t('home.dailyClaim')}
            </button>
          </div>
        </section>

        <section className="clay card-pad stack" aria-labelledby="deck-title">
          <div className="row">
            <span className="logo clay" data-tone="accent" style={{ color: '#fff' }}>
              <Icon name="deck" />
            </span>
            <div className="grow">
              <h2 id="deck-title" className="section-title">
                {t('home.activeDeck')}
              </h2>
              <p className="muted small">
                {profile.data?.activeDeck
                  ? `${profile.data.activeDeck.name} · ${t('deck.size', { count: profile.data.activeDeck.cardCount, max: GameConfig.deckSize })}`
                  : t('home.noDeck')}
              </p>
            </div>
            <Link href="/deck/" className="btn small squish" data-tone="surface">
              {t('home.buildDeck')}
            </Link>
          </div>
        </section>
      </div>

      {profile.status === 'error' && !profile.data && <ErrorState error={profile.error} onRetry={() => void profile.reload()} />}

      <div className="kpis">
        <div className="kpi clay">
          <span className="muted small">{t('home.winRate')}</span>
          <b>{stats?.winRate == null ? '—' : `${Math.round(stats.winRate * 100)}%`}</b>
        </div>
        <div className="kpi clay">
          <span className="muted small">{t('home.battles')}</span>
          <b>{stats?.total ?? 0}</b>
        </div>
        <div className="kpi clay">
          <span className="muted small">{t('home.collection')}</span>
          <b>
            {profile.data ? `${profile.data.collection.owned}/${profile.data.collection.total}` : '—'}
          </b>
        </div>
      </div>

      <section className="stack" aria-labelledby="mine-title">
        <div className="row">
          <h2 id="mine-title" className="section-title grow">
            {t('home.myMonsters')}
          </h2>
          <Link href="/collection/" className="btn-text">
            {t('home.seeAll')}
          </Link>
        </div>
        {inventory.status === 'loading' && !inventory.data ? (
          <Loading />
        ) : inventory.status === 'error' && !inventory.data ? (
          <ErrorState error={inventory.error} onRetry={() => void inventory.reload()} />
        ) : (
          <div className="scroll-x">
            {(inventory.data?.page.items ?? []).slice(0, 12).map((item) => (
              <div key={item.cardId} style={{ width: 150, flex: 'none' }}>
                <Link href={`/collection/card/?id=${encodeURIComponent(item.cardId)}`}>
                  <CardTile card={catalog?.byId.get(item.cardId) ?? item.card} quantity={item.quantity} />
                </Link>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="clay card-pad row" aria-labelledby="tip-title">
        <span className="logo clay" data-tone="info" style={{ color: '#fff' }}>
          <Icon name="shield" />
        </span>
        <div className="grow">
          <h2 id="tip-title" className="section-title">
            {t('home.tipTitle')}
          </h2>
          <p className="muted small">{t('home.tip')}</p>
        </div>
      </section>
    </main>
  );
}

'use client';

import Link from 'next/link';
import { useState } from 'react';
import { Env } from '@/lib/config/env.ts';
import { xpToNext } from '@/lib/config/game-config.ts';
import { ApiError } from '@/lib/data/api-client.ts';
import { relativeTime } from '@/lib/ui/time.ts';
import { useResource } from '@/components/hooks/use-resource';
import { errorMessage, useApp } from '@/components/providers/app-provider';
import { ConfirmDialog } from '@/components/ui/dialog';
import { Icon } from '@/components/ui/icon';
import { ErrorState, Loading, PageHead, ProgressBar } from '@/components/ui/states';
import { useToast } from '@/components/ui/toast';

export default function ProfilePage() {
  const { t, locale, services, user, applyWallet, logout } = useApp();
  const toast = useToast();
  const profile = useResource(() => services.repos.user.profile(), [user?.id]);
  const history = useResource(() => services.repos.battle.history(20), [user?.id]);
  const [claiming, setClaiming] = useState(false);
  const [logoutOpen, setLogoutOpen] = useState(false);

  if (!user) return null;
  const next = xpToNext(user.level);
  const data = profile.data;

  const claim = async () => {
    setClaiming(true);
    try {
      const result = await services.repos.user.claimDaily();
      applyWallet(result.balance);
      toast(t('home.dailyClaimedToast'));
    } catch (error) {
      toast(error instanceof ApiError && error.code === 'ALREADY_CLAIMED' ? t('home.dailyClaimed') : t('home.dailyClaimFailed', { message: errorMessage(error, t) }));
    } finally {
      setClaiming(false);
      void profile.reload(true);
    }
  };

  const joined = data?.user.createdAt
    ? new Intl.DateTimeFormat(locale === 'en' ? 'en-US' : 'id-ID', { dateStyle: 'long' }).format(data.user.createdAt)
    : '—';

  return (
    <main className="page">
      <PageHead title={t('profile.title')}>
        <Link href="/settings/" className="icon-btn" aria-label={t('profile.settings')}>
          <Icon name="settings" />
        </Link>
      </PageHead>

      <section className="clay card-pad stack">
        <div className="row">
          <span className="logo clay" data-tone="primary" style={{ width: 64, height: 64, color: '#fff', fontSize: 26, fontWeight: 900 }}>
            {user.username.slice(0, 1).toUpperCase()}
          </span>
          <div className="grow">
            <h2 style={{ fontSize: 22, fontWeight: 900 }}>{user.username}</h2>
            <p className="muted small">{t('profile.memberSince', { date: joined })}</p>
          </div>
          <span className="pill" data-tone="primary">
            {t('profile.level', { level: user.level })}
          </span>
        </div>
        <ProgressBar value={user.xp / next} />
        <span className="muted small">{t('profile.xp', { current: user.xp, next })}</span>
      </section>

      {profile.status === 'error' && !data && <ErrorState error={profile.error} onRetry={() => void profile.reload()} />}

      <div className="two-col">
        <section className="clay card-pad stack">
          <h2 className="section-title">{t('profile.stats')}</h2>
          {data ? (
            <div className="kpis">
              <div className="kpi clay pressed">
                <span className="muted small">{t('outcome.win')}</span>
                <b style={{ color: 'var(--success)' }}>{data.stats.wins}</b>
              </div>
              <div className="kpi clay pressed">
                <span className="muted small">{t('outcome.loss')}</span>
                <b style={{ color: 'var(--danger)' }}>{data.stats.losses}</b>
              </div>
              <div className="kpi clay pressed">
                <span className="muted small">{t('outcome.draw')}</span>
                <b>{data.stats.draws}</b>
              </div>
              <div className="kpi clay pressed">
                <span className="muted small">{t('home.winRate')}</span>
                <b>{data.stats.winRate == null ? '—' : `${Math.round(data.stats.winRate * 100)}%`}</b>
              </div>
              <div className="kpi clay pressed">
                <span className="muted small">{t('home.collection')}</span>
                <b>
                  {data.collection.owned}/{data.collection.total}
                </b>
              </div>
            </div>
          ) : (
            <Loading />
          )}
        </section>

        <section className="stack">
          <div className="clay card-pad stack">
            <h2 className="section-title">{t('profile.wallet')}</h2>
            <div className="row">
              <span className="pill" data-tone="gold" style={{ fontSize: 16, padding: '8px 14px' }}>
                <Icon name="coin" size={18} /> {t('gacha.costGold', { amount: user.gold.toLocaleString() })}
              </span>
              <span className="pill" data-tone="gem" style={{ fontSize: 16, padding: '8px 14px' }}>
                <Icon name="gem" size={18} /> {t('gacha.costGem', { amount: user.gems.toLocaleString() })}
              </span>
            </div>
          </div>
          <div className="clay card-pad row">
            <div className="grow">
              <h2 className="section-title">{t('profile.daily')}</h2>
              <p className="muted small">{t('home.dailyStreak', { streak: data?.daily.streak ?? 0 })}</p>
            </div>
            <button type="button" className="btn small squish" data-tone="gold" disabled={claiming || !data?.daily.canClaim} onClick={() => void claim()}>
              {data && !data.daily.canClaim ? t('profile.claimed') : t('profile.claim')}
            </button>
          </div>
        </section>
      </div>

      <section className="clay card-pad stack">
        <h2 className="section-title">{t('profile.history')}</h2>
        {history.status === 'loading' && !history.data ? (
          <Loading />
        ) : history.status === 'error' && !history.data ? (
          <ErrorState error={history.error} onRetry={() => void history.reload()} />
        ) : (history.data ?? []).length === 0 ? (
          <p className="muted small">{t('profile.noHistory')}</p>
        ) : (
          <div className="stack" style={{ gap: 4 }}>
            {(history.data ?? []).map((match) => (
              <div key={match.matchId} className="deck-line">
                <span className="pill" data-tone={match.outcome === 'win' ? 'success' : match.outcome === 'loss' ? 'danger' : 'high'}>
                  {t(`outcome.${match.outcome}`)}
                </span>
                <span className="grow small">
                  <b>{t('profile.historyMeta', { difficulty: t(`difficulty.${match.difficulty}`), turns: match.turns })}</b>
                  <span className="muted" style={{ display: 'block' }}>
                    {relativeTime(match.reportedAt, t)}
                  </span>
                </span>
                <span className="muted small">{t('profile.historyReward', { gold: match.goldAwarded, xp: match.xpAwarded })}</span>
              </div>
            ))}
          </div>
        )}
      </section>

      <section className="clay card-pad stack">
        <h2 className="section-title">{t('profile.account')}</h2>
        <div className="row">
          <span className="muted grow">{t('profile.email')}</span>
          <b>{user.email}</b>
        </div>
        <div className="row">
          <span className="muted grow">{t('profile.about')}</span>
          <b>{t('profile.version', { version: Env.appVersion })}</b>
        </div>
        {!services.offline && (
          <button type="button" className="btn squish" data-tone="surface" onClick={() => setLogoutOpen(true)}>
            <Icon name="logout" size={18} /> {t('profile.logout')}
          </button>
        )}
      </section>

      <ConfirmDialog
        open={logoutOpen}
        title={t('auth.logout')}
        message={t('auth.logoutConfirm')}
        confirmLabel={t('auth.logout')}
        tone="danger"
        onCancel={() => setLogoutOpen(false)}
        onConfirm={() => {
          setLogoutOpen(false);
          void logout().catch((error: unknown) => toast(errorMessage(error, t)));
        }}
      />
    </main>
  );
}

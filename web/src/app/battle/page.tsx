'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { DIFFICULTIES, GameConfig, type Difficulty } from '@/lib/config/game-config.ts';
import { setPendingMatch } from '@/lib/client/match-store.ts';
import { useResource } from '@/components/hooks/use-resource';
import { errorMessage, useApp } from '@/components/providers/app-provider';
import { Icon, type IconName } from '@/components/ui/icon';
import { ErrorState, Loading, PageHead } from '@/components/ui/states';

const DIFF_STYLE: Record<Difficulty, { icon: IconName; tone: string }> = {
  easy: { icon: 'heart', tone: 'success' },
  medium: { icon: 'sword', tone: 'warning' },
  master: { icon: 'crown', tone: 'danger' },
};

export default function BattleSetupPage() {
  const { t, services, activeDeckId, user } = useApp();
  const router = useRouter();
  const [difficulty, setDifficulty] = useState<Difficulty>('easy');
  const [starting, setStarting] = useState(false);
  const [startError, setStartError] = useState<string | null>(null);
  const decks = useResource(() => services.repos.deck.list(), [user?.id, activeDeckId]);

  const active = decks.data?.find((deck) => deck.id === activeDeckId) ?? decks.data?.find((deck) => deck.isActive) ?? null;
  const canStart = !!active && active.isValid;

  const start = async () => {
    if (!active) return;
    setStarting(true);
    setStartError(null);
    try {
      const data = await services.repos.battle.start(difficulty, active.id);
      setPendingMatch(data);
      router.push('/arena/');
    } catch (error) {
      setStartError(t('battle.startFailed', { message: errorMessage(error, t) }));
      setStarting(false);
    }
  };

  return (
    <main className="page">
      <PageHead title={t('battle.title')} back={() => router.back()} />
      <p className="muted">{t('battle.setupSubtitle')}</p>

      <section className="stack" aria-label={t('battle.selectDifficulty')}>
        {DIFFICULTIES.map((key) => {
          const reward = GameConfig.battleRewards[key];
          return (
            <button key={key} type="button" className="diff-card clay squish" aria-pressed={difficulty === key} onClick={() => setDifficulty(key)}>
              <span className="diff-ico" data-tone={DIFF_STYLE[key].tone}>
                <Icon name={DIFF_STYLE[key].icon} size={28} />
              </span>
              <span className="grow stack" style={{ gap: 2 }}>
                <b style={{ fontSize: 18 }}>{t(`battle.difficulty.${key}`)}</b>
                <span className="muted small">{t(`battle.difficultyHint.${key}`)}</span>
                <span className="small" style={{ fontWeight: 800, color: 'var(--ink-soft)' }}>
                  {t('battle.rewardPreview', { gold: reward.gold, xp: reward.xp })}
                </span>
              </span>
              {difficulty === key && (
                <span style={{ color: 'var(--primary)' }}>
                  <Icon name="check" size={26} />
                </span>
              )}
            </button>
          );
        })}
      </section>

      <section className="clay card-pad stack">
        {decks.status === 'loading' && !decks.data ? (
          <Loading />
        ) : decks.status === 'error' && !decks.data ? (
          <ErrorState error={decks.error} onRetry={() => void decks.reload()} />
        ) : active ? (
          <div className="row">
            <Icon name="deck" />
            <span className="grow" style={{ fontWeight: 800 }}>
              {t('battle.deckActive', { name: active.name })}
            </span>
            <span className="pill" data-tone={active.isValid ? 'success' : 'warning'}>
              {active.isValid ? t('deck.valid') : t('battle.invalidDeck')}
            </span>
          </div>
        ) : (
          <div className="row">
            <span className="grow muted">{t('battle.noDeck')}</span>
            <Link href="/deck/" className="btn small">
              {t('home.buildDeck')}
            </Link>
          </div>
        )}
      </section>

      {startError && (
        <p className="banner" data-tone="danger" role="alert">
          {startError}
        </p>
      )}

      <button type="button" className="btn block squish" data-tone="danger" disabled={!canStart || starting} onClick={() => void start()}>
        <Icon name="play" size={18} /> {starting ? t('web.battleStarting') : t('battle.start')}
      </button>
    </main>
  );
}

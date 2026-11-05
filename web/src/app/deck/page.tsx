'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { GameConfig } from '@/lib/config/game-config.ts';
import type { Deck } from '@/lib/domain/models.ts';
import { Creature } from '@/components/cards/creature';
import { useResource } from '@/components/hooks/use-resource';
import { errorMessage, useApp } from '@/components/providers/app-provider';
import { ConfirmDialog } from '@/components/ui/dialog';
import { Icon } from '@/components/ui/icon';
import { EmptyState, ErrorState, Loading, PageHead } from '@/components/ui/states';
import { useToast } from '@/components/ui/toast';

export default function DeckListPage() {
  const { t, services, setActiveDeckId, user } = useApp();
  const router = useRouter();
  const toast = useToast();
  const decks = useResource(() => services.repos.deck.list(), [user?.id]);
  const [deleting, setDeleting] = useState<Deck | null>(null);
  const [busy, setBusy] = useState<string | null>(null);

  const activate = async (deck: Deck) => {
    setBusy(deck.id);
    try {
      await services.repos.deck.activate(deck.id);
      setActiveDeckId(deck.id);
      await decks.reload(true);
    } catch (error) {
      toast(errorMessage(error, t));
    } finally {
      setBusy(null);
    }
  };

  const remove = async (deck: Deck) => {
    setDeleting(null);
    setBusy(deck.id);
    try {
      await services.repos.deck.remove(deck.id);
      if (deck.isActive) setActiveDeckId(null);
      await decks.reload(true);
    } catch (error) {
      toast(errorMessage(error, t));
    } finally {
      setBusy(null);
    }
  };

  const list = decks.data ?? [];
  const full = list.length >= GameConfig.maxDecks;

  return (
    <main className="page">
      <PageHead title={t('deck.title')}>
        <span className="pill">{t('deck.deckCount', { count: list.length, max: GameConfig.maxDecks })}</span>
      </PageHead>

      <div>
        {full ? (
          <p className="banner">{t('deck.limitReached')}</p>
        ) : (
          <Link href="/deck/edit/" className="btn squish">
            <Icon name="plus" /> {t('deck.new')}
          </Link>
        )}
      </div>

      {decks.status === 'loading' && !decks.data ? (
        <Loading />
      ) : decks.status === 'error' && !decks.data ? (
        <ErrorState error={decks.error} onRetry={() => void decks.reload()} />
      ) : list.length === 0 ? (
        <EmptyState icon="deck" message={t('deck.empty')} />
      ) : (
        <div className="two-col">
          {list.map((deck) => {
            const preview = deck.cards
              .map((entry) => entry.card)
              .filter((card) => card !== null)
              .slice(0, 3);
            return (
              <article key={deck.id} className="clay card-pad stack">
                <div className="row">
                  <div className="grow">
                    <h2 className="section-title">{deck.name}</h2>
                    <p className="muted small">{t('deck.size', { count: deck.cardCount, max: GameConfig.deckSize })}</p>
                  </div>
                  {deck.isActive && (
                    <span className="pill" data-tone="primary">
                      {t('deck.active')}
                    </span>
                  )}
                  <span className="pill" data-tone={deck.isValid ? 'success' : 'warning'}>
                    {deck.isValid ? t('deck.valid') : t('deck.invalid')}
                  </span>
                </div>
                <div className="row" aria-hidden style={{ height: 70 }}>
                  {preview.map((card) => (
                    <div key={card.id} style={{ width: 70, height: 70 }} className={`card-art el-bg-${card.element.toLowerCase()}`}>
                      <Creature card={card} animate={false} />
                    </div>
                  ))}
                </div>
                <div className="row wrap">
                  <button type="button" className="btn small squish" onClick={() => router.push(`/deck/edit/?id=${encodeURIComponent(deck.id)}`)}>
                    <Icon name="edit" size={18} /> {t('common.edit')}
                  </button>
                  {!deck.isActive && (
                    <button type="button" className="btn small squish" data-tone="surface" disabled={busy === deck.id} onClick={() => void activate(deck)}>
                      <Icon name="check" size={18} /> {t('deck.activate')}
                    </button>
                  )}
                  <span className="grow" />
                  <button type="button" className="icon-btn" aria-label={t('common.delete')} disabled={busy === deck.id} onClick={() => setDeleting(deck)}>
                    <Icon name="trash" />
                  </button>
                </div>
              </article>
            );
          })}
        </div>
      )}

      <ConfirmDialog
        open={deleting !== null}
        title={t('common.delete')}
        message={t('deck.deleteConfirm', { name: deleting?.name ?? '' })}
        confirmLabel={t('common.delete')}
        tone="danger"
        onCancel={() => setDeleting(null)}
        onConfirm={() => deleting && void remove(deleting)}
      />
    </main>
  );
}

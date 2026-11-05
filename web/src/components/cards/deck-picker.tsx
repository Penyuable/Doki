'use client';

import { GameConfig } from '@/lib/config/game-config.ts';
import { useResource } from '../hooks/use-resource';
import { useApp } from '../providers/app-provider';
import { Dialog } from '../ui/dialog';
import { Icon } from '../ui/icon';
import { Loading } from '../ui/states';

/** Pilih deck tujuan (port `_DeckPickerSheet`). `null` = deck baru. */
export function DeckPicker({ open, onClose, onPick }: { open: boolean; onClose: () => void; onPick: (deckId: string | null) => void }) {
  const { t, services } = useApp();
  const decks = useResource(() => services.repos.deck.list(), [open], open);

  return (
    <Dialog open={open} onClose={onClose} variant="sheet" title={t('deck.pickDeck')}>
      {decks.status === 'loading' ? (
        <Loading />
      ) : decks.status === 'error' ? (
        <div className="stack" style={{ justifyItems: 'center' }}>
          <p className="muted">{t('deck.noDecks')}</p>
          <button type="button" className="btn small" onClick={() => void decks.reload()}>
            {t('common.retry')}
          </button>
        </div>
      ) : (
        <div className="stack" style={{ gap: 2 }}>
          {decks.data.map((deck) => (
            <button key={deck.id} type="button" className="list-btn" onClick={() => onPick(deck.id)}>
              <Icon name="deck" />
              <span className="grow">
                {deck.name}
                <span className="muted small" style={{ display: 'block' }}>
                  {deck.cardCount}/{GameConfig.deckSize}
                </span>
              </span>
              <span style={{ color: deck.isValid ? 'var(--success)' : 'var(--warning)' }}>
                <Icon name={deck.isValid ? 'check' : 'help'} />
              </span>
            </button>
          ))}
          {decks.data.length < GameConfig.maxDecks && (
            <button type="button" className="list-btn" onClick={() => onPick(null)}>
              <Icon name="plus" />
              <span className="grow">{t('deck.new')}</span>
            </button>
          )}
        </div>
      )}
    </Dialog>
  );
}

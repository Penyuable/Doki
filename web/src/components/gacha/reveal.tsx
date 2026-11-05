'use client';

import { useEffect, useState } from 'react';
import { isRarePlus } from '@/lib/domain/card.ts';
import type { GachaPullResponse } from '@/lib/domain/models.ts';
import { CardArt, rarityTone } from '../cards/card-visuals';
import { useApp } from '../providers/app-provider';
import { Dialog } from '../ui/dialog';
import { Icon } from '../ui/icon';
import { canVibrate } from '../battle/use-battle-session';

/** Reveal hasil gacha (port `gacha_reveal_dialog.dart`): ketuk untuk membuka, atau buka semua. */
export function GachaReveal({
  response,
  onClose,
  onPullAgain,
  onViewCollection,
}: {
  response: GachaPullResponse | null;
  onClose: () => void;
  onPullAgain: () => void;
  onViewCollection: () => void;
}) {
  const { t, settings } = useApp();
  const [opened, setOpened] = useState<Set<number>>(new Set());

  useEffect(() => {
    // Kurangi animasi: hasil langsung terbuka (AC: hasil tetap ditampilkan).
    setOpened(settings.reduceMotion && response ? new Set(response.results.map((_, i) => i)) : new Set());
  }, [response, settings.reduceMotion]);

  useEffect(() => {
    if (!response || !settings.haptics || !canVibrate()) return;
    if (response.results.some((r) => isRarePlus(r.rarity))) navigator.vibrate(40);
  }, [response, settings.haptics]);

  if (!response) return null;
  const all = opened.size === response.results.length;

  return (
    <Dialog
      open
      onClose={onClose}
      title={t('gacha.reveal')}
      actions={
        all ? (
          <>
            <button type="button" className="btn-text" onClick={onViewCollection}>
              {t('gacha.viewCollection')}
            </button>
            <button type="button" className="btn small squish" onClick={onPullAgain}>
              {t('gacha.pullAgain')}
            </button>
          </>
        ) : (
          <button type="button" className="btn small squish" onClick={() => setOpened(new Set(response.results.map((_, i) => i)))}>
            {t('gacha.skip')}
          </button>
        )
      }
    >
      {!all && <p className="muted small" style={{ marginBottom: 10 }}>{t('gacha.revealHint')}</p>}
      <div className={`reveal-grid ${response.results.length === 1 ? 'single' : ''}`}>
        {response.results.map((result, index) => {
          const open = opened.has(index);
          const card = result.card;
          return (
            <button
              key={`${response.batchId}-${index}`}
              type="button"
              className={`flip ${open ? 'open' : ''}`}
              aria-label={open && card ? `${card.name} · ${t(`rarity.${result.rarity.toLowerCase()}`)}` : t('gacha.revealHint')}
              onClick={() => setOpened((current) => new Set(current).add(index))}
            >
              <div className="flip-inner">
                <div className="flip-face flip-back">
                  <Icon name="sparkle" size={30} />
                </div>
                <div className="flip-face flip-front" data-tone={rarityTone(result.rarity)}>
                  {card && <CardArt card={card} />}
                  <span className="name">{card?.name ?? result.cardId}</span>
                  <span className="pill" data-tone={rarityTone(result.rarity)} style={{ fontSize: 9 }}>
                    {t(`rarity.${result.rarity.toLowerCase()}`)}
                  </span>
                  <span className="flip-tags">
                    {result.isNew && <span className="pill" data-tone="success">{t('gacha.new')}</span>}
                    {result.wasPity && <span className="pill" data-tone="warning">{t('gacha.pityHit')}</span>}
                    {result.guaranteedRare && <span className="pill" data-tone="info">{t('gacha.guaranteed')}</span>}
                  </span>
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </Dialog>
  );
}

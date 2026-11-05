'use client';

import { useState } from 'react';
import { GameConfig } from '@/lib/config/game-config.ts';
import { Dialog } from '../ui/dialog';
import { Icon, type IconName } from '../ui/icon';
import { useT } from '../providers/app-provider';

const STEPS: Array<{ key: string; icon: IconName; tone: string; args: Record<string, number> }> = [
  { key: 'collect', icon: 'gift', tone: 'pink', args: { pity: GameConfig.pityThreshold } },
  { key: 'deck', icon: 'deck', tone: 'primary', args: { deck: GameConfig.deckSize, copies: GameConfig.maxCopiesPerCard } },
  { key: 'summon', icon: 'bolt', tone: 'accent', args: { slots: GameConfig.boardSlots } },
  { key: 'moves', icon: 'sword', tone: 'warning', args: {} },
  { key: 'win', icon: 'crown', tone: 'success', args: { hp: GameConfig.playerHp } },
];

/** Panduan 5 langkah (port `features/onboarding/how_to_play.dart`). */
export function HowToPlay({ open, onClose }: { open: boolean; onClose: () => void }) {
  const t = useT();
  const [index, setIndex] = useState(0);
  const step = STEPS[index]!;
  const last = index === STEPS.length - 1;
  const close = () => {
    setIndex(0);
    onClose();
  };

  return (
    <Dialog open={open} onClose={close} title={t('help.title')}>
      <div className="howto-art clay pressed" data-tone={step.tone} style={{ color: '#fff' }}>
        <Icon name={step.icon} size={64} strokeWidth={2} />
      </div>
      <h3 className="section-title">{t(`help.${step.key}.title`)}</h3>
      <p className="muted" style={{ marginTop: 6 }}>
        {t(`help.${step.key}.body`, step.args)}
      </p>
      <div className="dots" aria-hidden>
        {STEPS.map((s, i) => (
          <span key={s.key} aria-current={i === index} />
        ))}
      </div>
      <div className="dialog-actions">
        <button type="button" className="btn-text" onClick={close}>
          {t('common.skip')}
        </button>
        <button type="button" className="btn small squish" onClick={() => (last ? close() : setIndex(index + 1))}>
          {last ? t('help.start') : t('help.next')}
        </button>
      </div>
    </Dialog>
  );
}

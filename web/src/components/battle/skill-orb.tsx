'use client';

import type { Card } from '@/lib/domain/card.ts';
import { movesFor, type CardMove } from '@/lib/ui/battle-view.ts';
import { useT } from '../providers/app-provider';
import { ABILITY_ICON, ELEMENT_ICON, Icon, type IconName } from '../ui/icon';

function moveIcon(move: CardMove, card: Card): IconName {
  if (move.kind === 'strike') return ELEMENT_ICON[card.element];
  if (move.kind === 'guard') return 'shield';
  return ABILITY_ICON[card.ability?.type ?? ''] ?? 'sparkle';
}

/** Bola jurus clay (port `SkillOrb`). `power` = stat kartu, bukan hasil hitung damage (I-05). */
export function SkillOrb({ move, card, onClick, enabled = true }: { move: CardMove; card: Card; onClick?: () => void; enabled?: boolean }) {
  const t = useT();
  const costLabel = move.cost > 0 ? t('move.energy', { cost: move.cost }) : t('move.free');
  const content = (
    <>
      <span className="orb" data-tone={enabled ? move.tone : 'faint'}>
        <span style={{ display: 'grid', justifyItems: 'center' }}>
          <Icon name={moveIcon(move, card)} size={26} />
          {move.power !== null && <b>{move.power}</b>}
        </span>
        <span className="orb-cost">
          <Icon name="bolt" size={9} />
          {move.cost}
        </span>
      </span>
      <span className="orb-name">{move.name}</span>
      <span className="muted small">{costLabel}</span>
    </>
  );
  if (!onClick) return <div className="orb-wrap">{content}</div>;
  return (
    <button type="button" className="orb-wrap squish" disabled={!enabled} onClick={onClick} aria-label={move.name}>
      {content}
    </button>
  );
}

export function MoveOrbRow({ card }: { card: Card }) {
  const t = useT();
  return (
    <div className="row wrap" style={{ justifyContent: 'center', gap: 10 }}>
      {movesFor(card, t).map((move) => (
        <SkillOrb key={move.kind} move={move} card={card} />
      ))}
    </div>
  );
}

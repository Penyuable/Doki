'use client';

import type { ReactNode } from 'react';
import { elementSlug, type Card, type Rarity } from '@/lib/domain/card.ts';
import { useApp, useT } from '../providers/app-provider';
import { ELEMENT_ICON, Icon } from '../ui/icon';
import { Creature } from './creature';

export const rarityTone = (rarity: Rarity) => `r-${rarity.toLowerCase()}`;
export const elementTone = (card: Pick<Card, 'element'>) => `el-${elementSlug(card.element)}`;

export function ElementBadge({ card, size = 26 }: { card: Pick<Card, 'element'>; size?: number }) {
  const t = useT();
  return (
    <span className="el-badge" data-tone={elementTone(card)} style={{ width: size, height: size }} title={t(`element.${elementSlug(card.element)}`)}>
      <Icon name={ELEMENT_ICON[card.element]} size={size * 0.62} strokeWidth={2.4} />
    </span>
  );
}

export function RarityPill({ rarity }: { rarity: Rarity }) {
  const t = useT();
  return (
    <span className="pill" data-tone={rarityTone(rarity)}>
      {t(`rarity.${rarity.toLowerCase()}`)}
    </span>
  );
}

export function CostOrb({ cost }: { cost: number }) {
  return (
    <span className="cost-orb" aria-label={`${cost}`}>
      <Icon name="bolt" size={11} />
      {cost}
    </span>
  );
}

/** Karya kartu: latar pastel elemen + kreatur. */
export function CardArt({ card, dim = false, children }: { card: Card; dim?: boolean; children?: ReactNode }) {
  const { settings } = useApp();
  const animate = !settings.reduceMotion && !settings.batterySaver;
  return (
    <div className={`card-art el-bg-${elementSlug(card.element)} ${dim ? 'dim' : ''}`}>
      <Creature card={card} animate={animate} />
      {children}
    </div>
  );
}

/** Tile kartu untuk grid koleksi / deck builder. */
export function CardTile({
  card,
  quantity,
  onClick,
  footer,
  dimmed,
  selected,
}: {
  card: Card;
  quantity?: number;
  onClick?: () => void;
  footer?: ReactNode;
  dimmed?: boolean;
  selected?: boolean;
}) {
  const t = useT();
  const owned = quantity === undefined || quantity > 0;
  const body = (
    <>
      <div className="card-tile-top">
        <CostOrb cost={card.cost} />
        <ElementBadge card={card} size={24} />
      </div>
      <CardArt card={card} dim={dimmed ?? !owned}>
        {quantity !== undefined && quantity > 0 && <span className="qty">{t('collection.quantity', { count: quantity })}</span>}
      </CardArt>
      <div className="card-tile-name">{card.name}</div>
      <div className="row card-tile-meta">
        <span className="rarity-dot" data-tone={rarityTone(card.rarity)} />
        <span className="muted small grow">{t(`rarity.${card.rarity.toLowerCase()}`)}</span>
        {card.type === 'unit' ? (
          <span className="stat-mini">
            <b>{card.attack ?? 0}</b>/<b>{card.hp ?? 0}</b>
          </span>
        ) : (
          <span className="pill">{t('type.spell')}</span>
        )}
      </div>
      {footer}
    </>
  );
  const className = `card-tile clay ${selected ? 'selected' : ''} ${onClick ? 'squish' : ''}`;
  return onClick ? (
    <button type="button" className={className} onClick={onClick} aria-label={card.name}>
      {body}
    </button>
  ) : (
    <div className={className}>{body}</div>
  );
}

/** Statistik kartu (ATK/HP/DEF) — nilai kartu, bukan hasil hitung battle. */
export function CardStats({ card }: { card: Card }) {
  const t = useT();
  if (card.type !== 'unit') return null;
  const stats: Array<[string, number | null, string]> = [
    [t('card.attack'), card.attack, 'attack'],
    [t('card.hp'), card.hp, 'success'],
    [t('card.defense'), card.defense, 'info'],
  ];
  return (
    <div className="stat-row">
      {stats.map(([label, value, tone]) => (
        <div key={label} className="stat-box clay pressed" data-tone-text={tone}>
          <span className="muted small">{label}</span>
          <b>{value ?? 0}</b>
        </div>
      ))}
    </div>
  );
}

'use client';

import type { BattlePlayerState, BattleUnit } from '@/lib/battle/models.ts';
import type { Card } from '@/lib/domain/card.ts';
import { elementSlug } from '@/lib/domain/card.ts';
import type { FxItem } from '@/lib/ui/battle-view.ts';
import { CostOrb } from '../cards/card-visuals';
import { Creature } from '../cards/creature';
import { useApp } from '../providers/app-provider';
import { Icon } from '../ui/icon';
import { ProgressBar } from '../ui/states';

export function FxFloats({ items }: { items: FxItem[] }) {
  if (items.length === 0) return null;
  return (
    <span className="fx-layer" aria-hidden>
      {items.map((item, i) => (
        <span key={item.key} className={`fx ${item.kind}`} style={{ marginTop: i * -14 }}>
          {item.kind === 'heal' ? '+' : '−'}
          {item.amount}
        </span>
      ))}
    </span>
  );
}

/** Kepala sisi (HP pemain, energi, tangan, deck) — angka dari state engine (I-05). */
export function SideHeader({ side, state, fx, difficultyLabel }: { side: 'player' | 'bot'; state: BattlePlayerState; fx: FxItem[]; difficultyLabel?: string }) {
  const { t } = useApp();
  const hp = Math.max(0, state.hp);
  const hit = fx.some((item) => item.kind !== 'heal');
  return (
    <div className={`side-header clay ${hit ? 'hit' : ''}`}>
      <span className="hero-face" data-tone={side === 'bot' ? 'danger' : 'primary'} style={{ background: 'var(--c)' }}>
        <Icon name={side === 'bot' ? 'sparkle' : 'person'} size={24} />
      </span>
      <div className="grow stack" style={{ gap: 4 }}>
        <div className="row" style={{ gap: 6 }}>
          <b>{side === 'bot' ? t('battle.opponent') : t('battle.you')}</b>
          {difficultyLabel && <span className="pill" data-tone="high">{difficultyLabel}</span>}
          <span className="grow" />
          <span className="small" style={{ fontWeight: 900 }}>
            {t('battle.hpValue', { current: hp, max: state.maxHp })}
          </span>
        </div>
        <ProgressBar value={hp / state.maxHp} tone={hp / state.maxHp > 0.35 ? 'success' : 'danger'} label={t('battle.hpValue', { current: hp, max: state.maxHp })} />
        <div className="meta">
          <span className="pill" data-tone="accent">
            <Icon name="bolt" size={11} /> {t('battle.energy', { current: state.energy, max: state.maxEnergy })}
          </span>
          <span className="pill">{t('battle.hand', { count: state.hand.length })}</span>
          <span className="pill">{t('battle.deckCount', { count: state.deck.length })}</span>
          {state.fatigueCounter > 0 && <span className="pill" data-tone="warning">{t('battle.fatigue', { value: state.fatigueCounter })}</span>}
        </div>
      </div>
      <FxFloats items={fx} />
    </div>
  );
}

function StatusDots({ unit }: { unit: BattleUnit }) {
  const { t } = useApp();
  const tone = { burn: 'danger', freeze: 'accent', shield: 'info', rally: 'warning' } as const;
  const icon = { burn: 'fire', freeze: 'freeze', shield: 'shield', rally: 'trend' } as const;
  if (unit.statuses.length === 0) return null;
  return (
    <span className="statuses">
      {unit.statuses.map((status) => (
        <span
          key={status.kind}
          className="status-dot"
          data-tone={tone[status.kind]}
          title={t(`battle.status.${status.kind}`, { value: status.value, turns: status.turns })}
        >
          <Icon name={icon[status.kind]} size={11} strokeWidth={2.6} />
        </span>
      ))}
    </span>
  );
}

export function UnitTile({ unit, actionable, onClick, fx, side }: { unit: BattleUnit; actionable: boolean; onClick?: () => void; fx: FxItem[]; side: 'player' | 'bot' }) {
  const { t, settings } = useApp();
  const stanceLabel =
    unit.stance === 'guarding' ? t('battle.guarding') : unit.summonedThisTurn ? t('battle.summoning') : unit.hasActed ? t('battle.tapped') : t('battle.ready');
  const className = `unit clay ${actionable ? 'actionable' : ''} ${unit.stance === 'tapped' ? 'tapped' : ''} ${unit.stance === 'guarding' ? 'guarding' : ''}`;
  const body = (
    <>
      <span className={`unit-art el-bg-${elementSlug(unit.card.element)}`}>
        <Creature card={unit.card} animate={!settings.reduceMotion && !settings.batterySaver} turn={side === 'bot' ? 'left' : undefined} />
      </span>
      <span className="unit-name">{unit.card.name}</span>
      <span className="unit-stats">
        <span className="atk">
          <Icon name="sword" size={11} /> {unit.attack}
        </span>
        <span className="hp">
          <Icon name="heart" size={11} /> {Math.max(0, unit.hp)}
        </span>
      </span>
      <ProgressBar value={Math.max(0, unit.hp) / unit.maxHp} tone="success" />
      <StatusDots unit={unit} />
      <span className="stance">
        {unit.stance === 'guarding' ? (
          <span className="status-dot" data-tone="info" title={stanceLabel}>
            <Icon name="shield" size={11} />
          </span>
        ) : null}
      </span>
      <FxFloats items={fx} />
    </>
  );
  const label = `${unit.card.name} · ${unit.attack}/${Math.max(0, unit.hp)} · ${stanceLabel}`;
  return onClick ? (
    <button type="button" className={`${className} squish`} onClick={onClick} aria-label={label}>
      {body}
    </button>
  ) : (
    <div className={className} aria-label={label} role="group">
      {body}
    </div>
  );
}

export function Board({
  units,
  slots,
  side,
  fxFor,
  actionableIds,
  onUnit,
}: {
  units: BattleUnit[];
  slots: number;
  side: 'player' | 'bot';
  fxFor: (anchor: string) => FxItem[];
  actionableIds: Set<string>;
  onUnit?: (unit: BattleUnit) => void;
}) {
  const { t } = useApp();
  return (
    <div className="board" role="list" aria-label={side === 'bot' ? t('battle.botBoard') : t('battle.playerBoard')}>
      {Array.from({ length: slots }, (_, i) => {
        const unit = units[i];
        return (
          <div key={unit?.instanceId ?? `empty-${i}`} role="listitem">
            {unit ? (
              <UnitTile
                unit={unit}
                side={side}
                fx={fxFor(unit.instanceId)}
                actionable={actionableIds.has(unit.instanceId)}
                onClick={onUnit ? () => onUnit(unit) : undefined}
              />
            ) : (
              <div className="slot-empty" />
            )}
          </div>
        );
      })}
    </div>
  );
}

export function HandCard({ card, playable, onClick }: { card: Card; playable: boolean; onClick: () => void }) {
  const { settings } = useApp();
  return (
    <button type="button" className={`hand-card clay squish ${playable ? 'playable' : 'unplayable'}`} onClick={onClick} aria-label={`${card.name} (${card.cost})`}>
      <span className="row" style={{ justifyContent: 'space-between' }}>
        <CostOrb cost={card.cost} />
      </span>
      <span className={`hand-art el-bg-${elementSlug(card.element)}`}>
        <Creature card={card} animate={playable && !settings.reduceMotion && !settings.batterySaver} />
      </span>
      <span className="hand-name">{card.name}</span>
      {card.type === 'unit' ? (
        <span className="stat-mini">
          <b>{card.attack ?? 0}</b>/<b>{card.hp ?? 0}</b>
        </span>
      ) : (
        <span className="stat-mini">{card.ability?.name}</span>
      )}
    </button>
  );
}

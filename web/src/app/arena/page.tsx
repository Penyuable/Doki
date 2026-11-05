'use client';

import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useCallback, useEffect, useMemo, useState } from 'react';
import type { BattleAction, BattleUnit } from '@/lib/battle/models.ts';
import { GameConfig } from '@/lib/config/game-config.ts';
import { clearPendingMatch, setPendingMatch, takePendingMatch } from '@/lib/client/match-store.ts';
import type { BattleStartData } from '@/lib/domain/models.ts';
import { cantPlayReason, describeTarget, movesFor, nextStepHint, uniqueTargets, type MoveKind } from '@/lib/ui/battle-view.ts';
import { Board, HandCard, SideHeader } from '@/components/battle/arena-parts';
import { SkillOrb } from '@/components/battle/skill-orb';
import { useBattleSession } from '@/components/battle/use-battle-session';
import { CardArt } from '@/components/cards/card-visuals';
import { errorMessage, useApp } from '@/components/providers/app-provider';
import { HowToPlay } from '@/components/shell/how-to-play';
import { ConfirmDialog, Dialog } from '@/components/ui/dialog';
import { Icon } from '@/components/ui/icon';
import { EmptyState, ProgressBar } from '@/components/ui/states';
import { useToast } from '@/components/ui/toast';

type TargetRequest = { ids: Array<string | null>; resolve: (id: string | null | undefined) => void };

export default function ArenaPage() {
  const { t, services, settings, user } = useApp();
  const router = useRouter();
  const toast = useToast();
  const [start, setStart] = useState<BattleStartData | null>(null);
  const [checked, setChecked] = useState(false);
  const { session, state, fx } = useBattleSession(start);
  const [unitSheet, setUnitSheet] = useState<BattleUnit | null>(null);
  const [targets, setTargets] = useState<TargetRequest | null>(null);
  const [logOpen, setLogOpen] = useState(false);
  const [helpOpen, setHelpOpen] = useState(false);
  const [concedeOpen, setConcedeOpen] = useState(false);
  const [rematching, setRematching] = useState(false);

  useEffect(() => {
    setStart(takePendingMatch());
    setChecked(true);
  }, []);

  const battle = state?.battle ?? null;
  const interactive = !!battle && battle.activeSide === 'player' && !state?.busy && !battle.isTerminal;

  const report = useCallback(
    (error: string | null) => {
      if (error) toast(t('battle.illegal', { reason: error }));
    },
    [t, toast],
  );

  const chooseTarget = useCallback(
    (ids: Array<string | null | undefined>) =>
      new Promise<string | null | undefined>((resolve) => {
        const unique = uniqueTargets(ids);
        if (unique.length === 1) {
          resolve(unique[0]);
          return;
        }
        setTargets({ ids: unique, resolve });
      }),
    [],
  );

  const runWithTarget = useCallback(
    async <A extends BattleAction & { targetId?: string | null }>(options: A[]) => {
      if (!session || options.length === 0) return;
      let action = options[0]!;
      if (options.length > 1) {
        const picked = await chooseTarget(options.map((option) => option.targetId));
        if (picked === undefined) return;
        action = options.find((option) => (option.targetId ?? null) === picked) ?? action;
      }
      report(session.perform(action));
    },
    [session, chooseTarget, report],
  );

  const endTurn = useCallback(() => {
    if (session && interactive) report(session.endTurn());
  }, [session, interactive, report]);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => {
      const target = event.target as HTMLElement | null;
      if (target && ['INPUT', 'TEXTAREA', 'SELECT'].includes(target.tagName)) return;
      if (document.querySelector('[role="dialog"]')) return;
      if (event.key === 'e' || event.key === 'E') endTurn();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [endTurn]);

  useEffect(() => {
    if (start && battle?.isTerminal) clearPendingMatch(start.matchId);
  }, [start, battle?.isTerminal]);

  const fxFor = useCallback((anchor: string) => fx.filter((item) => item.anchor === anchor), [fx]);

  const actionable = useMemo(() => {
    const ids = new Set<string>();
    if (!session || !interactive || !battle) return ids;
    for (const unit of battle.player.board) {
      if (session.attackOptionsFor(unit.instanceId).length > 0 || session.abilityOptionsFor(unit.instanceId).length > 0) ids.add(unit.instanceId);
    }
    return ids;
  }, [session, interactive, battle]);

  if (!checked) return null;
  if (!start) {
    return (
      <main className="page">
        <EmptyState icon="sword" message={t('web.noMatch')} action={<Link href="/battle/" className="btn small">{t('battle.title')}</Link>} />
      </main>
    );
  }
  if (!session || !state || !battle) return null;

  const playHand = async (index: number) => {
    const options = session.playOptionsForHand(index);
    if (options.length === 0) {
      toast(cantPlayReason(battle, index, t));
      return;
    }
    await runWithTarget(options);
  };

  const openUnit = (unit: BattleUnit) => {
    const any =
      session.attackOptionsFor(unit.instanceId).length > 0 ||
      session.abilityOptionsFor(unit.instanceId).length > 0 ||
      session.guardActionFor(unit.instanceId) !== null;
    if (!any) {
      toast(t('move.notReady'));
      return;
    }
    setUnitSheet(unit);
  };

  const chooseMove = async (unit: BattleUnit, kind: MoveKind) => {
    setUnitSheet(null);
    if (kind === 'strike') await runWithTarget(session.attackOptionsFor(unit.instanceId));
    else if (kind === 'ability') await runWithTarget(session.abilityOptionsFor(unit.instanceId));
    else {
      const guard = session.guardActionFor(unit.instanceId);
      if (guard) report(session.perform(guard));
    }
  };

  const rematch = async () => {
    setRematching(true);
    try {
      const next = await services.repos.battle.start(start.difficulty, start.playerDeck.deckId ?? undefined);
      setPendingMatch(next);
      setStart(next);
    } catch (error) {
      toast(t('battle.startFailed', { message: errorMessage(error, t) }));
    } finally {
      setRematching(false);
    }
  };

  const hint = nextStepHint(session, t);
  const sheetUnit = unitSheet ? battle.player.board.find((u) => u.instanceId === unitSheet.instanceId) ?? null : null;
  const outcomeTitle = battle.outcome === 'win' ? t('battle.victory') : battle.outcome === 'loss' ? t('battle.defeat') : t('battle.draw');
  const result = state.result;

  return (
    <main className="arena">
      <header className="arena-bar">
        <button type="button" className="icon-btn" aria-label={t('battle.concede')} disabled={battle.isTerminal} onClick={() => setConcedeOpen(true)}>
          <Icon name="close" />
        </button>
        <h1>{t('battle.arena')}</h1>
        <span className="pill" data-tone="primary">
          {t(`battle.difficulty.${start.difficulty}`)}
        </span>
        <span className="grow" />
        <button type="button" className="icon-btn" aria-label={t('help.title')} onClick={() => setHelpOpen(true)}>
          <Icon name="help" />
        </button>
        <button type="button" className="icon-btn" aria-label={t('battle.log')} onClick={() => setLogOpen(true)}>
          <Icon name="log" />
        </button>
      </header>

      <SideHeader side="bot" state={battle.bot} fx={fxFor('hero:bot')} />

      <div className="table clay" data-table={settings.tableTheme}>
        <div className="table-felt">
          <Board units={battle.bot.board} slots={battle.config.boardSlots} side="bot" fxFor={fxFor} actionableIds={new Set()} />
          <div className="turn-strip" aria-live="polite">
            <span className="turn-pill">
              <span className="pill" data-tone="high">{t('battle.turn', { turn: battle.turnNumber })}</span>
              <span className="pill" data-tone={battle.activeSide === 'player' ? 'primary' : 'danger'}>
                {battle.activeSide === 'player' ? t('battle.yourTurn') : t('battle.botTurn')}
              </span>
            </span>
            {hint && <span className="small">{hint}</span>}
          </div>
          <Board
            units={battle.player.board}
            slots={battle.config.boardSlots}
            side="player"
            fxFor={fxFor}
            actionableIds={actionable}
            onUnit={interactive ? openUnit : undefined}
          />
        </div>
      </div>

      <SideHeader side="player" state={battle.player} fx={fxFor('hero:player')} />

      <div className="hand" role="list" aria-label={t('battle.hand', { count: battle.player.hand.length })}>
        {battle.player.hand.map((card, index) => (
          <div key={`${card.id}-${index}`} role="listitem">
            <HandCard card={card} playable={interactive && session.playOptionsForHand(index).length > 0} onClick={() => (interactive ? void playHand(index) : toast(t('battle.cantPlay.turn')))} />
          </div>
        ))}
      </div>

      <div className="bottom-bar">
        <button type="button" className="btn squish" data-tone="surface" disabled={battle.isTerminal} onClick={() => setConcedeOpen(true)}>
          <Icon name="flag" size={18} /> {t('battle.concede')}
        </button>
        <button type="button" className="btn grow squish" disabled={!interactive} onClick={endTurn} title={t('web.keyboardHint')}>
          {state.busy ? t('battle.waitBot') : t('battle.endTurn')}
        </button>
      </div>

      <Dialog open={!!sheetUnit} onClose={() => setUnitSheet(null)} variant="sheet">
        {sheetUnit && (
          <div className="stack">
            <div className="row">
              <div style={{ width: 66 }}>
                <CardArt card={sheetUnit.card} />
              </div>
              <div className="grow stack" style={{ gap: 4 }}>
                <b style={{ fontSize: 17 }}>{sheetUnit.card.name}</b>
                <span className="muted small">{t('move.title')}</span>
                <ProgressBar value={Math.max(0, sheetUnit.hp) / sheetUnit.maxHp} tone="success" />
              </div>
            </div>
            <div className="row wrap" style={{ justifyContent: 'center', gap: 8 }}>
              {movesFor(sheetUnit.card, t, sheetUnit.attack).map((move) => {
                const enabled =
                  move.kind === 'strike'
                    ? session.attackOptionsFor(sheetUnit.instanceId).length > 0
                    : move.kind === 'ability'
                      ? session.abilityOptionsFor(sheetUnit.instanceId).length > 0
                      : session.guardActionFor(sheetUnit.instanceId) !== null;
                return <SkillOrb key={move.kind} move={move} card={sheetUnit.card} enabled={enabled} onClick={() => void chooseMove(sheetUnit, move.kind)} />;
              })}
            </div>
          </div>
        )}
      </Dialog>

      <Dialog
        open={!!targets}
        onClose={() => {
          targets?.resolve(undefined);
          setTargets(null);
        }}
        variant="sheet"
        title={t('battle.targetTitle')}
      >
        <div className="stack" style={{ gap: 2 }}>
          {targets?.ids.map((id) => (
            <button
              key={id ?? 'face'}
              type="button"
              className="list-btn"
              onClick={() => {
                targets.resolve(id);
                setTargets(null);
              }}
            >
              <span style={{ color: id === null ? 'var(--danger)' : 'var(--accent)' }}>
                <Icon name={id === null ? 'person' : 'target'} />
              </span>
              {describeTarget(id, battle, t)}
            </button>
          ))}
        </div>
      </Dialog>

      <Dialog open={logOpen} onClose={() => setLogOpen(false)} variant="sheet" title={t('battle.log')}>
        {battle.log.length === 0 ? (
          <p className="muted">{t('battle.logEmpty')}</p>
        ) : (
          <ol className="stack" style={{ gap: 8, listStyle: 'none', padding: 0, margin: 0 }}>
            {[...battle.log].reverse().map((event, i) => (
              <li key={battle.log.length - i} className="row" style={{ alignItems: 'flex-start' }}>
                <span className="pill" style={{ minWidth: 28, justifyContent: 'center' }}>
                  {event.turn}
                </span>
                <span className="small">{event.message}</span>
              </li>
            ))}
          </ol>
        )}
      </Dialog>

      <ConfirmDialog
        open={concedeOpen}
        title={t('battle.confirmConcedeTitle')}
        message={t('battle.concedeConfirm')}
        confirmLabel={t('battle.concede')}
        tone="danger"
        onCancel={() => setConcedeOpen(false)}
        onConfirm={() => {
          setConcedeOpen(false);
          session.concede();
        }}
      />

      <HowToPlay open={helpOpen} onClose={() => setHelpOpen(false)} />

      {battle.isTerminal && (
        <div className="result-overlay" role="dialog" aria-modal="true" aria-labelledby="result-title">
          <div className="result-card clay">
            <span className="logo clay" data-tone={battle.outcome === 'win' ? 'gold' : battle.outcome === 'loss' ? 'faint' : 'info'} style={{ width: 72, height: 72, margin: '0 auto', color: '#fff' }}>
              <Icon name={battle.outcome === 'win' ? 'crown' : battle.outcome === 'loss' ? 'flag' : 'shield'} size={36} />
            </span>
            <h2 id="result-title">{outcomeTitle}</h2>
            {state.submitting && <p className="muted">{t('battle.submitting')}</p>}
            {result && (
              <div className="stack" style={{ gap: 10 }}>
                <b>{t('battle.rewards')}</b>
                <div className="reward-row">
                  <span className="pill" data-tone="gold">
                    <Icon name="coin" size={13} /> {t('battle.rewardGold', { gold: result.rewards.gold })}
                  </span>
                  <span className="pill" data-tone="primary">
                    {t('battle.rewardXp', { xp: result.rewards.xp })}
                  </span>
                </div>
                {result.rewards.firstWinBonus && <span className="muted small">{t('battle.firstWin', { gold: GameConfig.firstWinBonusGold })}</span>}
                {result.rewards.capped && <span className="muted small">{t('battle.capped')}</span>}
                {result.levelUp.levelsGained > 0 && (
                  <span className="pill" data-tone="success" style={{ justifySelf: 'center' }}>
                    {t('battle.levelUp', { level: result.user?.level ?? user?.level ?? 0 })}
                  </span>
                )}
              </div>
            )}
            {state.submitError && (
              <div className="stack" style={{ gap: 8 }}>
                <p className="banner" data-tone="danger">
                  {t('battle.resultFailed', { message: state.submitError })}
                </p>
                <button type="button" className="btn small squish" onClick={() => void session.retrySubmit()}>
                  <Icon name="refresh" size={16} /> {t('battle.retrySubmit')}
                </button>
              </div>
            )}
            <div className="row" style={{ justifyContent: 'center' }}>
              <button type="button" className="btn squish" data-tone="surface" onClick={() => router.replace('/')}>
                <Icon name="home" size={18} /> {t('battle.home')}
              </button>
              <button type="button" className="btn squish" disabled={rematching || state.submitting} onClick={() => void rematch()}>
                <Icon name="refresh" size={18} /> {t('battle.rematch')}
              </button>
            </div>
          </div>
        </div>
      )}
    </main>
  );
}

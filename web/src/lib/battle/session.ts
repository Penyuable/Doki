/**
 * Sesi pertandingan (port `features/battle/battle_cubit.dart`), tanpa React.
 * UI berlangganan lewat `subscribe`; semua angka berasal dari engine (I-05).
 */
import { BotAI, botSeedFor } from './bot-ai.ts';
import { BattleEngine, battleEngine } from './engine.ts';
import {
  CONCEDE,
  END_TURN,
  IllegalActionError,
  type AttackAction,
  type BattleAction,
  type BattleState,
  type PlayCardAction,
  type SetGuardAction,
  type UseAbilityAction,
} from './models.ts';
import type { BattleResultData, BattleStartData } from '../domain/models.ts';

export type BattleSessionState = {
  readonly battle: BattleState;
  readonly busy: boolean;
  readonly submitting: boolean;
  readonly result: BattleResultData | null;
  readonly submitError: string | null;
};

export type SubmitResult = (input: {
  matchId: string;
  outcome: string;
  turns: number;
  durationMs: number;
  logHash: string;
}) => Promise<BattleResultData>;

const BOT_DELAY_MS = 430;
const MAX_ACTIONS_PER_TURN = 80;

export class BattleSession {
  private readonly engine: BattleEngine;
  private readonly bot: BotAI;
  private readonly matchId: string;
  private readonly submitResult: SubmitResult;
  private readonly delay: (ms: number) => Promise<void>;
  private readonly botDelayMs: number;
  private readonly clock: () => number;
  private readonly startedAt: number;
  private readonly onResult: ((result: BattleResultData) => void) | null;
  private listeners = new Set<(state: BattleSessionState) => void>();
  private current: BattleSessionState;
  private botRunning = false;
  private stopRequested = false;
  private submitted = false;
  private closed = false;
  private finishedAt: number | null = null;

  constructor(options: {
    start: BattleStartData;
    submitResult: SubmitResult;
    onResult?: (result: BattleResultData) => void;
    engine?: BattleEngine;
    botDelayMs?: number;
    delay?: (ms: number) => Promise<void>;
    clock?: () => number;
  }) {
    this.engine = options.engine ?? battleEngine;
    this.matchId = options.start.matchId;
    this.submitResult = options.submitResult;
    this.onResult = options.onResult ?? null;
    this.delay = options.delay ?? ((ms) => new Promise((resolve) => setTimeout(resolve, ms)));
    this.clock = options.clock ?? (() => performance.now());
    this.startedAt = this.clock();
    this.bot = new BotAI({ difficulty: options.start.difficulty, seed: botSeedFor(options.start.seed), engine: this.engine });
    this.botDelayMs = options.botDelayMs ?? BOT_DELAY_MS;
    this.current = {
      battle: this.engine.start({
        playerDeck: options.start.playerDeck.cards,
        botDeck: options.start.botDeck.cards,
        seed: options.start.seed,
      }),
      busy: false,
      submitting: false,
      result: null,
      submitError: null,
    };
  }

  /** Mulai loop bot bila bot jalan duluan. Dipanggil sekali setelah UI siap. */
  begin(): void {
    if (this.current.battle.activeSide === 'bot' && !this.current.battle.isTerminal) void this.runBotLoop();
  }

  get state(): BattleSessionState {
    return this.current;
  }

  get battle(): BattleState {
    return this.current.battle;
  }

  subscribe(listener: (state: BattleSessionState) => void): () => void {
    this.listeners.add(listener);
    return () => {
      this.listeners.delete(listener);
    };
  }

  close(): void {
    this.closed = true;
    this.stopRequested = true;
    this.listeners.clear();
  }

  private emit(patch: Partial<BattleSessionState>): void {
    if (this.closed) return;
    this.current = { ...this.current, ...patch };
    for (const listener of this.listeners) listener(this.current);
  }

  private legalForPlayer(): BattleAction[] {
    if (this.current.busy || this.current.battle.isTerminal) return [];
    return this.engine.legalActions(this.current.battle, 'player');
  }

  playOptionsForHand(handIndex: number): PlayCardAction[] {
    return this.legalForPlayer().filter((a): a is PlayCardAction => a.kind === 'play' && a.handIndex === handIndex);
  }

  attackOptionsFor(unitId: string): AttackAction[] {
    return this.legalForPlayer().filter((a): a is AttackAction => a.kind === 'attack' && a.attackerId === unitId);
  }

  abilityOptionsFor(unitId: string): UseAbilityAction[] {
    return this.legalForPlayer().filter((a): a is UseAbilityAction => a.kind === 'ability' && a.unitId === unitId);
  }

  guardActionFor(unitId: string): SetGuardAction | null {
    return this.legalForPlayer().find((a): a is SetGuardAction => a.kind === 'guard' && a.unitId === unitId) ?? null;
  }

  /** Mengembalikan pesan error (null = aksi diterapkan). */
  perform(action: BattleAction): string | null {
    if (this.closed) return 'Sesi pertandingan sudah berakhir.';
    if (this.current.battle.isTerminal) return 'Pertandingan sudah selesai.';
    if (this.current.busy) return 'Tunggu bot menyelesaikan gilirannya.';
    try {
      const next = this.engine.apply(this.current.battle, action);
      this.emit({ battle: next, submitError: null });
      if (next.isTerminal) {
        void this.submit();
      } else if (next.activeSide === 'bot') {
        void this.runBotLoop();
      }
      return null;
    } catch (error) {
      if (error instanceof IllegalActionError) return error.reason;
      return 'Aksi gagal diterapkan.';
    }
  }

  endTurn(): string | null {
    return this.perform(END_TURN);
  }

  concede(): void {
    if (this.closed || this.current.battle.isTerminal) return;
    this.stopRequested = true;
    try {
      const next = this.engine.apply(this.current.battle, CONCEDE);
      this.emit({ battle: next, busy: false });
      void this.submit();
    } catch (error) {
      this.emit({ submitError: error instanceof IllegalActionError ? error.reason : 'Gagal menyerah.' });
    }
  }

  async retrySubmit(): Promise<void> {
    this.submitted = false;
    await this.submit();
  }

  private async runBotLoop(): Promise<void> {
    if (this.botRunning || this.closed) return;
    this.botRunning = true;
    this.emit({ busy: true });
    let actions = 0;

    while (!this.closed && !this.stopRequested) {
      const live = this.current.battle;
      if (live.isTerminal || live.activeSide !== 'bot') break;
      if (actions >= MAX_ACTIONS_PER_TURN) break;

      await this.delay(this.botDelayMs);
      if (this.closed || this.stopRequested) break;

      const latest = this.current.battle;
      if (latest.isTerminal || latest.activeSide !== 'bot') break;

      const action = this.bot.decide(latest, 'bot');
      let next: BattleState;
      try {
        next = this.engine.apply(latest, action);
      } catch {
        try {
          next = this.engine.apply(latest, END_TURN);
        } catch {
          break;
        }
      }
      actions += 1;
      this.emit({ battle: next, busy: !next.isTerminal && next.activeSide === 'bot' });
      if (next.isTerminal) break;
    }

    this.botRunning = false;
    if (this.closed) return;
    if (this.current.battle.isTerminal) {
      this.emit({ busy: false });
      await this.submit();
      return;
    }
    this.emit({ busy: false });
  }

  private async submit(): Promise<void> {
    if (this.closed || this.submitted || this.current.submitting) return;
    const battle = this.current.battle;
    const outcome = battle.outcome;
    if (outcome === null) return;

    this.submitted = true;
    this.finishedAt ??= this.clock();
    const turns = Math.max(1, Math.min(50, battle.turnNumber));
    const elapsed = Math.round(this.finishedAt - this.startedAt);
    const durationMs = Math.max(elapsed, turns * 500);

    this.emit({ submitting: true, submitError: null });
    try {
      const result = await this.submitResult({
        matchId: this.matchId,
        outcome,
        turns,
        durationMs,
        logHash: battle.logHash(),
      });
      if (this.closed) return;
      this.onResult?.(result);
      this.emit({ submitting: false, result });
    } catch (error) {
      this.submitted = false;
      if (this.closed) return;
      this.emit({
        submitting: false,
        submitError: error instanceof Error && error.message ? error.message : 'Hasil pertandingan gagal dikirim.',
      });
    }
  }
}

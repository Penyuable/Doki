'use client';

import { useEffect, useRef, useState } from 'react';
import { BattleSession, type BattleSessionState } from '@/lib/battle/session.ts';
import { fxFromEvents, type FxItem } from '@/lib/ui/battle-view.ts';
import type { BattleStartData } from '@/lib/domain/models.ts';
import { useApp } from '../providers/app-provider';

const FX_MS = 900;

/** Browser hanya mengizinkan vibrate setelah ada gestur pengguna (dan tidak di desktop/iOS). */
export function canVibrate(): boolean {
  if (typeof navigator === 'undefined' || typeof navigator.vibrate !== 'function') return false;
  const activation = (navigator as Navigator & { userActivation?: { hasBeenActive: boolean } }).userActivation;
  return activation ? activation.hasBeenActive : true;
}

/** Menghubungkan BattleSession (pure TS) ke React + efek visual dari event baru. */
export function useBattleSession(start: BattleStartData | null) {
  const { services, applyUser, applyWallet, settings } = useApp();
  const [session, setSession] = useState<BattleSession | null>(null);
  const [state, setState] = useState<BattleSessionState | null>(null);
  const [fx, setFx] = useState<FxItem[]>([]);
  const seen = useRef(0);
  const callbacks = useRef({ applyUser, applyWallet });
  callbacks.current = { applyUser, applyWallet };
  const fxEnabled = !settings.reduceMotion;
  const haptics = settings.haptics;

  useEffect(() => {
    if (!start) return;
    const next = new BattleSession({
      start,
      submitResult: (input) => services.repos.battle.submitResult(input),
      onResult: (result) => {
        if (result.user) callbacks.current.applyUser(result.user);
        else callbacks.current.applyWallet(result.balance);
      },
    });
    seen.current = next.battle.log.length;
    setSession(next);
    setState(next.state);
    setFx([]);
    const unsubscribe = next.subscribe(setState);
    next.begin();
    return () => {
      unsubscribe();
      next.close();
    };
  }, [start, services]);

  useEffect(() => {
    if (!state) return;
    const log = state.battle.log;
    if (log.length <= seen.current) {
      seen.current = log.length;
      return;
    }
    const fresh = fxFromEvents(log.slice(seen.current), seen.current);
    seen.current = log.length;
    if (fresh.length === 0) return;
    if (haptics && canVibrate()) navigator.vibrate(18);
    if (!fxEnabled) return;
    setFx((current) => [...current, ...fresh]);
    const keys = new Set(fresh.map((item) => item.key));
    window.setTimeout(() => setFx((current) => current.filter((item) => !keys.has(item.key))), FX_MS);
  }, [state, fxEnabled, haptics]);

  return { session, state, fx };
}

/**
 * Serah-terima data start match dari halaman setup (/battle) ke arena (/arena).
 * Sengaja in-memory: reload halaman arena = sesi berakhir (seperti app mobile
 * yang ditutup), dan match yang tidak dilaporkan kedaluwarsa di server.
 */
import type { BattleStartData } from '../domain/models.ts';

let pending: BattleStartData | null = null;

export function setPendingMatch(start: BattleStartData): void {
  pending = start;
}

export function takePendingMatch(): BattleStartData | null {
  return pending;
}

export function clearPendingMatch(matchId: string): void {
  if (pending?.matchId === matchId) pending = null;
}

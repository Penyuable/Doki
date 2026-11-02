export const WIB_OFFSET_MS = 7 * 60 * 60 * 1000;
export const DAY_MS = 24 * 60 * 60 * 1000;

/** Tanggal kalender WIB dalam format YYYY-MM-DD. */
export function wibDayKey(date: Date = new Date()): string {
  return new Date(date.getTime() + WIB_OFFSET_MS).toISOString().slice(0, 10);
}

/** 00:00 WIB pada hari `date`, dinyatakan sebagai Date UTC. */
export function startOfWibDayUtc(date: Date = new Date()): Date {
  return new Date(`${wibDayKey(date)}T00:00:00.000+07:00`);
}

export function isSameWibDay(a: Date | null | undefined, b: Date): boolean {
  if (!a) return false;
  return wibDayKey(a) === wibDayKey(b);
}

export function isYesterdayWib(previous: Date, now: Date): boolean {
  return wibDayKey(new Date(previous.getTime() + DAY_MS)) === wibDayKey(now);
}

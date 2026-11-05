/** Waktu relatif ("5 menit lalu") — `now` di-inject agar bisa dites. */
import type { Translator } from '../i18n/strings.ts';

export function relativeTime(date: Date | null, t: Translator, now: Date = new Date()): string {
  if (!date) return '—';
  const minutes = Math.floor((now.getTime() - date.getTime()) / 60000);
  if (minutes < 1) return t('time.justNow');
  if (minutes < 60) return t('time.minutesAgo', { count: minutes });
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return t('time.hoursAgo', { count: hours });
  return t('time.daysAgo', { count: Math.floor(hours / 24) });
}

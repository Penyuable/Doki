/** Ikon garis membulat (24×24), digambar sendiri — tanpa paket ikon eksternal. */
import type { CardElement } from '@/lib/domain/card.ts';

const PATHS = {
  home: 'M3 11.5 12 4l9 7.5M5.5 9.5V20h13V9.5M10 20v-5h4v5',
  cards: 'M7 3.5h10a2 2 0 0 1 2 2v13a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2v-13a2 2 0 0 1 2-2ZM9 8h6M9 12h6M9 16h3',
  deck: 'M4 8.5 12 4l8 4.5-8 4.5-8-4.5ZM4 12.5l8 4.5 8-4.5M4 16.5 12 21l8-4.5',
  gift: 'M4 10h16v10H4zM3 7h18v3H3zM12 7v13M12 7c-1.5-3.5-5.5-3.5-5.5-1S10 7 12 7Zm0 0c1.5-3.5 5.5-3.5 5.5-1S14 7 12 7Z',
  user: 'M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM4.5 20.5c1-4 4-6 7.5-6s6.5 2 7.5 6',
  settings:
    'M12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6ZM19.4 13.5l1.6 1.2-2 3.4-1.9-.7a7 7 0 0 1-2 1.2l-.3 2h-4l-.3-2a7 7 0 0 1-2-1.2l-1.9.7-2-3.4 1.6-1.2a7 7 0 0 1 0-3L2.6 9.3l2-3.4 1.9.7a7 7 0 0 1 2-1.2l.3-2h4l.3 2a7 7 0 0 1 2 1.2l1.9-.7 2 3.4-1.6 1.2a7 7 0 0 1 0 3Z',
  sword: 'M9.5 17.5 21 6V3h-3L6.5 14.5M11 19l-6-6M8 16l-4 4M5 21l-2-2',
  bolt: 'M13 2.5 4.5 13.5H11L10 21.5l8.5-11H12l1-8Z',
  heart: 'M12 20s-7.5-4.6-7.5-10A4.3 4.3 0 0 1 12 7.6 4.3 4.3 0 0 1 19.5 10c0 5.4-7.5 10-7.5 10Z',
  shield: 'M12 3 4.5 6v5.5c0 4.5 3.2 8 7.5 9.5 4.3-1.5 7.5-5 7.5-9.5V6L12 3Z',
  fire: 'M12 21c3.9 0 6.5-2.6 6.5-6.2 0-3.4-2.3-5.3-3.6-8.3-.7 2-1.7 3-2.9 3.5.3-2.8-.8-5.4-3.2-7-.2 3.4-3.3 5.6-3.3 10.6C5.5 18.4 8.1 21 12 21Z',
  water: 'M12 3s6.5 7 6.5 11.3A6.5 6.5 0 0 1 12 21a6.5 6.5 0 0 1-6.5-6.7C5.5 10 12 3 12 3Z',
  earth: 'M3 19.5 9 8l4 6.5 2.5-3.5 5.5 8.5H3Z',
  air: 'M3 9h11a3 3 0 1 0-3-3M3 15h15a3 3 0 1 1-3 3M3 12h8',
  void: 'M12 3.5l1.9 5.2 5.6.3-4.4 3.5 1.5 5.4L12 14.8l-4.6 3.1 1.5-5.4L4.5 9l5.6-.3L12 3.5Z',
  close: 'M6 6l12 12M18 6 6 18',
  flag: 'M5 21V4M5 4h11l-2 4 2 4H5',
  help: 'M12 21a9 9 0 1 0 0-18 9 9 0 0 0 0 18ZM9.5 9.5a2.5 2.5 0 1 1 3.5 2.3c-.6.3-1 .9-1 1.6v.6M12 17h.01',
  log: 'M7 4h10a1 1 0 0 1 1 1v15l-3-2-3 2-3-2-3 2V5a1 1 0 0 1 1-1ZM9 9h6M9 13h4',
  coin: 'M12 20.5a8.5 8.5 0 1 0 0-17 8.5 8.5 0 0 0 0 17ZM12 7.5v9M9.5 9.8c.4-1 1.4-1.6 2.5-1.6 1.4 0 2.5.9 2.5 2s-1 1.7-2.5 1.8-2.5.8-2.5 1.9 1.1 2 2.5 2c1.1 0 2.1-.6 2.5-1.6',
  gem: 'M6.5 4h11l3.5 5-9 11.5L3 9l3.5-5ZM3 9h18M9.5 4 12 9l2.5-5M12 9v11.5',
  plus: 'M12 5v14M5 12h14',
  minus: 'M5 12h14',
  trash: 'M4 7h16M10 7V4.5h4V7M6 7l1 13h10l1-13M10 11v6M14 11v6',
  edit: 'M4 20h4l11-11-4-4L4 16v4ZM13.5 6.5l4 4',
  check: 'M4.5 12.5 9.5 17.5 19.5 7',
  search: 'M10.5 18a7.5 7.5 0 1 0 0-15 7.5 7.5 0 0 0 0 15ZM16 16l5 5',
  back: 'M15 5l-7 7 7 7',
  refresh: 'M20 12a8 8 0 1 1-2.3-5.7M20 4v5h-5',
  logout: 'M15 4h3a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2h-3M10 8l-4 4 4 4M6 12h10',
  crown: 'M3.5 8 8 11.5 12 5l4 6.5L20.5 8 19 18H5L3.5 8Z',
  play: 'M7 4.5v15l12-7.5L7 4.5Z',
  filter: 'M3.5 5h17l-6.5 8v6l-4 1.5V13L3.5 5Z',
  sparkle: 'M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5 18 18M18 6l-2.5 2.5M8.5 15.5 6 18',
  target: 'M12 20.5a8.5 8.5 0 1 0 0-17 8.5 8.5 0 0 0 0 17ZM12 16a4 4 0 1 0 0-8 4 4 0 0 0 0 8ZM12 12h.01',
  person: 'M12 11.5a3.8 3.8 0 1 0 0-7.6 3.8 3.8 0 0 0 0 7.6ZM5 20c.9-3.5 3.7-5.5 7-5.5s6.1 2 7 5.5',
  trend: 'M3.5 17 9 11.5l4 4 7.5-8M15 7.5h5.5V13',
  freeze: 'M12 3v18M4.2 7.5l15.6 9M4.2 16.5l15.6-9M9.5 4.5 12 7l2.5-2.5M9.5 19.5 12 17l2.5 2.5',
  calendar: 'M4.5 6h15v14h-15zM4.5 10h15M8.5 3.5V7M15.5 3.5V7',
} as const;

export type IconName = keyof typeof PATHS;

export function Icon({ name, size = 22, className, strokeWidth = 2.2, label }: { name: IconName; size?: number; className?: string; strokeWidth?: number; label?: string }) {
  const filled = name === 'bolt' || name === 'play';
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill={filled ? 'currentColor' : 'none'}
      stroke="currentColor"
      strokeWidth={strokeWidth}
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
      role={label ? 'img' : undefined}
      aria-label={label}
      aria-hidden={label ? undefined : true}
      focusable="false"
    >
      <path d={PATHS[name]} />
    </svg>
  );
}

export const ELEMENT_ICON: Record<CardElement, IconName> = {
  Fire: 'fire',
  Water: 'water',
  Earth: 'earth',
  Air: 'air',
  Void: 'void',
};

export const ABILITY_ICON: Record<string, IconName> = {
  attack: 'bolt',
  heal: 'heart',
  buff: 'trend',
  control: 'freeze',
  shield: 'shield',
};

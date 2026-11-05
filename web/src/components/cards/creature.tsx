/**
 * Kreatur chibi kartun (SVG) — padanan web `core/ui/creature_avatar.dart`.
 * Spesies & palet ditentukan `speciesOf`/`PALETTES` (sama dengan mobile);
 * bentuk digambar ulang dengan SVG + animasi CSS (bob & kedip).
 */
import { memo, type CSSProperties, type ReactNode } from 'react';
import type { Card } from '@/lib/domain/card.ts';
import { rarityIndex } from '@/lib/domain/card.ts';
import { PALETTES, creatureSeed, speciesOf, type CreaturePalette, type Species } from '@/lib/ui/creature.ts';

const INK = '#1B1530';

type Parts = { p: CreaturePalette; line: string };

function Eyes({ y = 44, gap = 9, size = 1, p }: { y?: number; gap?: number; size?: number; p: CreaturePalette }) {
  return (
    <>
      {[50 - gap, 50 + gap].map((x) => (
        <g key={x} className="c-eye">
          <ellipse cx={x} cy={y} rx={4.6 * size} ry={5.6 * size} fill="#fff" stroke={INK} strokeWidth={1.4} />
          <circle cx={x + 0.6} cy={y + 0.8} r={3 * size} fill={INK} />
          <circle cx={x + 1.8} cy={y - 1} r={1.2 * size} fill="#fff" />
        </g>
      ))}
      <ellipse cx={50 - gap - 5} cy={y + 7} rx={3.4} ry={2} fill={p.accent === '#FFE066' ? '#FF9A8A' : '#FF8DB0'} opacity={0.5} />
      <ellipse cx={50 + gap + 5} cy={y + 7} rx={3.4} ry={2} fill={p.accent === '#FFE066' ? '#FF9A8A' : '#FF8DB0'} opacity={0.5} />
    </>
  );
}

const Smile = ({ y = 53, w = 4 }: { y?: number; w?: number }) => (
  <path d={`M${50 - w} ${y} Q50 ${y + 4} ${50 + w} ${y}`} fill="none" stroke={INK} strokeWidth={1.8} strokeLinecap="round" />
);

function RoundBody({ p, line, headR = 21, headY = 44, bodyRx = 21, bodyRy = 17 }: Parts & { headR?: number; headY?: number; bodyRx?: number; bodyRy?: number }) {
  return (
    <>
      <ellipse cx={50} cy={69} rx={bodyRx} ry={bodyRy} fill={p.base} stroke={line} strokeWidth={2.2} />
      <ellipse cx={50} cy={73} rx={bodyRx * 0.58} ry={bodyRy * 0.6} fill={p.light} opacity={0.9} />
      <ellipse cx={37} cy={84} rx={6} ry={4} fill={p.base} stroke={line} strokeWidth={2} />
      <ellipse cx={63} cy={84} rx={6} ry={4} fill={p.base} stroke={line} strokeWidth={2} />
      <circle cx={50} cy={headY} r={headR} fill={p.base} stroke={line} strokeWidth={2.2} />
      <ellipse cx={43} cy={headY - headR * 0.55} rx={7} ry={3.2} fill="#fff" opacity={0.45} transform={`rotate(-20 43 ${headY - headR * 0.55})`} />
    </>
  );
}

function speciesArt(species: Species, parts: Parts): ReactNode {
  const { p, line } = parts;
  switch (species) {
    case 'dog':
      return (
        <>
          <RoundBody {...parts} />
          <path d="M31 30 Q22 40 27 54 Q34 50 35 38Z" fill={p.dark} stroke={line} strokeWidth={2} />
          <path d="M69 30 Q78 40 73 54 Q66 50 65 38Z" fill={p.dark} stroke={line} strokeWidth={2} />
          <Eyes p={p} />
          <ellipse cx={50} cy={51} rx={3.4} ry={2.4} fill={INK} />
          <Smile y={55} />
        </>
      );
    case 'bear':
      return (
        <>
          <circle cx={33} cy={27} r={7} fill={p.base} stroke={line} strokeWidth={2} />
          <circle cx={67} cy={27} r={7} fill={p.base} stroke={line} strokeWidth={2} />
          <circle cx={33} cy={27} r={3.4} fill={p.light} />
          <circle cx={67} cy={27} r={3.4} fill={p.light} />
          <RoundBody {...parts} bodyRx={23} />
          <ellipse cx={50} cy={52} rx={8} ry={6} fill={p.light} />
          <Eyes p={p} y={43} />
          <ellipse cx={50} cy={50} rx={3} ry={2.2} fill={INK} />
          <Smile y={54} w={3} />
        </>
      );
    case 'pig':
      return (
        <>
          <RoundBody {...parts} bodyRx={23} bodyRy={18} />
          <path d="M32 28 L28 18 L40 25Z" fill={p.dark} stroke={line} strokeWidth={2} strokeLinejoin="round" />
          <path d="M68 28 L72 18 L60 25Z" fill={p.dark} stroke={line} strokeWidth={2} strokeLinejoin="round" />
          <Eyes p={p} y={41} />
          <ellipse cx={50} cy={51} rx={8} ry={5.6} fill={p.light} stroke={line} strokeWidth={1.8} />
          <ellipse cx={47} cy={51} rx={1.4} ry={2} fill={INK} />
          <ellipse cx={53} cy={51} rx={1.4} ry={2} fill={INK} />
          <path d="M71 70 q8 -2 6 6 q-2 4 3 4" fill="none" stroke={line} strokeWidth={2} strokeLinecap="round" />
        </>
      );
    case 'bunny':
      return (
        <>
          <ellipse cx={40} cy={16} rx={5.5} ry={15} fill={p.base} stroke={line} strokeWidth={2} transform="rotate(-10 40 16)" />
          <ellipse cx={60} cy={16} rx={5.5} ry={15} fill={p.base} stroke={line} strokeWidth={2} transform="rotate(10 60 16)" />
          <ellipse cx={40} cy={17} rx={2.4} ry={10} fill={p.light} transform="rotate(-10 40 17)" />
          <ellipse cx={60} cy={17} rx={2.4} ry={10} fill={p.light} transform="rotate(10 60 17)" />
          <RoundBody {...parts} headR={20} headY={46} />
          <Eyes p={p} y={46} />
          <path d="M48 52 L52 52 L50 54.5Z" fill={INK} />
          <path d="M50 54.5 v2.5 M50 57 q-3 2 -5 0 M50 57 q3 2 5 0" fill="none" stroke={INK} strokeWidth={1.5} strokeLinecap="round" />
        </>
      );
    case 'cat':
      return (
        <>
          <path d="M71 74 q14 -6 10 -20" fill="none" stroke={line} strokeWidth={5} strokeLinecap="round" />
          <path d="M71 74 q14 -6 10 -20" fill="none" stroke={p.base} strokeWidth={2.4} strokeLinecap="round" />
          <RoundBody {...parts} />
          <path d="M31 33 L33 17 L45 26Z" fill={p.base} stroke={line} strokeWidth={2} strokeLinejoin="round" />
          <path d="M69 33 L67 17 L55 26Z" fill={p.base} stroke={line} strokeWidth={2} strokeLinejoin="round" />
          <path d="M35 29 L35.5 21 L41 26Z" fill={p.light} />
          <path d="M65 29 L64.5 21 L59 26Z" fill={p.light} />
          <Eyes p={p} />
          <path d="M48 51 L52 51 L50 53Z" fill={INK} />
          <path d="M50 53 q-2.5 2.5 -4.5 0.5 M50 53 q2.5 2.5 4.5 0.5" fill="none" stroke={INK} strokeWidth={1.4} strokeLinecap="round" />
          <path d="M28 50 h-8 M28 53 l-7 2 M72 50 h8 M72 53 l7 2" stroke={INK} strokeWidth={1.2} strokeLinecap="round" />
        </>
      );
    case 'bird':
      return (
        <>
          <path d="M28 64 Q12 58 16 74 Q24 76 31 72Z" fill={p.dark} stroke={line} strokeWidth={2} />
          <path d="M72 64 Q88 58 84 74 Q76 76 69 72Z" fill={p.dark} stroke={line} strokeWidth={2} />
          <RoundBody {...parts} bodyRx={19} />
          <path d="M44 25 Q47 12 50 23 Q53 12 56 25" fill={p.accent} stroke={line} strokeWidth={2} strokeLinejoin="round" />
          <Eyes p={p} y={42} />
          <path d="M45 50 L55 50 L50 57Z" fill="#FFB547" stroke={line} strokeWidth={1.8} strokeLinejoin="round" />
        </>
      );
    case 'dino':
      return (
        <>
          <path d="M70 76 Q88 78 90 66 Q80 70 68 66Z" fill={p.base} stroke={line} strokeWidth={2} />
          <path d="M38 24 l4 -8 l4 7 l4 -9 l4 9 l4 -7 l4 8" fill={p.accent} stroke={line} strokeWidth={1.8} strokeLinejoin="round" />
          <RoundBody {...parts} />
          <Eyes p={p} />
          <path d="M43 52 Q50 58 57 52" fill="#fff" stroke={INK} strokeWidth={1.6} />
          <path d="M46 53 l1 2 l1 -1.6 M52 53 l1 1.6 l1 -2" fill="none" stroke={INK} strokeWidth={1} />
          <circle cx={36} cy={66} r={2} fill={p.dark} opacity={0.5} />
          <circle cx={64} cy={64} r={2.4} fill={p.dark} opacity={0.5} />
        </>
      );
    case 'dragon':
      return (
        <>
          <path d="M30 58 L8 44 L14 60 L6 66 L28 70Z" fill={p.dark} stroke={line} strokeWidth={2} strokeLinejoin="round" />
          <path d="M70 58 L92 44 L86 60 L94 66 L72 70Z" fill={p.dark} stroke={line} strokeWidth={2} strokeLinejoin="round" />
          <path d="M70 78 Q86 82 88 70" fill="none" stroke={line} strokeWidth={5} strokeLinecap="round" />
          <path d="M70 78 Q86 82 88 70" fill="none" stroke={p.base} strokeWidth={2.4} strokeLinecap="round" />
          <RoundBody {...parts} />
          <path d="M36 28 Q32 16 38 12 Q38 20 42 24Z" fill={p.accent} stroke={line} strokeWidth={1.8} />
          <path d="M64 28 Q68 16 62 12 Q62 20 58 24Z" fill={p.accent} stroke={line} strokeWidth={1.8} />
          <Eyes p={p} />
          <circle cx={47} cy={51} r={1.1} fill={INK} />
          <circle cx={53} cy={51} r={1.1} fill={INK} />
          <Smile y={55} w={5} />
        </>
      );
    case 'turtle':
      return (
        <>
          <ellipse cx={50} cy={70} rx={30} ry={18} fill={p.dark} stroke={line} strokeWidth={2.2} />
          <path d="M28 66 Q50 48 72 66" fill="none" stroke={p.accent} strokeWidth={2} />
          <path d="M40 58 L44 70 L56 70 L60 58" fill="none" stroke={p.accent} strokeWidth={2} />
          <ellipse cx={30} cy={86} rx={6} ry={4} fill={p.base} stroke={line} strokeWidth={2} />
          <ellipse cx={70} cy={86} rx={6} ry={4} fill={p.base} stroke={line} strokeWidth={2} />
          <circle cx={50} cy={42} r={18} fill={p.base} stroke={line} strokeWidth={2.2} />
          <Eyes p={p} y={41} gap={8} />
          <Smile y={50} />
        </>
      );
    case 'golem':
      return (
        <>
          <rect x={26} y={56} width={48} height={30} rx={9} fill={p.base} stroke={line} strokeWidth={2.2} />
          <rect x={16} y={60} width={12} height={20} rx={5} fill={p.dark} stroke={line} strokeWidth={2} />
          <rect x={72} y={60} width={12} height={20} rx={5} fill={p.dark} stroke={line} strokeWidth={2} />
          <rect x={30} y={24} width={40} height={34} rx={10} fill={p.base} stroke={line} strokeWidth={2.2} />
          <path d="M36 30 l5 5 l-2 6 M64 64 l-6 5 l2 6 M60 28 l-3 4" fill="none" stroke={p.dark} strokeWidth={1.6} strokeLinecap="round" />
          <circle cx={56} cy={70} r={3} fill={p.accent} opacity={0.8} />
          <Eyes p={p} y={40} gap={8} />
          <path d="M44 50 h12" stroke={INK} strokeWidth={2} strokeLinecap="round" />
        </>
      );
    case 'serpent':
      return (
        <>
          <ellipse cx={50} cy={80} rx={28} ry={8} fill={p.base} stroke={line} strokeWidth={2.2} />
          <ellipse cx={50} cy={70} rx={22} ry={8} fill={p.base} stroke={line} strokeWidth={2.2} />
          <ellipse cx={50} cy={70} rx={12} ry={3.5} fill={p.light} opacity={0.8} />
          <path d="M58 62 Q62 52 54 46" fill="none" stroke={line} strokeWidth={13} strokeLinecap="round" />
          <path d="M58 62 Q62 52 54 46" fill="none" stroke={p.base} strokeWidth={9} strokeLinecap="round" />
          <ellipse cx={50} cy={40} rx={18} ry={15} fill={p.base} stroke={line} strokeWidth={2.2} />
          <Eyes p={p} y={38} gap={7} />
          <path d="M50 49 v5 l-2 2 M50 54 l2 2" fill="none" stroke="#F2617F" strokeWidth={1.6} strokeLinecap="round" />
        </>
      );
    case 'sprite':
      return (
        <>
          <ellipse cx={26} cy={46} rx={14} ry={9} fill={p.light} opacity={0.75} stroke={line} strokeWidth={1.6} transform="rotate(-25 26 46)" />
          <ellipse cx={74} cy={46} rx={14} ry={9} fill={p.light} opacity={0.75} stroke={line} strokeWidth={1.6} transform="rotate(25 74 46)" />
          <ellipse cx={50} cy={70} rx={13} ry={12} fill={p.base} stroke={line} strokeWidth={2.2} />
          <circle cx={50} cy={44} r={19} fill={p.base} stroke={line} strokeWidth={2.2} />
          <path d="M44 26 Q40 16 34 15 M56 26 Q60 16 66 15" fill="none" stroke={line} strokeWidth={1.8} strokeLinecap="round" />
          <circle cx={34} cy={15} r={2.6} fill={p.accent} stroke={line} strokeWidth={1.2} />
          <circle cx={66} cy={15} r={2.6} fill={p.accent} stroke={line} strokeWidth={1.2} />
          <Eyes p={p} y={44} gap={8} size={1.08} />
          <Smile y={53} w={3} />
        </>
      );
    case 'bug':
      return (
        <>
          <ellipse cx={50} cy={68} rx={24} ry={18} fill={p.dark} stroke={line} strokeWidth={2.2} />
          <path d="M50 52 V86" stroke={line} strokeWidth={1.8} />
          <circle cx={40} cy={66} r={4} fill={p.accent} />
          <circle cx={60} cy={72} r={4} fill={p.accent} />
          <circle cx={42} cy={78} r={2.6} fill={p.accent} />
          <path d="M28 76 l-8 6 M72 76 l8 6 M30 64 l-9 0 M70 64 l9 0" stroke={line} strokeWidth={2} strokeLinecap="round" />
          <circle cx={50} cy={42} r={17} fill={p.base} stroke={line} strokeWidth={2.2} />
          <path d="M44 27 Q40 16 33 14 M56 27 Q60 16 67 14" fill="none" stroke={line} strokeWidth={1.8} strokeLinecap="round" />
          <circle cx={33} cy={14} r={2.4} fill={line} />
          <circle cx={67} cy={14} r={2.4} fill={line} />
          <Eyes p={p} y={42} gap={7} />
          <Smile y={50} w={3} />
        </>
      );
  }
}

function ElementMark({ element, p, line }: { element: Card['element'] } & Parts) {
  switch (element) {
    case 'Fire':
      return <path d="M50 7 Q57 14 54 19 Q58 18 58 14 Q63 21 56 26 Q50 29 45 26 Q39 21 44 14 Q45 18 48 19 Q45 13 50 7Z" fill={p.accent} stroke={line} strokeWidth={1.4} />;
    case 'Water':
      return <path d="M50 9 Q56 17 56 21 a6 6 0 0 1 -12 0 Q44 17 50 9Z" fill={p.accent} stroke={line} strokeWidth={1.4} />;
    case 'Earth':
      return (
        <>
          <path d="M50 24 V14" stroke={line} strokeWidth={2} strokeLinecap="round" />
          <path d="M50 16 Q42 8 38 14 Q44 19 50 16Z M50 14 Q58 6 62 12 Q56 17 50 14Z" fill="#7DD35A" stroke={line} strokeWidth={1.4} />
        </>
      );
    case 'Air':
      return <path d="M40 16 q6 -6 12 0 q4 4 8 0 M44 21 q4 -3 8 0" fill="none" stroke={p.accent} strokeWidth={2.6} strokeLinecap="round" />;
    case 'Void':
      return <path d="M50 8 l2.4 5.6 6 .5 -4.6 3.9 1.4 5.9 -5.2 -3.2 -5.2 3.2 1.4 -5.9 -4.6 -3.9 6 -.5Z" fill={p.accent} stroke={line} strokeWidth={1.2} />;
  }
}

export type CreatureProps = { card: Card; size?: number | string; animate?: boolean; turn?: 'left' | 'right'; className?: string };

function CreatureImpl({ card, size = '100%', animate = true, turn, className }: CreatureProps) {
  const p = PALETTES[card.element];
  const line = p.dark;
  const species = speciesOf(card);
  const seed = creatureSeed(card.id);
  const tier = rarityIndex(card.rarity);
  const hover = species === 'sprite';
  const style = {
    '--bob': `${(2.4 + (seed % 900) / 1000).toFixed(2)}s`,
    '--blink': `${(3.6 + (seed % 1700) / 1000).toFixed(2)}s`,
  } as CSSProperties;

  const markFree = !['bird', 'sprite', 'dragon', 'bunny', 'bug', 'serpent', 'cat', 'turtle', 'dino'].includes(species);

  return (
    <svg
      viewBox="0 0 100 100"
      width={size}
      height={size}
      className={`${animate ? 'creature-anim' : ''} ${className ?? ''}`}
      style={style}
      role="img"
      aria-label={card.name}
    >
      <ellipse cx={50} cy={93} rx={hover ? 16 : 27} ry={hover ? 2.6 : 4} fill="rgba(43,39,82,0.16)" />
      <g className="c-body" transform={turn === 'left' ? 'translate(100 0) scale(-1 1)' : undefined}>
        <g transform={hover ? 'translate(0 -4)' : undefined}>
          {speciesArt(species, { p, line })}
          {markFree && tier < 4 && <ElementMark element={card.element} p={p} line={line} />}
          {tier >= 4 && (
            <path
              d="M40 11 L43 3 L47 9 L50 1 L53 9 L57 3 L60 11Z"
              fill={tier === 5 ? '#FF6BD6' : '#FFD54A'}
              stroke={INK}
              strokeWidth={1.4}
              strokeLinejoin="round"
              transform="translate(0 -1)"
            />
          )}
        </g>
      </g>
    </svg>
  );
}

export const Creature = memo(CreatureImpl);

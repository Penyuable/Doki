/** Pemilihan spesies & palet kreatur (port bagian data `core/ui/creature_avatar.dart`). */
import type { Card, CardElement } from '../domain/card.ts';

export const SPECIES = ['dino', 'dragon', 'bird', 'pig', 'dog', 'bear', 'bunny', 'cat', 'turtle', 'golem', 'serpent', 'sprite', 'bug'] as const;
export type Species = (typeof SPECIES)[number];

export type CreaturePalette = { light: string; base: string; dark: string; accent: string };

export const PALETTES: Record<CardElement, CreaturePalette> = {
  Fire: { light: '#FFD39A', base: '#FF7A3D', dark: '#B2341A', accent: '#FFE066' },
  Water: { light: '#BDEBFF', base: '#3FA9F5', dark: '#1B559C', accent: '#7FFFE0' },
  Earth: { light: '#DDF2A6', base: '#8BBF4A', dark: '#486B22', accent: '#A67C52' },
  Air: { light: '#FFFFFF', base: '#DCE6F7', dark: '#8396BD', accent: '#9BE7FF' },
  Void: { light: '#DCD0FF', base: '#8E6CF0', dark: '#38227F', accent: '#FF6BD6' },
};

/** Kata kunci nama kartu → spesies (urutan penting: yang lebih spesifik dulu). */
const SPECIES_KEYWORDS: ReadonlyArray<[readonly string[], Species]> = [
  [['drake', 'dragon', 'wyvern'], 'dragon'],
  [['dino', 'saur', 'rex', 'raptor', 'titan'], 'dino'],
  [['phoenix', 'griffon', 'bird', 'hawk', 'sovereign', 'wisp', 'owl'], 'bird'],
  [['pig', 'boar', 'hog', 'cinder'], 'pig'],
  [['pup', 'dog', 'hound', 'wolf'], 'dog'],
  [['cub', 'bear'], 'bear'],
  [['hare', 'bunny', 'rabbit', 'hop'], 'bunny'],
  [['stalker', 'cat', 'panther', 'lynx'], 'cat'],
  [['turtle', 'tortoise', 'shell', 'tidal warden'], 'turtle'],
  [['golem', 'sentinel', 'warden', 'colossus', 'giant'], 'golem'],
  [['serpent', 'snake', 'wyrm', 'naga'], 'serpent'],
  [['sprite', 'nymph', 'fairy', 'devil', 'pixie'], 'sprite'],
  [['mite', 'beetle', 'bug', 'moth'], 'bug'],
];

const FALLBACK: readonly Species[] = ['pig', 'dino', 'bird', 'dog', 'bunny', 'cat', 'bear'];

/** Hash FNV-1a 32-bit dari id kartu (sama dengan `creatureSeed` Dart). */
export function creatureSeed(id: string): number {
  let hash = 0x811c9dc5;
  for (let i = 0; i < id.length; i += 1) {
    hash ^= id.charCodeAt(i);
    hash = Math.imul(hash, 0x01000193) >>> 0;
  }
  return hash >>> 0;
}

export function speciesOf(card: Pick<Card, 'id' | 'name'>): Species {
  const name = card.name.toLowerCase();
  for (const [keywords, species] of SPECIES_KEYWORDS) {
    if (keywords.some((keyword) => name.includes(keyword))) return species;
  }
  return FALLBACK[creatureSeed(card.id) % FALLBACK.length]!;
}

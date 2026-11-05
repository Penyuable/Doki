/** Model kartu (port `domain/models/card_model.dart`). Entity domain, bukan DTO mentah. */
import { asBool, asInt, asIntOrNull, asList, asMap, asString, asStringOrNull, enumFrom } from '../core/json.ts';

export const ELEMENTS = ['Fire', 'Water', 'Earth', 'Air', 'Void'] as const;
export type CardElement = (typeof ELEMENTS)[number];

export const RARITIES = ['Common', 'Uncommon', 'Rare', 'Epic', 'Legendary', 'Master'] as const;
export type Rarity = (typeof RARITIES)[number];

export const CARD_TYPES = ['unit', 'spell'] as const;
export type CardType = (typeof CARD_TYPES)[number];

export type CardAbilityStatus = { kind: string; value: number; turns: number };

export type CardAbility = {
  name: string;
  type: string;
  cost: number;
  target: string;
  power: number;
  text: string;
  status: CardAbilityStatus | null;
};

export type Card = {
  id: string;
  name: string;
  element: CardElement;
  rarity: Rarity;
  type: CardType;
  cost: number;
  hp: number | null;
  attack: number | null;
  defense: number | null;
  keywords: readonly string[];
  ability: CardAbility | null;
  flavorText: string;
  imageUrl: string;
  thumbnailUrl: string | null;
  model3dUrl: string | null;
  obtainable: boolean;
  retired: boolean;
  version: number;
};

export const elementSlug = (element: CardElement): string => element.toLowerCase();
export const rarityIndex = (rarity: Rarity): number => RARITIES.indexOf(rarity);
export const isRarePlus = (rarity: Rarity): boolean => rarityIndex(rarity) >= rarityIndex('Rare');
export const isUnit = (card: Card): boolean => card.type === 'unit';
export const hasKeyword = (card: Card, keyword: string): boolean => card.keywords.includes(keyword);

export function requiresUnitTarget(ability: CardAbility): boolean {
  return ability.target === 'enemy_unit' || ability.target === 'any_unit' || ability.target === 'self';
}

function parseAbility(raw: unknown): CardAbility | null {
  const json = asMap(raw);
  if (Object.keys(json).length === 0) return null;
  const statusJson = asMap(json.status);
  return {
    name: asString(json.name),
    type: asString(json.type, 'attack'),
    cost: asInt(json.cost),
    target: asString(json.target, 'enemy_unit'),
    power: asInt(json.power),
    text: asString(json.text),
    status:
      Object.keys(statusJson).length === 0
        ? null
        : { kind: asString(statusJson.kind), value: asInt(statusJson.value), turns: asInt(statusJson.turns, 1) },
  };
}

export function parseCard(raw: unknown): Card | null {
  if (raw === null || typeof raw !== 'object' || Array.isArray(raw)) return null;
  const json = asMap(raw);
  const id = asString(json.id);
  if (!id) return null;
  const keywords = [
    ...new Set(
      asList(json.keywords)
        .map((value) => asString(value).toLowerCase())
        .filter((value) => value.length > 0),
    ),
  ];
  return {
    id,
    name: asString(json.name, id),
    element: enumFrom(json.element, ELEMENTS, 'Void'),
    rarity: enumFrom(json.rarity, RARITIES, 'Common'),
    type: enumFrom(json.type, CARD_TYPES, 'unit'),
    cost: asInt(json.cost),
    hp: asIntOrNull(json.hp),
    attack: asIntOrNull(json.attack),
    defense: asIntOrNull(json.defense),
    keywords,
    ability: parseAbility(json.ability),
    flavorText: asString(json.flavorText),
    imageUrl: asString(json.imageUrl),
    thumbnailUrl: asStringOrNull(json.thumbnailUrl),
    model3dUrl: asStringOrNull(json.model3dUrl),
    obtainable: asBool(json.obtainable, true),
    retired: asBool(json.retired),
    version: asInt(json.version, 1),
  };
}

export function parseCards(raw: unknown): Card[] {
  return asList(raw)
    .map(parseCard)
    .filter((card): card is Card => card !== null);
}

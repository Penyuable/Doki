import { z } from 'zod';
import { RARITIES } from '../../config/economy.js';

export const ELEMENTS = ['Fire', 'Water', 'Earth', 'Air', 'Void'] as const;
export type Element = (typeof ELEMENTS)[number];

export const CARD_TYPES = ['unit', 'spell'] as const;
export const KEYWORDS = ['charge', 'pierce', 'lifesteal'] as const;
export const ABILITY_TYPES = ['attack', 'heal', 'buff', 'control', 'shield'] as const;
export const ABILITY_TARGETS = [
  'enemy_unit',
  'any_unit',
  'self',
  'all_enemy_units',
  'all_allies',
  'enemy_player',
] as const;
export const STATUS_KINDS = ['burn', 'freeze', 'shield', 'rally'] as const;

export const statusSchema = z
  .object({
    kind: z.enum(STATUS_KINDS),
    value: z.number().int().min(0).max(200),
    turns: z.number().int().min(1).max(3),
  })
  .strict();

export const abilitySchema = z
  .object({
    name: z.string().min(2).max(40),
    type: z.enum(ABILITY_TYPES),
    cost: z.number().int().min(0).max(10),
    target: z.enum(ABILITY_TARGETS),
    power: z.number().int().min(0).max(300),
    status: statusSchema.nullable().optional(),
    text: z.string().min(5).max(160),
  })
  .strict();

export const cardSchema = z
  .object({
    id: z.string().regex(/^card_[a-z0-9_]{3,32}$/),
    name: z.string().min(1).max(40),
    element: z.enum(ELEMENTS),
    rarity: z.enum(RARITIES),
    type: z.enum(CARD_TYPES),
    cost: z.number().int().min(0).max(10),
    hp: z.number().int().min(0).max(999).nullable(),
    attack: z.number().int().min(0).max(999).nullable(),
    defense: z.number().int().min(0).max(999).nullable(),
    keywords: z.array(z.enum(KEYWORDS)).max(3),
    ability: abilitySchema.nullable(),
    flavorText: z.string().max(200).optional(),
    imageUrl: z.string().url().max(500),
    thumbnailUrl: z.string().url().max(500).optional(),
    model3dUrl: z.string().url().max(500).nullable().optional(),
    obtainable: z.boolean(),
    retired: z.boolean().optional(),
    version: z.number().int().min(1),
  })
  .strict()
  .superRefine((card, ctx) => {
    if (card.type === 'unit') {
      if (card.hp === null || card.hp < 1) {
        ctx.addIssue({ code: 'custom', path: ['hp'], message: 'Unit wajib punya hp >= 1' });
      }
      if (card.attack === null || card.defense === null) {
        ctx.addIssue({
          code: 'custom',
          path: ['attack'],
          message: 'Unit wajib punya attack & defense',
        });
      }
    } else {
      if (card.hp !== null || card.attack !== null || card.defense !== null) {
        ctx.addIssue({
          code: 'custom',
          path: ['hp'],
          message: 'Spell harus punya hp/attack/defense null',
        });
      }
      if (!card.ability) {
        ctx.addIssue({ code: 'custom', path: ['ability'], message: 'Spell wajib punya ability' });
      }
    }
  });

export const cardCatalogSchema = z.array(cardSchema).min(1);

export const manifestSchema = z
  .object({
    schemaVersion: z.number().int().min(1),
    catalogVersion: z.string().min(1).max(40),
    updatedAt: z.string().min(1),
    cardCount: z.number().int().min(1),
    checksum: z.string().regex(/^sha256:[a-f0-9]{64}$/),
    baseAssetUrl: z.string().url(),
  })
  .strict();

export type Card = z.infer<typeof cardSchema>;
export type Ability = z.infer<typeof abilitySchema>;
export type Manifest = z.infer<typeof manifestSchema>;

export function crossValidate(cards: Card[]): string[] {
  const problems: string[] = [];
  const ids = new Set<string>();
  for (const card of cards) {
    if (ids.has(card.id)) problems.push(`id duplikat: ${card.id}`);
    ids.add(card.id);
  }
  const obtainable = cards.filter((c) => c.obtainable && !c.retired);
  for (const rarity of RARITIES) {
    if (!obtainable.some((c) => c.rarity === rarity)) {
      // bukan error: gacha akan fallback ke rarity di bawahnya
      continue;
    }
  }
  if (obtainable.length < 6) problems.push('minimal 6 kartu obtainable');
  return problems;
}

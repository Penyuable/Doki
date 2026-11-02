import { Router } from 'express';
import { z } from 'zod';
import { wrap } from '../../lib/async.js';
import { authGuard, userIdOf } from '../../middleware/auth.js';
import { parse } from '../../lib/validate.js';
import * as deck from './deck.service.js';

export const deckRouter = Router();
deckRouter.use(authGuard);

const entrySchema = z
  .object({
    cardId: z.string().min(3).max(40),
    quantity: z.number().int().min(1).max(99),
  })
  .strict();

const cardsSchema = z.array(entrySchema).max(60);

const nameSchema = z.string().trim().min(3, 'Nama deck 3–24 karakter').max(24);

const createSchema = z
  .object({
    name: nameSchema,
    cards: cardsSchema,
  })
  .strict();

const updateSchema = z
  .object({
    name: nameSchema.optional(),
    cards: cardsSchema.optional(),
  })
  .strict()
  .refine((v) => v.name !== undefined || v.cards !== undefined, {
    message: 'Kirim minimal satu field: name atau cards',
  });

const validateSchema = z.object({ cards: cardsSchema }).strict();

deckRouter.get(
  '/',
  wrap(async (_req, res) => {
    const decks = await deck.listDecks(userIdOf(res));
    res.json({ data: { decks }, meta: { requestId: res.locals.requestId } });
  }),
);

deckRouter.post(
  '/',
  wrap(async (req, res) => {
    const input = parse(createSchema, req.body);
    const created = await deck.createDeck(userIdOf(res), input);
    res.status(201).json({ data: { deck: created }, meta: { requestId: res.locals.requestId } });
  }),
);

deckRouter.post(
  '/validate',
  wrap(async (req, res) => {
    const input = parse(validateSchema, req.body);
    const validation = await deck.validateOnly(userIdOf(res), input.cards);
    res.json({ data: validation, meta: { requestId: res.locals.requestId } });
  }),
);

deckRouter.get(
  '/:id',
  wrap(async (req, res) => {
    const found = await deck.getDeck(userIdOf(res), String(req.params.id));
    res.json({ data: { deck: found }, meta: { requestId: res.locals.requestId } });
  }),
);

deckRouter.patch(
  '/:id',
  wrap(async (req, res) => {
    const input = parse(updateSchema, req.body);
    const updated = await deck.updateDeck(userIdOf(res), String(req.params.id), input);
    res.json({ data: { deck: updated }, meta: { requestId: res.locals.requestId } });
  }),
);

deckRouter.delete(
  '/:id',
  wrap(async (req, res) => {
    await deck.deleteDeck(userIdOf(res), String(req.params.id));
    res.status(204).send();
  }),
);

deckRouter.put(
  '/:id/activate',
  wrap(async (req, res) => {
    const active = await deck.activateDeck(userIdOf(res), String(req.params.id));
    res.json({
      data: { activeDeckId: active.id, deck: active },
      meta: { requestId: res.locals.requestId },
    });
  }),
);

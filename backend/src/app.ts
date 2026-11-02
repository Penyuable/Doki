import express from 'express';
import helmet from 'helmet';
import cors from 'cors';
import { env } from './config/env.js';
import { requestId } from './middleware/requestId.js';
import { errorHandler, notFoundHandler } from './middleware/error.js';
import { globalLimiter } from './middleware/rateLimit.js';
import { authRouter } from './modules/auth/auth.routes.js';
import { userRouter } from './modules/user/user.routes.js';
import { catalogRouter } from './modules/catalog/catalog.routes.js';
import { gachaRouter } from './modules/gacha/gacha.routes.js';
import { inventoryRouter } from './modules/inventory/inventory.routes.js';
import { deckRouter } from './modules/deck/deck.routes.js';
import { battleRouter } from './modules/battle/battle.routes.js';
import { telemetryRouter } from './modules/telemetry/telemetry.routes.js';
import { peekSnapshot } from './modules/catalog/catalog.service.js';

export function createApp() {
  const app = express();

  app.set('trust proxy', 1);
  app.disable('x-powered-by');

  app.use(requestId);
  app.use(helmet());
  app.use(
    cors({
      origin: env.corsOrigins.length > 0 ? env.corsOrigins : true,
      methods: ['GET', 'POST', 'PATCH', 'PUT', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization', 'X-Request-Id'],
      exposedHeaders: ['X-Request-Id', 'ETag', 'Retry-After'],
      maxAge: 600,
    }),
  );
  app.use(express.json({ limit: '64kb' }));
  app.use(globalLimiter);

  app.get('/healthz', (_req, res) => {
    res.json({
      status: 'ok',
      service: 'dokimon-api',
      version: '1.0.0',
      environment: env.NODE_ENV,
      catalogVersion: peekSnapshot()?.version ?? null,
      time: new Date().toISOString(),
    });
  });

  app.get('/', (_req, res) => {
    res.json({
      data: {
        name: 'Dokimon TCG 3D API',
        version: '1.0.0',
        docs: '/api/v1/catalog/manifest',
        health: '/healthz',
      },
    });
  });

  app.use('/api/v1/auth', authRouter);
  app.use('/api/v1/user', userRouter);
  app.use('/api/v1/catalog', catalogRouter);
  app.use('/api/v1/gacha', gachaRouter);
  app.use('/api/v1/inventory', inventoryRouter);
  app.use('/api/v1/decks', deckRouter);
  app.use('/api/v1/battles', battleRouter);
  app.use('/api/v1/telemetry', telemetryRouter);

  app.use(notFoundHandler);
  app.use(errorHandler);

  return app;
}

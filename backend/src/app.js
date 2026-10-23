import express from 'express';
import { config } from './config/env.js';
import { query } from './db/pool.js';
import { errorHandler, notFound } from './middleware/error.js';
import { requestId } from './middleware/request-id.js';
import { routes } from './modules/routes.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.set('trust proxy', config.trustProxy);
  app.use(requestId);
  app.use(express.json({ limit: '100kb' }));
  // ponytail: permissive CORS for the Flutter web client; tighten origin when deployed.
  app.use((req, res, next) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type, Idempotency-Key',
    );
    res.setHeader(
      'Access-Control-Allow-Methods',
      'GET, POST, PATCH, PUT, DELETE, OPTIONS',
    );
    if (req.method === 'OPTIONS') return res.sendStatus(204);
    next();
  });

  app.get('/healthz', async (_req, res) => {
    await query('SELECT 1');
    res.json({ ok: true });
  });
  app.use(routes);

  app.use(notFound);
  app.use(errorHandler);
  return app;
}

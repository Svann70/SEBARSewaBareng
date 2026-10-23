import { Router } from 'express';
import { config } from '../../config/env.js';
import { rateLimit } from '../../middleware/rate-limit.js';
import * as controller from './users.controller.js';

// Mounted at /me (auth required).
export const usersRoutes = Router();

// Password change burns scrypt twice (verify + hash), so it gets the same cheap cutoff
// as login before the expensive work starts.
const scryptRoutes = rateLimit({ windowMs: 60_000, max: config.authRateLimit });

usersRoutes.get('/', controller.me);
usersRoutes.patch('/', controller.updateMe);
usersRoutes.post('/password', scryptRoutes, controller.changePassword);

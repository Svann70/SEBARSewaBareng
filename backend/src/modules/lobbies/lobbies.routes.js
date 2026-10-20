import { Router } from 'express';
import { requireRole } from '../../middleware/auth.js';
import * as controller from './lobbies.controller.js';

// Mounted at /lobbies (auth required). Only players create or join; venue accounts can only browse.
export const lobbiesRoutes = Router();

lobbiesRoutes.get('/', controller.list);
lobbiesRoutes.post('/', requireRole('PLAYER'), controller.create);
lobbiesRoutes.get('/:id', controller.detail);
lobbiesRoutes.post('/:id/join', requireRole('PLAYER'), controller.join);
lobbiesRoutes.delete('/:id/members/me', controller.leave);
lobbiesRoutes.delete('/:id', controller.cancel);

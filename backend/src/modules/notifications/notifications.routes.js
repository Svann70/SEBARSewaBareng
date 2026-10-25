import { Router } from 'express';
import * as controller from './notifications.controller.js';

// Mounted at /me/notifications (auth required): in-app notifications of the signed-in user.
export const notificationsRoutes = Router();

notificationsRoutes.get('/', controller.list);
notificationsRoutes.post('/read', controller.readAll);

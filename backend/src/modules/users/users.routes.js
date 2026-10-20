import { Router } from 'express';
import * as controller from './users.controller.js';

// Mounted at /me (auth required).
export const usersRoutes = Router();

usersRoutes.get('/', controller.me);

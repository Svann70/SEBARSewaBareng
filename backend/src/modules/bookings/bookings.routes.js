import { Router } from 'express';
import * as controller from './bookings.controller.js';

// Mounted at /me/bookings (auth required).
export const bookingsRoutes = Router();

bookingsRoutes.get('/', controller.listMine);

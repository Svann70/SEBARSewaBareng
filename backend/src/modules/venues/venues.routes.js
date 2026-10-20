import { Router } from 'express';
import * as controller from './venues.controller.js';

// Mounted at /venues (auth required). Player-facing catalogue.
export const venuesRoutes = Router();

venuesRoutes.get('/', controller.list);
venuesRoutes.get('/:id/slots', controller.listSlots);

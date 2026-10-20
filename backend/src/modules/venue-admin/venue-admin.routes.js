import { Router } from 'express';
import * as controller from './venue-admin.controller.js';

// Mounted at /venue (auth + VENUE_ADMIN required).
export const venueAdminRoutes = Router();

venueAdminRoutes.get('/venues', controller.listVenues);
venueAdminRoutes.get('/slots', controller.listSlots);
venueAdminRoutes.post('/slots', controller.createSlot);
venueAdminRoutes.patch('/slots/:id', controller.updateSlot);

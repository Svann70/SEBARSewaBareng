import express, { Router } from 'express';
import * as controller from './venue-admin.controller.js';

// Mounted at /venue (auth + VENUE_ADMIN required).
export const venueAdminRoutes = Router();

venueAdminRoutes.get('/venues', controller.listVenues);
venueAdminRoutes.post('/venues', controller.createVenue);
venueAdminRoutes.patch('/venues/:id', controller.updateVenue);
venueAdminRoutes.post('/courts', controller.createCourt);
venueAdminRoutes.patch('/courts/:id', controller.updateCourt);
// Body = the image bytes. The type is checked from the bytes (lib/image.js), not this header.
venueAdminRoutes.post(
  '/courts/:id/photos',
  express.raw({ type: ['image/*', 'application/octet-stream'], limit: '5mb' }),
  controller.addPhoto,
);
venueAdminRoutes.delete('/courts/:id/photos/:photoId', controller.deletePhoto);
venueAdminRoutes.get('/slots', controller.listSlots);
venueAdminRoutes.post('/slots', controller.createSlot);
venueAdminRoutes.patch('/slots/:id', controller.updateSlot);
venueAdminRoutes.get('/checkins', controller.listCheckins);
venueAdminRoutes.post('/checkins/scan', controller.scanCheckin);

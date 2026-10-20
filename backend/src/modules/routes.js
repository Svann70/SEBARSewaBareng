import { Router } from 'express';
import { requireAuth, requireRole } from '../middleware/auth.js';
import { authRoutes } from './auth/auth.routes.js';
import { bookingsRoutes } from './bookings/bookings.routes.js';
import { lobbiesRoutes } from './lobbies/lobbies.routes.js';
import { usersRoutes } from './users/users.routes.js';
import { venueAdminRoutes } from './venue-admin/venue-admin.routes.js';
import { venuesRoutes } from './venues/venues.routes.js';
import { walletRoutes } from './wallet/wallet.routes.js';

// Single map of every endpoint group and the guard in front of it.
export const routes = Router();

routes.use('/auth', authRoutes);
routes.use('/me/wallet', requireAuth, walletRoutes);
routes.use('/me/bookings', requireAuth, bookingsRoutes);
routes.use('/me', requireAuth, usersRoutes);
routes.use('/venues', requireAuth, venuesRoutes);
routes.use('/venue', requireAuth, requireRole('VENUE_ADMIN'), venueAdminRoutes);
routes.use('/lobbies', requireAuth, lobbiesRoutes);

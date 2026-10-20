import { Router } from 'express';
import * as controller from './wallet.controller.js';

// Mounted at /me/wallet (auth required).
export const walletRoutes = Router();

walletRoutes.get('/', controller.get);
walletRoutes.post('/topup', controller.topup);
walletRoutes.get('/ledger', controller.ledger);

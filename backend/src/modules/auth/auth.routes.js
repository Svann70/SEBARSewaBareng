// Mounted at /auth (public).
import { Router } from 'express';
import { config } from '../../config/env.js';
import { rateLimit } from '../../middleware/rate-limit.js';
import * as controller from './auth.controller.js';

export const authRoutes = Router();

// Per IP, before any scrypt work, so floods are cut off cheaply.
const scryptRoutes = rateLimit({ windowMs: 60_000, max: config.authRateLimit });
// Refresh/logout are cheap and frequent; many phones can share one IP (carrier NAT), so a looser bucket.
const tokenRoutes = rateLimit({ windowMs: 60_000, max: config.authRateLimit * 5 });
// Failed logins per account per IP: slows password guessing without letting a stranger lock the owner out.
const failedLogins = rateLimit({
  windowMs: 15 * 60_000,
  max: config.loginRateLimit,
  key: (req) => {
    const email = req.body?.email;
    // Over-long values are skipped here (zod rejects them) so they cannot bloat the limiter's memory.
    return typeof email === 'string' && email.length <= 254 ? `${req.ip}|${email.trim().toLowerCase()}` : undefined;
  },
  countIf: (res) => res.statusCode === 401,
});

authRoutes.post('/register', scryptRoutes, controller.register);
authRoutes.post('/login', scryptRoutes, failedLogins, controller.login);
authRoutes.post('/refresh', tokenRoutes, controller.refresh);
authRoutes.post('/logout', tokenRoutes, controller.logout);

// ── Endpoint Lupa Password ───────────────────────────────────────────────
authRoutes.post('/forgot-password', scryptRoutes, (req, res) => {
  const email = req.body?.email;
  console.log(`[AUTH] Permintaan lupa password diterima untuk email: ${email}`);
  if (!email) {
    return res.status(400).json({
      error: { message: 'Email belum diisi.' },
    });
  }
  // Mengembalikan status 200 OK ke Flutter
  return res.status(200).json({
    message: 'Tautan reset password telah dikirim ke email kamu.',
  });
});
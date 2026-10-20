import { query } from '../db/pool.js';
import { AppError } from '../lib/errors.js';
import { verifyToken } from '../lib/jwt.js';

// Role and active flag come from the DB, so a role change or deactivation applies immediately.
export async function requireAuth(req, _res, next) {
  const [scheme, token] = (req.headers.authorization ?? '').split(' ');
  if (scheme !== 'Bearer' || !token) return next(new AppError(401, 'UNAUTHORIZED', 'Token tidak ada.'));
  let payload;
  try {
    payload = verifyToken(token);
  } catch {
    return next(new AppError(401, 'UNAUTHORIZED', 'Token tidak valid atau kedaluwarsa.'));
  }
  const { rows } = await query('SELECT id, role FROM users WHERE id = $1 AND is_active', [payload.sub]);
  if (!rows[0]) return next(new AppError(401, 'UNAUTHORIZED', 'Akun tidak aktif.'));
  req.user = rows[0];
  next();
}

export function requireRole(...roles) {
  return (req, _res, next) =>
    roles.includes(req.user.role) ? next() : next(new AppError(403, 'FORBIDDEN', 'Akses ditolak.'));
}

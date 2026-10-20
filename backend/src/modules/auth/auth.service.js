import crypto from 'node:crypto';
import { config } from '../../config/env.js';
import { query, tx } from '../../db/pool.js';
import { AppError } from '../../lib/errors.js';
import { signToken } from '../../lib/jwt.js';
import { hashPassword, verifyPassword } from '../../lib/password.js';

// Burns the same scrypt time for unknown emails so login timing does not reveal which emails exist.
const dummyHash = await hashPassword('dummy-password-for-timing');

const sha256 = (value) => crypto.createHash('sha256').update(value).digest('hex');
const invalidRefresh = () => new AppError(401, 'UNAUTHORIZED', 'Refresh token tidak valid atau kedaluwarsa.');
// A rotated token presented again within this window is a client race (two parallel refreshes), not theft.
const REUSE_GRACE_SECONDS = 10;

// Creates the user, their wallet and (for venue accounts) their venue together.
export async function register({ email, password, fullName, phone, role, venue }) {
  const passwordHash = await hashPassword(password);
  return tx(async (c) => {
    const { rows } = await c.query(
      `INSERT INTO users (email, phone, full_name, password_hash, role) VALUES ($1, $2, $3, $4, $5)
       ON CONFLICT DO NOTHING RETURNING *`,
      [email, phone ?? null, fullName, passwordHash, role],
    );
    const user = rows[0];
    if (!user) throw new AppError(409, 'CONFLICT', 'Email atau nomor telepon sudah dipakai.');
    await c.query('INSERT INTO wallets (user_id) VALUES ($1)', [user.id]);
    if (venue) {
      await c.query('INSERT INTO venues (owner_id, name, address, city, description) VALUES ($1, $2, $3, $4, $5)', [
        user.id,
        venue.name,
        venue.address,
        venue.city,
        venue.description ?? null,
      ]);
    }
    return { user, tokens: await issueTokens(c, user.id) };
  });
}

export async function login({ email, password, role }) {
  const { rows } = await query('SELECT * FROM users WHERE email = $1 AND is_active', [email]);
  const user = rows[0];
  const ok = await verifyPassword(password, user?.password_hash ?? dummyHash);
  if (!user || !ok) throw new AppError(401, 'UNAUTHORIZED', 'Email atau password salah.');
  // Checked only after the password, so it reveals nothing to someone who does not own the account.
  if (role && user.role !== role && user.role !== 'SUPER_ADMIN') {
    const where = user.role === 'VENUE_ADMIN' ? 'Venue' : 'Pemain';
    throw new AppError(403, 'WRONG_ACCOUNT_TYPE', `Ini akun ${where}. Masuk lewat tab ${where}.`, { role: user.role });
  }
  return { user, tokens: await tx((c) => issueTokens(c, user.id)) };
}

// New refresh token. Login/register start a family that lives REFRESH_TTL_DAYS; rotations inherit
// its expiry, so a session has an absolute lifetime and a stolen token cannot be kept alive forever.
async function issueTokens(c, userId, family) {
  const refreshToken = crypto.randomBytes(32).toString('base64url');
  const { rows } = await c.query(
    `INSERT INTO refresh_tokens (user_id, family_id, token_hash, expires_at)
     VALUES ($1, $2, $3, COALESCE($5::timestamptz, now() + make_interval(days => $4))) RETURNING id, expires_at`,
    [userId, family?.id ?? crypto.randomUUID(), sha256(refreshToken), config.refreshTtlDays, family?.expiresAt ?? null],
  );
  return { id: rows[0].id, accessToken: signToken(userId), refreshToken, refreshExpiresAt: rows[0].expires_at };
}

// Rotation: each refresh token works once. Presenting a token that was already rotated means it was
// stolen (or replayed), so the whole family is revoked and both holders must log in again.
export async function refresh(refreshToken) {
  const result = await tx(async (c) => {
    const { rows } = await c.query(
      `SELECT r.*, r.expires_at <= now() AS expired, u.is_active,
              r.revoked_at > now() - make_interval(secs => $2) AS just_rotated
         FROM refresh_tokens r JOIN users u ON u.id = r.user_id
        WHERE r.token_hash = $1 FOR UPDATE OF r`,
      [sha256(refreshToken), REUSE_GRACE_SECONDS],
    );
    const current = rows[0];
    if (!current) return { error: invalidRefresh() };
    if (current.revoked_at) {
      if (!current.just_rotated) await revokeFamily(c, current.family_id);
      return { error: invalidRefresh() };
    }
    if (current.expired || !current.is_active) return { error: invalidRefresh() };
    const tokens = await issueTokens(c, current.user_id, { id: current.family_id, expiresAt: current.expires_at });
    await c.query('UPDATE refresh_tokens SET revoked_at = now(), replaced_by = $2 WHERE id = $1', [current.id, tokens.id]);
    return { tokens };
  });
  // Thrown after commit so the family revocation above is not rolled back.
  if (result.error) throw result.error;
  return result.tokens;
}

async function revokeFamily(c, familyId) {
  await c.query('UPDATE refresh_tokens SET revoked_at = now() WHERE family_id = $1 AND revoked_at IS NULL', [familyId]);
}

// Ends this device's session. Idempotent: an unknown or already revoked token is not an error.
export async function logout(refreshToken) {
  await tx(async (c) => {
    // Lock first (waits for an in-flight refresh of this token), then revoke in a later statement
    // so the UPDATE also sees the replacement token that refresh just committed.
    const { rows } = await c.query('SELECT family_id FROM refresh_tokens WHERE token_hash = $1 FOR UPDATE', [sha256(refreshToken)]);
    if (!rows[0]) return;
    // Also lock the rest of the family, so a refresh of a newer token in it finishes first.
    await c.query('SELECT 1 FROM refresh_tokens WHERE family_id = $1 FOR UPDATE', [rows[0].family_id]);
    await revokeFamily(c, rows[0].family_id);
  });
}

// Expired tokens are useless (also for reuse detection), so the job deletes them.
export async function purgeExpiredRefreshTokens() {
  await query('DELETE FROM refresh_tokens WHERE expires_at < now()');
}

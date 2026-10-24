import { query } from '../../db/pool.js';
import { AppError } from '../../lib/errors.js';
import { hashPassword, verifyPassword } from '../../lib/password.js';

export async function getById(id) {
  const { rows } = await query('SELECT * FROM users WHERE id = $1', [id]);
  return rows[0];
}

// Patch update: only the fields present change. phone: null clears it.
export async function update(id, patch) {
  const sets = [];
  const args = [id];
  if (patch.fullName !== undefined) {
    args.push(patch.fullName);
    sets.push(`full_name = $${args.length}`);
  }
  if (patch.phone !== undefined) {
    args.push(patch.phone ?? null);
    sets.push(`phone = $${args.length}`);
  }
  if (sets.length === 0) return getById(id);
  try {
    const { rows } = await query(
      `UPDATE users SET ${sets.join(', ')} WHERE id = $1 RETURNING *`,
      args,
    );
    return rows[0];
  } catch (err) {
    // users.phone is UNIQUE (01_users.sql): a number already registered elsewhere is a conflict, not a crash.
    if (err.code === '23505') throw new AppError(409, 'CONFLICT', 'Nomor telepon sudah dipakai akun lain.');
    throw err;
  }
}

// Verifies the current password, re-hashes, then revokes every refresh token of the user:
// a stolen session cannot survive a password change, all devices must log in again.
export async function changePassword(id, { currentPassword, newPassword }) {
  const user = await getById(id);
  const ok = await verifyPassword(currentPassword, user?.password_hash ?? '');
  if (!user || !ok) throw new AppError(401, 'UNAUTHORIZED', 'Password saat ini salah.');
  const passwordHash = await hashPassword(newPassword);
  await query('UPDATE users SET password_hash = $2 WHERE id = $1', [id, passwordHash]);
  await query(
    'UPDATE refresh_tokens SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL',
    [id],
  );
}

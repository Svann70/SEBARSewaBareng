import { config } from '../../config/env.js';
import { query, tx } from '../../db/pool.js';
import { AppError } from '../../lib/errors.js';

export const PAGE_SIZE = 20;

// Top-up is the one money movement without a DB function, so it is written here.
// `key` must already be namespaced: wallet_ledger.idempotency_key is unique across all users.
export async function creditTopup(c, userId, amount, key) {
  const { rows } = await c.query(
    `UPDATE wallets SET balance = balance + $2, version = version + 1 WHERE user_id = $1 RETURNING id, balance, held_balance`,
    [userId, amount],
  );
  const w = rows[0];
  const entry = await c.query(
    `INSERT INTO wallet_ledger (wallet_id, entry_type, amount, balance_after, held_after, ref_type, idempotency_key)
     VALUES ($1, 'TOPUP', $2, $3, $4, 'TOPUP', $5) RETURNING *`,
    [w.id, amount, w.balance, w.held_balance, key],
  );
  return entry.rows[0];
}

// Client keys are prefixed with the user id so two users can never collide on the global unique index.
const ledgerKey = (userId, key) => `TOPUP:${userId}:${key}`;

export async function getWallet(userId) {
  const { rows } = await query('SELECT * FROM wallets WHERE user_id = $1', [userId]);
  return rows[0];
}

// A reused key must carry the same request; otherwise the client has a bug and gets no silent no-op.
function sameRequest(entry, amount) {
  if (entry.entry_type !== 'TOPUP' || entry.amount !== amount) {
    throw new AppError(422, 'IDEMPOTENCY_KEY_REUSED', 'Idempotency-Key sudah dipakai untuk request lain.');
  }
  return { entry, created: false };
}

async function findByKey(userId, key) {
  const { rows } = await query(
    `SELECT l.* FROM wallet_ledger l JOIN wallets w ON w.id = l.wallet_id
      WHERE w.user_id = $1 AND l.idempotency_key = $2`,
    [userId, ledgerKey(userId, key)],
  );
  return rows[0];
}

// Sandbox top-up (no payment gateway in v1). Returns { entry, created }; a repeated key returns the first entry.
export async function topup(userId, amount, key) {
  if (!config.allowSandboxTopup) throw new AppError(403, 'FORBIDDEN', 'Top up sandbox dimatikan.');
  const existing = await findByKey(userId, key);
  if (existing) return sameRequest(existing, amount);
  try {
    const entry = await tx((c) => creditTopup(c, userId, amount, ledgerKey(userId, key)));
    return { entry, created: true };
  } catch (err) {
    // Two concurrent requests with the same key: the loser returns the winner's entry.
    if (err.code === '23505' && err.constraint === 'wallet_ledger_idempotency_key_key') return sameRequest(await findByKey(userId, key), amount);
    throw err;
  }
}

export async function listLedger(userId, page) {
  const { rows } = await query(
    `SELECT l.* FROM wallet_ledger l JOIN wallets w ON w.id = l.wallet_id
      WHERE w.user_id = $1 ORDER BY l.created_at DESC, l.id LIMIT $2 OFFSET $3`,
    [userId, PAGE_SIZE, (page - 1) * PAGE_SIZE],
  );
  return rows;
}

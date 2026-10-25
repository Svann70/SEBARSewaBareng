import { query } from '../../db/pool.js';

const LIMIT = 50;

export async function listMine(userId) {
  const { rows } = await query(
    `SELECT id, type, payload, read_at, created_at, count(*) FILTER (WHERE read_at IS NULL) OVER ()::int AS unread
       FROM notifications WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2`,
    [userId, LIMIT],
  );
  return rows;
}

export async function markAllRead(userId) {
  const { rowCount } = await query('UPDATE notifications SET read_at = now() WHERE user_id = $1 AND read_at IS NULL', [userId]);
  return rowCount;
}

import { query, tx } from '../../db/pool.js';
import { AppError } from '../../lib/errors.js';
import { onDateWib } from '../../lib/sql.js';
import { cancelLobby, JOIN_CUTOFF_HOURS, joinLobby, leaveLobby } from './membership.service.js';

export const PAGE_SIZE = 20;
const MAX_ACTIVE_HOSTED = 3;

const LOBBY_SELECT = `
  SELECT l.*, s.start_at, s.end_at, c.name AS court_name, c.sport_type, v.id AS venue_id, v.name AS venue_name, v.city,
         (SELECT count(*)::int FROM lobby_members m WHERE m.lobby_id = l.id AND m.status IN ('HOLDING', 'CONFIRMED')) AS joined
    FROM lobbies l
    JOIN court_slots s ON s.id = l.slot_id
    JOIN courts c ON c.id = s.court_id
    JOIN venues v ON v.id = c.venue_id`;

export async function list({ city, sport, date, minScore, page }) {
  const where = [`l.status = 'OPEN'`, 'l.join_deadline > now()'];
  const params = [];
  // Values are always bound as parameters; only the fixed SQL fragments are concatenated.
  const add = (sql, value) => {
    params.push(value);
    where.push(sql.replace('?', `$${params.length}`));
  };
  if (city) add('lower(v.city) = lower(?)', city);
  if (sport) add('c.sport_type = ?', sport);
  if (date) add(onDateWib('s.start_at', '?'), date);
  if (minScore !== undefined) add('l.min_reliability <= ?', minScore);
  params.push(PAGE_SIZE, (page - 1) * PAGE_SIZE);
  const { rows } = await query(
    `${LOBBY_SELECT} WHERE ${where.join(' AND ')} ORDER BY s.start_at, l.id LIMIT $${params.length - 1} OFFSET $${params.length}`,
    params,
  );
  return rows;
}

export async function getById(id) {
  const { rows } = await query(`${LOBBY_SELECT} WHERE l.id = $1`, [id]);
  if (!rows[0]) throw new AppError(404, 'NOT_FOUND', 'Lobby tidak ditemukan.');
  return rows[0];
}

export async function listMembers(lobbyId) {
  const { rows } = await query(
    `SELECT m.user_id, m.role_in_lobby, m.status, u.full_name, u.reliability_score
       FROM lobby_members m JOIN users u ON u.id = m.user_id
      WHERE m.lobby_id = $1 AND m.status IN ('HOLDING', 'CONFIRMED') ORDER BY m.joined_at`,
    [lobbyId],
  );
  return rows;
}

// The hold trigger only says "insufficient"; add the numbers the app shows in its top-up sheet (SDD §8.4).
// `requiredSql` returns one row with column `required` from params [$1 = userId, ...rest].
async function withBalanceDetails(fn, requiredSql, params) {
  try {
    return await fn();
  } catch (err) {
    if (err.code !== 'P0001' || err.message !== 'SEBAR::INSUFFICIENT_AVAILABLE_BALANCE') throw err;
    const { rows } = await query(
      `SELECT (${requiredSql}) AS required, balance - held_balance AS available FROM wallets WHERE user_id = $1`,
      params,
    );
    throw new AppError(409, 'INSUFFICIENT_AVAILABLE_BALANCE', 'Saldo tersedia tidak cukup.', rows[0]);
  }
}

// Creates the lobby and joins the host (with hold) in one transaction: no balance = no lobby.
export async function create(hostId, { slotId, title, quota, minReliability }) {
  const lobbyId = await withBalanceDetails(() => createTx(hostId, { slotId, title, quota, minReliability }),
    'SELECT ceil(price / $3) FROM court_slots WHERE id = $2', [hostId, slotId, quota]);
  return getById(lobbyId);
}

function createTx(hostId, { slotId, title, quota, minReliability }) {
  return tx(async (c) => {
    // Cap open lobbies per host so one account cannot squat every slot. The wallet lock makes the count race-free.
    await c.query('SELECT 1 FROM wallets WHERE user_id = $1 FOR UPDATE', [hostId]);
    const hosted = await c.query(`SELECT count(*)::int AS n FROM lobbies WHERE host_id = $1 AND status = 'OPEN'`, [hostId]);
    if (hosted.rows[0].n >= MAX_ACTIVE_HOSTED) {
      throw new AppError(409, 'CONFLICT', `Maksimal ${MAX_ACTIVE_HOSTED} lobby aktif per host.`);
    }
    const found = await c.query(
      `SELECT s.*, c.capacity, s.start_at - make_interval(hours => $2) AS join_deadline,
              s.start_at - make_interval(hours => $2) <= now() AS too_late
         FROM court_slots s
         JOIN courts c ON c.id = s.court_id AND c.status = 'ACTIVE'
         JOIN venues v ON v.id = c.venue_id AND v.status = 'ACTIVE'
        WHERE s.id = $1 FOR UPDATE OF s`,
      [slotId, JOIN_CUTOFF_HOURS],
    );
    const slot = found.rows[0];
    if (!slot) throw new AppError(404, 'NOT_FOUND', 'Slot tidak ditemukan.');
    if (slot.status !== 'OPEN') throw new AppError(409, 'SLOT_NOT_OPEN', 'Slot tidak tersedia.');
    if (quota > slot.capacity) throw new AppError(422, 'VALIDATION_ERROR', `Kuota maksimal lapangan ini ${slot.capacity}.`);

    if (slot.too_late) {
      throw new AppError(422, 'VALIDATION_ERROR', `Lobby harus dibuat paling lambat ${JOIN_CUTOFF_HOURS} jam sebelum main.`);
    }
    let lobby;
    try {
      const { rows } = await c.query(
        `INSERT INTO lobbies (slot_id, host_id, title, min_reliability, quota, price_total, join_deadline)
         VALUES ($1, $2, $3, $4, $5, $6, $7) RETURNING *`,
        [slot.id, hostId, title, minReliability, quota, slot.price, slot.join_deadline],
      );
      lobby = rows[0];
    } catch (err) {
      if (err.code === '23505' && err.constraint === 'uq_lobbies_active_slot') {
        throw new AppError(409, 'CONFLICT', 'Slot ini sudah punya lobby aktif.');
      }
      throw err;
    }
    await joinLobby(c, lobby.id, hostId, 'HOST');
    return lobby.id;
  });
}

export const join = (lobbyId, userId) =>
  withBalanceDetails(() => tx((c) => joinLobby(c, lobbyId, userId)), 'SELECT price_per_person FROM lobbies WHERE id = $2', [userId, lobbyId]);
export const leave = (lobbyId, userId) => tx((c) => leaveLobby(c, lobbyId, userId));
export const cancel = (lobbyId, userId) => tx((c) => cancelLobby(c, lobbyId, userId));

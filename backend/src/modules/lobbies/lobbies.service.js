import { query, tx } from '../../db/pool.js';
import { AppError } from '../../lib/errors.js';
import { onDateWib } from '../../lib/sql.js';
import { ACTIVE_LOBBY } from '../venues/slots.shared.js';
import { cancelLobby, JOIN_CUTOFF_HOURS, joinLobby, leaveLobby } from './membership.service.js';

export const PAGE_SIZE = 20;
const MAX_ACTIVE_HOSTED = 3;

const LOBBY_SELECT = `
  SELECT l.*, s.start_at, s.end_at, c.name AS court_name, COALESCE(l.sport_type, c.sport_type) AS sport_type, v.id AS venue_id, v.name AS venue_name, v.city,
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
  if (sport) add('COALESCE(l.sport_type, c.sport_type) = ?', sport);
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
export async function create(hostId, input) {
  const { slotId, courtId, startAt, hours, quota } = input;
  const lobbyId = await withBalanceDetails(
    () => createTx(hostId, input),
    ...(slotId
      ? ['SELECT ceil(price / $3) FROM court_slots WHERE id = $2', [hostId, slotId, quota]]
      : [`SELECT ceil(${RATE_SQL} * $5 / $3) FROM courts c WHERE c.id = $2`, [hostId, courtId, quota, startAt, hours]]),
  );
  return getById(lobbyId);
}

// Hourly rate of court `c` for a start time `$4` (timestamptz): weekend price on Saturday/Sunday WIB.
const RATE_SQL = `(CASE WHEN extract(isodow FROM ($4::timestamptz AT TIME ZONE 'Asia/Jakarta')) >= 6
                        THEN COALESCE(c.price_weekend, c.price_per_hour) ELSE c.price_per_hour END)`;

const MAX_DAYS_AHEAD = 60;

// Slot for a room on any free hour inside the court's opening hours. Rooms always pay the court
// rate (one-time setup). Leftover OPEN slots without an active room (opened by hand, or left by a
// cancelled/expired room) only mark hours as free: unused ones are deleted, ones a past room still
// references are released (kept for history, ignored by the overlap rule and the schedule).
async function slotForHours(c, { courtId, startAt, hours }) {
  const start = new Date(startAt);
  if (start.getTime() % 3600_000 !== 0) {
    throw new AppError(422, 'VALIDATION_ERROR', 'Jam mulai harus tepat di awal jam (mis. 16:00).');
  }
  if (start.getTime() > Date.now() + MAX_DAYS_AHEAD * 86_400_000) {
    throw new AppError(422, 'VALIDATION_ERROR', `Room hanya bisa dibuat maksimal ${MAX_DAYS_AHEAD} hari ke depan.`);
  }
  const end = new Date(start.getTime() + hours * 3600_000);
  // Locking the court makes concurrent rooms on one court take turns between the overlap check and the insert.
  const found = await c.query(
    `SELECT ${RATE_SQL} * $5 AS price,
            ($2::timestamptz AT TIME ZONE 'Asia/Jakarta')::time >= c.open_time
              AND ($3::timestamptz AT TIME ZONE 'Asia/Jakarta') <= ($2::timestamptz AT TIME ZONE 'Asia/Jakarta')::date + c.close_time
              AS in_hours
       FROM courts c JOIN venues v ON v.id = c.venue_id AND v.status = 'ACTIVE'
      WHERE c.id = $1 AND c.status = 'ACTIVE' FOR UPDATE OF c`,
    [courtId, start.toISOString(), end.toISOString(), start.toISOString(), hours],
  );
  const court = found.rows[0];
  if (!court) throw new AppError(404, 'NOT_FOUND', 'Lapangan tidak ditemukan.');
  if (!court.in_hours) throw new AppError(422, 'VALIDATION_ERROR', 'Jam main di luar jam buka lapangan.');

  // Lock first, then check lobbies in a second statement: a check inside the locking statement would
  // keep the snapshot from before the lock wait and miss a lobby committed meanwhile.
  const locked = await c.query(
    `SELECT s.id FROM court_slots s
      WHERE s.court_id = $1 AND NOT s.released AND tstzrange(s.start_at, s.end_at) && tstzrange($2, $3)
        FOR UPDATE OF s`,
    [courtId, start.toISOString(), end.toISOString()],
  );
  const overlap = await c.query(
    `SELECT s.id, s.status, ${ACTIVE_LOBBY} AS active,
            EXISTS (SELECT 1 FROM lobbies l WHERE l.slot_id = s.id) AS referenced
       FROM court_slots s WHERE s.id = ANY($1::uuid[])`,
    [locked.rows.map((r) => r.id)],
  );
  if (overlap.rows.some((s) => s.status === 'BLOCKED')) {
    throw new AppError(409, 'SLOT_NOT_OPEN', 'Jam ini ditutup pengelola lapangan. Pilih jam lain.');
  }
  if (overlap.rows.some((s) => s.status !== 'OPEN' || s.active)) {
    throw new AppError(409, 'SLOT_NOT_OPEN', 'Jam ini sudah terisi. Pilih jam lain.');
  }
  const ids = (pick) => overlap.rows.filter(pick).map((s) => s.id);
  await c.query('DELETE FROM court_slots WHERE id = ANY($1::uuid[])', [ids((s) => !s.referenced)]);
  await c.query('UPDATE court_slots SET released = true WHERE id = ANY($1::uuid[])', [ids((s) => s.referenced)]);
  const { rows } = await c.query(
    'INSERT INTO court_slots (court_id, start_at, end_at, price) VALUES ($1, $2, $3, $4) RETURNING id',
    [courtId, start.toISOString(), end.toISOString(), court.price],
  );
  return rows[0].id;
}

function createTx(hostId, { slotId, courtId, startAt, hours, sport, title, quota, minReliability }) {
  return tx(async (c) => {
    // Cap open lobbies per host so one account cannot squat every slot. The wallet lock makes the count race-free.
    await c.query('SELECT 1 FROM wallets WHERE user_id = $1 FOR UPDATE', [hostId]);
    const hosted = await c.query(`SELECT count(*)::int AS n FROM lobbies WHERE host_id = $1 AND status = 'OPEN'`, [hostId]);
    if (hosted.rows[0].n >= MAX_ACTIVE_HOSTED) {
      throw new AppError(409, 'CONFLICT', `Maksimal ${MAX_ACTIVE_HOSTED} lobby aktif per host.`);
    }
    // Both paths lock the court, so an existing-slot room and a new-hours room on one court never interleave.
    if (slotId) {
      await c.query(
        'SELECT 1 FROM courts WHERE id = (SELECT court_id FROM court_slots WHERE id = $1) FOR UPDATE',
        [slotId],
      );
    }
    const id = slotId ?? (await slotForHours(c, { courtId, startAt, hours }));
    // Capacity is per sport on multi-purpose courts; no sport = the court's main sport.
    const found = await c.query(
      `SELECT s.*, COALESCE(cs.capacity, c.capacity) AS capacity, cs.sport_type IS NOT NULL AS sport_ok, c.sport_type AS main_sport,
              s.start_at - make_interval(hours => $2) AS join_deadline,
              s.start_at - make_interval(hours => $2) <= now() AS too_late
         FROM court_slots s
         JOIN courts c ON c.id = s.court_id AND c.status = 'ACTIVE'
         JOIN venues v ON v.id = c.venue_id AND v.status = 'ACTIVE'
         LEFT JOIN court_sports cs ON cs.court_id = c.id AND cs.sport_type = COALESCE($3::sport_type, c.sport_type)
        WHERE s.id = $1 AND NOT s.released FOR UPDATE OF s`,
      [id, JOIN_CUTOFF_HOURS, sport ?? null],
    );
    const slot = found.rows[0];
    if (!slot) throw new AppError(404, 'NOT_FOUND', 'Slot tidak ditemukan.');
    if (slot.status !== 'OPEN') throw new AppError(409, 'SLOT_NOT_OPEN', 'Slot tidak tersedia.');
    if (sport && !slot.sport_ok) throw new AppError(422, 'VALIDATION_ERROR', 'Lapangan ini tidak menyediakan olahraga itu.');
    if (quota > slot.capacity) throw new AppError(422, 'VALIDATION_ERROR', `Kuota maksimal lapangan ini ${slot.capacity}.`);

    if (slot.too_late) {
      throw new AppError(422, 'VALIDATION_ERROR', `Lobby harus dibuat paling lambat ${JOIN_CUTOFF_HOURS} jam sebelum main.`);
    }
    let lobby;
    try {
      const { rows } = await c.query(
        `INSERT INTO lobbies (slot_id, host_id, title, min_reliability, quota, price_total, join_deadline, sport_type)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
        // Store the sport now: later edits to the court's sports must not relabel this room.
        [slot.id, hostId, title, minReliability, quota, slot.price, slot.join_deadline, sport ?? slot.main_sport],
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

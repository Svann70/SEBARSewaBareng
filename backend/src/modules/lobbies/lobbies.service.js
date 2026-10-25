import { query, tx } from '../../db/pool.js';
import { AppError } from '../../lib/errors.js';
import { onDateWib } from '../../lib/sql.js';
import { coverPhoto } from '../venues/courts.shared.js';
import { clearFreeSlots } from '../venues/slots.shared.js';
import { addHost, disbandLobby, JOIN_CLOSE_MINUTES, joinCost, joinLobby, kickMember, leaveLobby, lockLobby, shareOf } from './patungan.service.js';

export const PAGE_SIZE = 20;
const MAX_ACTIVE_HOSTED = 3;

const LOBBY_SELECT = `
  SELECT l.*, s.start_at, s.end_at, c.name AS court_name, COALESCE(l.sport_type, c.sport_type) AS sport_type,
         ${coverPhoto('c')} AS court_photo, v.id AS venue_id, v.name AS venue_name, v.city,
         (SELECT count(*)::int FROM lobby_members m WHERE m.lobby_id = l.id AND m.status = 'ACTIVE') AS joined,
         (SELECT count(*)::int FROM lobby_members m WHERE m.lobby_id = l.id AND m.status IN ('ACTIVE', 'VACANT', 'ABSENT')) AS seats,
         (SELECT count(*)::int FROM lobby_members m WHERE m.lobby_id = l.id AND m.status = 'VACANT') AS vacant
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

// Share now (per seat) and what joining would cost, from the seat counts in LOBBY_SELECT.
export function shares(r) {
  const price = Number(r.price_total);
  const share = shareOf(price, r.seats);
  // The creator's seat also pays the rounding remainder.
  return { share, hostShare: price - share * (r.seats - 1), joinCost: joinCost(price, r.seats, r.vacant, r.quota) };
}

// The viewer's own seat and phase in this room (null = not a member).
export async function myMembership(lobbyId, userId) {
  const { rows } = await query(
    `SELECT m.status, m.role_in_lobby, m.hold_amount, m.share_at_join, m.fine_amount, m.free_until, m.protect_until,
            CASE WHEN m.status <> 'ACTIVE' THEN m.status::text
                 WHEN l.status <> 'OPEN' OR l.join_deadline <= now() THEN 'FINAL'
                 WHEN m.user_id = l.creator_id THEN 'HOST'
                 WHEN m.free_until > now() THEN 'FREE'
                 WHEN m.protect_until > now()
                      AND floor(l.price_total / (SELECT count(*) FROM lobby_members x
                                                  WHERE x.lobby_id = l.id AND x.status IN ('ACTIVE', 'VACANT', 'ABSENT'))) > m.share_at_join
                   THEN 'PROTECTED'
                 ELSE 'LOCKED' END AS phase
       FROM lobby_members m JOIN lobbies l ON l.id = m.lobby_id
      WHERE m.lobby_id = $1 AND m.user_id = $2 AND m.status IN ('ACTIVE', 'VACANT', 'ABSENT', 'REPLACED')
      ORDER BY m.joined_at DESC LIMIT 1`,
    [lobbyId, userId],
  );
  return rows[0] ?? null;
}

export async function listMembers(lobbyId) {
  const { rows } = await query(
    `SELECT m.user_id, m.role_in_lobby, m.status, u.full_name, u.reliability_score
       FROM lobby_members m JOIN users u ON u.id = m.user_id
      WHERE m.lobby_id = $1 AND m.status IN ('ACTIVE', 'VACANT', 'ABSENT') ORDER BY m.joined_at`,
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

// Creates the room and holds 100% of the price from the host (guarantee) in one transaction:
// no balance = no room.
export async function create(hostId, input) {
  const { slotId, courtId, startAt, hours } = input;
  const lobbyId = await withBalanceDetails(
    () => createTx(hostId, input),
    ...(slotId
      ? ['SELECT price FROM court_slots WHERE id = $2', [hostId, slotId]]
      : [`SELECT ${RATE_SQL} * $3 FROM courts c WHERE c.id = $2`, [hostId, courtId, hours, startAt]]),
  );
  return getById(lobbyId);
}

// Hourly rate of court `c` for a start time `$4` (timestamptz): weekend price on Saturday/Sunday WIB.
const RATE_SQL = `(CASE WHEN extract(isodow FROM ($4::timestamptz AT TIME ZONE 'Asia/Jakarta')) >= 6
                        THEN COALESCE(c.price_weekend, c.price_per_hour) ELSE c.price_per_hour END)`;

const MAX_DAYS_AHEAD = 60;

// Slot for a room on any free hour inside the court's opening hours. Rooms always pay the court
// rate (one-time setup); leftover OPEN slots in the way are cleared by clearFreeSlots.
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

  await clearFreeSlots(c, courtId, start.toISOString(), end.toISOString());
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
              s.start_at - make_interval(mins => $2) AS join_deadline,
              s.start_at - make_interval(mins => $2) <= now() AS too_late
         FROM court_slots s
         JOIN courts c ON c.id = s.court_id AND c.status = 'ACTIVE'
         JOIN venues v ON v.id = c.venue_id AND v.status = 'ACTIVE'
         LEFT JOIN court_sports cs ON cs.court_id = c.id AND cs.sport_type = COALESCE($3::sport_type, c.sport_type)
        WHERE s.id = $1 AND NOT s.released FOR UPDATE OF s`,
      [id, JOIN_CLOSE_MINUTES, sport ?? null],
    );
    const slot = found.rows[0];
    if (!slot) throw new AppError(404, 'NOT_FOUND', 'Slot tidak ditemukan.');
    if (slot.status !== 'OPEN') throw new AppError(409, 'SLOT_NOT_OPEN', 'Slot tidak tersedia.');
    if (sport && !slot.sport_ok) throw new AppError(422, 'VALIDATION_ERROR', 'Lapangan ini tidak menyediakan olahraga itu.');
    if (quota > slot.capacity) throw new AppError(422, 'VALIDATION_ERROR', `Kuota maksimal lapangan ini ${slot.capacity}.`);

    if (slot.too_late) {
      throw new AppError(422, 'VALIDATION_ERROR', `Room harus dibuat paling lambat ${JOIN_CLOSE_MINUTES} menit sebelum main.`);
    }
    let lobby;
    try {
      const { rows } = await c.query(
        `INSERT INTO lobbies (slot_id, host_id, creator_id, title, min_reliability, quota, price_total, join_deadline, sport_type)
         VALUES ($1, $2, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
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
    await addHost(c, lobby, hostId);
    return lobby.id;
  });
}

export async function join(lobbyId, userId) {
  try {
    return await tx((c) => joinLobby(c, lobbyId, userId));
  } catch (err) {
    if (err.code !== 'P0001' || err.message !== 'SEBAR::INSUFFICIENT_AVAILABLE_BALANCE') throw err;
    const lobby = await getById(lobbyId);
    const { rows } = await query('SELECT balance - held_balance AS available FROM wallets WHERE user_id = $1', [userId]);
    throw new AppError(409, 'INSUFFICIENT_AVAILABLE_BALANCE', 'Saldo tersedia tidak cukup.', {
      required: shares(lobby).joinCost, available: rows[0].available,
    });
  }
}
export const leave = (lobbyId, userId) => tx((c) => leaveLobby(c, lobbyId, userId));
export const kick = (lobbyId, hostId, targetId) => tx((c) => kickMember(c, lobbyId, hostId, targetId));
export const disband = (lobbyId, userId) => tx((c) => disbandLobby(c, lobbyId, userId));
export const lock = (lobbyId, userId) => tx((c) => lockLobby(c, lobbyId, userId));

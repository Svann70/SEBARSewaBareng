import { query, tx } from '../../db/pool.js';
import { AppError } from '../../lib/errors.js';
import { onDateWib } from '../../lib/sql.js';
import { SLOT_SELECT } from '../venues/slots.shared.js';

// Every query filters on v.owner_id: an admin only sees and changes their own venues (BR-6.1).

export async function listVenues(ownerId) {
  const { rows } = await query(
    `SELECT v.id, v.name, v.city, v.status,
            COALESCE(json_agg(json_build_object('id', c.id, 'name', c.name, 'sport', c.sport_type,
                     'pricePerHour', c.price_per_hour, 'capacity', c.capacity, 'status', c.status) ORDER BY c.name)
                     FILTER (WHERE c.id IS NOT NULL), '[]') AS courts
       FROM venues v LEFT JOIN courts c ON c.venue_id = v.id
      WHERE v.owner_id = $1 GROUP BY v.id ORDER BY v.name`,
    [ownerId],
  );
  return rows;
}

export async function listSlots(ownerId, { date, venueId }) {
  const { rows } = await query(
    `${SLOT_SELECT} WHERE v.owner_id = $1 AND ${onDateWib('s.start_at', '$2')}
       AND ($3::uuid IS NULL OR c.venue_id = $3) ORDER BY c.name, s.start_at`,
    [ownerId, date, venueId ?? null],
  );
  return rows;
}

const COURT_RETURNING = `id, venue_id AS "venueId", name, sport_type AS sport,
  price_per_hour AS "pricePerHour", capacity, status`;

// Court price lives here (courts.price_per_hour): every slot inherits it at creation.
export async function createCourt(ownerId, { venueId, name, sport, pricePerHour, capacity }) {
  const owned = await query('SELECT id FROM venues WHERE id = $1 AND owner_id = $2', [venueId, ownerId]);
  if (!owned.rows[0]) throw new AppError(404, 'NOT_FOUND', 'Venue tidak ditemukan.');
  const { rows } = await query(
    `INSERT INTO courts (venue_id, name, sport_type, price_per_hour, capacity)
     VALUES ($1, $2, $3, $4, $5) RETURNING ${COURT_RETURNING}`,
    [venueId, name, sport, pricePerHour, capacity],
  );
  return rows[0];
}

export async function updateCourt(ownerId, courtId, { name, pricePerHour, capacity, status }) {
  const { rows } = await query(
    `UPDATE courts c SET name = COALESCE($3, c.name), price_per_hour = COALESCE($4::numeric, c.price_per_hour),
            capacity = COALESCE($5::smallint, c.capacity), status = COALESCE($6::court_status, c.status)
       FROM venues v
      WHERE c.venue_id = v.id AND c.id = $1 AND v.owner_id = $2
      RETURNING c.id, c.venue_id AS "venueId", c.name, c.sport_type AS sport,
                c.price_per_hour AS "pricePerHour", c.capacity, c.status`,
    [courtId, ownerId, name ?? null, pricePerHour ?? null, capacity ?? null, status ?? null],
  );
  if (!rows[0]) throw new AppError(404, 'NOT_FOUND', 'Lapangan tidak ditemukan.');
  return rows[0];
}

async function loadSlot(id) {
  const { rows } = await query(`${SLOT_SELECT} WHERE s.id = $1`, [id]);
  return rows[0];
}

export async function createSlot(ownerId, { courtId, startAt, endAt, price }) {
  if (new Date(startAt) <= new Date()) throw new AppError(422, 'VALIDATION_ERROR', 'Slot harus di masa depan.');
  const id = await tx(async (c) => {
    const court = await c.query(
      `SELECT c.id FROM courts c JOIN venues v ON v.id = c.venue_id WHERE c.id = $1 AND v.owner_id = $2`,
      [courtId, ownerId],
    );
    if (!court.rows[0]) throw new AppError(404, 'NOT_FOUND', 'Lapangan tidak ditemukan.');
    try {
      const { rows } = await c.query(
        'INSERT INTO court_slots (court_id, start_at, end_at, price) VALUES ($1, $2, $3, $4) RETURNING id',
        [courtId, startAt, endAt, price],
      );
      return rows[0].id;
    } catch (err) {
      // court_slots_court_id_tstzrange_excl (overlap) or the (court_id, start_at) unique key.
      if (err.code === '23P01' || err.code === '23505') {
        throw new AppError(409, 'CONFLICT', 'Slot bertabrakan dengan slot lain di lapangan ini.');
      }
      throw err;
    }
  });
  return loadSlot(id);
}

export async function updateSlot(ownerId, slotId, { status, price }) {
  await tx(async (c) => {
    // Lock first, then check for a lobby in a separate statement: under READ COMMITTED a check in the
    // locking statement would read the snapshot from before the lock wait and miss a just-committed lobby.
    const found = await c.query(
      `SELECT s.* FROM court_slots s JOIN courts c ON c.id = s.court_id JOIN venues v ON v.id = c.venue_id
        WHERE s.id = $1 AND v.owner_id = $2 FOR UPDATE OF s`,
      [slotId, ownerId],
    );
    const s = found.rows[0];
    if (!s) throw new AppError(404, 'NOT_FOUND', 'Slot tidak ditemukan.');
    const lobby = await c.query(
      `SELECT 1 FROM lobbies WHERE slot_id = $1 AND status IN ('OPEN', 'FILLED', 'CONFIRMED') LIMIT 1`,
      [slotId],
    );
    if (!['OPEN', 'BLOCKED'].includes(s.status) || lobby.rows[0]) {
      throw new AppError(409, 'CONFLICT', 'Slot sudah dipakai lobby/booking dan tidak bisa diubah.');
    }
    await c.query('UPDATE court_slots SET status = COALESCE($2, status), price = COALESCE($3, price) WHERE id = $1', [
      slotId,
      status ?? null,
      price ?? null,
    ]);
  });
  return loadSlot(slotId);
}

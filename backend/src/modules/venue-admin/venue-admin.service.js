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

export async function listSlots(ownerId, date) {
  const { rows } = await query(
    `${SLOT_SELECT} WHERE v.owner_id = $1 AND ${onDateWib('s.start_at', '$2')} ORDER BY c.name, s.start_at`,
    [ownerId, date],
  );
  return rows;
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

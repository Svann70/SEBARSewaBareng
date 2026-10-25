import { query, tx } from '../../db/pool.js';
import crypto from 'node:crypto';
import { AppError } from '../../lib/errors.js';
import { detectImage } from '../../lib/image.js';
import { deleteObject, publicUrl, storageEnabled, uploadObject } from '../../lib/storage.js';
import { onDateWib } from '../../lib/sql.js';
import { courtJson } from '../venues/courts.shared.js';
import { clearFreeSlots, SLOT_SELECT } from '../venues/slots.shared.js';

// Every query filters on v.owner_id: an admin only sees and changes their own venues (BR-6.1).

export async function listVenues(ownerId) {
  const { rows } = await query(
    `SELECT v.id, v.name, v.address, v.city, v.description, v.status,
            COALESCE(json_agg(${courtJson('c')} ORDER BY c.name) FILTER (WHERE c.id IS NOT NULL), '[]') AS courts
       FROM venues v LEFT JOIN courts c ON c.venue_id = v.id
      WHERE v.owner_id = $1 GROUP BY v.id ORDER BY v.name`,
    [ownerId],
  );
  return rows;
}

// Admin with no venue (e.g. a promoted PLAYER account) creates their first one here;
// the register endpoint is the other place venues are born.
export async function createVenue(ownerId, { name, address, city, description }) {
  const { rows } = await query(
    `INSERT INTO venues (owner_id, name, address, city, description)
     VALUES ($1, $2, $3, $4, $5) RETURNING id, name, city, status`,
    [ownerId, name, address, city, description ?? null],
  );
  return { ...rows[0], courts: [] };
}

// Venue details from the one-page setup form. Only the owner's own venue.
export async function updateVenue(ownerId, venueId, { name, address, city, description }) {
  const { rows } = await query(
    `UPDATE venues SET name = COALESCE($3, name), address = COALESCE($4, address),
            city = COALESCE($5, city), description = COALESCE($6, description)
      WHERE id = $1 AND owner_id = $2
      RETURNING id, name, address, city, description, status`,
    [venueId, ownerId, name ?? null, address ?? null, city ?? null, description ?? null],
  );
  if (!rows[0]) throw new AppError(404, 'NOT_FOUND', 'Venue tidak ditemukan.');
  return rows[0];
}

export async function listSlots(ownerId, { date, venueId }) {
  const { rows } = await query(
    `${SLOT_SELECT} WHERE v.owner_id = $1 AND NOT s.released AND ${onDateWib('s.start_at', '$2')}
       AND ($3::uuid IS NULL OR c.venue_id = $3) ORDER BY c.name, s.start_at`,
    [ownerId, date, venueId ?? null],
  );
  return rows;
}

async function loadCourt(c, id) {
  const { rows } = await c.query(`SELECT ${courtJson('c')} AS court, c.venue_id FROM courts c WHERE c.id = $1`, [id]);
  return { ...rows[0].court, venueId: rows[0].venue_id };
}

async function replaceSports(c, courtId, sports) {
  await c.query('DELETE FROM court_sports WHERE court_id = $1', [courtId]);
  for (const { sport, capacity } of sports) {
    await c.query('INSERT INTO court_sports (court_id, sport_type, capacity) VALUES ($1, $2, $3)', [courtId, sport, capacity]);
  }
}

// One-time setup: price (weekday/weekend), opening hours and sports. Every hour inside the opening
// hours can then be rented without opening slots by hand. The first sport is the court's main sport
// (courts.sport_type/capacity), kept for views and older app builds.
export async function createCourt(ownerId, { venueId, name, sports, pricePerHour, priceWeekend, openTime, closeTime }) {
  return tx(async (c) => {
    const owned = await c.query('SELECT id FROM venues WHERE id = $1 AND owner_id = $2', [venueId, ownerId]);
    if (!owned.rows[0]) throw new AppError(404, 'NOT_FOUND', 'Venue tidak ditemukan.');
    let id;
    try {
      const { rows } = await c.query(
        `INSERT INTO courts (venue_id, name, sport_type, capacity, price_per_hour, price_weekend, open_time, close_time)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING id`,
        [venueId, name, sports[0].sport, sports[0].capacity, pricePerHour, priceWeekend ?? null, openTime, closeTime],
      );
      id = rows[0].id;
    } catch (err) {
      if (err.code === '23505') throw new AppError(409, 'CONFLICT', 'Nama lapangan sudah dipakai di venue ini.');
      throw err;
    }
    await replaceSports(c, id, sports);
    return loadCourt(c, id);
  });
}

export async function updateCourt(ownerId, courtId, patch) {
  const { name, sports, pricePerHour, priceWeekend, capacity, openTime, closeTime, status } = patch;
  return tx(async (c) => {
    let found;
    try {
      found = await c.query(
        `UPDATE courts c SET name = COALESCE($3, c.name),
                price_per_hour = COALESCE($4::numeric, c.price_per_hour),
                price_weekend = CASE WHEN $11 THEN $5::numeric ELSE c.price_weekend END,
                sport_type = COALESCE($6::sport_type, c.sport_type),
                capacity = COALESCE($7::smallint, c.capacity),
                open_time = COALESCE($8::time, c.open_time),
                close_time = COALESCE($9::time, c.close_time),
                status = COALESCE($10::court_status, c.status)
           FROM venues v
          WHERE c.venue_id = v.id AND c.id = $1 AND v.owner_id = $2
          RETURNING c.id, c.sport_type`,
        [courtId, ownerId, name ?? null, pricePerHour ?? null, priceWeekend ?? null,
          sports?.[0].sport ?? null, sports?.[0].capacity ?? capacity ?? null, openTime ?? null, closeTime ?? null, status ?? null,
          // null clears the weekend price (= weekday price); undefined keeps it.
          priceWeekend !== undefined],
      );
    } catch (err) {
      if (err.code === '23514' && err.constraint === 'courts_hours_check') {
        throw new AppError(422, 'VALIDATION_ERROR', 'Jam tutup harus setelah jam buka.');
      }
      if (err.code === '23505') throw new AppError(409, 'CONFLICT', 'Nama lapangan sudah dipakai di venue ini.');
      throw err;
    }
    if (!found.rows[0]) throw new AppError(404, 'NOT_FOUND', 'Lapangan tidak ditemukan.');
    if (sports) await replaceSports(c, courtId, sports);
    else if (capacity) {
      // Old single-sport form: capacity belongs to the main sport.
      await c.query('UPDATE court_sports SET capacity = $3 WHERE court_id = $1 AND sport_type = $2', [
        courtId, found.rows[0].sport_type, capacity,
      ]);
    }
    return loadCourt(c, courtId);
  });
}

async function loadSlot(id) {
  const { rows } = await query(`${SLOT_SELECT} WHERE s.id = $1`, [id]);
  return rows[0];
}

export async function createSlot(ownerId, { courtId, startAt, endAt, price, status }) {
  if (new Date(startAt) <= new Date()) throw new AppError(422, 'VALIDATION_ERROR', 'Slot harus di masa depan.');
  const id = await tx(async (c) => {
    // Court lock: same order as room creation, so closing an hour and booking it cannot interleave.
    const court = await c.query(
      `SELECT c.id FROM courts c JOIN venues v ON v.id = c.venue_id WHERE c.id = $1 AND v.owner_id = $2
          FOR UPDATE OF c`,
      [courtId, ownerId],
    );
    if (!court.rows[0]) throw new AppError(404, 'NOT_FOUND', 'Lapangan tidak ditemukan.');
    // Closing an hour: leftovers of cancelled rooms must not make a free-looking hour unclosable.
    if (status === 'BLOCKED') await clearFreeSlots(c, courtId, startAt, endAt);
    try {
      const { rows } = await c.query(
        'INSERT INTO court_slots (court_id, start_at, end_at, price, status) VALUES ($1, $2, $3, $4, $5) RETURNING id',
        [courtId, startAt, endAt, price, status],
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
        WHERE s.id = $1 AND v.owner_id = $2 AND NOT s.released FOR UPDATE OF s`,
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

// ── Court photos (Supabase Storage) ──────────────────────────────────────────

export const MAX_PHOTOS_PER_COURT = 6;

// Owner check + photo count. `lock` holds the court row so concurrent uploads can't pass the cap together.
// The count is a separate statement: run after the lock wait, it sees photos committed meanwhile.
async function photoSlotsLeft(c, ownerId, courtId, lock = false) {
  const owned = await c.query(
    `SELECT c.id FROM courts c JOIN venues v ON v.id = c.venue_id
      WHERE c.id = $1 AND v.owner_id = $2${lock ? ' FOR UPDATE OF c' : ''}`,
    [courtId, ownerId],
  );
  if (!owned.rows[0]) throw new AppError(404, 'NOT_FOUND', 'Lapangan tidak ditemukan.');
  const { rows } = await c.query('SELECT count(*)::int AS n FROM court_photos WHERE court_id = $1', [courtId]);
  if (rows[0].n >= MAX_PHOTOS_PER_COURT) {
    throw new AppError(409, 'CONFLICT', `Maksimal ${MAX_PHOTOS_PER_COURT} foto per lapangan.`);
  }
}

export async function addPhoto(ownerId, courtId, body) {
  if (!storageEnabled()) throw new AppError(503, 'STORAGE_DISABLED', 'Upload foto belum diaktifkan di server.');
  // Cheap pre-check so a full court costs no upload; the locked re-check below is the real guard.
  await photoSlotsLeft({ query }, ownerId, courtId);
  const image = detectImage(body);
  if (!image) throw new AppError(415, 'UNSUPPORTED_MEDIA_TYPE', 'Foto harus JPG, PNG, atau WEBP.');
  // Random name: no user input in the object path, and a re-upload never overwrites another photo.
  const path = `courts/${courtId}/${crypto.randomUUID()}.${image.ext}`;
  await uploadObject(path, body, image.type);
  try {
    return await tx(async (c) => {
      await photoSlotsLeft(c, ownerId, courtId, true);
      const { rows } = await c.query(
        `INSERT INTO court_photos (court_id, path, url, sort)
         VALUES ($1, $2, $3, (SELECT COALESCE(max(sort) + 1, 0) FROM court_photos WHERE court_id = $1))
         RETURNING id, url, sort`,
        [courtId, path, publicUrl(path)],
      );
      return rows[0];
    });
  } catch (err) {
    await deleteObject(path);
    throw err;
  }
}

export async function deletePhoto(ownerId, courtId, photoId) {
  const { rows } = await query(
    `DELETE FROM court_photos p USING courts c, venues v
      WHERE p.id = $1 AND p.court_id = $2 AND c.id = p.court_id AND v.id = c.venue_id AND v.owner_id = $3
      RETURNING p.path`,
    [photoId, courtId, ownerId],
  );
  if (!rows[0]) throw new AppError(404, 'NOT_FOUND', 'Foto tidak ditemukan.');
  await deleteObject(rows[0].path);
}

// ── Check-in (code on the player's ticket, typed by the venue) ───────────────

const CHECKIN_SELECT = `
  SELECT ci.id, ci.code, ci.status, ci.scanned_at, u.full_name, l.title, ct.name AS court_name, s.start_at, s.end_at
    FROM checkins ci
    JOIN bookings b ON b.id = ci.booking_id
    JOIN lobbies l ON l.id = b.lobby_id
    JOIN court_slots s ON s.id = b.slot_id
    JOIN courts ct ON ct.id = s.court_id
    JOIN venues v ON v.id = ct.venue_id
    JOIN users u ON u.id = ci.user_id`;

const checkinDto = (r) => ({
  code: r.code,
  status: r.status,
  scannedAt: r.scanned_at,
  playerName: r.full_name,
  roomTitle: r.title,
  courtName: r.court_name,
  startAt: r.start_at,
  endAt: r.end_at,
});

// Only the venue that owns the court can check a ticket in. An unknown code and another venue's
// code get the same answer, so codes of other venues cannot be probed.
export async function scanCheckin(ownerId, rawCode) {
  const code = rawCode.toUpperCase().replace(/[^0-9A-Z]/g, '');
  return tx(async (c) => {
    const { rows } = await c.query(
      `${CHECKIN_SELECT.replace('SELECT ci.id', `SELECT now() < s.start_at - interval '1 hour' AS too_early,
                                                       ci.token_expires_at <= now() AS expired, ci.id`)}
        WHERE ci.code = $1 AND v.owner_id = $2
        FOR UPDATE OF ci`,
      [code, ownerId],
    );
    const t = rows[0];
    if (!t) throw new AppError(404, 'NOT_FOUND', 'Kode tidak dikenal.');
    if (t.status === 'SCANNED') {
      throw new AppError(409, 'ALREADY_SCANNED', 'Tiket ini sudah discan.', checkinDto(t));
    }
    if (t.too_early) {
      throw new AppError(422, 'TOO_EARLY', 'Belum waktunya. Check-in dibuka 1 jam sebelum main.', checkinDto(t));
    }
    if (t.expired) throw new AppError(410, 'EXPIRED', 'Tiket sudah kedaluwarsa.', checkinDto(t));
    const { rows: done } = await c.query(
      `UPDATE checkins SET status = 'SCANNED', scanned_by = $2, scanned_at = now() WHERE id = $1 RETURNING scanned_at`,
      [t.id, ownerId],
    );
    return checkinDto({ ...t, status: 'SCANNED', scanned_at: done[0].scanned_at });
  });
}

// Latest check-ins at this owner's venues, newest first.
export async function listCheckins(ownerId) {
  const { rows } = await query(
    `${CHECKIN_SELECT} WHERE v.owner_id = $1 AND ci.status = 'SCANNED' ORDER BY ci.scanned_at DESC LIMIT 30`,
    [ownerId],
  );
  return rows.map(checkinDto);
}

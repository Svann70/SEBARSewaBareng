import { AppError } from '../../lib/errors.js';

// Slot query + mapper shared by the player catalogue (venues) and the venue admin module.

export const SLOT_SELECT = `
  SELECT s.*, c.name AS court_name, c.sport_type, l.id AS lobby_id, l.quota AS lobby_quota,
         hu.full_name AS host_name,
         (SELECT count(*)::int FROM lobby_members m
           WHERE m.lobby_id = l.id AND m.status IN ('HOLDING', 'CONFIRMED')) AS joined_count
    FROM court_slots s
    JOIN courts c ON c.id = s.court_id
    JOIN venues v ON v.id = c.venue_id
    LEFT JOIN lobbies l ON l.slot_id = s.id AND l.status IN ('OPEN', 'FILLED', 'CONFIRMED')
    LEFT JOIN users hu ON hu.id = l.host_id`;

// One definition of "this slot is taken by a room", shared by the availability grid and room creation.
// `s` is the court_slots alias.
export const ACTIVE_LOBBY = `EXISTS (SELECT 1 FROM lobbies al WHERE al.slot_id = s.id AND al.status IN ('OPEN', 'FILLED', 'CONFIRMED'))`;

// Make [start, end) on a court free for a new slot. Leftover OPEN slots without an active room
// (opened by hand, or left by a cancelled/expired room) only mark hours as free: unused ones are
// deleted, ones a past room still references are released (kept for history, ignored by the overlap
// rule and the schedule). Throws 409 when an hour is closed by the owner or taken by a room.
// The caller must hold the court row lock so concurrent writers on one court take turns.
export async function clearFreeSlots(c, courtId, startAt, endAt) {
  // Lock first, then check lobbies in a second statement: a check inside the locking statement would
  // keep the snapshot from before the lock wait and miss a lobby committed meanwhile.
  const locked = await c.query(
    `SELECT s.id FROM court_slots s
      WHERE s.court_id = $1 AND NOT s.released AND tstzrange(s.start_at, s.end_at) && tstzrange($2, $3)
        FOR UPDATE OF s`,
    [courtId, startAt, endAt],
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
}

/// POV pemain: tanpa identitas pemesan.
export function slotDto(r) {
  return {
    id: r.id,
    courtId: r.court_id,
    courtName: r.court_name,
    sport: r.sport_type,
    startAt: r.start_at,
    endAt: r.end_at,
    price: r.price,
    status: r.status,
    lobbyId: r.lobby_id ?? null,
  };
}

/// POV venue: slot terisi menampilkan siapa yang booking + jumlah pemain.
export function venueSlotDto(r) {
  return {
    ...slotDto(r),
    hostName: r.host_name ?? null,
    joined: r.joined_count ?? 0,
    quota: r.lobby_quota ?? null,
  };
}

import { query } from '../../db/pool.js';

export async function listMine(userId) {
  const { rows } = await query(
    `SELECT b.id, b.booking_code, b.status, b.booked_at, l.id AS lobby_id, l.title, m.hold_amount,
            s.start_at, s.end_at, c.name AS court_name, COALESCE(l.sport_type, c.sport_type) AS sport_type, v.name AS venue_name, v.city
       FROM lobby_members m
       JOIN bookings b ON b.lobby_id = m.lobby_id
       JOIN lobbies l ON l.id = m.lobby_id
       JOIN court_slots s ON s.id = b.slot_id
       JOIN courts c ON c.id = s.court_id
       JOIN venues v ON v.id = c.venue_id
      WHERE m.user_id = $1 AND m.status = 'CONFIRMED'
      ORDER BY s.start_at DESC`,
    [userId],
  );
  return rows;
}

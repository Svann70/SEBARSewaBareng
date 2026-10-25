import { query } from '../../db/pool.js';
import { onDateWib, wibDayStart } from '../../lib/sql.js';
import { JOIN_CLOSE_MINUTES } from '../lobbies/patungan.service.js';
import { courtJson, hourOf } from './courts.shared.js';
import { ACTIVE_LOBBY, SLOT_SELECT } from './slots.shared.js';

export async function list({ city, sport }) {
  const { rows } = await query(
    `SELECT v.id, v.name, v.address, v.city, v.description, v.photo_url,
            json_agg(${courtJson('c')} ORDER BY c.name) AS courts
       FROM venues v JOIN courts c ON c.venue_id = v.id AND c.status = 'ACTIVE'
      WHERE v.status = 'ACTIVE' AND ($1::text IS NULL OR lower(v.city) = lower($1))
        AND ($2::sport_type IS NULL OR c.sport_type = $2
             OR EXISTS (SELECT 1 FROM court_sports cs WHERE cs.court_id = c.id AND cs.sport_type = $2))
      GROUP BY v.id ORDER BY v.name`,
    [city ?? null, sport ?? null],
  );
  return rows;
}

export async function listSlots(venueId, date) {
  const { rows } = await query(
    `${SLOT_SELECT}
      WHERE v.id = $1 AND v.status = 'ACTIVE' AND c.status = 'ACTIVE' AND NOT s.released
        AND ${onDateWib('s.start_at', '$2')}
      ORDER BY s.start_at, c.name`,
    [venueId, date],
  );
  return rows;
}

// Hourly grid per court for one WIB date. Every hour inside the court's opening hours can be rented
// without the owner opening it first; the slot is created when a player makes a room (lobbies.service).
//   FREE   = a room can start here
//   TAKEN  = an active room/booking covers this hour
//   CLOSED = the owner blocked this hour
//   PAST   = too late to make a room (starts within JOIN_CLOSE_MINUTES)
export async function availability(venueId, date) {
  const courts = await query(
    `SELECT ${courtJson('c')} AS court
       FROM courts c JOIN venues v ON v.id = c.venue_id
      WHERE v.id = $1 AND v.status = 'ACTIVE' AND c.status = 'ACTIVE' ORDER BY c.name`,
    [venueId],
  );
  const slots = await query(
    `SELECT s.court_id, s.start_at, s.end_at, s.status, ${ACTIVE_LOBBY} AS has_lobby
       FROM court_slots s JOIN courts c ON c.id = s.court_id
      WHERE c.venue_id = $1 AND NOT s.released
        AND s.start_at < ${wibDayStart('$2')} + interval '1 day' AND s.end_at > ${wibDayStart('$2')}`,
    [venueId, date],
  );
  // Noon WIB is the same UTC calendar day, so getUTCDay() is the WIB weekday.
  const weekend = [0, 6].includes(new Date(`${date}T12:00:00+07:00`).getUTCDay());
  const cutoff = Date.now() + JOIN_CLOSE_MINUTES * 60_000;
  const byCourt = Map.groupBy(slots.rows, (s) => s.court_id);
  return {
    date,
    weekend,
    courts: courts.rows.map(({ court }) => {
      const own = byCourt.get(court.id) ?? [];
      const hours = [];
      for (let h = hourOf(court.openTime); h < hourOf(court.closeTime); h++) {
        const start = new Date(`${date}T${String(h).padStart(2, '0')}:00:00+07:00`);
        const end = new Date(start.getTime() + 3600_000);
        const hit = own.filter((s) => s.start_at < end && s.end_at > start);
        let status = 'FREE';
        if (hit.some((s) => s.status === 'BLOCKED')) status = 'CLOSED';
        else if (hit.some((s) => s.has_lobby || s.status !== 'OPEN')) status = 'TAKEN';
        else if (start.getTime() <= cutoff) status = 'PAST';
        hours.push({ start: start.toISOString(), hour: h, status });
      }
      return { ...court, rate: weekend ? (court.priceWeekend ?? court.pricePerHour) : court.pricePerHour, hours };
    }),
  };
}

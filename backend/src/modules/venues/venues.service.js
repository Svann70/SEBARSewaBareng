import { query } from '../../db/pool.js';
import { onDateWib } from '../../lib/sql.js';
import { SLOT_SELECT } from './slots.shared.js';

export async function list({ city, sport }) {
  const { rows } = await query(
    `SELECT v.id, v.name, v.address, v.city, v.description, v.photo_url,
            json_agg(json_build_object('id', c.id, 'name', c.name, 'sport', c.sport_type,
                     'pricePerHour', c.price_per_hour, 'capacity', c.capacity) ORDER BY c.name) AS courts
       FROM venues v JOIN courts c ON c.venue_id = v.id AND c.status = 'ACTIVE'
      WHERE v.status = 'ACTIVE' AND ($1::text IS NULL OR lower(v.city) = lower($1)) AND ($2::sport_type IS NULL OR c.sport_type = $2)
      GROUP BY v.id ORDER BY v.name`,
    [city ?? null, sport ?? null],
  );
  return rows;
}

export async function listSlots(venueId, date) {
  const { rows } = await query(
    `${SLOT_SELECT}
      WHERE v.id = $1 AND v.status = 'ACTIVE' AND c.status = 'ACTIVE' AND ${onDateWib('s.start_at', '$2')}
      ORDER BY s.start_at, c.name`,
    [venueId, date],
  );
  return rows;
}

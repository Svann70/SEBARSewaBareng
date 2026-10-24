// Court JSON shared by the player catalogue and the venue admin module. `c` is the courts alias.
// Times are 'HH:MM' (close may be '24:00'); priceWeekend null = same as the weekday price.
export const courtJson = (c) => `json_build_object(
  'id', ${c}.id, 'name', ${c}.name, 'status', ${c}.status,
  'sport', ${c}.sport_type, 'capacity', ${c}.capacity,
  'pricePerHour', ${c}.price_per_hour,
  'priceWeekend', ${c}.price_weekend,
  'openTime', to_char(${c}.open_time, 'HH24:MI'), 'closeTime', to_char(${c}.close_time, 'HH24:MI'),
  'sports', (SELECT COALESCE(json_agg(json_build_object('sport', cs.sport_type, 'capacity', cs.capacity)
                                      ORDER BY cs.sport_type), '[]'::json)
               FROM court_sports cs WHERE cs.court_id = ${c}.id),
  'photos', (SELECT COALESCE(json_agg(json_build_object('id', p.id, 'url', p.url) ORDER BY p.sort, p.created_at), '[]'::json)
               FROM court_photos p WHERE p.court_id = ${c}.id))`;

// Cover photo of court `c` (lowest sort), or NULL.
export const coverPhoto = (c) =>
  `(SELECT p.url FROM court_photos p WHERE p.court_id = ${c}.id ORDER BY p.sort, p.created_at LIMIT 1)`;

// Hourly grid works on whole hours: '06:00' -> 6, '24:00' -> 24.
export const hourOf = (hhmm) => Number(hhmm.slice(0, 2));

// Slot query + mapper shared by the player catalogue (venues) and the venue admin module.

export const SLOT_SELECT = `
  SELECT s.*, c.name AS court_name, c.sport_type, l.id AS lobby_id
    FROM court_slots s
    JOIN courts c ON c.id = s.court_id
    JOIN venues v ON v.id = c.venue_id
    LEFT JOIN lobbies l ON l.slot_id = s.id AND l.status IN ('OPEN', 'FILLED', 'CONFIRMED')`;

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

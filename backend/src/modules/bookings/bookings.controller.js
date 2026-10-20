import * as service from './bookings.service.js';

function bookingDto(r) {
  return {
    id: r.id,
    bookingCode: r.booking_code,
    status: r.status,
    bookedAt: r.booked_at,
    lobby: { id: r.lobby_id, title: r.title },
    amountPaid: r.hold_amount,
    slot: { startAt: r.start_at, endAt: r.end_at },
    court: { name: r.court_name, sport: r.sport_type },
    venue: { name: r.venue_name, city: r.city },
  };
}

export async function listMine(req, res) {
  res.json({ items: (await service.listMine(req.user.id)).map(bookingDto) });
}

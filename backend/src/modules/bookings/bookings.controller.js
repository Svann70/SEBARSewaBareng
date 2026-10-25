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
    // This player's own check-in code (the venue types it in) and its state.
    checkin: { code: r.checkin_code, status: r.checkin_status, scannedAt: r.scanned_at },
  };
}

export async function listMine(req, res) {
  res.json({ items: (await service.listMine(req.user.id)).map(bookingDto) });
}

-- ============================================================================
-- SEBAR — view : vw_venue_monthly_revenue (SDD §4.8)
-- ============================================================================
-- Run order : 6.1 — setelah tables/ (agregasi dashboard venue, GROUP BY)
-- ============================================================================

CREATE OR REPLACE VIEW public.vw_venue_monthly_revenue AS
SELECT
  v.id                             AS venue_id,
  v.name                           AS venue_name,
  date_trunc('month', b.booked_at) AS bulan,
  count(*)                         AS total_booking,
  sum(b.gross_amount)              AS omzet,
  sum(b.platform_fee)              AS fee_sebar,
  sum(b.venue_payout)              AS payout_gor
FROM public.bookings b
JOIN public.lobbies l     ON l.id = b.lobby_id
JOIN public.court_slots s ON s.id = b.slot_id
JOIN public.courts c      ON c.id = s.court_id
JOIN public.venues v      ON v.id = c.venue_id
WHERE b.status <> 'CANCELLED'
GROUP BY v.id, v.name, date_trunc('month', b.booked_at);

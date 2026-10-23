-- ============================================================================
-- SEBAR — view : vw_lobby_search (SDD §4.8)
-- ============================================================================
-- Run order : 6.2 — setelah tables/ (join lobbies + slots + courts + venues)
-- ============================================================================

CREATE OR REPLACE VIEW public.vw_lobby_search AS
SELECT
  l.id, l.slot_id, l.host_id, l.title, l.min_reliability, l.quota,
  l.price_total, l.price_per_person, l.join_deadline, l.status,
  s.start_at, s.end_at,
  c.sport_type, c.name AS court_name,
  v.id AS venue_id, v.name AS venue_name, v.city,
  (SELECT count(*) FROM public.lobby_members m
     WHERE m.lobby_id = l.id AND m.status IN ('HOLDING', 'CONFIRMED')) AS joined
FROM public.lobbies l
JOIN public.court_slots s ON s.id = l.slot_id
JOIN public.courts c      ON c.id = s.court_id
JOIN public.venues v      ON v.id = c.venue_id;

-- ============================================================================
-- SEBAR — functions : analytics (SDD §4.6, §4.8)
-- ============================================================================
-- Run order : 4.5 — setelah tables/ (LANGUAGE sql divalidasi saat CREATE)
-- ============================================================================

-- fn_peak_hours(uuid, date, date) — jam tersibuk venue
-- Memakai window function untuk persentase (bukti rubrik analitik).
CREATE OR REPLACE FUNCTION public.fn_peak_hours(
  p_venue uuid,
  p_from  date,
  p_to    date
) RETURNS TABLE (jam numeric, booking bigint, persen numeric)
LANGUAGE sql STABLE AS $$
  SELECT extract(hour FROM s.start_at)                          AS jam,
         count(*)                                               AS booking,
         round(100.0 * count(*) / sum(count(*)) OVER (), 1)     AS persen
  FROM public.bookings b
  JOIN public.court_slots s ON s.id = b.slot_id
  JOIN public.courts c      ON c.id = s.court_id
  WHERE c.venue_id = p_venue
    AND b.booked_at::date BETWEEN p_from AND p_to
    AND b.status <> 'CANCELLED'
  GROUP BY 1
  ORDER BY 2 DESC
$$;

-- ============================================================================
-- SEBAR — table 3.5 : courts (SDD §4.3.5)
-- ============================================================================
-- Run order : 3.5 — setelah tables/04_venues.sql
-- Depends   : public.venues, enum public.sport_type, public.court_status
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.courts (
  id             uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id       uuid                NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  name           varchar(60)         NOT NULL,
  sport_type     public.sport_type   NOT NULL,
  price_per_hour numeric(12,2)       NOT NULL CHECK (price_per_hour > 0),
  capacity       smallint            NOT NULL CHECK (capacity BETWEEN 2 AND 30),
  status         public.court_status NOT NULL DEFAULT 'ACTIVE',
  UNIQUE (venue_id, name)
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_courts_venue
  ON public.courts (venue_id);

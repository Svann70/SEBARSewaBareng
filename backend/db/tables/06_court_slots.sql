-- ============================================================================
-- SEBAR — table 3.6 : court_slots (SDD §4.3.6)
-- ============================================================================
-- Run order : 3.6 — setelah tables/05_courts.sql
-- Depends   : public.courts, enum public.slot_status, ext btree_gist
-- Invariant : UNIQUE(court_id, start_at) + exclusion anti-overlap (SDD §4.4)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.court_slots (
  id         uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
  court_id   uuid                NOT NULL REFERENCES public.courts(id) ON DELETE CASCADE,
  start_at   timestamptz         NOT NULL,
  end_at     timestamptz         NOT NULL CHECK (end_at > start_at),
  price      numeric(12,2)       NOT NULL CHECK (price > 0),
  status     public.slot_status  NOT NULL DEFAULT 'OPEN',
  created_at timestamptz         NOT NULL DEFAULT now(),
  UNIQUE (court_id, start_at),                       -- mencegah dua slot identik
  EXCLUDE USING gist (court_id WITH =, tstzrange(start_at, end_at) WITH &&)  -- anti tumpang tindih
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_slots_open
  ON public.court_slots (start_at)
  WHERE status = 'OPEN';

CREATE INDEX IF NOT EXISTS idx_slots_court_start
  ON public.court_slots (court_id, start_at DESC);

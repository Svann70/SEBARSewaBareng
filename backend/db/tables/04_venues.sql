-- ============================================================================
-- SEBAR — table 3.4 : venues (SDD §4.3.4)
-- ============================================================================
-- Run order : 3.4 — setelah tables/01_users.sql
-- Depends   : public.users (owner), enum public.venue_status
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.venues (
  id          uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    uuid                NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  name        varchar(120)        NOT NULL,
  address     text                NOT NULL,
  city        varchar(60)         NOT NULL,
  description text,
  photo_url   text,
  status      public.venue_status NOT NULL DEFAULT 'ACTIVE',
  created_at  timestamptz         NOT NULL DEFAULT now()
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_venues_city_status
  ON public.venues (city, status);

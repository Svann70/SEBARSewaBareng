-- ============================================================================
-- SEBAR — table 3.7 : lobbies (SDD §4.3.7)
-- ============================================================================
-- Run order : 3.7 — setelah tables/06_court_slots.sql
-- Depends   : public.court_slots, public.users, enum public.lobby_status
-- Note      : price_per_person generated (BR-1.1); validasi via trg_lobby_validate
--             (lihat db/triggers/02_lobbies.sql — dijalankan setelah functions/)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.lobbies (
  id               uuid                 PRIMARY KEY DEFAULT gen_random_uuid(),
  slot_id          uuid                 NOT NULL REFERENCES public.court_slots(id) ON DELETE RESTRICT,
  host_id          uuid                 NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  title            varchar(100)         NOT NULL,
  min_reliability  numeric(5,2)         NOT NULL DEFAULT 0 CHECK (min_reliability BETWEEN 0 AND 100),
  quota            smallint             NOT NULL CHECK (quota BETWEEN 2 AND 30),
  price_total      numeric(12,2)        NOT NULL CHECK (price_total > 0),
  price_per_person numeric(12,2)        GENERATED ALWAYS AS (ceil(price_total / (quota::numeric))) STORED,
  join_deadline    timestamptz          NOT NULL,
  status           public.lobby_status  NOT NULL DEFAULT 'OPEN',
  created_at       timestamptz          NOT NULL DEFAULT now()
);

-- Satu slot hanya satu lobby aktif (BR-1.3)
CREATE UNIQUE INDEX IF NOT EXISTS uq_lobbies_active_slot
  ON public.lobbies (slot_id)
  WHERE status IN ('OPEN', 'FILLED', 'CONFIRMED');

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_lobbies_search
  ON public.lobbies (status, min_reliability, created_at DESC);

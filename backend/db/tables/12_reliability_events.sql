-- ============================================================================
-- SEBAR — table 3.12 : reliability_events (SDD §4.3.12)
-- ============================================================================
-- Run order : 3.12 — setelah tables/01_users.sql (+ tables/07_lobbies.sql)
-- Depends   : public.users, public.lobbies, enum public.reliability_reason
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.reliability_events (
  id          uuid                    PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid                    NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  lobby_id    uuid                    REFERENCES public.lobbies(id) ON DELETE SET NULL,
  delta       numeric(5,2)            NOT NULL CHECK (delta <> 0),
  reason      public.reliability_reason NOT NULL,
  score_after numeric(5,2)            NOT NULL,
  created_at  timestamptz             NOT NULL DEFAULT now()
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_reliability_user_created
  ON public.reliability_events (user_id, created_at DESC);

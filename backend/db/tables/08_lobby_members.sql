-- ============================================================================
-- SEBAR — table 3.8 : lobby_members (SDD §4.3.8)
-- ============================================================================
-- Run order : 3.8 — setelah tables/07_lobbies.sql (+ tables/03_wallet_ledger.sql)
-- Depends   : public.lobbies, public.users, public.wallet_ledger,
--             enum public.member_role, public.member_status
-- Note      : hold trigger ada di db/triggers/03_lobby_members.sql
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.lobby_members (
  id             uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
  lobby_id       uuid                  NOT NULL REFERENCES public.lobbies(id) ON DELETE CASCADE,
  user_id        uuid                  NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  role_in_lobby  public.member_role    NOT NULL DEFAULT 'PLAYER',
  status         public.member_status  NOT NULL DEFAULT 'HOLDING',
  hold_amount    numeric(12,2)         NOT NULL CHECK (hold_amount > 0),
  hold_ledger_id uuid                  REFERENCES public.wallet_ledger(id) ON DELETE SET NULL,
  joined_at      timestamptz           NOT NULL DEFAULT now(),
  cancelled_at   timestamptz,
  UNIQUE (lobby_id, user_id)
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_lobby_members_user
  ON public.lobby_members (user_id, status);

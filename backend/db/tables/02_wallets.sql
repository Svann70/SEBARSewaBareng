-- ============================================================================
-- SEBAR — table 3.2 : wallets (SDD §4.3.2)
-- ============================================================================
-- Run order : 3.2 — setelah tables/01_users.sql
-- Depends   : public.users (1:1); available = balance - held_balance
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.wallets (
  id            uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       uuid          NOT NULL UNIQUE REFERENCES public.users(id) ON DELETE RESTRICT,
  balance       numeric(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
  held_balance  numeric(14,2) NOT NULL DEFAULT 0 CHECK (held_balance >= 0),
  version       integer       NOT NULL DEFAULT 0,          -- optimistic lock (opsional)
  CONSTRAINT wallets_balance_gte_held CHECK (balance >= held_balance)
);

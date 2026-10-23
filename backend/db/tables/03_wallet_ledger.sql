-- ============================================================================
-- SEBAR — table 3.3 : wallet_ledger (SDD §4.3.3)
-- ============================================================================
-- Run order : 3.3 — setelah tables/02_wallets.sql
-- Depends   : public.wallets, enum public.ledger_type
-- G2        : append-only — setiap mutasi saldo tercatat
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.wallet_ledger (
  id              uuid            PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id       uuid            NOT NULL REFERENCES public.wallets(id) ON DELETE RESTRICT,
  entry_type      public.ledger_type NOT NULL,
  amount          numeric(14,2)   NOT NULL CHECK (amount > 0),
  balance_after   numeric(14,2)   NOT NULL,
  held_after      numeric(14,2)   NOT NULL,
  ref_type        text,
  ref_id          uuid,
  idempotency_key text            UNIQUE,                  -- ADR-07
  created_at      timestamptz     NOT NULL DEFAULT now()
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_ledger_wallet
  ON public.wallet_ledger (wallet_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_ledger_ref
  ON public.wallet_ledger (ref_type, ref_id);

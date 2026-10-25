DO $$ BEGIN
  CREATE TYPE public.withdrawal_status AS ENUM ('PENDING', 'PROCESSING', 'COMPLETED', 'REJECTED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS public.wallet_withdrawals (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id       uuid NOT NULL REFERENCES public.wallets(id) ON DELETE RESTRICT,
  amount          numeric(14,2) NOT NULL CHECK (amount > 0),
  bank_code       text NOT NULL,
  account_number  text NOT NULL,
  account_name    text NOT NULL,
  status          public.withdrawal_status NOT NULL DEFAULT 'PENDING',
  idempotency_key text NOT NULL UNIQUE,
  created_at      timestamptz NOT NULL DEFAULT now(),
  processed_at    timestamptz
);

CREATE INDEX IF NOT EXISTS idx_wallet_withdrawals_wallet
  ON public.wallet_withdrawals (wallet_id, created_at DESC);

ALTER TABLE public.wallet_withdrawals ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- SEBAR — functions : wallet (SDD §4.5, §5.4–§5.6, BR-2.x, ADR-04, ADR-07)
-- ============================================================================
-- Run order : 4.3 — setelah tables/02_wallets.sql + tables/03_wallet_ledger.sql,
--             sebelum triggers/ (trg_member_hold memanggil wallet_hold)
-- ============================================================================

-- HOLD (BR-2.1/2.2/2.3): kunci saldo tanpa memotong; idempoten; FOR UPDATE
CREATE OR REPLACE FUNCTION public.wallet_hold(
  p_user_id         uuid,
  p_amount          numeric,
  p_ref_type        text,
  p_ref_id          uuid,
  p_idempotency_key text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_wallet    public.wallets%ROWTYPE;
  v_ledger_id uuid;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'SEBAR::HOLD_AMOUNT_INVALID';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::WALLET_NOT_FOUND'; END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_ledger_id FROM public.wallet_ledger
    WHERE idempotency_key = p_idempotency_key;
    IF v_ledger_id IS NOT NULL THEN
      RETURN v_ledger_id;                    -- retry → idempoten (BR-2.3)
    END IF;
  END IF;

  IF (v_wallet.balance - v_wallet.held_balance) < p_amount THEN
    RAISE EXCEPTION 'SEBAR::INSUFFICIENT_AVAILABLE_BALANCE';  -- BR-2.1
  END IF;

  UPDATE public.wallets
  SET held_balance = held_balance + p_amount,
      version      = version + 1
  WHERE id = v_wallet.id
  RETURNING * INTO v_wallet;

  INSERT INTO public.wallet_ledger
    (wallet_id, entry_type, amount, balance_after, held_after, ref_type, ref_id, idempotency_key)
  VALUES
    (v_wallet.id, 'HOLD', p_amount, v_wallet.balance, v_wallet.held_balance,
     p_ref_type, p_ref_id, p_idempotency_key)
  RETURNING id INTO v_ledger_id;

  RETURN v_ledger_id;
END $$;

-- RELEASE (§5.4): pelepasan hold tanpa pemotongan
CREATE OR REPLACE FUNCTION public.wallet_release(
  p_user_id         uuid,
  p_amount          numeric,
  p_ref_type        text,
  p_ref_id          uuid,
  p_idempotency_key text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_wallet    public.wallets%ROWTYPE;
  v_ledger_id uuid;
  v_release   numeric;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'SEBAR::RELEASE_AMOUNT_INVALID';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::WALLET_NOT_FOUND'; END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_ledger_id FROM public.wallet_ledger
    WHERE idempotency_key = p_idempotency_key;
    IF v_ledger_id IS NOT NULL THEN
      RETURN v_ledger_id;
    END IF;
  END IF;

  v_release := LEAST(p_amount, v_wallet.held_balance);
  IF v_release <= 0 THEN
    RAISE EXCEPTION 'SEBAR::NOTHING_TO_RELEASE';
  END IF;

  UPDATE public.wallets
  SET held_balance = held_balance - v_release,
      version      = version + 1
  WHERE id = v_wallet.id
  RETURNING * INTO v_wallet;

  INSERT INTO public.wallet_ledger
    (wallet_id, entry_type, amount, balance_after, held_after, ref_type, ref_id, idempotency_key)
  VALUES
    (v_wallet.id, 'RELEASE', v_release, v_wallet.balance, v_wallet.held_balance,
     p_ref_type, p_ref_id, p_idempotency_key)
  RETURNING id INTO v_ledger_id;

  RETURN v_ledger_id;
END $$;

-- CAPTURE (§5.4): pemotongan saldo hasil hold; dipakai juga untuk PENALTY
CREATE OR REPLACE FUNCTION public.wallet_capture(
  p_user_id         uuid,
  p_amount          numeric,
  p_ref_type        text,
  p_ref_id          uuid,
  p_entry_type      public.ledger_type DEFAULT 'CAPTURE',
  p_idempotency_key text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_wallet    public.wallets%ROWTYPE;
  v_ledger_id uuid;
  v_capture   numeric;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'SEBAR::CAPTURE_AMOUNT_INVALID';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::WALLET_NOT_FOUND'; END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_ledger_id FROM public.wallet_ledger
    WHERE idempotency_key = p_idempotency_key;
    IF v_ledger_id IS NOT NULL THEN
      RETURN v_ledger_id;
    END IF;
  END IF;

  v_capture := LEAST(p_amount, v_wallet.held_balance);

  UPDATE public.wallets
  SET balance      = balance - v_capture,
      held_balance = held_balance - v_capture,
      version      = version + 1
  WHERE id = v_wallet.id
  RETURNING * INTO v_wallet;

  INSERT INTO public.wallet_ledger
    (wallet_id, entry_type, amount, balance_after, held_after, ref_type, ref_id, idempotency_key)
  VALUES
    (v_wallet.id, p_entry_type, v_capture, v_wallet.balance, v_wallet.held_balance,
     p_ref_type, p_ref_id, p_idempotency_key)
  RETURNING id INTO v_ledger_id;

  RETURN v_ledger_id;
END $$;

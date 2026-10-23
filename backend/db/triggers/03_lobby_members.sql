-- ============================================================================
-- SEBAR — triggers : public.lobby_members (SDD §4.6, BR-2.x, BR-3.1, §5.6)
-- ============================================================================
-- Run order : 5.3 — setelah tables/08_lobby_members.sql,
--             functions/01_apply_reliability.sql, functions/03_wallet.sql,
--             functions/04_lobby_lifecycle.sql
-- ============================================================================

-- (a) JOIN → wallet_hold → auto-booking saat 100% kuota (SDD §4.6 / BR-3.1)
CREATE OR REPLACE FUNCTION public.trg_member_hold() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_user   public.users%ROWTYPE;
  v_lobby  public.lobbies%ROWTYPE;
  v_filled int;
  v_ledger uuid;
BEGIN
  SELECT * INTO v_user FROM public.users WHERE id = NEW.user_id;

  SELECT * INTO v_lobby FROM public.lobbies WHERE id = NEW.lobby_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::LOBBY_NOT_FOUND'; END IF;
  IF v_lobby.status <> 'OPEN' THEN
    RAISE EXCEPTION 'SEBAR::LOBBY_FULL';                  -- US: 409
  END IF;
  IF now() > v_lobby.join_deadline THEN
    RAISE EXCEPTION 'SEBAR::DEADLINE_PASSED';             -- 410
  END IF;

  -- BR-5.1: join ditolak bila skor < minimum → 403 tanpa hold (US-11, T-07)
  IF v_user.reliability_score < v_lobby.min_reliability THEN
    RAISE EXCEPTION 'SEBAR::SCORE_TOO_LOW';
  END IF;

  -- BR-2.x: join = komitmen dana, dihitung DB di transaksi yang sama (ADR-04)
  v_ledger := public.wallet_hold(
    NEW.user_id, v_lobby.price_per_person, 'LOBBY', v_lobby.id,
    'HOLD:' || NEW.lobby_id::text || ':' || NEW.user_id::text);

  UPDATE public.lobby_members SET hold_ledger_id = v_ledger WHERE id = NEW.id;

  -- BR-3.1: kuota 100% → FILLED → confirm_lobby() pada transaksi yang sama
  SELECT count(*) INTO v_filled
  FROM public.lobby_members
  WHERE lobby_id = NEW.lobby_id AND status = 'HOLDING';

  IF v_filled = v_lobby.quota THEN
    UPDATE public.lobbies SET status = 'FILLED' WHERE id = v_lobby.id;
    UPDATE public.court_slots SET status = 'LOBBY_FULL' WHERE id = v_lobby.slot_id;
    PERFORM public.confirm_lobby(v_lobby.id);   -- transaksi identik
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_member_hold ON public.lobby_members;
CREATE TRIGGER trg_member_hold
  AFTER INSERT ON public.lobby_members
  FOR EACH ROW EXECUTE FUNCTION public.trg_member_hold();

-- (b) Pembatalan member — kebijakan 3 zona (SDD §5.6):
--     batal ≥ 6 jam  → release 100%, tanpa denda, skor 0   (US-08)
--     batal < 6 jam  → release 50%, denda 50% ke venue, skor −10 (US-09)
CREATE OR REPLACE FUNCTION public.trg_member_cancel() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_start_at  timestamptz;
  v_booking   uuid;
  v_payout_id uuid;
  v_amount    numeric(12,2) := OLD.hold_amount;
  v_half      numeric(12,2);
  v_hours     numeric;
BEGIN
  IF NEW.status <> 'CANCELLED' OR OLD.status NOT IN ('HOLDING', 'CONFIRMED') THEN
    RETURN NEW;
  END IF;

  SELECT s.start_at INTO v_start_at
  FROM public.lobbies l
  JOIN public.court_slots s ON s.id = l.slot_id
  WHERE l.id = OLD.lobby_id;

  v_hours := extract(epoch FROM (v_start_at - now())) / 3600.0;
  v_half  := round(v_amount / 2, 2);

  IF v_hours >= 6 THEN
    PERFORM public.wallet_release(
      OLD.user_id, v_amount, 'LOBBY', OLD.lobby_id,
      'RELEASE-CANCEL:' || OLD.lobby_id::text || ':' || OLD.user_id::text);
  ELSE
    PERFORM public.wallet_release(
      OLD.user_id, v_half, 'LOBBY', OLD.lobby_id,
      'RELEASE-CANCEL:' || OLD.lobby_id::text || ':' || OLD.user_id::text);
    PERFORM public.wallet_capture(
      OLD.user_id, v_half, 'LOBBY', OLD.lobby_id, 'PENALTY',
      'PENALTY-CANCEL:' || OLD.lobby_id::text || ':' || OLD.user_id::text);

    -- BR-4.1: denda dikreditkan ke venue_payout booking terkait
    SELECT b.id, vp.id INTO v_booking, v_payout_id
    FROM public.bookings b
    JOIN public.venue_payouts vp ON vp.booking_id = b.id
    WHERE b.lobby_id = OLD.lobby_id;
    IF v_payout_id IS NOT NULL THEN
      UPDATE public.venue_payouts SET amount = amount + v_half WHERE id = v_payout_id;
    END IF;

    PERFORM public.apply_reliability(OLD.user_id, -10, 'LATE_CANCEL', OLD.lobby_id);
    NEW.status := 'PENALIZED';   -- beda dari batal.awal (SDD enum member_status)
  END IF;

  NEW.cancelled_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_member_cancel ON public.lobby_members;
CREATE TRIGGER trg_member_cancel
  BEFORE UPDATE OF status ON public.lobby_members
  FOR EACH ROW EXECUTE FUNCTION public.trg_member_cancel();

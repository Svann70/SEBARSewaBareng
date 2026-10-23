-- ============================================================================
-- SEBAR — functions : lobby lifecycle (SDD §4.5, §5.6, BR-3.x)
-- ============================================================================
-- Run order : 4.4 — setelah functions/01–03, sebelum triggers/
-- confirm_lobby(uuid)   : transaksi auto-booking 9 langkah — kegagalan di langkah
--                         mana pun = ROLLBACK penuh (T-05).
-- expire_stale_lobbies(): lobby lewat deadline & kuota < 100% → release hold.
-- cancel_lobby_by_host(): host batalkan lobby → release hold, host −15 skor.
-- ============================================================================

CREATE OR REPLACE FUNCTION public.confirm_lobby(p_lobby_id uuid) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_lobby    public.lobbies%ROWTYPE;
  v_slot     public.court_slots%ROWTYPE;
  v_member   public.lobby_members%ROWTYPE;
  v_booking  public.bookings%ROWTYPE;
  v_venue_id uuid;
  v_count    int;
  v_fee      numeric(12,2);
  v_surplus  numeric(12,2);
  v_code     text;
BEGIN
  -- (1) lock lobby & slot — SELECT … FOR UPDATE (SDD §4.4, G1)
  SELECT * INTO v_lobby FROM public.lobbies WHERE id = p_lobby_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::LOBBY_NOT_FOUND'; END IF;
  IF v_lobby.status NOT IN ('OPEN', 'FILLED') THEN
    RAISE EXCEPTION 'SEBAR::LOBBY_NOT_CONFIRMABLE';
  END IF;

  SELECT * INTO v_slot FROM public.court_slots WHERE id = v_lobby.slot_id FOR UPDATE;

  -- (2) validasi kuota 100% (G3)
  SELECT count(*) INTO v_count
  FROM public.lobby_members
  WHERE lobby_id = p_lobby_id AND status IN ('HOLDING', 'CONFIRMED');
  IF v_count <> v_lobby.quota THEN
    RAISE EXCEPTION 'SEBAR::QUOTA_NOT_FULL';
  END IF;

  SELECT c.venue_id INTO v_venue_id
  FROM public.courts c WHERE c.id = v_slot.court_id;

  -- (3) CAPTURE setiap member HOLDING — bila gagal → ROLLBACK penuh (BR-3.2)
  FOR v_member IN
    SELECT * FROM public.lobby_members
    WHERE lobby_id = p_lobby_id AND status = 'HOLDING'
    FOR UPDATE
  LOOP
    PERFORM public.wallet_capture(
      v_member.user_id, v_member.hold_amount, 'LOBBY', v_lobby.id, 'CAPTURE',
      'CAPTURE:' || v_lobby.id::text || ':' || v_member.user_id::text);
    UPDATE public.lobby_members SET status = 'CONFIRMED' WHERE id = v_member.id;
  END LOOP;

  -- surplus pembulatan iter ke venue (BR-1.2, BR-3.5)
  v_surplus := GREATEST((v_lobby.price_per_person * v_lobby.quota) - v_lobby.price_total, 0);
  v_fee     := round(v_lobby.price_total * 0.05, 2);
  v_code    := 'SEB' || upper(replace(gen_random_uuid()::text, '-', ''));
  v_code    := substr(v_code, 1, 9) || lpad((floor(random() * 900) + 100)::int::text, 3, '0'); -- 12 char

  -- (4) INSERT booking — UNIQUE(slot_id) pertahanan terakhir (SDD §4.3.9)
  INSERT INTO public.bookings
    (lobby_id, slot_id, booking_code, gross_amount, platform_fee, rounding_surplus, venue_payout)
  VALUES
    (v_lobby.id, v_slot.id, v_code, v_lobby.price_total, v_fee, v_surplus,
     v_lobby.price_total - v_fee + v_surplus)
  RETURNING * INTO v_booking;

  -- (5) slot → BOOKED
  UPDATE public.court_slots SET status = 'BOOKED' WHERE id = v_slot.id;

  -- (6) venue_payout PENDING
  INSERT INTO public.venue_payouts (booking_id, venue_id, amount)
  VALUES (v_booking.id, v_venue_id, v_booking.venue_payout);

  -- (7) 1 QR per peserta — hash disimpan, token hanya via API (BR-5.3)
  FOR v_member IN
    SELECT * FROM public.lobby_members WHERE lobby_id = p_lobby_id
  LOOP
    INSERT INTO public.checkins (booking_id, user_id, token_hash, token_expires_at)
    VALUES (
      v_booking.id,
      v_member.user_id,
      encode(digest(v_lobby.id::text || ':' || v_member.user_id::text || ':' ||
                    clock_timestamp()::text, 'sha256'), 'hex'),
      v_slot.start_at + interval '2 hours');   -- exp = start_at + 2 jam (BR-5.2)
  END LOOP;

  -- (8) lobby → CONFIRMED
  UPDATE public.lobbies SET status = 'CONFIRMED' WHERE id = v_lobby.id;

  -- (9) notifications + audit
  INSERT INTO public.notifications (user_id, type, payload)
  SELECT lm.user_id, 'BOOKING_CONFIRMED',
         jsonb_build_object('bookingId', v_booking.id, 'bookingCode', v_booking.booking_code,
                            'startAt', v_slot.start_at, 'grossAmount', v_booking.gross_amount)
  FROM public.lobby_members lm
  WHERE lm.lobby_id = p_lobby_id;

  PERFORM public.log_audit('CONFIRM_LOBBY', 'lobbies', v_lobby.id, v_lobby.host_id,
    NULL, jsonb_build_object('bookingId', v_booking.id, 'bookingCode', v_booking.booking_code));

  RETURN v_booking.id;
END $$;

-- ============================================================================
-- expire_stale_lobbies() (BR-3.4, US-07): lobby lewat deadline & kuota < 100%
-- → release 100% hold, status EXPIRED, slot tetap/kembali OPEN.
-- Dipanggil scheduler atau endpoint admin POST /admin/expire-lobbies (§15).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.expire_stale_lobbies() RETURNS integer
LANGUAGE plpgsql AS $$
DECLARE
  v_lobby  public.lobbies%ROWTYPE;
  v_member public.lobby_members%ROWTYPE;
  v_count  int := 0;
  v_filled int;
BEGIN
  FOR v_lobby IN
    SELECT * FROM public.lobbies
    WHERE status = 'OPEN' AND join_deadline < now()
    ORDER BY id
    FOR UPDATE SKIP LOCKED
  LOOP
    SELECT count(*) INTO v_filled
    FROM public.lobby_members
    WHERE lobby_id = v_lobby.id AND status = 'HOLDING';

    IF v_filled = v_lobby.quota THEN
      PERFORM public.confirm_lobby(v_lobby.id);   -- kuota penuh tapi belum konfirmasi
    ELSE
      FOR v_member IN
        SELECT * FROM public.lobby_members
        WHERE lobby_id = v_lobby.id AND status = 'HOLDING'
        FOR UPDATE
      LOOP
        PERFORM public.wallet_release(
          v_member.user_id, v_member.hold_amount, 'LOBBY', v_lobby.id,
          'RELEASE-EXPIRE:' || v_lobby.id::text || ':' || v_member.user_id::text);
        UPDATE public.lobby_members SET status = 'REFUNDED' WHERE id = v_member.id;
      END LOOP;

      UPDATE public.lobbies SET status = 'EXPIRED' WHERE id = v_lobby.id;

      INSERT INTO public.notifications (user_id, type, payload)
      SELECT lm.user_id, 'LOBBY_EXPIRED',
             jsonb_build_object('lobbyId', v_lobby.id, 'title', v_lobby.title)
      FROM public.lobby_members lm WHERE lm.lobby_id = v_lobby.id;

      PERFORM public.log_audit('EXPIRE_LOBBY', 'lobbies', v_lobby.id, NULL,
        jsonb_build_object('status', 'OPEN'), jsonb_build_object('status', 'EXPIRED'));
    END IF;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END $$;

-- ============================================================================
-- cancel_lobby_by_host(uuid, uuid) (SDD §5.6): host batalkan lobby
-- → release 100% semua hold, host −15 skor, peserta notifikasi (US-16).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.cancel_lobby_by_host(p_lobby_id uuid, p_actor uuid)
RETURNS void
LANGUAGE plpgsql AS $$
DECLARE
  v_lobby  public.lobbies%ROWTYPE;
  v_member public.lobby_members%ROWTYPE;
BEGIN
  SELECT * INTO v_lobby FROM public.lobbies WHERE id = p_lobby_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::LOBBY_NOT_FOUND'; END IF;
  IF v_lobby.host_id <> p_actor THEN RAISE EXCEPTION 'SEBAR::FORBIDDEN'; END IF;
  IF v_lobby.status NOT IN ('OPEN', 'FILLED') THEN
    RAISE EXCEPTION 'SEBAR::LOBBY_NOT_CANCELLABLE';
  END IF;

  FOR v_member IN
    SELECT * FROM public.lobby_members
    WHERE lobby_id = p_lobby_id AND status = 'HOLDING'
    FOR UPDATE
  LOOP
    PERFORM public.wallet_release(
      v_member.user_id, v_member.hold_amount, 'LOBBY', v_lobby.id,
      'RELEASE-HOSTCANCEL:' || v_lobby.id::text || ':' || v_member.user_id::text);
    UPDATE public.lobby_members
    SET status = 'REFUNDED', cancelled_at = now()
    WHERE id = v_member.id;
  END LOOP;

  UPDATE public.lobbies SET status = 'CANCELLED' WHERE id = v_lobby.id;

  PERFORM public.apply_reliability(v_lobby.host_id, -15, 'HOST_CANCEL', v_lobby.id);

  INSERT INTO public.notifications (user_id, type, payload)
  SELECT lm.user_id, 'LOBBY_CANCELLED',
         jsonb_build_object('lobbyId', v_lobby.id, 'title', v_lobby.title)
  FROM public.lobby_members lm WHERE lm.lobby_id = v_lobby.id;

  PERFORM public.log_audit('HOST_CANCEL_LOBBY', 'lobbies', v_lobby.id, p_actor,
    jsonb_build_object('status', v_lobby.status), jsonb_build_object('status', 'CANCELLED'));
END $$;

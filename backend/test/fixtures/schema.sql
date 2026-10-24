-- TEST FIXTURE ONLY. Production schema lives in Supabase and is not managed by this repo.
-- Generated 2026-10-21 with: pg_dump --schema-only --schema=public --no-owner --no-privileges --no-comments
-- Re-generate when the Supabase schema changes. The lines below recreate what Supabase provides outside `public`.
CREATE SCHEMA IF NOT EXISTS extensions;
CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
DO $$ BEGIN EXECUTE format('ALTER DATABASE %I SET search_path = "$user", public, extensions', current_database()); END $$;

--
-- PostgreSQL database dump
--

\restrict aampWs302EydbzBwdMb3F8wYjXVzbArSIIWxR6ZmYvh3rvOmiekhk91AnDZZ6G0

-- Dumped from database version 17.11
-- Dumped by pg_dump version 18.6

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--



--
-- Name: booking_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.booking_status AS ENUM (
    'CONFIRMED',
    'COMPLETED',
    'CANCELLED'
);


--
-- Name: checkin_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.checkin_status AS ENUM (
    'PENDING',
    'SCANNED',
    'EXPIRED',
    'NO_SHOW'
);


--
-- Name: court_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.court_status AS ENUM (
    'ACTIVE',
    'MAINTENANCE'
);


--
-- Name: ledger_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.ledger_type AS ENUM (
    'TOPUP',
    'HOLD',
    'RELEASE',
    'CAPTURE',
    'REFUND',
    'PAYOUT',
    'PENALTY'
);


--
-- Name: lobby_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.lobby_status AS ENUM (
    'OPEN',
    'FILLED',
    'CONFIRMED',
    'CANCELLED',
    'EXPIRED',
    'FAILED'
);


--
-- Name: member_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.member_role AS ENUM (
    'HOST',
    'PLAYER'
);


--
-- Name: member_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.member_status AS ENUM (
    'HOLDING',
    'CONFIRMED',
    'CANCELLED',
    'REFUNDED',
    'PENALIZED',
    'NO_SHOW'
);


--
-- Name: payout_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.payout_status AS ENUM (
    'PENDING',
    'PAID'
);


--
-- Name: reliability_reason; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reliability_reason AS ENUM (
    'CHECKIN',
    'LATE_CANCEL',
    'NO_SHOW',
    'HOST_CANCEL',
    'MANUAL_ADJUST'
);


--
-- Name: slot_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.slot_status AS ENUM (
    'OPEN',
    'LOBBY_FULL',
    'BOOKED',
    'BLOCKED',
    'PAST'
);


--
-- Name: sport_type; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.sport_type AS ENUM (
    'BADMINTON',
    'FUTSAL',
    'VOLLEY',
    'MINISOCCER'
);


--
-- Name: user_role; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.user_role AS ENUM (
    'PLAYER',
    'VENUE_ADMIN',
    'SUPER_ADMIN'
);


--
-- Name: venue_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.venue_status AS ENUM (
    'ACTIVE',
    'INACTIVE'
);


--
-- Name: apply_reliability(uuid, numeric, public.reliability_reason, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.apply_reliability(p_user_id uuid, p_delta numeric, p_reason public.reliability_reason, p_lobby_id uuid DEFAULT NULL::uuid) RETURNS numeric
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_old numeric;
  v_new numeric;
BEGIN
  SELECT reliability_score INTO v_old FROM public.users WHERE id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::USER_NOT_FOUND'; END IF;

  v_new := LEAST(100::numeric, GREATEST(0::numeric, v_old + p_delta));
  UPDATE public.users SET reliability_score = v_new WHERE id = p_user_id;

  -- skip bila clamp menghasilkan delta 0 (CHECK delta <> 0 di reliability_events)
  IF v_new <> v_old THEN
    INSERT INTO public.reliability_events (user_id, lobby_id, delta, reason, score_after)
    VALUES (p_user_id, p_lobby_id, (v_new - v_old), p_reason, v_new);
  END IF;

  RETURN v_new;
END $$;


--
-- Name: cancel_lobby_by_host(uuid, uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cancel_lobby_by_host(p_lobby_id uuid, p_actor uuid) RETURNS void
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: confirm_lobby(uuid); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.confirm_lobby(p_lobby_id uuid) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: expire_stale_lobbies(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.expire_stale_lobbies() RETURNS integer
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: fn_peak_hours(uuid, date, date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_peak_hours(p_venue uuid, p_from date, p_to date) RETURNS TABLE(jam numeric, booking bigint, persen numeric)
    LANGUAGE sql STABLE
    AS $$
  SELECT extract(hour FROM s.start_at)                          AS jam,
         count(*)                                               AS booking,
         round(100.0 * count(*) / sum(count(*)) OVER (), 1)     AS persen
  FROM public.bookings b
  JOIN public.court_slots s ON s.id = b.slot_id
  JOIN public.courts c      ON c.id = s.court_id
  WHERE c.venue_id = p_venue
    AND b.booked_at::date BETWEEN p_from AND p_to
    AND b.status <> 'CANCELLED'
  GROUP BY 1
  ORDER BY 2 DESC
$$;


--
-- Name: fn_touch_updated_at(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.fn_touch_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;


--
-- Name: log_audit(text, text, uuid, uuid, jsonb, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.log_audit(p_action text, p_entity text, p_entity_id uuid, p_actor uuid DEFAULT NULL::uuid, p_before jsonb DEFAULT NULL::jsonb, p_after jsonb DEFAULT NULL::jsonb) RETURNS void
    LANGUAGE plpgsql
    AS $$
BEGIN
  INSERT INTO public.audit_log (actor_id, action, entity, entity_id, "before", "after")
  VALUES (p_actor, p_action, p_entity, p_entity_id, p_before, p_after);
END $$;


--
-- Name: rls_auto_enable(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.rls_auto_enable() RETURNS event_trigger
    LANGUAGE plpgsql SECURITY DEFINER
    SET search_path TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
  tbl name;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        SELECT c.relname INTO tbl FROM pg_catalog.pg_class c WHERE c.oid = cmd.objid;
        EXECUTE format('alter table if exists %I.%I enable row level security', cmd.schema_name, tbl);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


--
-- Name: trg_checkin_scanned(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_checkin_scanned() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  IF NEW.status = 'SCANNED' AND OLD.status <> 'SCANNED' THEN
    PERFORM public.apply_reliability(NEW.user_id, 2, 'CHECKIN');
  END IF;
  RETURN NEW;
END $$;


--
-- Name: trg_lobby_validate(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_lobby_validate() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_slot public.court_slots%ROWTYPE;
BEGIN
  SELECT * INTO v_slot FROM public.court_slots WHERE id = NEW.slot_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::SLOT_NOT_FOUND'; END IF;

  IF TG_OP = 'INSERT' AND v_slot.status <> 'OPEN' THEN
    RAISE EXCEPTION 'SEBAR::SLOT_NOT_OPEN';
  END IF;

  IF NEW.price_total <> v_slot.price THEN
    RAISE EXCEPTION 'SEBAR::PRICE_MISMATCH';
  END IF;

  IF NEW.join_deadline > v_slot.start_at - interval '6 hours' THEN
    RAISE EXCEPTION 'SEBAR::DEADLINE_TOO_LATE';   -- BR-1.5 / SDD §4.4
  END IF;

  -- perman: BR-1.4 — min_reliability tidak bisa diubah setelah ada member pertama
  IF TG_OP = 'UPDATE'
     AND EXISTS (SELECT 1 FROM public.lobby_members WHERE lobby_id = OLD.id)
     AND (NEW.min_reliability <> OLD.min_reliability OR NEW.quota <> OLD.quota) THEN
    RAISE EXCEPTION 'SEBAR::LOBBY_LOCKED';
  END IF;

  RETURN NEW;
END $$;


--
-- Name: trg_member_cancel(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_member_cancel() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: trg_member_hold(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_member_hold() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: trg_no_show(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_no_show() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_booking uuid;
  v_member  public.lobby_members%ROWTYPE;
  v_checkin public.checkins%ROWTYPE;
BEGIN
  IF NEW.status <> 'PAST' OR OLD.status NOT IN ('BOOKED', 'LOBBY_FULL') THEN
    RETURN NEW;
  END IF;

  SELECT id INTO v_booking FROM public.bookings WHERE slot_id = NEW.id;
  IF v_booking IS NULL THEN
    RETURN NEW;   -- slot OPEN/PAST tanpa booking → tak ada yang dihukum
  END IF;

  FOR v_member IN
    SELECT * FROM public.lobby_members
    WHERE lobby_id = (SELECT lobby_id FROM public.bookings WHERE slot_id = NEW.id)
      AND status IN ('HOLDING', 'CONFIRMED')
  LOOP
    SELECT * INTO v_checkin
    FROM public.checkins
    WHERE booking_id = v_booking AND user_id = v_member.user_id
    FOR UPDATE;

    IF v_checkin.id IS NOT NULL AND v_checkin.status <> 'SCANNED' THEN
      UPDATE public.checkins SET status = 'NO_SHOW' WHERE id = v_checkin.id;

      IF v_member.status = 'HOLDING' THEN
        PERFORM public.wallet_capture(
          v_member.user_id, v_member.hold_amount, 'LOBBY', v_member.lobby_id, 'PENALTY',
          'PENALTY-NOSHOW:' || v_member.lobby_id::text || ':' || v_member.user_id::text);
      END IF;

      UPDATE public.lobby_members SET status = 'NO_SHOW' WHERE id = v_member.id;
      PERFORM public.apply_reliability(v_member.user_id, -25, 'NO_SHOW', v_member.lobby_id);
    END IF;
  END LOOP;

  RETURN NEW;
END $$;


--
-- Name: trg_reliability_clamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.trg_reliability_clamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
  NEW.reliability_score := LEAST(100::numeric, GREATEST(0::numeric, NEW.reliability_score));
  RETURN NEW;
END $$;


--
-- Name: wallet_capture(uuid, numeric, text, uuid, public.ledger_type, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.wallet_capture(p_user_id uuid, p_amount numeric, p_ref_type text, p_ref_id uuid, p_entry_type public.ledger_type DEFAULT 'CAPTURE'::public.ledger_type, p_idempotency_key text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: wallet_hold(uuid, numeric, text, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.wallet_hold(p_user_id uuid, p_amount numeric, p_ref_type text, p_ref_id uuid, p_idempotency_key text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
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


--
-- Name: wallet_release(uuid, numeric, text, uuid, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.wallet_release(p_user_id uuid, p_amount numeric, p_ref_type text, p_ref_id uuid, p_idempotency_key text DEFAULT NULL::text) RETURNS uuid
    LANGUAGE plpgsql
    AS $$
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


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: audit_log; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_log (
    id bigint NOT NULL,
    actor_id uuid,
    action text NOT NULL,
    entity text NOT NULL,
    entity_id uuid,
    before jsonb,
    after jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: audit_log_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.audit_log_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: audit_log_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.audit_log_id_seq OWNED BY public.audit_log.id;


--
-- Name: bookings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.bookings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lobby_id uuid NOT NULL,
    slot_id uuid NOT NULL,
    booking_code character varying(12) NOT NULL,
    gross_amount numeric(12,2) NOT NULL,
    platform_fee numeric(12,2) NOT NULL,
    rounding_surplus numeric(12,2) DEFAULT 0 NOT NULL,
    venue_payout numeric(12,2) NOT NULL,
    status public.booking_status DEFAULT 'CONFIRMED'::public.booking_status NOT NULL,
    booked_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT bookings_fee_is_5pct CHECK ((platform_fee = round((gross_amount * 0.05), 2))),
    CONSTRAINT bookings_gross_amount_check CHECK ((gross_amount > (0)::numeric)),
    CONSTRAINT bookings_payout_invariant CHECK ((venue_payout >= (gross_amount - platform_fee))),
    CONSTRAINT bookings_platform_fee_check CHECK ((platform_fee >= (0)::numeric)),
    CONSTRAINT bookings_rounding_surplus_check CHECK ((rounding_surplus >= (0)::numeric)),
    CONSTRAINT bookings_venue_payout_check CHECK ((venue_payout > (0)::numeric))
);


--
-- Name: checkins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.checkins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid NOT NULL,
    user_id uuid NOT NULL,
    token_hash character(64) NOT NULL,
    token_expires_at timestamp with time zone NOT NULL,
    status public.checkin_status DEFAULT 'PENDING'::public.checkin_status NOT NULL,
    scanned_by uuid,
    scanned_at timestamp with time zone
);


--
-- Name: court_slots; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.court_slots (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    court_id uuid NOT NULL,
    start_at timestamp with time zone NOT NULL,
    end_at timestamp with time zone NOT NULL,
    price numeric(12,2) NOT NULL,
    status public.slot_status DEFAULT 'OPEN'::public.slot_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT court_slots_check CHECK ((end_at > start_at)),
    CONSTRAINT court_slots_price_check CHECK ((price > (0)::numeric))
);


--
-- Name: courts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.courts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    venue_id uuid NOT NULL,
    name character varying(60) NOT NULL,
    sport_type public.sport_type NOT NULL,
    price_per_hour numeric(12,2) NOT NULL,
    price_weekend numeric(12,2),
    capacity smallint NOT NULL,
    status public.court_status DEFAULT 'ACTIVE'::public.court_status NOT NULL,
    CONSTRAINT courts_capacity_check CHECK (((capacity >= 2) AND (capacity <= 30))),
    CONSTRAINT courts_price_per_hour_check CHECK ((price_per_hour > (0)::numeric))
);


--
-- Name: lobbies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lobbies (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    slot_id uuid NOT NULL,
    host_id uuid NOT NULL,
    title character varying(100) NOT NULL,
    min_reliability numeric(5,2) DEFAULT 0 NOT NULL,
    quota smallint NOT NULL,
    price_total numeric(12,2) NOT NULL,
    price_per_person numeric(12,2) GENERATED ALWAYS AS (ceil((price_total / (quota)::numeric))) STORED,
    join_deadline timestamp with time zone NOT NULL,
    status public.lobby_status DEFAULT 'OPEN'::public.lobby_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT lobbies_min_reliability_check CHECK (((min_reliability >= (0)::numeric) AND (min_reliability <= (100)::numeric))),
    CONSTRAINT lobbies_price_total_check CHECK ((price_total > (0)::numeric)),
    CONSTRAINT lobbies_quota_check CHECK (((quota >= 2) AND (quota <= 30)))
);


--
-- Name: lobby_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.lobby_members (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    lobby_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role_in_lobby public.member_role DEFAULT 'PLAYER'::public.member_role NOT NULL,
    status public.member_status DEFAULT 'HOLDING'::public.member_status NOT NULL,
    hold_amount numeric(12,2) NOT NULL,
    hold_ledger_id uuid,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    cancelled_at timestamp with time zone,
    CONSTRAINT lobby_members_hold_amount_check CHECK ((hold_amount > (0)::numeric))
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    type text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: reliability_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reliability_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    lobby_id uuid,
    delta numeric(5,2) NOT NULL,
    reason public.reliability_reason NOT NULL,
    score_after numeric(5,2) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reliability_events_delta_check CHECK ((delta <> (0)::numeric))
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    email public.citext NOT NULL,
    phone character varying(20),
    full_name character varying(80) NOT NULL,
    password_hash text NOT NULL,
    role public.user_role DEFAULT 'PLAYER'::public.user_role NOT NULL,
    reliability_score numeric(5,2) DEFAULT 100 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT users_reliability_score_check CHECK (((reliability_score >= (0)::numeric) AND (reliability_score <= (100)::numeric)))
);


--
-- Name: venue_payouts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venue_payouts (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    booking_id uuid NOT NULL,
    venue_id uuid NOT NULL,
    amount numeric(12,2) NOT NULL,
    status public.payout_status DEFAULT 'PENDING'::public.payout_status NOT NULL,
    disbursed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payouts_state_coherent CHECK ((((status = 'PENDING'::public.payout_status) AND (disbursed_at IS NULL)) OR ((status = 'PAID'::public.payout_status) AND (disbursed_at IS NOT NULL)))),
    CONSTRAINT venue_payouts_amount_check CHECK ((amount > (0)::numeric))
);


--
-- Name: venues; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.venues (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    owner_id uuid NOT NULL,
    name character varying(120) NOT NULL,
    address text NOT NULL,
    city character varying(60) NOT NULL,
    description text,
    photo_url text,
    status public.venue_status DEFAULT 'ACTIVE'::public.venue_status NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: vw_lobby_search; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_lobby_search AS
 SELECT l.id,
    l.slot_id,
    l.host_id,
    l.title,
    l.min_reliability,
    l.quota,
    l.price_total,
    l.price_per_person,
    l.join_deadline,
    l.status,
    s.start_at,
    s.end_at,
    c.sport_type,
    c.name AS court_name,
    v.id AS venue_id,
    v.name AS venue_name,
    v.city,
    ( SELECT count(*) AS count
           FROM public.lobby_members m
          WHERE ((m.lobby_id = l.id) AND (m.status = ANY (ARRAY['HOLDING'::public.member_status, 'CONFIRMED'::public.member_status])))) AS joined
   FROM (((public.lobbies l
     JOIN public.court_slots s ON ((s.id = l.slot_id)))
     JOIN public.courts c ON ((c.id = s.court_id)))
     JOIN public.venues v ON ((v.id = c.venue_id)));


--
-- Name: vw_venue_monthly_revenue; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_venue_monthly_revenue AS
 SELECT v.id AS venue_id,
    v.name AS venue_name,
    date_trunc('month'::text, b.booked_at) AS bulan,
    count(*) AS total_booking,
    sum(b.gross_amount) AS omzet,
    sum(b.platform_fee) AS fee_sebar,
    sum(b.venue_payout) AS payout_gor
   FROM ((((public.bookings b
     JOIN public.lobbies l ON ((l.id = b.lobby_id)))
     JOIN public.court_slots s ON ((s.id = b.slot_id)))
     JOIN public.courts c ON ((c.id = s.court_id)))
     JOIN public.venues v ON ((v.id = c.venue_id)))
  WHERE (b.status <> 'CANCELLED'::public.booking_status)
  GROUP BY v.id, v.name, (date_trunc('month'::text, b.booked_at));


--
-- Name: wallet_ledger; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallet_ledger (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    wallet_id uuid NOT NULL,
    entry_type public.ledger_type NOT NULL,
    amount numeric(14,2) NOT NULL,
    balance_after numeric(14,2) NOT NULL,
    held_after numeric(14,2) NOT NULL,
    ref_type text,
    ref_id uuid,
    idempotency_key text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT wallet_ledger_amount_check CHECK ((amount > (0)::numeric))
);


--
-- Name: wallets; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.wallets (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    balance numeric(14,2) DEFAULT 0 NOT NULL,
    held_balance numeric(14,2) DEFAULT 0 NOT NULL,
    version integer DEFAULT 0 NOT NULL,
    CONSTRAINT wallets_balance_check CHECK ((balance >= (0)::numeric)),
    CONSTRAINT wallets_balance_gte_held CHECK ((balance >= held_balance)),
    CONSTRAINT wallets_held_balance_check CHECK ((held_balance >= (0)::numeric))
);


--
-- Name: audit_log id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log ALTER COLUMN id SET DEFAULT nextval('public.audit_log_id_seq'::regclass);


--
-- Name: audit_log audit_log_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_pkey PRIMARY KEY (id);


--
-- Name: bookings bookings_booking_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_booking_code_key UNIQUE (booking_code);


--
-- Name: bookings bookings_lobby_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_lobby_id_key UNIQUE (lobby_id);


--
-- Name: bookings bookings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_pkey PRIMARY KEY (id);


--
-- Name: bookings bookings_slot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_slot_id_key UNIQUE (slot_id);


--
-- Name: checkins checkins_booking_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins
    ADD CONSTRAINT checkins_booking_id_user_id_key UNIQUE (booking_id, user_id);


--
-- Name: checkins checkins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins
    ADD CONSTRAINT checkins_pkey PRIMARY KEY (id);


--
-- Name: checkins checkins_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins
    ADD CONSTRAINT checkins_token_hash_key UNIQUE (token_hash);


--
-- Name: court_slots court_slots_court_id_start_at_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.court_slots
    ADD CONSTRAINT court_slots_court_id_start_at_key UNIQUE (court_id, start_at);


--
-- Name: court_slots court_slots_court_id_tstzrange_excl; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.court_slots
    ADD CONSTRAINT court_slots_court_id_tstzrange_excl EXCLUDE USING gist (court_id WITH =, tstzrange(start_at, end_at) WITH &&);


--
-- Name: court_slots court_slots_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.court_slots
    ADD CONSTRAINT court_slots_pkey PRIMARY KEY (id);


--
-- Name: courts courts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT courts_pkey PRIMARY KEY (id);


--
-- Name: courts courts_venue_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT courts_venue_id_name_key UNIQUE (venue_id, name);


--
-- Name: lobbies lobbies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lobbies
    ADD CONSTRAINT lobbies_pkey PRIMARY KEY (id);


--
-- Name: lobby_members lobby_members_lobby_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lobby_members
    ADD CONSTRAINT lobby_members_lobby_id_user_id_key UNIQUE (lobby_id, user_id);


--
-- Name: lobby_members lobby_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lobby_members
    ADD CONSTRAINT lobby_members_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: reliability_events reliability_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reliability_events
    ADD CONSTRAINT reliability_events_pkey PRIMARY KEY (id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_phone_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_phone_key UNIQUE (phone);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: venue_payouts venue_payouts_booking_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_payouts
    ADD CONSTRAINT venue_payouts_booking_id_key UNIQUE (booking_id);


--
-- Name: venue_payouts venue_payouts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_payouts
    ADD CONSTRAINT venue_payouts_pkey PRIMARY KEY (id);


--
-- Name: venues venues_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_pkey PRIMARY KEY (id);


--
-- Name: wallet_ledger wallet_ledger_idempotency_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_ledger
    ADD CONSTRAINT wallet_ledger_idempotency_key_key UNIQUE (idempotency_key);


--
-- Name: wallet_ledger wallet_ledger_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_ledger
    ADD CONSTRAINT wallet_ledger_pkey PRIMARY KEY (id);


--
-- Name: wallets wallets_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT wallets_pkey PRIMARY KEY (id);


--
-- Name: wallets wallets_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT wallets_user_id_key UNIQUE (user_id);


--
-- Name: idx_audit_entity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_audit_entity ON public.audit_log USING btree (entity, entity_id, created_at DESC);


--
-- Name: idx_bookings_status_booked_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_bookings_status_booked_at ON public.bookings USING btree (status, booked_at DESC);


--
-- Name: idx_checkins_booking; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_checkins_booking ON public.checkins USING btree (booking_id, status);


--
-- Name: idx_courts_venue; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_courts_venue ON public.courts USING btree (venue_id);


--
-- Name: idx_ledger_ref; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ledger_ref ON public.wallet_ledger USING btree (ref_type, ref_id);


--
-- Name: idx_ledger_wallet; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ledger_wallet ON public.wallet_ledger USING btree (wallet_id, created_at DESC);


--
-- Name: idx_lobbies_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lobbies_search ON public.lobbies USING btree (status, min_reliability, created_at DESC);


--
-- Name: idx_lobby_members_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_lobby_members_user ON public.lobby_members USING btree (user_id, status);


--
-- Name: idx_notifications_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_notifications_user_created ON public.notifications USING btree (user_id, created_at DESC);


--
-- Name: idx_reliability_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reliability_user_created ON public.reliability_events USING btree (user_id, created_at DESC);


--
-- Name: idx_slots_court_start; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_slots_court_start ON public.court_slots USING btree (court_id, start_at DESC);


--
-- Name: idx_slots_open; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_slots_open ON public.court_slots USING btree (start_at) WHERE (status = 'OPEN'::public.slot_status);


--
-- Name: idx_venues_city_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_venues_city_status ON public.venues USING btree (city, status);


--
-- Name: uq_lobbies_active_slot; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX uq_lobbies_active_slot ON public.lobbies USING btree (slot_id) WHERE (status = ANY (ARRAY['OPEN'::public.lobby_status, 'FILLED'::public.lobby_status, 'CONFIRMED'::public.lobby_status]));


--
-- Name: checkins trg_checkin_scanned; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_checkin_scanned BEFORE UPDATE OF status ON public.checkins FOR EACH ROW EXECUTE FUNCTION public.trg_checkin_scanned();


--
-- Name: lobbies trg_lobby_validate; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_lobby_validate BEFORE INSERT OR UPDATE OF slot_id, price_total, join_deadline, min_reliability, quota ON public.lobbies FOR EACH ROW EXECUTE FUNCTION public.trg_lobby_validate();


--
-- Name: lobby_members trg_member_cancel; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_member_cancel BEFORE UPDATE OF status ON public.lobby_members FOR EACH ROW EXECUTE FUNCTION public.trg_member_cancel();


--
-- Name: lobby_members trg_member_hold; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_member_hold AFTER INSERT ON public.lobby_members FOR EACH ROW EXECUTE FUNCTION public.trg_member_hold();


--
-- Name: court_slots trg_no_show; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_no_show BEFORE UPDATE OF status ON public.court_slots FOR EACH ROW EXECUTE FUNCTION public.trg_no_show();


--
-- Name: users trg_reliability_clamp; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_reliability_clamp BEFORE UPDATE OF reliability_score ON public.users FOR EACH ROW EXECUTE FUNCTION public.trg_reliability_clamp();


--
-- Name: users trg_users_touch; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER trg_users_touch BEFORE UPDATE ON public.users FOR EACH ROW EXECUTE FUNCTION public.fn_touch_updated_at();


--
-- Name: audit_log audit_log_actor_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_log
    ADD CONSTRAINT audit_log_actor_id_fkey FOREIGN KEY (actor_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: bookings bookings_lobby_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES public.lobbies(id) ON DELETE RESTRICT;


--
-- Name: bookings bookings_slot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.bookings
    ADD CONSTRAINT bookings_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES public.court_slots(id) ON DELETE RESTRICT;


--
-- Name: checkins checkins_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins
    ADD CONSTRAINT checkins_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE RESTRICT;


--
-- Name: checkins checkins_scanned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins
    ADD CONSTRAINT checkins_scanned_by_fkey FOREIGN KEY (scanned_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: checkins checkins_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.checkins
    ADD CONSTRAINT checkins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: court_slots court_slots_court_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.court_slots
    ADD CONSTRAINT court_slots_court_id_fkey FOREIGN KEY (court_id) REFERENCES public.courts(id) ON DELETE CASCADE;


--
-- Name: courts courts_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.courts
    ADD CONSTRAINT courts_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE CASCADE;


--
-- Name: lobbies lobbies_host_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lobbies
    ADD CONSTRAINT lobbies_host_id_fkey FOREIGN KEY (host_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: lobbies lobbies_slot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lobbies
    ADD CONSTRAINT lobbies_slot_id_fkey FOREIGN KEY (slot_id) REFERENCES public.court_slots(id) ON DELETE RESTRICT;


--
-- Name: lobby_members lobby_members_hold_ledger_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lobby_members
    ADD CONSTRAINT lobby_members_hold_ledger_id_fkey FOREIGN KEY (hold_ledger_id) REFERENCES public.wallet_ledger(id) ON DELETE SET NULL;


--
-- Name: lobby_members lobby_members_lobby_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lobby_members
    ADD CONSTRAINT lobby_members_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES public.lobbies(id) ON DELETE CASCADE;


--
-- Name: lobby_members lobby_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.lobby_members
    ADD CONSTRAINT lobby_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reliability_events reliability_events_lobby_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reliability_events
    ADD CONSTRAINT reliability_events_lobby_id_fkey FOREIGN KEY (lobby_id) REFERENCES public.lobbies(id) ON DELETE SET NULL;


--
-- Name: reliability_events reliability_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reliability_events
    ADD CONSTRAINT reliability_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: venue_payouts venue_payouts_booking_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_payouts
    ADD CONSTRAINT venue_payouts_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id) ON DELETE RESTRICT;


--
-- Name: venue_payouts venue_payouts_venue_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venue_payouts
    ADD CONSTRAINT venue_payouts_venue_id_fkey FOREIGN KEY (venue_id) REFERENCES public.venues(id) ON DELETE RESTRICT;


--
-- Name: venues venues_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.venues
    ADD CONSTRAINT venues_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: wallet_ledger wallet_ledger_wallet_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallet_ledger
    ADD CONSTRAINT wallet_ledger_wallet_id_fkey FOREIGN KEY (wallet_id) REFERENCES public.wallets(id) ON DELETE RESTRICT;


--
-- Name: wallets wallets_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.wallets
    ADD CONSTRAINT wallets_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: audit_log; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

--
-- Name: bookings; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

--
-- Name: checkins; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.checkins ENABLE ROW LEVEL SECURITY;

--
-- Name: court_slots; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.court_slots ENABLE ROW LEVEL SECURITY;

--
-- Name: courts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.courts ENABLE ROW LEVEL SECURITY;

--
-- Name: lobbies; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lobbies ENABLE ROW LEVEL SECURITY;

--
-- Name: lobby_members; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.lobby_members ENABLE ROW LEVEL SECURITY;

--
-- Name: notifications; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

--
-- Name: reliability_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reliability_events ENABLE ROW LEVEL SECURITY;

--
-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--
-- Name: venue_payouts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.venue_payouts ENABLE ROW LEVEL SECURITY;

--
-- Name: venues; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.venues ENABLE ROW LEVEL SECURITY;

--
-- Name: wallet_ledger; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wallet_ledger ENABLE ROW LEVEL SECURITY;

--
-- Name: wallets; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

--
-- PostgreSQL database dump complete
--

\unrestrict aampWs302EydbzBwdMb3F8wYjXVzbArSIIWxR6ZmYvh3rvOmiekhk91AnDZZ6G0


-- Manual Supabase SQL from db/supabase/ (not part of the pg_dump above); included, not copied.
\ir ../../db/supabase/001_refresh_tokens.sql
\ir ../../db/supabase/003_court_setup.sql

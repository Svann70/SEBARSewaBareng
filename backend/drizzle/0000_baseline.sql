-- 0000_baseline — skema dasar SEBAR (ekstensi, enum, tabel, function, trigger, view).
-- Semua pernyataan idempoten: aman di database kosong maupun di Supabase yang sudah berisi skema ini.
-- Aturan uang (hold, capture, denda, booking otomatis) ada di function/trigger di bawah, bukan di app.

-- ════ 00_extensions.sql ════
-- ============================================================================
-- SEBAR — Sewa Bareng : 00 EXTENSIONS
-- ============================================================================
-- Run order : 1 — jalankan pertama (tanpa dependensi)
-- Source     : SDD_SEBAR.md §4 (Desain Data)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";    -- digest(): hash token QR (SDD ADR-08)
CREATE EXTENSION IF NOT EXISTS "citext";      -- email unik case-insensitive (SDD §4.3.1)
CREATE EXTENSION IF NOT EXISTS "btree_gist";  -- exclusion slot overlap (SDD §4.4)

-- ════ 01_enums.sql ════
-- ============================================================================
-- SEBAR — Sewa Bareng : 01 ENUM TYPES (SDD §4.3)
-- ============================================================================
-- Run order : 2 — setelah 00_extensions.sql, sebelum tables/
-- Idempoten : setiap CREATE TYPE dibungkus EXCEPTION WHEN duplicate_object
-- ============================================================================

DO $$ BEGIN
  CREATE TYPE public.user_role AS ENUM ('PLAYER', 'VENUE_ADMIN', 'SUPER_ADMIN');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.venue_status AS ENUM ('ACTIVE', 'INACTIVE');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.sport_type AS ENUM ('BADMINTON', 'FUTSAL', 'VOLLEY', 'MINISOCCER');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.court_status AS ENUM ('ACTIVE', 'MAINTENANCE');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.slot_status AS ENUM ('OPEN', 'LOBBY_FULL', 'BOOKED', 'BLOCKED', 'PAST');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.lobby_status AS ENUM ('OPEN', 'FILLED', 'CONFIRMED', 'CANCELLED', 'EXPIRED', 'FAILED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.member_role AS ENUM ('HOST', 'PLAYER');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.member_status AS ENUM ('HOLDING', 'CONFIRMED', 'CANCELLED', 'REFUNDED', 'PENALIZED', 'NO_SHOW');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.ledger_type AS ENUM ('TOPUP', 'HOLD', 'RELEASE', 'CAPTURE', 'REFUND', 'PAYOUT', 'PENALTY');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.booking_status AS ENUM ('CONFIRMED', 'COMPLETED', 'CANCELLED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.payout_status AS ENUM ('PENDING', 'PAID');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.checkin_status AS ENUM ('PENDING', 'SCANNED', 'EXPIRED', 'NO_SHOW');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.reliability_reason AS ENUM ('CHECKIN', 'LATE_CANCEL', 'NO_SHOW', 'HOST_CANCEL', 'MANUAL_ADJUST');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ════ tables/01_users.sql ════
-- ============================================================================
-- SEBAR — table 3.1 : users (SDD §4.3.1)
-- ============================================================================
-- Run order : 3.1 — setelah 00_extensions.sql, 01_enums.sql
-- Depends   : enum public.user_role, ext citext
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.users (
  id                uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  email             citext       NOT NULL UNIQUE,
  phone             varchar(20)  UNIQUE,
  full_name         varchar(80)  NOT NULL,
  password_hash     text         NOT NULL,               -- Argon2id (verifikasi di API)
  role              public.user_role  NOT NULL DEFAULT 'PLAYER',
  reliability_score numeric(5,2) NOT NULL DEFAULT 100 CHECK (reliability_score BETWEEN 0 AND 100),
  is_active         boolean      NOT NULL DEFAULT true,
  created_at        timestamptz  NOT NULL DEFAULT now(),
  updated_at        timestamptz  NOT NULL DEFAULT now()
);

-- ════ tables/02_wallets.sql ════
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

-- ════ tables/03_wallet_ledger.sql ════
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

-- ════ tables/04_venues.sql ════
-- ============================================================================
-- SEBAR — table 3.4 : venues (SDD §4.3.4)
-- ============================================================================
-- Run order : 3.4 — setelah tables/01_users.sql
-- Depends   : public.users (owner), enum public.venue_status
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.venues (
  id          uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id    uuid                NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  name        varchar(120)        NOT NULL,
  address     text                NOT NULL,
  city        varchar(60)         NOT NULL,
  description text,
  photo_url   text,
  status      public.venue_status NOT NULL DEFAULT 'ACTIVE',
  created_at  timestamptz         NOT NULL DEFAULT now()
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_venues_city_status
  ON public.venues (city, status);

-- ════ tables/05_courts.sql ════
-- ============================================================================
-- SEBAR — table 3.5 : courts (SDD §4.3.5)
-- ============================================================================
-- Run order : 3.5 — setelah tables/04_venues.sql
-- Depends   : public.venues, enum public.sport_type, public.court_status
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.courts (
  id             uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id       uuid                NOT NULL REFERENCES public.venues(id) ON DELETE CASCADE,
  name           varchar(60)         NOT NULL,
  sport_type     public.sport_type   NOT NULL,
  price_per_hour numeric(12,2)       NOT NULL CHECK (price_per_hour > 0),
  capacity       smallint            NOT NULL CHECK (capacity BETWEEN 2 AND 30),
  status         public.court_status NOT NULL DEFAULT 'ACTIVE',
  UNIQUE (venue_id, name)
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_courts_venue
  ON public.courts (venue_id);

-- ════ tables/06_court_slots.sql ════
-- ============================================================================
-- SEBAR — table 3.6 : court_slots (SDD §4.3.6)
-- ============================================================================
-- Run order : 3.6 — setelah tables/05_courts.sql
-- Depends   : public.courts, enum public.slot_status, ext btree_gist
-- Invariant : UNIQUE(court_id, start_at) + exclusion anti-overlap (SDD §4.4)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.court_slots (
  id         uuid                PRIMARY KEY DEFAULT gen_random_uuid(),
  court_id   uuid                NOT NULL REFERENCES public.courts(id) ON DELETE CASCADE,
  start_at   timestamptz         NOT NULL,
  end_at     timestamptz         NOT NULL CHECK (end_at > start_at),
  price      numeric(12,2)       NOT NULL CHECK (price > 0),
  status     public.slot_status  NOT NULL DEFAULT 'OPEN',
  created_at timestamptz         NOT NULL DEFAULT now(),
  UNIQUE (court_id, start_at),                       -- mencegah dua slot identik
  EXCLUDE USING gist (court_id WITH =, tstzrange(start_at, end_at) WITH &&)  -- anti tumpang tindih
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_slots_open
  ON public.court_slots (start_at)
  WHERE status = 'OPEN';

CREATE INDEX IF NOT EXISTS idx_slots_court_start
  ON public.court_slots (court_id, start_at DESC);

-- ════ tables/07_lobbies.sql ════
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

-- ════ tables/08_lobby_members.sql ════
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

-- ════ tables/09_bookings.sql ════
-- ============================================================================
-- SEBAR — table 3.9 : bookings (SDD §4.3.9)
-- ============================================================================
-- Run order : 3.9 — setelah tables/07_lobbies.sql, tables/06_court_slots.sql
-- Depends   : public.lobbies, public.court_slots, enum public.booking_status
-- Anti      : UNIQUE(slot_id) = pertahanan terakhir anti double-booking
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.bookings (
  id               uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
  lobby_id         uuid                  NOT NULL UNIQUE REFERENCES public.lobbies(id) ON DELETE RESTRICT,
  slot_id          uuid                  NOT NULL UNIQUE REFERENCES public.court_slots(id) ON DELETE RESTRICT,
  booking_code     varchar(12)           NOT NULL UNIQUE,
  gross_amount     numeric(12,2)         NOT NULL CHECK (gross_amount > 0),
  platform_fee     numeric(12,2)         NOT NULL CHECK (platform_fee >= 0),
  rounding_surplus numeric(12,2)         NOT NULL DEFAULT 0 CHECK (rounding_surplus >= 0),
  venue_payout     numeric(12,2)         NOT NULL CHECK (venue_payout > 0),
  status           public.booking_status NOT NULL DEFAULT 'CONFIRMED',
  booked_at        timestamptz           NOT NULL DEFAULT now(),
  CONSTRAINT bookings_fee_is_5pct      CHECK (platform_fee = round(gross_amount * 0.05, 2)),
  CONSTRAINT bookings_payout_invariant CHECK (venue_payout >= gross_amount - platform_fee)
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_bookings_status_booked_at
  ON public.bookings (status, booked_at DESC);

-- ════ tables/10_venue_payouts.sql ════
-- ============================================================================
-- SEBAR — table 3.10 : venue_payouts (SDD §4.3.10)
-- ============================================================================
-- Run order : 3.10 — setelah tables/09_bookings.sql, tables/04_venues.sql
-- Depends   : public.bookings, public.venues, enum public.payout_status
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.venue_payouts (
  id           uuid                 PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id   uuid                 NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE RESTRICT,
  venue_id     uuid                 NOT NULL REFERENCES public.venues(id) ON DELETE RESTRICT,
  amount       numeric(12,2)        NOT NULL CHECK (amount > 0),
  status       public.payout_status NOT NULL DEFAULT 'PENDING',
  disbursed_at timestamptz,
  created_at   timestamptz          NOT NULL DEFAULT now(),
  CONSTRAINT payouts_state_coherent CHECK (
    (status = 'PENDING' AND disbursed_at IS NULL) OR
    (status = 'PAID'    AND disbursed_at IS NOT NULL))
);

-- ════ tables/11_checkins.sql ════
-- ============================================================================
-- SEBAR — table 3.11 : checkins (SDD §4.3.11)
-- ============================================================================
-- Run order : 3.11 — setelah tables/09_bookings.sql, tables/01_users.sql
-- Depends   : public.bookings, public.users, enum public.checkin_status
-- ADR-08    : menyimpan HASH token (char 64 sha256 hex), bukan token mentah
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.checkins (
  id               uuid                  PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id       uuid                  NOT NULL REFERENCES public.bookings(id) ON DELETE RESTRICT,
  user_id          uuid                  NOT NULL REFERENCES public.users(id) ON DELETE RESTRICT,
  token_hash       char(64)              NOT NULL UNIQUE,
  token_expires_at timestamptz           NOT NULL,
  status           public.checkin_status NOT NULL DEFAULT 'PENDING',
  scanned_by       uuid                  REFERENCES public.users(id) ON DELETE SET NULL,
  scanned_at       timestamptz,
  UNIQUE (booking_id, user_id)   -- satu tiket per peserta per booking
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_checkins_booking
  ON public.checkins (booking_id, status);

-- ════ tables/12_reliability_events.sql ════
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

-- ════ tables/13_notifications.sql ════
-- ============================================================================
-- SEBAR — table 3.13 : notifications (SDD §4.3.13)
-- ============================================================================
-- Run order : 3.13 — setelah tables/01_users.sql
-- Depends   : public.users
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.notifications (
  id         uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid        NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  type       text        NOT NULL,
  payload    jsonb       NOT NULL DEFAULT '{}'::jsonb,
  read_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_notifications_user_created
  ON public.notifications (user_id, created_at DESC);

-- ════ tables/14_audit_log.sql ════
-- ============================================================================
-- SEBAR — table 3.14 : audit_log (SDD §4.3.14)
-- ============================================================================
-- Run order : 3.14 — setelah tables/01_users.sql
-- Depends   : public.users (actor, nullable)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.audit_log (
  id         bigserial   PRIMARY KEY,
  actor_id   uuid        REFERENCES public.users(id) ON DELETE SET NULL,
  action     text        NOT NULL,
  entity     text        NOT NULL,
  entity_id  uuid,
  "before"   jsonb,
  "after"    jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_audit_entity
  ON public.audit_log (entity, entity_id, created_at DESC);

-- ════ functions/01_apply_reliability.sql ════
-- ============================================================================
-- SEBAR — functions : reliability (SDD §4.5, BR-4.4, BR-5.7, ADR-04)
-- ============================================================================
-- Run order : 4.1 — setelah tables/, sebelum triggers/
-- ============================================================================

-- Reputasi: delta + clamp 0–100 di DB + audit event
CREATE OR REPLACE FUNCTION public.apply_reliability(
  p_user_id  uuid,
  p_delta    numeric,
  p_reason   public.reliability_reason,
  p_lobby_id uuid DEFAULT NULL
) RETURNS numeric
LANGUAGE plpgsql AS $$
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

-- ════ functions/02_log_audit.sql ════
-- ============================================================================
-- SEBAR — functions : audit helper (SDD §4.3.14)
-- ============================================================================
-- Run order : 4.2 — setelah tables/, sebelum functions/04_lobby*.sql & triggers/
-- ============================================================================

CREATE OR REPLACE FUNCTION public.log_audit(
  p_action    text,
  p_entity    text,
  p_entity_id uuid,
  p_actor     uuid DEFAULT NULL,
  p_before    jsonb DEFAULT NULL,
  p_after     jsonb DEFAULT NULL
) RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  INSERT INTO public.audit_log (actor_id, action, entity, entity_id, "before", "after")
  VALUES (p_actor, p_action, p_entity, p_entity_id, p_before, p_after);
END $$;

-- ════ functions/03_wallet.sql ════
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

-- ════ functions/04_lobby_lifecycle.sql ════
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

-- ════ functions/05_fn_peak_hours.sql ════
-- ============================================================================
-- SEBAR — functions : analytics (SDD §4.6, §4.8)
-- ============================================================================
-- Run order : 4.5 — setelah tables/ (LANGUAGE sql divalidasi saat CREATE)
-- ============================================================================

-- fn_peak_hours(uuid, date, date) — jam tersibuk venue
-- Memakai window function untuk persentase (bukti rubrik analitik).
CREATE OR REPLACE FUNCTION public.fn_peak_hours(
  p_venue uuid,
  p_from  date,
  p_to    date
) RETURNS TABLE (jam numeric, booking bigint, persen numeric)
LANGUAGE sql STABLE AS $$
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

-- ════ triggers/01_users.sql ════
-- ============================================================================
-- SEBAR — triggers : public.users (SDD §4.6)
-- ============================================================================
-- Run order : 5.1 — setelah tables/01_users.sql & functions/
-- ============================================================================

-- updated_at maintenance
CREATE OR REPLACE FUNCTION public.fn_touch_updated_at() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_users_touch ON public.users;
CREATE TRIGGER trg_users_touch
  BEFORE UPDATE ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.fn_touch_updated_at();

-- Clamp defensif untuk update langsung (clamp di database, BR-4.4)
CREATE OR REPLACE FUNCTION public.trg_reliability_clamp() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  NEW.reliability_score := LEAST(100::numeric, GREATEST(0::numeric, NEW.reliability_score));
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_reliability_clamp ON public.users;
CREATE TRIGGER trg_reliability_clamp
  BEFORE UPDATE OF reliability_score ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.trg_reliability_clamp();

-- ════ triggers/02_lobbies.sql ════
-- ============================================================================
-- SEBAR — triggers : public.lobbies (SDD §4.6)
-- ============================================================================
-- Run order : 5.2 — setelah tables/07_lobbies.sql, tables/06_court_slots.sql,
--             tables/08_lobby_members.sql & functions/
-- ============================================================================

-- Validasi lobby saat dibuat/diubah:
-- slot harus OPEN, price_total = harga slot, join_deadline ≤ start_at − 6 jam
CREATE OR REPLACE FUNCTION public.trg_lobby_validate() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_slot public.court_slots%ROWTYPE;
BEGIN
  SELECT * INTO v_slot FROM public.court_slots WHERE id = NEW.slot_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::SLOT_NOT_FOUND'; END IF;

  IF TG_OP = 'INSERT' AND (v_slot.status <> 'OPEN' OR v_slot.released) THEN
    RAISE EXCEPTION 'SEBAR::SLOT_NOT_OPEN';   -- released = jamnya sudah dipakai slot lain
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

DROP TRIGGER IF EXISTS trg_lobby_validate ON public.lobbies;
CREATE TRIGGER trg_lobby_validate
  BEFORE INSERT OR UPDATE OF slot_id, price_total, join_deadline, min_reliability, quota ON public.lobbies
  FOR EACH ROW EXECUTE FUNCTION public.trg_lobby_validate();

-- ════ triggers/03_lobby_members.sql ════
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

-- ════ triggers/04_checkins.sql ════
-- ============================================================================
-- SEBAR — triggers : public.checkins (SDD §4.6, US-15)
-- ============================================================================
-- Run order : 5.4 — setelah tables/11_checkins.sql & functions/01_apply_reliability.sql
-- ============================================================================

-- Check-in discan → skor +2 (US-15); idempoten (scan kedua tak menambah, T-08)
CREATE OR REPLACE FUNCTION public.trg_checkin_scanned() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'SCANNED' AND OLD.status <> 'SCANNED' THEN
    PERFORM public.apply_reliability(NEW.user_id, 2, 'CHECKIN');
  END IF;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_checkin_scanned ON public.checkins;
CREATE TRIGGER trg_checkin_scanned
  BEFORE UPDATE OF status ON public.checkins
  FOR EACH ROW EXECUTE FUNCTION public.trg_checkin_scanned();

-- ════ triggers/05_court_slots.sql ════
-- ============================================================================
-- SEBAR — triggers : public.court_slots (SDD §4.6, US-10, BR-4.2)
-- ============================================================================
-- Run order : 5.5 — setelah tables/06_court_slots.sql & functions/
--             (memanggil wallet_capture, apply_reliability)
-- ============================================================================

-- Slot → PAST: participant QR tidak discan (≤30 mnt setelah mulai) = NO_SHOW
-- sita hold 100% (bila masih HOLDING), skor −25 (US-10, BR-4.2)
CREATE OR REPLACE FUNCTION public.trg_no_show() RETURNS trigger
LANGUAGE plpgsql AS $$
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

DROP TRIGGER IF EXISTS trg_no_show ON public.court_slots;
CREATE TRIGGER trg_no_show
  BEFORE UPDATE OF status ON public.court_slots
  FOR EACH ROW EXECUTE FUNCTION public.trg_no_show();

-- ════ views/01_vw_venue_monthly_revenue.sql ════
-- ============================================================================
-- SEBAR — view : vw_venue_monthly_revenue (SDD §4.8)
-- ============================================================================
-- Run order : 6.1 — setelah tables/ (agregasi dashboard venue, GROUP BY)
-- ============================================================================

CREATE OR REPLACE VIEW public.vw_venue_monthly_revenue AS
SELECT
  v.id                             AS venue_id,
  v.name                           AS venue_name,
  date_trunc('month', b.booked_at) AS bulan,
  count(*)                         AS total_booking,
  sum(b.gross_amount)              AS omzet,
  sum(b.platform_fee)              AS fee_sebar,
  sum(b.venue_payout)              AS payout_gor
FROM public.bookings b
JOIN public.lobbies l     ON l.id = b.lobby_id
JOIN public.court_slots s ON s.id = b.slot_id
JOIN public.courts c      ON c.id = s.court_id
JOIN public.venues v      ON v.id = c.venue_id
WHERE b.status <> 'CANCELLED'
GROUP BY v.id, v.name, date_trunc('month', b.booked_at);

-- ════ views/02_vw_lobby_search.sql ════
-- ============================================================================
-- SEBAR — view : vw_lobby_search (SDD §4.8)
-- ============================================================================
-- Run order : 6.2 — setelah tables/ (join lobbies + slots + courts + venues)
-- ============================================================================

CREATE OR REPLACE VIEW public.vw_lobby_search AS
SELECT
  l.id, l.slot_id, l.host_id, l.title, l.min_reliability, l.quota,
  l.price_total, l.price_per_person, l.join_deadline, l.status,
  s.start_at, s.end_at,
  c.sport_type, c.name AS court_name,
  v.id AS venue_id, v.name AS venue_name, v.city,
  (SELECT count(*) FROM public.lobby_members m
     WHERE m.lobby_id = l.id AND m.status IN ('HOLDING', 'CONFIRMED')) AS joined
FROM public.lobbies l
JOIN public.court_slots s ON s.id = l.slot_id
JOIN public.courts c      ON c.id = s.court_id
JOIN public.venues v      ON v.id = c.venue_id;

-- ════ RLS ════
-- Aktif di semua tabel: Data API/anon key tidak boleh akses langsung; backend memakai koneksi owner.
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.courts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.court_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lobbies ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lobby_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.venue_payouts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.checkins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reliability_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

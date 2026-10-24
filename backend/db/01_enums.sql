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

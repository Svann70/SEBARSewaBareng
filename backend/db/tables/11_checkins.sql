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

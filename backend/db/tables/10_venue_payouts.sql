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

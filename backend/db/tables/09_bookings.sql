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

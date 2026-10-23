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

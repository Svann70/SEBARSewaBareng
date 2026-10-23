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

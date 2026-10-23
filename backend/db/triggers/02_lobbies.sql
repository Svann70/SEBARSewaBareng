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

DROP TRIGGER IF EXISTS trg_lobby_validate ON public.lobbies;
CREATE TRIGGER trg_lobby_validate
  BEFORE INSERT OR UPDATE OF slot_id, price_total, join_deadline, min_reliability, quota ON public.lobbies
  FOR EACH ROW EXECUTE FUNCTION public.trg_lobby_validate();

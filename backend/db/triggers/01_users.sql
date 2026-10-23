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

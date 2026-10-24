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

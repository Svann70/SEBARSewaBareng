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

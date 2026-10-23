-- ============================================================================
-- SEBAR — table 3.14 : audit_log (SDD §4.3.14)
-- ============================================================================
-- Run order : 3.14 — setelah tables/01_users.sql
-- Depends   : public.users (actor, nullable)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.audit_log (
  id         bigserial   PRIMARY KEY,
  actor_id   uuid        REFERENCES public.users(id) ON DELETE SET NULL,
  action     text        NOT NULL,
  entity     text        NOT NULL,
  entity_id  uuid,
  "before"   jsonb,
  "after"    jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- indexes (SDD §4.7)
CREATE INDEX IF NOT EXISTS idx_audit_entity
  ON public.audit_log (entity, entity_id, created_at DESC);

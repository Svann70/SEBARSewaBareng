-- Run once in Supabase SQL Editor (the repo does not apply schema changes itself).
-- Opaque refresh tokens for POST /auth/refresh and /auth/logout. Only a SHA-256 hash is stored.
-- family_id ties a rotation chain together: reusing an already-rotated token revokes the whole family.
CREATE TABLE IF NOT EXISTS public.refresh_tokens (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  family_id   uuid NOT NULL,
  token_hash  char(64) NOT NULL UNIQUE,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,
  replaced_by uuid REFERENCES public.refresh_tokens(id) ON DELETE SET NULL,
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_family ON public.refresh_tokens (family_id);
-- Used by the backend job that deletes expired tokens.
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires ON public.refresh_tokens (expires_at);

-- Backend only: no Data API access with the anon/authenticated keys.
ALTER TABLE public.refresh_tokens ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE ALL ON public.refresh_tokens FROM anon, authenticated;
  END IF;
END $$;

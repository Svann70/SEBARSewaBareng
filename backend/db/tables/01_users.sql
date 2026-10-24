-- ============================================================================
-- SEBAR — table 3.1 : users (SDD §4.3.1)
-- ============================================================================
-- Run order : 3.1 — setelah 00_extensions.sql, 01_enums.sql
-- Depends   : enum public.user_role, ext citext
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.users (
  id                uuid         PRIMARY KEY DEFAULT gen_random_uuid(),
  email             citext       NOT NULL UNIQUE,
  phone             varchar(20)  UNIQUE,
  full_name         varchar(80)  NOT NULL,
  password_hash     text         NOT NULL,               -- Argon2id (verifikasi di API)
  role              public.user_role  NOT NULL DEFAULT 'PLAYER',
  reliability_score numeric(5,2) NOT NULL DEFAULT 100 CHECK (reliability_score BETWEEN 0 AND 100),
  is_active         boolean      NOT NULL DEFAULT true,
  created_at        timestamptz  NOT NULL DEFAULT now(),
  updated_at        timestamptz  NOT NULL DEFAULT now()
);

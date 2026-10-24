-- ============================================================================
-- SEBAR — Sewa Bareng : 00 EXTENSIONS
-- ============================================================================
-- Run order : 1 — jalankan pertama (tanpa dependensi)
-- Source     : SDD_SEBAR.md §4 (Desain Data)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";    -- digest(): hash token QR (SDD ADR-08)
CREATE EXTENSION IF NOT EXISTS "citext";      -- email unik case-insensitive (SDD §4.3.1)
CREATE EXTENSION IF NOT EXISTS "btree_gist";  -- exclusion slot overlap (SDD §4.4)

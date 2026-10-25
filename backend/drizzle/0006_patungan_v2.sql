ALTER TYPE "public"."ledger_type" ADD VALUE IF NOT EXISTS 'COMPENSATION';
--> statement-breakpoint
ALTER TYPE "public"."member_status" ADD VALUE IF NOT EXISTS 'ACTIVE';
--> statement-breakpoint
ALTER TYPE "public"."member_status" ADD VALUE IF NOT EXISTS 'VACANT';
--> statement-breakpoint
ALTER TYPE "public"."member_status" ADD VALUE IF NOT EXISTS 'REPLACED';
--> statement-breakpoint
ALTER TYPE "public"."member_status" ADD VALUE IF NOT EXISTS 'LEFT';
--> statement-breakpoint
ALTER TYPE "public"."member_status" ADD VALUE IF NOT EXISTS 'ABSENT';
--> statement-breakpoint
ALTER TABLE "lobby_members" DROP CONSTRAINT IF EXISTS "lobby_members_lobby_id_user_id_key";
--> statement-breakpoint
ALTER TABLE "lobby_members" DROP CONSTRAINT IF EXISTS "lobby_members_hold_amount_check";
--> statement-breakpoint
ALTER TABLE "lobbies" ADD COLUMN IF NOT EXISTS "creator_id" uuid;
--> statement-breakpoint
ALTER TABLE "lobbies" ADD COLUMN IF NOT EXISTS "settled_at" timestamp with time zone;
--> statement-breakpoint
ALTER TABLE "lobby_members" ADD COLUMN IF NOT EXISTS "share_at_join" numeric(12, 2);
--> statement-breakpoint
ALTER TABLE "lobby_members" ADD COLUMN IF NOT EXISTS "fine_amount" numeric(12, 2) DEFAULT '0' NOT NULL;
--> statement-breakpoint
ALTER TABLE "lobby_members" ADD COLUMN IF NOT EXISTS "free_until" timestamp with time zone;
--> statement-breakpoint
ALTER TABLE "lobby_members" ADD COLUMN IF NOT EXISTS "protect_until" timestamp with time zone;
--> statement-breakpoint
ALTER TABLE "lobby_members" ADD COLUMN IF NOT EXISTS "reminded_at" timestamp with time zone;
--> statement-breakpoint
ALTER TABLE "lobbies" DROP CONSTRAINT IF EXISTS "lobbies_creator_id_fkey";
--> statement-breakpoint
ALTER TABLE "lobbies" ADD CONSTRAINT "lobbies_creator_id_fkey" FOREIGN KEY ("creator_id") REFERENCES "public"."users"("id") ON DELETE restrict ON UPDATE no action;
--> statement-breakpoint
CREATE UNIQUE INDEX IF NOT EXISTS "uq_lobby_members_seat" ON "lobby_members" USING btree ("lobby_id","user_id") WHERE (cancelled_at IS NULL);
--> statement-breakpoint
ALTER TABLE "lobby_members" DROP CONSTRAINT IF EXISTS "lobby_members_fine_amount_check";
--> statement-breakpoint
ALTER TABLE "lobby_members" ADD CONSTRAINT "lobby_members_fine_amount_check" CHECK (fine_amount >= (0)::numeric);
--> statement-breakpoint
ALTER TABLE "lobby_members" DROP CONSTRAINT IF EXISTS "lobby_members_hold_amount_check";
--> statement-breakpoint
ALTER TABLE "lobby_members" ADD CONSTRAINT "lobby_members_hold_amount_check" CHECK (hold_amount >= (0)::numeric);
--> statement-breakpoint
-- ════ Patungan v2 (backend/PATUNGAN_V2.md) ════
-- Rules now run in the backend (lobbies/patungan.service.js) on top of the wallet primitives below.

-- CREDIT: money into a wallet's free balance (fine compensation, venue share of a host fine).
CREATE OR REPLACE FUNCTION public.wallet_credit(
  p_user_id         uuid,
  p_amount          numeric,
  p_ref_type        text,
  p_ref_id          uuid,
  p_idempotency_key text DEFAULT NULL
) RETURNS uuid
LANGUAGE plpgsql AS $$
DECLARE
  v_wallet    public.wallets%ROWTYPE;
  v_ledger_id uuid;
BEGIN
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RAISE EXCEPTION 'SEBAR::CREDIT_AMOUNT_INVALID';
  END IF;

  SELECT * INTO v_wallet FROM public.wallets WHERE user_id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::WALLET_NOT_FOUND'; END IF;

  IF p_idempotency_key IS NOT NULL THEN
    SELECT id INTO v_ledger_id FROM public.wallet_ledger WHERE idempotency_key = p_idempotency_key;
    IF v_ledger_id IS NOT NULL THEN
      RETURN v_ledger_id;
    END IF;
  END IF;

  UPDATE public.wallets
  SET balance = balance + p_amount,
      version = version + 1
  WHERE id = v_wallet.id
  RETURNING * INTO v_wallet;

  INSERT INTO public.wallet_ledger
    (wallet_id, entry_type, amount, balance_after, held_after, ref_type, ref_id, idempotency_key)
  VALUES
    (v_wallet.id, 'COMPENSATION', p_amount, v_wallet.balance, v_wallet.held_balance,
     p_ref_type, p_ref_id, p_idempotency_key)
  RETURNING id INTO v_ledger_id;

  RETURN v_ledger_id;
END $$;
--> statement-breakpoint

-- Join closes 30 minutes before the start (was 6 hours).
CREATE OR REPLACE FUNCTION public.trg_lobby_validate() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
  v_slot public.court_slots%ROWTYPE;
BEGIN
  SELECT * INTO v_slot FROM public.court_slots WHERE id = NEW.slot_id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'SEBAR::SLOT_NOT_FOUND'; END IF;

  IF TG_OP = 'INSERT' AND (v_slot.status <> 'OPEN' OR v_slot.released) THEN
    RAISE EXCEPTION 'SEBAR::SLOT_NOT_OPEN';
  END IF;

  IF NEW.price_total <> v_slot.price THEN
    RAISE EXCEPTION 'SEBAR::PRICE_MISMATCH';
  END IF;

  IF NEW.join_deadline > v_slot.start_at - interval '30 minutes' THEN
    RAISE EXCEPTION 'SEBAR::DEADLINE_TOO_LATE';
  END IF;

  IF TG_OP = 'UPDATE'
     AND EXISTS (SELECT 1 FROM public.lobby_members WHERE lobby_id = OLD.id)
     AND (NEW.min_reliability <> OLD.min_reliability OR NEW.quota <> OLD.quota) THEN
    RAISE EXCEPTION 'SEBAR::LOBBY_LOCKED';
  END IF;

  RETURN NEW;
END $$;
--> statement-breakpoint

-- v1 money triggers: joining/leaving no longer goes through them.
DROP TRIGGER IF EXISTS trg_member_hold ON public.lobby_members;
--> statement-breakpoint
DROP TRIGGER IF EXISTS trg_member_cancel ON public.lobby_members;
--> statement-breakpoint

-- No real users yet: cancel every v1 room that is still open and release its holds.
DO $$
DECLARE
  v_member public.lobby_members%ROWTYPE;
BEGIN
  FOR v_member IN
    SELECT m.* FROM public.lobby_members m JOIN public.lobbies l ON l.id = m.lobby_id
     WHERE l.status IN ('OPEN', 'FILLED') AND m.status = 'HOLDING'
     ORDER BY m.id
  LOOP
    PERFORM public.wallet_release(v_member.user_id, v_member.hold_amount, 'LOBBY', v_member.lobby_id,
      'RELEASE-V2MIGRATE:' || v_member.lobby_id::text || ':' || v_member.user_id::text);
    UPDATE public.lobby_members SET status = 'REFUNDED', cancelled_at = now() WHERE id = v_member.id;
  END LOOP;
  UPDATE public.lobbies SET status = 'CANCELLED' WHERE status IN ('OPEN', 'FILLED');
END $$;
--> statement-breakpoint

UPDATE public.lobbies SET creator_id = host_id WHERE creator_id IS NULL;
--> statement-breakpoint

-- Wallet functions move money: only the backend (table owner) may call them, never the Supabase
-- Data API roles through /rest/v1/rpc.
REVOKE EXECUTE ON FUNCTION public.wallet_hold(uuid, numeric, text, uuid, text) FROM PUBLIC;
--> statement-breakpoint
REVOKE EXECUTE ON FUNCTION public.wallet_release(uuid, numeric, text, uuid, text) FROM PUBLIC;
--> statement-breakpoint
REVOKE EXECUTE ON FUNCTION public.wallet_capture(uuid, numeric, text, uuid, public.ledger_type, text) FROM PUBLIC;
--> statement-breakpoint
REVOKE EXECUTE ON FUNCTION public.wallet_credit(uuid, numeric, text, uuid, text) FROM PUBLIC;
--> statement-breakpoint
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'anon') THEN
    REVOKE EXECUTE ON FUNCTION public.wallet_hold(uuid, numeric, text, uuid, text) FROM anon, authenticated;
    REVOKE EXECUTE ON FUNCTION public.wallet_release(uuid, numeric, text, uuid, text) FROM anon, authenticated;
    REVOKE EXECUTE ON FUNCTION public.wallet_capture(uuid, numeric, text, uuid, public.ledger_type, text) FROM anon, authenticated;
    REVOKE EXECUTE ON FUNCTION public.wallet_credit(uuid, numeric, text, uuid, text) FROM anon, authenticated;
  END IF;
END $$;

ALTER TABLE "checkins" ADD COLUMN IF NOT EXISTS "code" varchar(10);--> statement-breakpoint
ALTER TABLE "checkins" DROP CONSTRAINT IF EXISTS "checkins_code_key";--> statement-breakpoint
ALTER TABLE "checkins" ADD CONSTRAINT "checkins_code_key" UNIQUE("code");--> statement-breakpoint
-- Tickets issued before this migration get a code too.
UPDATE "checkins" SET "code" = upper(substr(md5(gen_random_uuid()::text), 1, 10)) WHERE "code" IS NULL;

-- Baseline: the schema that already existed in Supabase before migrations were tracked
-- (tables, enums, views, functions, triggers from db/*.sql). Nothing to run here; drizzle/meta/
-- 0000_snapshot.json holds that schema for `drizzle-kit generate`. New empty databases get the
-- base schema from db/*.sql (README) and then run `npm run db:migrate`.
SELECT 1;

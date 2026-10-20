# Backend rules (from review findings)

- Money and quota rules live in the Supabase DB (triggers + PL/pgSQL functions). Do not re-implement
  hold/capture/release in JS; trigger them (INSERT/UPDATE lobby_members, call the function).
- Before any statement that makes the DB touch several wallets (filling join, cancel_lobby_by_host,
  expire_stale_lobbies), lock those wallets first in id order: `SELECT 1 FROM wallets WHERE ... ORDER BY id FOR UPDATE`.
  The DB functions lock in table order and deadlock otherwise.
- Lock a row in one statement, then run related checks (EXISTS, count) in a later statement.
  Under READ COMMITTED a check in the locking statement reads a snapshot from before the lock wait.
- `wallet_ledger.idempotency_key` is unique across all users: always prefix client keys (`TOPUP:<userId>:<key>`).
- Ticket/check-in queries must join `lobby_members.status = 'CONFIRMED'`: `confirm_lobby` creates a
  check-in row for every member row, including members who left.
- Schema is not managed here. After a Supabase schema change, regenerate `test/fixtures/schema.sql` with pg_dump.
- Every unauthenticated endpoint that runs scrypt or hits the DB sits behind `rateLimit` (src/middleware/rate-limit.js).
- Validate env values at boot (src/config/env.js) before they reach a library, e.g. `JWT_EXPIRES_IN` needs a unit.
- New tables: write the SQL in `db/supabase/NNN_*.sql` (RLS on, revoke anon/authenticated), the user runs it in
  Supabase, and `test/fixtures/schema.sql` includes it with `\ir`.
- In-memory maps keyed by client input (rate limiter) must cap key length and total size.

import { config } from './config/env.js';
import { createApp } from './app.js';
import { pool, query } from './db/pool.js';
import { purgeExpiredRefreshTokens } from './modules/auth/auth.service.js';
import { runLobbyJobs } from './modules/lobbies/jobs.js';
import journal from '../drizzle/meta/_journal.json' with { type: 'json' };

const EXPIRE_EVERY_MS = 60_000;

// Fail fast when migrations are pending, else queries hit missing tables/columns at runtime.
// Drizzle applies in journal order, so an entry newer than the latest applied one is not applied.
const applied = await query('SELECT max(created_at) AS at FROM drizzle.__drizzle_migrations')
  .then(({ rows }) => Number(rows[0].at ?? 0))
  .catch((err) => {
    if (err.code !== '42P01') throw err; // 42P01: nothing migrated yet (no drizzle schema/table)
    return 0;
  });
const pending = journal.entries.filter((e) => e.when > applied).map((e) => e.tag);
if (pending.length) {
  console.error(`Database is behind: pending migrations ${pending.join(', ')}. Run \`npm run db:migrate\` first.`);
  process.exit(1);
}

const server = createApp().listen(config.port, () => {
  console.log(JSON.stringify({ level: 'info', msg: `SEBAR API on :${config.port}` }));
});

// Simple in-process scheduler: patungan jobs (reminders, join close, fine payout) + refresh token cleanup.
async function runJobs() {
  try {
    await runLobbyJobs();
    await purgeExpiredRefreshTokens();
  } catch (err) {
    console.error(JSON.stringify({ level: 'error', msg: 'scheduled job failed', error: err.message }));
  }
}
const timer = setInterval(runJobs, EXPIRE_EVERY_MS);
runJobs();

function shutdown() {
  clearInterval(timer);
  server.close(() => pool.end().then(() => process.exit(0)));
}
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);

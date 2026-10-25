import { config } from './config/env.js';
import { createApp } from './app.js';
import { pool, query } from './db/pool.js';
import { purgeExpiredRefreshTokens } from './modules/auth/auth.service.js';
import { runLobbyJobs } from './modules/lobbies/jobs.js';

const EXPIRE_EVERY_MS = 60_000;

// Fail fast when the manual Supabase SQL (README) has not been applied: every login would 500.
const { rows } = await query(`SELECT to_regclass('public.refresh_tokens') AS t`);
if (!rows[0].t) {
  console.error('Table public.refresh_tokens is missing. Run `npm run db:migrate` first.');
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

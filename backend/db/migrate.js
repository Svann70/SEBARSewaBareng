// Apply pending migrations in drizzle/ (journal order), each recorded in drizzle.__drizzle_migrations.
// Usage: npm run db:migrate  (uses DATABASE_URL / DATABASE_SSL_CA from .env, same TLS rules as the app).
// Pending migrations run in one transaction: on error nothing is applied.
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { connectionOptions } from '../src/db/connection.js';

export const migrationsFolder = fileURLToPath(new URL('../drizzle', import.meta.url));

export async function runMigrations(pool) {
  await migrate(drizzle(pool), { migrationsFolder });
}

// Tags of journal entries not applied yet. Same rule as drizzle's migrator: an entry is pending
// when its `when` is newer than the latest applied created_at.
export async function pendingMigrations(pool) {
  const { entries } = JSON.parse(await readFile(`${migrationsFolder}/meta/_journal.json`, 'utf8'));
  const applied = await pool
    .query('SELECT max(created_at) AS at FROM drizzle.__drizzle_migrations')
    .then(({ rows }) => Number(rows[0].at ?? 0))
    .catch((err) => {
      if (err.code !== '42P01') throw err; // 42P01: nothing migrated yet (no drizzle schema/table)
      return 0;
    });
  return entries.filter((e) => e.when > applied).map((e) => e.tag);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  if (!process.env.DATABASE_URL) throw new Error('Missing env DATABASE_URL');
  const pool = new pg.Pool(connectionOptions(process.env.DATABASE_URL, process.env.DATABASE_SSL_CA));
  try {
    await runMigrations(pool);
    console.log('migrations up to date');
  } finally {
    await pool.end();
  }
}

// Apply pending migrations in drizzle/ (journal order), each recorded in drizzle.__drizzle_migrations.
// Usage: npm run db:migrate  (uses DATABASE_URL / DATABASE_SSL_CA from .env, same TLS rules as the app).
// Pending migrations run in one transaction: on error nothing is applied.
import { fileURLToPath } from 'node:url';
import pg from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';
import { migrate } from 'drizzle-orm/node-postgres/migrator';
import { connectionOptions } from '../src/db/connection.js';

export const migrationsFolder = fileURLToPath(new URL('../drizzle', import.meta.url));

export async function runMigrations(pool) {
  await migrate(drizzle(pool), { migrationsFolder });
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

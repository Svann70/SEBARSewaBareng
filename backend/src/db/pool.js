import pg from 'pg';
import { config } from '../config/env.js';
import { connectionOptions } from './connection.js';

// NUMERIC money columns arrive as strings; rupiah values fit safely in a JS number.
pg.types.setTypeParser(pg.types.builtins.NUMERIC, Number);

export const pool = new pg.Pool({ ...connectionOptions(config.databaseUrl, config.databaseCa), max: 10 });

// An idle connection dropped by the server (pooler restart, failover) must not crash the process.
pool.on('error', (err) => console.error(JSON.stringify({ level: 'error', msg: 'pg pool error', error: err.message })));

export function query(text, params) {
  return pool.query(text, params);
}

export async function tx(fn) {
  const client = await pool.connect();
  let broken;
  try {
    await client.query('BEGIN');
    const result = await fn(client);
    await client.query('COMMIT');
    return result;
  } catch (err) {
    // Business rejections roll back cleanly and keep the connection; only a failed ROLLBACK means it is broken.
    await client.query('ROLLBACK').catch((rollbackErr) => {
      broken = rollbackErr;
    });
    throw err;
  } finally {
    client.release(broken);
  }
}

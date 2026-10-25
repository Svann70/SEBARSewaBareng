// pendingMigrations with a fake pool: no database needed (the real DB path is covered in api.test.js).
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import { migrationsFolder, pendingMigrations } from '../db/migrate.js';

const { entries } = JSON.parse(await readFile(`${migrationsFolder}/meta/_journal.json`, 'utf8'));
const last = entries.at(-1);
const poolWith = (query) => ({ query });

test('nothing applied yet (42P01) -> every journal tag is pending', async () => {
  const pool = poolWith(async () => { throw Object.assign(new Error('relation does not exist'), { code: '42P01' }); });
  assert.deepEqual(await pendingMigrations(pool), entries.map((e) => e.tag));
});

test('latest applied one entry behind -> only the last tag is pending', async () => {
  const pool = poolWith(async () => ({ rows: [{ at: String(last.when - 1) }] }));
  assert.deepEqual(await pendingMigrations(pool), [last.tag]);
});

test('latest applied is the last entry -> nothing pending', async () => {
  const pool = poolWith(async () => ({ rows: [{ at: String(last.when) }] }));
  assert.deepEqual(await pendingMigrations(pool), []);
});

test('empty migrations table (max is NULL) -> every tag is pending', async () => {
  const pool = poolWith(async () => ({ rows: [{ at: null }] }));
  assert.deepEqual(await pendingMigrations(pool), entries.map((e) => e.tag));
});

test('other database errors are rethrown', async () => {
  const pool = poolWith(async () => { throw Object.assign(new Error('connection refused'), { code: 'ECONNREFUSED' }); });
  await assert.rejects(pendingMigrations(pool), { code: 'ECONNREFUSED' });
});

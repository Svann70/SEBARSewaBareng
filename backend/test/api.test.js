// Integration tests against a real Postgres. Point TEST_DATABASE_URL at a disposable database
// (e.g. a local docker container), never at Supabase production. Data is namespaced per run, not truncated.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import http from 'node:http';
import { after, before, describe, test } from 'node:test';

const skip = !process.env.TEST_DATABASE_URL && 'TEST_DATABASE_URL not set';
let base, server, db;
const storage = { calls: [], failNext: false, server: null };
const run = crypto.randomBytes(4).toString('hex');
let n = 0;

before(async () => {
  if (skip) return;
  process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
  process.env.JWT_SECRET ??= crypto.randomBytes(48).toString('base64url');
  process.env.ALLOW_SANDBOX_TOPUP = '1';
  // Every test request comes from 127.0.0.1; the limiter itself is covered in rate-limit.test.js.
  // Court photos go to a fake Supabase Storage on localhost, never the real project.
  storage.server = http.createServer((req, res) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => {
      storage.calls.push({ method: req.method, url: req.url, auth: req.headers.authorization, type: req.headers['content-type'], body: Buffer.concat(chunks) });
      res.statusCode = storage.failNext ? 500 : 200;
      storage.failNext = false;
      res.end('{}');
    });
  }).listen(0);
  await new Promise((r) => storage.server.once('listening', r));
  process.env.SUPABASE_URL = `http://127.0.0.1:${storage.server.address().port}`;
  process.env.SUPABASE_SERVICE_ROLE_KEY = 'test-service-key';
  process.env.SUPABASE_PHOTO_BUCKET = 'courts-photos';
  process.env.AUTH_RATE_LIMIT = '100000';
  process.env.LOGIN_RATE_LIMIT = '100000';
  const { createApp } = await import('../src/app.js');
  ({ pool: db } = await import('../src/db/pool.js'));
  // Schema = fixture dump + drizzle/ migrations, exactly as on Supabase.
  await (await import('../db/migrate.js')).runMigrations(db);
  server = createApp().listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (skip) return;
  server.close();
  storage.server.close();
  await db.end();
});

async function api(method, path, { token, body, headers = {} } = {}) {
  const res = await fetch(base + path, {
    method,
    headers: { 'content-type': 'application/json', ...(token && { authorization: `Bearer ${token}` }), ...headers },
    body: body && JSON.stringify(body),
  });
  return { status: res.status, body: res.status === 204 ? null : await res.json() };
}

async function register(role = 'PLAYER') {
  const r = await api('POST', '/auth/register', {
    body: {
      email: `u${run}-${++n}@test.local`,
      password: 'password123',
      fullName: `User ${n}`,
      role,
      ...(role === 'VENUE_ADMIN' && { venue: { name: `GOR ${run}-${n}`, address: 'Jl. Tes No. 1', city: 'Bandung' } }),
    },
  });
  assert.equal(r.status, 201, JSON.stringify(r.body));
  return { token: r.body.accessToken, refreshToken: r.body.refreshToken, id: r.body.user.id };
}

async function player(balance) {
  const p = await register();
  if (balance) {
    const r = await api('POST', '/me/wallet/topup', { token: p.token, body: { amount: balance }, headers: { 'Idempotency-Key': crypto.randomUUID() } });
    assert.equal(r.status, 201);
  }
  return p;
}

const wallet = async (p) => (await api('GET', '/me/wallet', { token: p.token })).body;

// Venue admin with one court; returns a helper that creates future slots via the API.
async function venueWithCourt() {
  const admin = await register('VENUE_ADMIN');
  const v = await db.query('SELECT id FROM venues WHERE owner_id = $1', [admin.id]);
  const c = await db.query(`INSERT INTO courts (venue_id, name, sport_type, price_per_hour, capacity) VALUES ($1, 'A', 'BADMINTON', 200000, 10) RETURNING id`, [v.rows[0].id]);
  let hour = 0;
  const slot = async (price = 400_000) => {
    const start = new Date(Date.now() + 48 * 3600_000 + hour++ * 2 * 3600_000);
    start.setUTCMinutes(0, 0, 0);
    const r = await api('POST', '/venue/slots', {
      token: admin.token,
      body: { courtId: c.rows[0].id, startAt: start.toISOString(), endAt: new Date(start.getTime() + 2 * 3600_000).toISOString(), price },
    });
    assert.equal(r.status, 201, JSON.stringify(r.body));
    return r.body;
  };
  return { admin, venueId: v.rows[0].id, courtId: c.rows[0].id, slot };
}

async function createLobby(host, slotId, quota, extra = {}) {
  return api('POST', '/lobbies', { token: host.token, body: { slotId, title: 'Main bareng', quota, ...extra } });
}

describe('auth', { skip }, () => {
  test('register validates, logs in, rejects duplicates and bad passwords', async () => {
    const email = `auth${run}@test.local`;
    assert.equal((await api('POST', '/auth/register', { body: { email, password: 'short', fullName: 'A' } })).status, 422);
    assert.equal((await api('POST', '/auth/register', { body: { email, password: 'password123', fullName: 'A' } })).status, 201);
    assert.equal((await api('POST', '/auth/register', { body: { email, password: 'password123', fullName: 'A' } })).status, 409);
    assert.equal((await api('POST', '/auth/login', { body: { email, password: 'wrongpass1' } })).status, 401);
    const ok = await api('POST', '/auth/login', { body: { email, password: 'password123' } });
    assert.equal(ok.status, 200);
    const me = await api('GET', '/me', { token: ok.body.accessToken });
    assert.equal(me.body.reliabilityScore, 100);
    assert.equal((await api('GET', '/me', { token: 'garbage' })).status, 401);
  });

  test('login checks the account type picked in the app', async () => {
    const email = `role${run}@test.local`;
    await api('POST', '/auth/register', { body: { email, password: 'password123', fullName: 'P' } });
    const wrong = await api('POST', '/auth/login', { body: { email, password: 'password123', role: 'VENUE_ADMIN' } });
    assert.equal(wrong.status, 403);
    assert.equal(wrong.body.error.code, 'WRONG_ACCOUNT_TYPE');
    assert.equal((await api('POST', '/auth/login', { body: { email, password: 'password123', role: 'PLAYER' } })).status, 200);
    const badPass = await api('POST', '/auth/login', { body: { email, password: 'wrongpass1', role: 'VENUE_ADMIN' } });
    assert.equal(badPass.status, 401, 'wrong password never reveals the role');
  });

  test('venue registration creates the venue; venue data is required for venue accounts only', async () => {
    const base = { password: 'password123', fullName: 'Admin' };
    const missing = await api('POST', '/auth/register', { body: { ...base, email: `v1${run}@test.local`, role: 'VENUE_ADMIN' } });
    assert.equal(missing.status, 422);
    const extra = await api('POST', '/auth/register', {
      body: { ...base, email: `v2${run}@test.local`, venue: { name: 'GOR X', address: 'Jl. X No. 1', city: 'Bandung' } },
    });
    assert.equal(extra.status, 422);
    const ok = await register('VENUE_ADMIN');
    const venues = await api('GET', '/venue/venues', { token: ok.token });
    assert.equal(venues.body.items.length, 1);
    assert.equal(venues.body.items[0].city, 'Bandung');
  });

  test('refresh rotates the token; reusing an old one revokes the session', async () => {
    const u = await register();
    const r1 = await api('POST', '/auth/refresh', { body: { refreshToken: u.refreshToken } });
    assert.equal(r1.status, 200);
    assert.notEqual(r1.body.refreshToken, u.refreshToken);
    assert.equal((await api('GET', '/me', { token: r1.body.accessToken })).status, 200);

    // Outside the 10 s race window, a replayed old token is treated as theft.
    await db.query(`UPDATE refresh_tokens SET revoked_at = now() - interval '1 minute' WHERE user_id = $1 AND revoked_at IS NOT NULL`, [u.id]);
    const replay = await api('POST', '/auth/refresh', { body: { refreshToken: u.refreshToken } });
    assert.equal(replay.status, 401);
    const afterTheft = await api('POST', '/auth/refresh', { body: { refreshToken: r1.body.refreshToken } });
    assert.equal(afterTheft.status, 401, 'whole family revoked after reuse');
    assert.equal((await api('POST', '/auth/refresh', { body: { refreshToken: 'x'.repeat(43) } })).status, 401);
  });

  test('two parallel refreshes of one token: one wins and the session survives', async () => {
    const u = await register();
    const [a, b] = await Promise.all([1, 2].map(() => api('POST', '/auth/refresh', { body: { refreshToken: u.refreshToken } })));
    assert.deepEqual([a.status, b.status].sort(), [200, 401]);
    const winner = a.status === 200 ? a : b;
    assert.equal((await api('POST', '/auth/refresh', { body: { refreshToken: winner.body.refreshToken } })).status, 200);
  });

  test('rotation keeps the absolute session expiry; expired and deactivated sessions are rejected', async () => {
    const u = await register();
    const r1 = await api('POST', '/auth/refresh', { body: { refreshToken: u.refreshToken } });
    const first = await db.query('SELECT expires_at FROM refresh_tokens WHERE user_id = $1 ORDER BY created_at LIMIT 1', [u.id]);
    assert.equal(new Date(r1.body.refreshExpiresAt).getTime(), first.rows[0].expires_at.getTime());

    await db.query(`UPDATE refresh_tokens SET expires_at = now() - interval '1 second' WHERE user_id = $1`, [u.id]);
    assert.equal((await api('POST', '/auth/refresh', { body: { refreshToken: r1.body.refreshToken } })).status, 401);

    const d = await register();
    await db.query('UPDATE users SET is_active = false WHERE id = $1', [d.id]);
    assert.equal((await api('POST', '/auth/refresh', { body: { refreshToken: d.refreshToken } })).status, 401);
    assert.equal((await api('GET', '/me', { token: d.token })).status, 401);
  });

  test('register refuses SUPER_ADMIN; token responses are not cacheable', async () => {
    const r = await api('POST', '/auth/register', { body: { email: `sa${run}@test.local`, password: 'password123', fullName: 'X', role: 'SUPER_ADMIN' } });
    assert.equal(r.status, 422);
    const res = await fetch(`${base}/auth/register`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email: `nc${run}@test.local`, password: 'password123', fullName: 'X' }),
    });
    assert.equal(res.headers.get('cache-control'), 'no-store');
  });

  test('logout revokes the refresh token and is idempotent', async () => {
    const u = await register();
    assert.equal((await api('POST', '/auth/logout', { body: { refreshToken: u.refreshToken } })).status, 204);
    assert.equal((await api('POST', '/auth/logout', { body: { refreshToken: u.refreshToken } })).status, 204);
    assert.equal((await api('POST', '/auth/refresh', { body: { refreshToken: u.refreshToken } })).status, 401);
    assert.equal((await api('POST', '/auth/logout', { body: { refreshToken: 'short' } })).status, 204, 'malformed token');
  });

  test('players cannot use venue admin endpoints', async () => {
    const p = await player();
    assert.equal((await api('GET', '/venue/slots?date=2026-01-01', { token: p.token })).status, 403);
  });

  test('profile updates name and phone; phone is validated and unique', async () => {
    const p = await player();
    const r = await api('PATCH', '/me', { token: p.token, body: { fullName: 'Nama Baru', phone: '+62812345678' } });
    assert.equal(r.status, 200);
    assert.equal(r.body.fullName, 'Nama Baru');
    assert.equal(r.body.phone, '+62812345678');

    assert.equal((await api('PATCH', '/me', { token: p.token, body: { phone: '08x' } })).status, 422);
    assert.equal((await api('PATCH', '/me', { token: p.token, body: {} })).status, 422, 'no-op patch rejected');

    const other = await player();
    assert.equal(
      (await api('PATCH', '/me', { token: other.token, body: { phone: '+62812345678' } })).status,
      409,
      'phone already registered',
    );

    // Omitted fields survive; null clears the phone.
    const kept = await api('PATCH', '/me', { token: p.token, body: { fullName: 'Nama Kedua' } });
    assert.equal(kept.body.phone, '+62812345678');
    const cleared = await api('PATCH', '/me', { token: p.token, body: { phone: null } });
    assert.equal(cleared.body.phone, null);
    assert.equal((await api('PATCH', '/me', { body: { fullName: 'X' } })).status, 401);
  });

  test('password change verifies the current one, then revokes every session', async () => {
    const u = await register();
    const email = `pw${run}-${u.id.slice(0, 8)}@test.local`;
    await db.query('UPDATE users SET email = $2 WHERE id = $1', [u.id, email]);

    assert.equal(
      (await api('POST', '/me/password', { token: u.token, body: { currentPassword: 'nope-wrong', newPassword: 'password456' } })).status,
      401,
    );
    assert.equal(
      (await api('POST', '/me/password', { token: u.token, body: { currentPassword: 'password123', newPassword: 'password123', } })).status,
      422,
      'same password refused',
    );
    assert.equal(
      (await api('POST', '/me/password', { token: u.token, body: { currentPassword: 'password123', newPassword: 'short' } })).status,
      422,
    );

    const ok = await api('POST', '/me/password', { token: u.token, body: { currentPassword: 'password123', newPassword: 'password456' } });
    assert.equal(ok.status, 204);

    assert.equal((await api('POST', '/auth/login', { body: { email, password: 'password123' } })).status, 401, 'old password dead');
    assert.equal((await api('POST', '/auth/login', { body: { email, password: 'password456' } })).status, 200);
    assert.equal((await api('POST', '/auth/refresh', { body: { refreshToken: u.refreshToken } })).status, 401, 'sessions revoked');
  });
});

describe('wallet', { skip }, () => {
  test('top-up needs an Idempotency-Key and is idempotent', async () => {
    const p = await player();
    assert.equal((await api('POST', '/me/wallet/topup', { token: p.token, body: { amount: 50_000 } })).status, 422);
    const headers = { 'Idempotency-Key': crypto.randomUUID() };
    const first = await api('POST', '/me/wallet/topup', { token: p.token, body: { amount: 50_000 }, headers });
    const again = await api('POST', '/me/wallet/topup', { token: p.token, body: { amount: 50_000 }, headers });
    assert.equal(first.status, 201);
    assert.equal(again.status, 200);
    assert.equal(again.body.id, first.body.id);
    assert.deepEqual(await wallet(p), { balance: 50_000, held: 0, available: 50_000 });
    const reused = await api('POST', '/me/wallet/topup', { token: p.token, body: { amount: 99_000 }, headers });
    assert.equal(reused.body.error.code, 'IDEMPOTENCY_KEY_REUSED');
  });

  test('same key: concurrent retries credit once; another user may use it too', async () => {
    const [p, q] = [await player(), await player()];
    const headers = { 'Idempotency-Key': `shared-${run}` };
    const results = await Promise.all(Array.from({ length: 6 }, () => api('POST', '/me/wallet/topup', { token: p.token, body: { amount: 20_000 }, headers })));
    assert.deepEqual(results.map((r) => r.status).sort(), [200, 200, 200, 200, 200, 201]);
    assert.equal((await wallet(p)).balance, 20_000);
    assert.equal((await api('POST', '/me/wallet/topup', { token: q.token, body: { amount: 20_000 }, headers })).status, 201);
  });
});

describe('venue admin', { skip }, () => {
  test('an admin without a venue can create one via POST /venue/venues', async () => {
    // Simulate an account whose role was promoted by hand: venue row removed.
    const admin = await register('VENUE_ADMIN');
    await db.query('DELETE FROM venues WHERE owner_id = $1', [admin.id]);
    const empty = await api('GET', '/venue/venues', { token: admin.token });
    assert.equal(empty.status, 200);
    assert.equal(empty.body.items.length, 0);

    assert.equal(
      (await api('POST', '/venue/venues', { token: admin.token, body: { name: 'X', address: 'Jl. 1', city: 'B' } })).status,
      422,
      'validation',
    );
    assert.equal(
      (await api('POST', '/venue/venues', { token: (await player()).token, body: { name: 'GOR Y', address: 'Jl. Y No. 1', city: 'Bandung' } })).status,
      403,
      'players rejected',
    );

    const r = await api('POST', '/venue/venues', {
      token: admin.token,
      body: { name: 'GOR Baru', address: 'Jl. Baru No. 9', city: 'Bandung', description: 'Cabang baru' },
    });
    assert.equal(r.status, 201, JSON.stringify(r.body));
    assert.equal(r.body.name, 'GOR Baru');
    assert.deepEqual(r.body.courts, []);
    const list = await api('GET', '/venue/venues', { token: admin.token });
    assert.equal(list.body.items.length, 1);
    assert.equal(list.body.items[0].id, r.body.id);
  });
});

describe('venue slots', { skip }, () => {
  test('overlapping slot on the same court is rejected', async () => {
    const v = await venueWithCourt();
    const s = await v.slot();
    const clash = await api('POST', '/venue/slots', {
      token: v.admin.token,
      body: { courtId: v.courtId, startAt: new Date(new Date(s.startAt).getTime() + 3600_000).toISOString(), endAt: new Date(new Date(s.endAt).getTime() + 3600_000).toISOString(), price: 100_000 },
    });
    assert.equal(clash.status, 409);
  });

  test('another admin cannot add slots to my court', async () => {
    const v = await venueWithCourt();
    const other = await register('VENUE_ADMIN');
    const start = new Date(Date.now() + 72 * 3600_000);
    const r = await api('POST', '/venue/slots', {
      token: other.token,
      body: { courtId: v.courtId, startAt: start.toISOString(), endAt: new Date(start.getTime() + 3600_000).toISOString(), price: 100_000 },
    });
    assert.equal(r.status, 404);
  });
});

describe('venue slots vs lobbies', { skip }, () => {
  test('slot with a lobby cannot be blocked; write responses include court info', async () => {
    const v = await venueWithCourt();
    const slot = await v.slot();
    assert.equal(slot.courtName, 'A');
    assert.equal(slot.sport, 'BADMINTON');
    await createLobby(await player(500_000), slot.id, 4);
    const r = await api('PATCH', `/venue/slots/${slot.id}`, { token: v.admin.token, body: { status: 'BLOCKED' } });
    assert.equal(r.status, 409);
    const free = await v.slot();
    const blocked = await api('PATCH', `/venue/slots/${free.id}`, { token: v.admin.token, body: { status: 'BLOCKED' } });
    assert.equal(blocked.body.status, 'BLOCKED');
    assert.equal(blocked.body.courtName, 'A');
  });

  test('lobby list date filter uses the WIB calendar date', async () => {
    const v = await venueWithCourt();
    const slot = await v.slot();
    const lobby = (await createLobby(await player(500_000), slot.id, 4)).body;
    const wibDate = new Date(new Date(slot.startAt).getTime() + 7 * 3600_000).toISOString().slice(0, 10);
    const p = await player();
    // The test DB keeps every run's lobbies, so look through all pages, not just the first.
    const listed = async (query) => {
      for (let page = 1; ; page++) {
        const r = await api('GET', `/lobbies?${query}&page=${page}`, { token: p.token });
        if (r.body.items.some((l) => l.id === lobby.id)) return true;
        if (r.body.items.length === 0) return false;
      }
    };
    assert.ok(await listed(`date=${wibDate}&city=bandung`));
    const dayAfter = new Date(Date.parse(wibDate) + 86400_000).toISOString().slice(0, 10);
    assert.ok(!(await listed(`date=${dayAfter}`)));

    // POV venue: jadwal menampilkan siapa yang booking + jumlah pemain.
    const venueSlots = await api('GET', `/venue/slots?date=${wibDate}`, { token: v.admin.token });
    const row = venueSlots.body.items.find((s) => s.id === slot.id);
    assert.ok(row.hostName, 'host name present');
    assert.equal(row.joined, 1);
    assert.equal(row.quota, 4);
    assert.equal((await api('GET', `/venues/${v.venueId}/slots?date=${wibDate}`, { token: p.token })).body.items[0].hostName, undefined);
  });
});

describe('lobby (patungan v2)', { skip }, () => {
  const join = (p, lobby) => api('POST', `/lobbies/${lobby.id}/join`, { token: p.token });
  const leave = (p, lobby) => api('DELETE', `/lobbies/${lobby.id}/members/me`, { token: p.token });
  const detail = async (p, lobby) => (await api('GET', `/lobbies/${lobby.id}`, { token: p.token })).body;
  const held = async (p) => (await wallet(p)).held;
  // End the member's free period (as if 2 hours passed).
  const lock = (p, lobby) => db.query(`UPDATE lobby_members SET free_until = now() - interval '1 second' WHERE lobby_id = $1 AND user_id = $2`, [lobby.id, p.id]);
  const closeJoin = (lobby) => db.query(`UPDATE lobbies SET join_deadline = now() - interval '1 second' WHERE id = $1`, [lobby.id]);

  test('a host can have at most 3 open rooms', async () => {
    const v = await venueWithCourt();
    const host = await player(2_000_000);
    for (let i = 0; i < 3; i++) assert.equal((await createLobby(host, (await v.slot()).id, 4)).status, 201);
    assert.equal((await createLobby(host, (await v.slot()).id, 4)).status, 409);
  });

  test('create holds 100% from the host; joining costs the next share', async () => {
    const v = await venueWithCourt();
    const host = await player(500_000);
    const r = await createLobby(host, (await v.slot(400_000)).id, 8);
    assert.equal(r.status, 201, JSON.stringify(r.body));
    assert.equal(r.body.share, 400_000);
    assert.equal(r.body.joinCost, 200_000);
    assert.equal(r.body.pricePerPerson, 200_000);
    assert.equal(r.body.creatorId, host.id);
    assert.deepEqual(await wallet(host), { balance: 500_000, held: 400_000, available: 100_000 });
    assert.equal((await createLobby(await player(500_000), r.body.slot.id, 4)).status, 409, 'one active room per slot');

    const poor = await createLobby(await player(10_000), (await v.slot(400_000)).id, 4);
    assert.equal(poor.status, 409);
    assert.deepEqual(poor.body.error.details, { required: 400_000, available: 10_000 });
  });

  test('joins split the bill; the difference comes back when join closes', async () => {
    const v = await venueWithCourt();
    const host = await player(500_000);
    const lobby = (await createLobby(host, (await v.slot(400_000)).id, 4)).body;
    const [a, b] = [await player(500_000), await player(500_000)];
    assert.equal((await join(a, lobby)).status, 201);
    assert.equal((await join(a, lobby)).status, 200, 'retry is idempotent');
    assert.equal(await held(a), 200_000);
    await join(b, lobby);
    assert.equal(await held(a), 200_000, 'difference stays held until join closes');
    assert.equal(await held(b), 133_333);
    assert.equal(await held(host), 400_000, 'host guarantee stays until join closes');
    const d = await detail(a, lobby);
    assert.equal(d.share, 133_333);
    assert.equal(d.seats, 3);
    assert.equal(d.me.phase, 'FREE');
  });

  test('join rejects low balance and low score without holding money', async () => {
    const v = await venueWithCourt();
    const lobby = (await createLobby(await player(500_000), (await v.slot(400_000)).id, 4, { minReliability: 80 })).body;
    const poor = await player(10_000);
    const r1 = await join(poor, lobby);
    assert.equal(r1.status, 409);
    assert.deepEqual(r1.body.error.details, { required: 200_000, available: 10_000 });
    assert.equal(await held(poor), 0);
    const shady = await player(500_000);
    await db.query('UPDATE users SET reliability_score = 65 WHERE id = $1', [shady.id]);
    assert.equal((await join(shady, lobby)).body.error.code, 'SCORE_TOO_LOW');
    assert.equal(await held(shady), 0);
  });

  test('free period: full refund, shares go back up, 10 minute cooldown', async () => {
    const v = await venueWithCourt();
    const lobby = (await createLobby(await player(500_000), (await v.slot(400_000)).id, 4)).body;
    const [a, b] = [await player(500_000), await player(500_000)];
    await join(a, lobby);
    await join(b, lobby);
    const r = await leave(b, lobby);
    assert.deepEqual(r.body, { phase: 'FREE', refund: 133_333 });
    assert.equal(await held(b), 0);
    assert.equal(await held(a), 200_000, 'share back to 200k');
    assert.equal((await join(b, lobby)).body.error.code, 'COOLDOWN');
    await db.query(`UPDATE lobby_members SET cancelled_at = now() - interval '11 minutes' WHERE lobby_id = $1 AND user_id = $2`, [lobby.id, b.id]);
    assert.equal((await join(b, lobby)).status, 201, 'can join again after 10 minutes');
  });

  test('locked leave leaves a vacant seat; the next joiner replaces it (Rp10.000 fine held)', async () => {
    const v = await venueWithCourt();
    const host = await player(500_000);
    const lobby = (await createLobby(host, (await v.slot(400_000)).id, 4)).body;
    const [a, b, c] = [await player(500_000), await player(500_000), await player(500_000)];
    await join(a, lobby);
    await join(b, lobby);
    await lock(b, lobby);
    assert.deepEqual((await leave(b, lobby)).body, { phase: 'LOCKED', refund: 0, fineIfReplaced: 10_000 });
    assert.equal(await held(b), 133_333, 'vacant seat keeps paying');
    assert.equal((await join(b, lobby)).body.error.code, 'ALREADY_JOINED');
    assert.equal((await detail(a, lobby)).vacant, 1);
    assert.equal((await detail(a, lobby)).joinCost, 133_333, 'replacement pays the same share');

    assert.equal((await join(c, lobby)).status, 201);
    assert.equal(await held(c), 133_333);
    assert.equal(await held(b), 10_000, 'refund minus fine; fine stays held');
    assert.equal(await held(a), 200_000, 'nobody else changes');
    assert.equal((await detail(c, lobby)).me.phase, 'LOCKED', 'a replacement gets no free period');
    assert.equal((await detail(a, lobby)).vacant, 0);
  });

  test('protection: a share above the join share lets a locked member leave for free', async () => {
    const v = await venueWithCourt();
    const host = await player(500_000);
    const lobby = (await createLobby(host, (await v.slot(400_000)).id, 4)).body;
    const [a, b, c] = [await player(500_000), await player(500_000), await player(500_000)];
    await join(a, lobby); // n=2, 200k
    await join(b, lobby); // n=3, 133333
    await join(c, lobby); // n=4, 100k
    await lock(b, lobby);
    await leave(a, lobby); // free: n=3 -> 133333 = b's join share, no protection
    assert.equal((await detail(b, lobby)).me.phase, 'LOCKED');
    const kick = await api('DELETE', `/lobbies/${lobby.id}/members/${c.id}`, { token: host.token });
    assert.deepEqual(kick.body, { refund: 133_333 });
    assert.equal(await held(c), 0);
    assert.equal(await held(b), 200_000, 'share 200k is above the 133333 b agreed to');
    const inbox = (await api('GET', '/me/notifications', { token: b.token })).body;
    assert.ok(inbox.items.some((x) => x.type === 'SHARE_PROTECTION' && x.payload.share === 200_000));
    assert.ok(inbox.unread > 0);
    await api('POST', '/me/notifications/read', { token: b.token });
    assert.equal((await api('GET', '/me/notifications', { token: b.token })).body.unread, 0);
    assert.equal((await detail(b, lobby)).me.phase, 'PROTECTED');
    assert.deepEqual((await leave(b, lobby)).body, { phase: 'PROTECTED', refund: 200_000 });
    assert.equal(await held(b), 0);
    assert.equal((await api('DELETE', `/lobbies/${lobby.id}/members/${host.id}`, { token: b.token })).status, 403, 'only the host kicks');
  });

  test('a member who cannot pay a higher share is taken out with a full refund', async () => {
    const v = await venueWithCourt();
    const host = await player(500_000);
    const lobby = (await createLobby(host, (await v.slot(400_000)).id, 4)).body;
    const a = await player(500_000);
    const b = await player(133_333);
    await join(a, lobby); // n=2
    await join(b, lobby); // n=3, b holds 133333 and has nothing left
    await leave(a, lobby); // free: share 200k, b cannot top up -> out, refunded
    assert.deepEqual(await wallet(b), { balance: 133_333, held: 0, available: 133_333 });
    const notes = await db.query(`SELECT payload FROM notifications WHERE user_id = $1 AND type = 'AUTO_LEFT'`, [b.id]);
    assert.equal(notes.rows[0].payload.refund, 133_333);
    assert.equal((await detail(host, lobby)).seats, 1);
    await closeJoin(lobby);
    const { runLobbyJobs } = await import('../src/modules/lobbies/jobs.js');
    await runLobbyJobs();
    assert.deepEqual(await wallet(host), { balance: 100_000, held: 0, available: 100_000 }, 'host pays only the room, alone');
  });

  test('join close: captures exactly P, vacant seats are forfeited, booking + payout + tickets', async () => {
    const v = await venueWithCourt();
    const slot = await v.slot(400_000);
    const host = await player(500_000);
    const lobby = (await createLobby(host, slot.id, 4)).body;
    const [a, b] = [await player(500_000), await player(500_000)];
    await join(a, lobby);
    await join(b, lobby); // 133333 each, host seat 133334
    await lock(b, lobby);
    await leave(b, lobby); // vacant, nobody replaces
    await closeJoin(lobby);
    assert.equal((await join(await player(500_000), lobby)).status, 410);
    const { runLobbyJobs } = await import('../src/modules/lobbies/jobs.js');
    await runLobbyJobs();
    assert.deepEqual(await wallet(a), { balance: 366_667, held: 0, available: 366_667 });
    assert.deepEqual(await wallet(b), { balance: 366_667, held: 0, available: 366_667 }, 'forfeited');
    assert.deepEqual(await wallet(host), { balance: 366_666, held: 0, available: 366_666 }, 'host pays the remainder');
    const bk = (await db.query('SELECT * FROM bookings WHERE lobby_id = $1', [lobby.id])).rows[0];
    assert.equal(bk.gross_amount, 400_000);
    assert.equal(bk.venue_payout, 380_000);
    assert.equal((await db.query('SELECT status FROM court_slots WHERE id = $1', [slot.id])).rows[0].status, 'BOOKED');
    assert.equal((await db.query('SELECT count(*)::int AS n FROM checkins WHERE booking_id = $1', [bk.id])).rows[0].n, 2, 'tickets for players only');
    assert.equal((await api('GET', '/me/bookings', { token: a.token })).body.items[0].bookingCode, bk.booking_code);
    assert.deepEqual((await leave(a, lobby)).body, { phase: 'FINAL', refund: 0 });
  });

  test('room finished: held fines go to the members still in the room', async () => {
    const v = await venueWithCourt();
    const slot = await v.slot(400_000);
    const host = await player(500_000);
    const lobby = (await createLobby(host, slot.id, 4)).body;
    const [a, b, c] = [await player(500_000), await player(500_000), await player(500_000)];
    await join(a, lobby);
    await join(b, lobby);
    await lock(b, lobby);
    await leave(b, lobby);
    await join(c, lobby); // replaces b, b's 10k fine held
    await closeJoin(lobby);
    const { runLobbyJobs } = await import('../src/modules/lobbies/jobs.js');
    await runLobbyJobs();
    await db.query(`UPDATE court_slots SET start_at = now() - interval '3 hours', end_at = now() - interval '1 hour' WHERE id = $1`, [slot.id]);
    await runLobbyJobs();
    assert.deepEqual(await wallet(b), { balance: 490_000, held: 0, available: 490_000 });
    // 10k over host, a, c = 3333 each, 1 rupiah to the host.
    assert.equal((await wallet(a)).balance, 500_000 - 133_333 + 3_333);
    assert.equal((await wallet(host)).balance, 500_000 - 133_334 + 3_334);
    await runLobbyJobs();
    assert.equal((await wallet(a)).balance, 500_000 - 133_333 + 3_333, 'paid once');
  });

  test('disband: free in the first 2 hours, then the host share is the fine', async () => {
    const v = await venueWithCourt();
    const host = await player(1_000_000);
    const [a, b] = [await player(500_000), await player(500_000)];
    const free = (await createLobby(host, (await v.slot(400_000)).id, 4)).body;
    await join(a, free);
    assert.equal((await api('DELETE', `/lobbies/${free.id}`, { token: a.token })).status, 403);
    const r1 = await api('DELETE', `/lobbies/${free.id}`, { token: host.token });
    assert.deepEqual(r1.body, { fine: 0, compensationEach: 0, refundedMembers: 1 });
    assert.equal(await held(a), 0);
    assert.equal(await held(host), 0);

    const late = (await createLobby(host, (await v.slot(400_000)).id, 4)).body;
    await join(a, late);
    await join(b, late); // host seat 133334
    await db.query(`UPDATE lobbies SET created_at = now() - interval '3 hours' WHERE id = $1`, [late.id]);
    const r2 = await api('DELETE', `/lobbies/${late.id}`, { token: host.token });
    assert.deepEqual(r2.body, { fine: 133_334, compensationEach: 33_333, refundedMembers: 2 });
    assert.deepEqual(await wallet(a), { balance: 533_333, held: 0, available: 533_333 });
    assert.equal((await wallet(host)).balance, 1_000_000 - 133_334);
    assert.equal((await wallet(v.admin)).balance, 133_334 - 2 * 33_333, 'venue half + remainder');
  });

  test('match day: no disband; the host leaving hands over the room and pays anyway', async () => {
    const v = await venueWithCourt();
    const slot = await v.slot(400_000);
    const host = await player(500_000);
    const lobby = (await createLobby(host, slot.id, 4)).body;
    const a = await player(500_000);
    assert.equal((await leave(host, lobby)).body.error.code, 'HOST_MUST_DISBAND');
    await join(a, lobby);
    await db.query(`UPDATE court_slots SET start_at = now(), end_at = now() + interval '2 hours' WHERE id = $1`, [slot.id]);
    assert.equal((await api('DELETE', `/lobbies/${lobby.id}`, { token: host.token })).body.error.code, 'MATCH_DAY');
    assert.deepEqual((await leave(host, lobby)).body, { phase: 'HOST_MATCH_DAY', refund: 0 });
    const d = await detail(a, lobby);
    assert.equal(d.hostId, a.id);
    assert.equal(await held(host), 400_000, 'guarantee stays');
  });

  test('protection ends once the share is back down', async () => {
    const v = await venueWithCourt();
    const host = await player(500_000);
    const lobby = (await createLobby(host, (await v.slot(400_000)).id, 4)).body;
    const [m, s, g] = [await player(500_000), await player(500_000), await player(500_000)];
    await join(m, lobby); // n=2, m agreed to 200k
    await join(s, lobby); // n=3
    await join(await player(500_000), lobby); // n=4, 100k
    await lock(m, lobby);
    await leave(s, lobby); // n=3: 133333 < 200k -> no protection for m
    assert.equal((await detail(m, lobby)).me.phase, 'LOCKED');
    await db.query(`UPDATE lobby_members SET protect_until = now() + interval '30 minutes' WHERE lobby_id = $1 AND user_id = $2`, [lobby.id, m.id]);
    await join(g, lobby); // n=4 again: a stale window must not allow a free exit
    assert.equal((await detail(m, lobby)).me.phase, 'LOCKED');
    assert.equal((await leave(m, lobby)).body.phase, 'LOCKED');
  });

  test('kicking everyone first does not make disbanding free', async () => {
    const v = await venueWithCourt();
    const host = await player(1_000_000);
    const lobby = (await createLobby(host, (await v.slot(400_000)).id, 4)).body;
    const a = await player(500_000);
    await join(a, lobby);
    await db.query(`UPDATE lobbies SET created_at = now() - interval '3 hours' WHERE id = $1`, [lobby.id]);
    await api('DELETE', `/lobbies/${lobby.id}/members/${a.id}`, { token: host.token });
    const r = await api('DELETE', `/lobbies/${lobby.id}`, { token: host.token });
    assert.equal(r.body.fine, 400_000, 'host alone pays the full share as the fine');
    assert.equal((await wallet(a)).balance, 500_000 + 200_000, 'kicked member gets the members half');
  });

  test('host who left alone on match day hands over to the first joiner', async () => {
    const v = await venueWithCourt();
    const slot = await v.slot(400_000);
    const host = await player(500_000);
    const lobby = (await createLobby(host, slot.id, 4)).body;
    // Match day = WIB date of the start; skip when "in 2 hours" is already the next WIB day.
    const { rows } = await db.query(
      `UPDATE court_slots SET start_at = now() + interval '2 hours', end_at = now() + interval '3 hours' WHERE id = $1
       RETURNING (now() AT TIME ZONE 'Asia/Jakarta')::date = (start_at AT TIME ZONE 'Asia/Jakarta')::date AS same_day`,
      [slot.id],
    );
    if (!rows[0].same_day) return;
    await db.query(`UPDATE lobbies SET join_deadline = now() + interval '60 minutes' WHERE id = $1`, [lobby.id]);
    assert.equal((await leave(host, lobby)).body.phase, 'HOST_MATCH_DAY');
    const j = await player(500_000);
    await join(j, lobby);
    assert.equal((await detail(j, lobby)).hostId, j.id);
    assert.equal((await api('DELETE', `/lobbies/${lobby.id}/members/${j.id}`, { token: host.token })).status, 403, 'ex-host cannot kick');
  });

  test('20 concurrent joins on quota 8: exactly 7 succeed, holds add up', async () => {
    const v = await venueWithCourt();
    const host = await player(500_000);
    const lobby = (await createLobby(host, (await v.slot(400_000)).id, 8)).body;
    const players = await Promise.all(Array.from({ length: 20 }, () => player(500_000)));
    const results = await Promise.all(players.map((p) => join(p, lobby)));
    assert.equal(results.filter((r) => r.status === 201).length, 7);
    assert.ok(results.filter((r) => r.status !== 201).every((r) => r.body.error.code === 'LOBBY_FULL'));
    const holds = await Promise.all(players.map(held));
    assert.equal(holds.filter((h) => h > 0).length, 7);
    assert.equal(holds.filter((h) => h === 0).length, 13);
  });

  test('ledger always reconciles with wallet balances', async () => {
    const { rows } = await db.query(`
      SELECT w.id FROM wallets w LEFT JOIN wallet_ledger l ON l.wallet_id = w.id
       GROUP BY w.id
      HAVING w.balance <> COALESCE(sum(CASE WHEN l.entry_type IN ('TOPUP', 'REFUND', 'COMPENSATION') THEN l.amount
                                             WHEN l.entry_type IN ('CAPTURE', 'PAYOUT', 'PENALTY') THEN -l.amount ELSE 0 END), 0)
          OR w.held_balance <> COALESCE(sum(CASE WHEN l.entry_type = 'HOLD' THEN l.amount
                                                  WHEN l.entry_type IN ('RELEASE', 'CAPTURE', 'PENALTY') THEN -l.amount ELSE 0 END), 0)`);
    assert.equal(rows.length, 0);
  });
});

// WIB calendar date at least `daysAhead` days out that is (not) a weekend, and an instant on it.
function wibDate(daysAhead, weekend) {
  const d = new Date(Date.now() + 7 * 3600_000);
  d.setUTCDate(d.getUTCDate() + daysAhead);
  while ([0, 6].includes(d.getUTCDay()) !== weekend) d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().slice(0, 10);
}
const wibAt = (date, hour) => new Date(`${date}T${String(hour).padStart(2, '0')}:00:00+07:00`).toISOString();

async function setupCourt(body = {}) {
  const admin = await register('VENUE_ADMIN');
  const venueId = (await db.query('SELECT id FROM venues WHERE owner_id = $1', [admin.id])).rows[0].id;
  const r = await api('POST', '/venue/courts', {
    token: admin.token,
    body: {
      venueId,
      name: 'Serbaguna',
      sports: [{ sport: 'FUTSAL', capacity: 10 }, { sport: 'BASKETBALL', capacity: 10 }, { sport: 'TENNIS', capacity: 4 }],
      pricePerHour: 100_000,
      priceWeekend: 150_000,
      openTime: '08:00',
      closeTime: '22:00',
      ...body,
    },
  });
  assert.equal(r.status, 201, JSON.stringify(r.body));
  return { admin, venueId, court: r.body };
}

const roomAt = (p, courtId, startAt, extra = {}) =>
  api('POST', '/lobbies', { token: p.token, body: { courtId, startAt, hours: 1, title: 'Main bareng', quota: 4, ...extra } });

describe('court setup (one-time, no manual slots)', { skip }, () => {
  test('court keeps sports with capacity, weekday/weekend price and opening hours', async () => {
    const { admin, venueId, court } = await setupCourt();
    assert.deepEqual(court.sports.map((s) => [s.sport, s.capacity]).sort(), [['BASKETBALL', 10], ['FUTSAL', 10], ['TENNIS', 4]]);
    assert.equal(court.pricePerHour, 100_000);
    assert.equal(court.priceWeekend, 150_000);
    assert.equal(court.openTime, '08:00');
    assert.equal(court.closeTime, '22:00');

    const post = (body) => api('POST', '/venue/courts', { token: admin.token, body: { venueId, pricePerHour: 100_000, ...body } });
    assert.equal((await post({ name: 'Lap B', sport: 'BADMINTON', capacity: 8, openTime: '22:00', closeTime: '08:00' })).status, 422);
    assert.equal((await post({ name: 'Lap B', sports: [{ sport: 'FUTSAL', capacity: 10 }, { sport: 'FUTSAL', capacity: 8 }] })).status, 422);
    assert.equal((await post({ name: 'Lap B', sport: 'BADMINTON', capacity: 8, openTime: '08:30' })).status, 422);
    const legacy = await post({ name: 'Lap B', sport: 'BADMINTON', capacity: 8, closeTime: '24:00' });
    assert.equal(legacy.status, 201, JSON.stringify(legacy.body));
    assert.deepEqual(legacy.body.sports, [{ sport: 'BADMINTON', capacity: 8 }]);
    assert.equal(legacy.body.priceWeekend, null, 'no weekend price = weekday price');
    const nullWeekend = await post({ name: 'Lap C', sport: 'BADMINTON', capacity: 4, priceWeekend: null });
    assert.equal(nullWeekend.status, 201, 'explicit null weekend price = weekday price');
    assert.equal(legacy.body.closeTime, '24:00');
    assert.equal((await post({ name: 'Lap B', sport: 'BADMINTON', capacity: 8 })).status, 409, 'duplicate court name');

    const patch = (body) => api('PATCH', `/venue/courts/${court.id}`, { token: admin.token, body });
    const p1 = await patch({ sports: [{ sport: 'PADEL', capacity: 4 }], closeTime: '23:00' });
    assert.equal(p1.status, 200, JSON.stringify(p1.body));
    assert.deepEqual(p1.body.sports, [{ sport: 'PADEL', capacity: 4 }]);
    assert.equal(p1.body.sport, 'PADEL', 'first sport becomes the main sport');
    assert.equal(p1.body.closeTime, '23:00');
    assert.equal((await patch({ openTime: '23:00' })).status, 422);
  });

  test('every opening hour is rentable; a room creates its slot at the weekday/weekend rate', async () => {
    const { venueId, court } = await setupCourt();
    const weekday = wibDate(30, false);
    const weekend = wibDate(30, true);
    const p1 = await player(1_000_000);
    const p2 = await player(1_000_000);

    const avail = await api('GET', `/venues/${venueId}/availability?date=${weekday}`, { token: p1.token });
    assert.equal(avail.status, 200, JSON.stringify(avail.body));
    const grid = avail.body.courts[0];
    assert.equal(grid.rate, 100_000);
    assert.deepEqual(grid.hours.map((h) => h.hour), [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21]);
    assert.ok(grid.hours.every((h) => h.status === 'FREE'));

    const room = await roomAt(p1, court.id, wibAt(weekday, 16), { hours: 2, sport: 'FUTSAL', quota: 10 });
    assert.equal(room.status, 201, JSON.stringify(room.body));
    assert.equal(room.body.priceTotal, 200_000);
    assert.equal(room.body.court.sport, 'FUTSAL');

    const after = (await api('GET', `/venues/${venueId}/availability?date=${weekday}`, { token: p1.token })).body.courts[0];
    assert.deepEqual(after.hours.filter((h) => h.status === 'TAKEN').map((h) => h.hour), [16, 17]);

    // One booking per hour on a multi-purpose court, whatever the sport.
    const clash = await roomAt(p2, court.id, wibAt(weekday, 17), { sport: 'BASKETBALL' });
    assert.equal(clash.status, 409);
    assert.equal(clash.body.error.code, 'SLOT_NOT_OPEN');

    const tennis = await roomAt(p2, court.id, wibAt(weekend, 10), { sport: 'TENNIS', quota: 4 });
    assert.equal(tennis.status, 201, JSON.stringify(tennis.body));
    assert.equal(tennis.body.priceTotal, 150_000, 'weekend rate');
    assert.equal((await roomAt(p2, court.id, wibAt(weekend, 12), { sport: 'TENNIS', quota: 5 })).status, 422, 'tennis capacity 4');
    assert.equal((await roomAt(p2, court.id, wibAt(weekend, 12), { sport: 'BADMINTON' })).status, 422, 'sport not on this court');
    assert.equal((await roomAt(p2, court.id, wibAt(weekend, 7))).status, 422, 'before opening');
    assert.equal((await roomAt(p2, court.id, wibAt(weekend, 21), { hours: 2 })).status, 422, 'past closing');
    const halfHour = new Date(new Date(wibAt(weekend, 12)).getTime() + 30 * 60_000).toISOString();
    assert.equal((await roomAt(p2, court.id, halfHour)).status, 422, 'whole hours only');
    assert.equal((await api('POST', '/lobbies', { token: p2.token, body: { courtId: court.id, title: 'x', quota: 4 } })).status, 422);
  });

  test('hours closed by the owner show CLOSED and cannot be booked', async () => {
    const { admin, venueId, court } = await setupCourt();
    const day = wibDate(30, false);
    const block = await api('POST', '/venue/slots', {
      token: admin.token,
      body: { courtId: court.id, startAt: wibAt(day, 12), endAt: wibAt(day, 14), price: 200_000, status: 'BLOCKED' },
    });
    assert.equal(block.status, 201, JSON.stringify(block.body));
    const p = await player(1_000_000);
    const grid = (await api('GET', `/venues/${venueId}/availability?date=${day}`, { token: p.token })).body.courts[0];
    assert.deepEqual(grid.hours.filter((h) => h.status === 'CLOSED').map((h) => h.hour), [12, 13]);
    const r = await roomAt(p, court.id, wibAt(day, 13), { sport: 'FUTSAL' });
    assert.equal(r.status, 409);
    assert.match(r.body.error.message, /ditutup/);
  });

  test('leftover OPEN slots from the manual flow do not block a room', async () => {
    const { admin, court } = await setupCourt();
    const day = wibDate(30, false);
    const old = await api('POST', '/venue/slots', {
      token: admin.token,
      body: { courtId: court.id, startAt: wibAt(day, 18), endAt: wibAt(day, 20), price: 200_000 },
    });
    assert.equal(old.status, 201);
    const p = await player(1_000_000);
    const r = await roomAt(p, court.id, wibAt(day, 19), { sport: 'FUTSAL' });
    assert.equal(r.status, 201, JSON.stringify(r.body));
    assert.equal(r.body.priceTotal, 100_000);
    const same = await roomAt(await player(1_000_000), court.id, wibAt(day, 10), { sport: 'FUTSAL', hours: 2 });
    assert.equal(same.status, 201, 'unrelated hour still free');
  });

  test('players can filter venues by any sport of a multi-purpose court', async () => {
    const { venueId } = await setupCourt();
    const p = await player();
    const r = await api('GET', '/venues?sport=TENNIS', { token: p.token });
    assert.equal(r.status, 200);
    assert.ok(r.body.items.some((v) => v.id === venueId));
  });
});

describe('court setup edge cases (review fixes)', { skip }, () => {
  test('a cancelled room frees its hours for any duration; grid and create agree', async () => {
    const { venueId, court } = await setupCourt();
    const day = wibDate(31, false);
    const host = await player(1_000_000);
    const room = await roomAt(host, court.id, wibAt(day, 16), { hours: 2, sport: 'FUTSAL' });
    assert.equal(room.status, 201);
    assert.equal((await api('DELETE', `/lobbies/${room.body.id}`, { token: host.token })).status, 200);
    const grid = (await api('GET', `/venues/${venueId}/availability?date=${day}`, { token: host.token })).body.courts[0];
    assert.equal(grid.hours.find((h) => h.hour === 17).status, 'FREE');
    const other = await player(1_000_000);
    const again = await roomAt(other, court.id, wibAt(day, 17), { sport: 'FUTSAL' });
    assert.equal(again.status, 201, JSON.stringify(again.body));
    const clash = await roomAt(await player(1_000_000), court.id, wibAt(day, 16), { hours: 2, sport: 'FUTSAL' });
    assert.equal(clash.status, 409, '16–18 overlaps the new active room at 17:00');
    const before = await roomAt(await player(1_000_000), court.id, wibAt(day, 15), { hours: 2, sport: 'FUTSAL' });
    assert.equal(before.status, 201, '15–17 ends where the active room starts');
  });

  test('court inserted outside the API (seed) still has its sport and shows in the sport filter', async () => {
    const admin = await register('VENUE_ADMIN');
    const venueId = (await db.query('SELECT id FROM venues WHERE owner_id = $1', [admin.id])).rows[0].id;
    await db.query(`INSERT INTO courts (venue_id, name, sport_type, price_per_hour, capacity) VALUES ($1, 'Seed', 'VOLLEY', 90000, 12)`, [venueId]);
    const p = await player();
    const r = await api('GET', '/venues?sport=VOLLEY', { token: p.token });
    const v = r.body.items.find((x) => x.id === venueId);
    assert.ok(v, 'listed under VOLLEY');
    assert.deepEqual(v.courts[0].sports, [{ sport: 'VOLLEY', capacity: 12 }]);
  });

  test('room keeps its sport when the owner changes the court sports later', async () => {
    const { admin, court } = await setupCourt();
    const p = await player(1_000_000);
    const room = await roomAt(p, court.id, wibAt(wibDate(31, false), 9), { quota: 10 });
    assert.equal(room.status, 201);
    assert.equal(room.body.court.sport, 'FUTSAL', 'no sport = main sport at creation');
    const patch = await api('PATCH', `/venue/courts/${court.id}`, {
      token: admin.token,
      body: { sports: [{ sport: 'BASKETBALL', capacity: 10 }, { sport: 'FUTSAL', capacity: 10 }] },
    });
    assert.equal(patch.status, 200);
    const after = await api('GET', `/lobbies/${room.body.id}`, { token: p.token });
    assert.equal(after.body.court.sport, 'FUTSAL');
  });

  test('weekend price can be cleared; Friday 23:00 is weekday, 24:00 close allows a last hour', async () => {
    const { admin, court } = await setupCourt({ closeTime: '24:00' });
    const friday = (() => {
      let d = wibDate(31, false);
      while (new Date(`${d}T12:00:00+07:00`).getUTCDay() !== 5) d = new Date(Date.parse(d) + 86_400_000).toISOString().slice(0, 10);
      return d;
    })();
    const fri = await roomAt(await player(1_000_000), court.id, wibAt(friday, 23), { sport: 'FUTSAL' });
    assert.equal(fri.status, 201, JSON.stringify(fri.body));
    assert.equal(fri.body.priceTotal, 100_000, 'Friday 23:00 WIB = weekday');
    const sat = new Date(Date.parse(friday) + 86_400_000).toISOString().slice(0, 10);
    const late = await roomAt(await player(1_000_000), court.id, wibAt(sat, 23), { sport: 'FUTSAL' });
    assert.equal(late.status, 201);
    assert.equal(late.body.priceTotal, 150_000, 'Saturday 23:00 WIB = weekend');

    const cleared = await api('PATCH', `/venue/courts/${court.id}`, { token: admin.token, body: { priceWeekend: null } });
    assert.equal(cleared.status, 200, JSON.stringify(cleared.body));
    assert.equal(cleared.body.priceWeekend, null);
  });

  test('rooms cannot be made beyond the booking horizon', async () => {
    const { court } = await setupCourt();
    const far = new Date(Date.now() + 90 * 86_400_000);
    far.setUTCMinutes(0, 0, 0);
    far.setUTCHours(3);
    const r = await roomAt(await player(1_000_000), court.id, far.toISOString(), { sport: 'FUTSAL' });
    assert.equal(r.status, 422);
    assert.match(r.body.error.message, /60 hari/);
  });
});

describe('court setup: no double booking (review round 2)', { skip }, () => {
  test('a released slot cannot be reused through the old slotId path', async () => {
    const { court } = await setupCourt();
    const day = wibDate(32, false);
    const host = await player(1_000_000);
    const first = await roomAt(host, court.id, wibAt(day, 16), { sport: 'FUTSAL' });
    assert.equal(first.status, 201);
    const oldSlotId = first.body.slot.id;
    assert.equal((await api('DELETE', `/lobbies/${first.body.id}`, { token: host.token })).status, 200);
    const rebooked = await roomAt(await player(1_000_000), court.id, wibAt(day, 16), { hours: 2, sport: 'FUTSAL' });
    assert.equal(rebooked.status, 201, JSON.stringify(rebooked.body));
    assert.notEqual(rebooked.body.slot.id, oldSlotId, 'old slot was released, a new one was made');
    const sneak = await createLobby(await player(1_000_000), oldSlotId, 4);
    assert.ok([404, 409].includes(sneak.status), `released slot must be refused, got ${sneak.status}`);
  });

  test('parallel rooms for the same hour: exactly one wins', async () => {
    const { court } = await setupCourt();
    const day = wibDate(32, false);
    const players = await Promise.all([1, 2, 3, 4].map(() => player(1_000_000)));
    const results = await Promise.all(
      players.map((p, i) => roomAt(p, court.id, wibAt(day, 10), { hours: 1 + (i % 2), sport: 'FUTSAL' })),
    );
    const codes = results.map((r) => r.status).sort();
    assert.deepEqual(codes, [201, 409, 409, 409], JSON.stringify(results.map((r) => r.body)));
  });
});

describe('venue setup form', { skip }, () => {
  test('owner edits venue details; other owners cannot; courts can be switched off', async () => {
    const { admin, venueId, court } = await setupCourt();
    const r = await api('PATCH', `/venue/venues/${venueId}`, { token: admin.token, body: { name: 'GOR Baru Jaya', city: 'Cimahi' } });
    assert.equal(r.status, 200, JSON.stringify(r.body));
    assert.equal(r.body.name, 'GOR Baru Jaya');
    assert.equal(r.body.city, 'Cimahi');
    const mine = await api('GET', '/venue/venues', { token: admin.token });
    assert.equal(mine.body.items[0].address, 'Jl. Tes No. 1');
    assert.equal((await api('PATCH', `/venue/venues/${venueId}`, { token: admin.token, body: {} })).status, 422);
    const other = await register('VENUE_ADMIN');
    assert.equal((await api('PATCH', `/venue/venues/${venueId}`, { token: other.token, body: { name: 'Curian' } })).status, 404);

    // Off = hidden from players and not bookable; the owner still sees it.
    const off = await api('PATCH', `/venue/courts/${court.id}`, { token: admin.token, body: { status: 'MAINTENANCE' } });
    assert.equal(off.status, 200);
    const p = await player(1_000_000);
    const grid = await api('GET', `/venues/${venueId}/availability?date=${wibDate(30, false)}`, { token: p.token });
    assert.equal(grid.body.courts.length, 0);
    assert.equal((await roomAt(p, court.id, wibAt(wibDate(30, false), 10), { sport: 'FUTSAL' })).status, 404);
    const own = await api('GET', '/venue/venues', { token: admin.token });
    assert.equal(own.body.items[0].courts[0].status, 'MAINTENANCE');
  });
});

describe('closing hours (review fix)', { skip }, () => {
  test('owner can close an hour a cancelled room used to hold; not one a live room holds', async () => {
    const { admin, court } = await setupCourt();
    const day = wibDate(33, false);
    const host = await player(1_000_000);
    const room = await roomAt(host, court.id, wibAt(day, 16), { hours: 2, sport: 'FUTSAL' });
    assert.equal(room.status, 201);
    assert.equal((await api('DELETE', `/lobbies/${room.body.id}`, { token: host.token })).status, 200);
    const close = (h) =>
      api('POST', '/venue/slots', {
        token: admin.token,
        body: { courtId: court.id, startAt: wibAt(day, h), endAt: wibAt(day, h + 1), price: 100_000, status: 'BLOCKED' },
      });
    const closed = await close(17);
    assert.equal(closed.status, 201, JSON.stringify(closed.body));
    const live = await roomAt(await player(1_000_000), court.id, wibAt(day, 10), { sport: 'FUTSAL' });
    assert.equal(live.status, 201);
    const refused = await close(10);
    assert.equal(refused.status, 409);
    assert.match(refused.body.error.message, /terisi/);
  });
});

const PNG = Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), Buffer.alloc(32, 1)]);
const JPG = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff, 0xe0]), Buffer.alloc(32, 2)]);
async function upload(token, courtId, bytes, type = 'image/png') {
  const res = await fetch(`${base}/venue/courts/${courtId}/photos`, {
    method: 'POST',
    headers: { authorization: `Bearer ${token}`, 'content-type': type },
    body: bytes,
  });
  return { status: res.status, body: res.status === 204 ? null : await res.json() };
}

describe('court photos (Supabase Storage)', { skip }, () => {
  test('owner uploads photos; players see them on the court and the room cover', async () => {
    const { admin, venueId, court } = await setupCourt();
    storage.calls.length = 0;
    const first = await upload(admin.token, court.id, PNG);
    assert.equal(first.status, 201, JSON.stringify(first.body));
    const call = storage.calls[0];
    assert.equal(call.method, 'POST');
    assert.match(call.url, new RegExp(`^/storage/v1/object/courts-photos/courts/${court.id}/[0-9a-f-]{36}\\.png$`));
    assert.equal(call.auth, 'Bearer test-service-key');
    assert.ok(call.body.equals(PNG));
    assert.match(first.body.url, /\/storage\/v1\/object\/public\/courts-photos\/courts\//);
    // Declared type is ignored: a JPEG sent as octet-stream is stored as .jpg.
    const second = await upload(admin.token, court.id, JPG, 'application/octet-stream');
    assert.equal(second.status, 201);
    assert.match(storage.calls[1].url, /\.jpg$/);

    const p = await player(1_000_000);
    const venues = await api('GET', '/venues', { token: p.token });
    const photos = venues.body.items.find((v) => v.id === venueId).courts[0].photos;
    assert.deepEqual(photos.map((x) => x.id), [first.body.id, second.body.id]);
    const room = await roomAt(p, court.id, wibAt(wibDate(34, false), 10), { sport: 'FUTSAL' });
    assert.equal(room.status, 201);
    assert.equal(room.body.court.photoUrl, first.body.url, 'cover = first photo');

    const del = await api('DELETE', `/venue/courts/${court.id}/photos/${first.body.id}`, { token: admin.token });
    assert.equal(del.status, 204);
    assert.equal(storage.calls.at(-1).method, 'DELETE');
    assert.deepEqual(JSON.parse(storage.calls.at(-1).body), { prefixes: [first.body.url.split('/courts-photos/')[1]] });
    const after = await api('GET', `/lobbies/${room.body.id}`, { token: p.token });
    assert.equal(after.body.court.photoUrl, second.body.url);
  });

  test('concurrent uploads never pass the 6-photo cap', async () => {
    const { admin, court } = await setupCourt();
    const results = await Promise.all(Array.from({ length: 9 }, () => upload(admin.token, court.id, PNG)));
    assert.equal(results.filter((r) => r.status === 201).length, 6);
    assert.ok(results.every((r) => r.status === 201 || r.status === 409));
    const { rows } = await db.query('SELECT count(*)::int AS n, count(DISTINCT sort)::int AS sorts FROM court_photos WHERE court_id = $1', [court.id]);
    assert.deepEqual(rows[0], { n: 6, sorts: 6 });
  });

  test('rejects non-images, other owners, players, too many photos and storage failures', async () => {
    const { admin, court } = await setupCourt();
    assert.equal((await upload(admin.token, court.id, Buffer.from('<?php echo 1; ?>              '), 'image/png')).status, 415);
    assert.equal((await upload(admin.token, court.id, Buffer.from('{"a":1}'), 'application/json')).status, 415);
    const other = await register('VENUE_ADMIN');
    assert.equal((await upload(other.token, court.id, PNG)).status, 404);
    const p = await player();
    assert.equal((await upload(p.token, court.id, PNG)).status, 403);
    assert.equal((await upload(admin.token, court.id, Buffer.alloc(6 * 1024 * 1024, 0xff))).status, 413);
    storage.failNext = true;
    const failed = await upload(admin.token, court.id, PNG);
    assert.equal(failed.status, 502);
    for (let i = 0; i < 6; i++) assert.equal((await upload(admin.token, court.id, PNG)).status, 201);
    assert.equal((await upload(admin.token, court.id, PNG)).status, 409, 'max 6 photos');
    const bogus = await api('DELETE', `/venue/courts/${court.id}/photos/${crypto.randomUUID()}`, { token: admin.token });
    assert.equal(bogus.status, 404);
  });
});

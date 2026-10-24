// Integration tests against a real Postgres. Point TEST_DATABASE_URL at a disposable database
// (e.g. a local docker container), never at Supabase production. Data is namespaced per run, not truncated.
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import { after, before, describe, test } from 'node:test';

const skip = !process.env.TEST_DATABASE_URL && 'TEST_DATABASE_URL not set';
let base, server, db, expireStaleLobbies, tx;
const run = crypto.randomBytes(4).toString('hex');
let n = 0;

before(async () => {
  if (skip) return;
  process.env.DATABASE_URL = process.env.TEST_DATABASE_URL;
  process.env.JWT_SECRET ??= crypto.randomBytes(48).toString('base64url');
  process.env.ALLOW_SANDBOX_TOPUP = '1';
  // Every test request comes from 127.0.0.1; the limiter itself is covered in rate-limit.test.js.
  process.env.AUTH_RATE_LIMIT = '100000';
  process.env.LOGIN_RATE_LIMIT = '100000';
  const { createApp } = await import('../src/app.js');
  ({ pool: db, tx } = await import('../src/db/pool.js'));
  ({ expireStaleLobbies } = await import('../src/modules/lobbies/membership.service.js'));
  server = createApp().listen(0);
  base = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (skip) return;
  server.close();
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
    await createLobby(await player(200_000), slot.id, 4);
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
    const lobby = (await createLobby(await player(200_000), slot.id, 4)).body;
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

describe('lobby', { skip }, () => {
  test('a host can have at most 3 open lobbies', async () => {
    const v = await venueWithCourt();
    const host = await player(1_000_000);
    for (let i = 0; i < 3; i++) assert.equal((await createLobby(host, (await v.slot()).id, 4)).status, 201);
    assert.equal((await createLobby(host, (await v.slot()).id, 4)).status, 409);
  });

  test('create splits the bill and holds the host share', async () => {
    const v = await venueWithCourt();
    const host = await player(200_000);
    const r = await createLobby(host, (await v.slot(400_000)).id, 8);
    assert.equal(r.status, 201, JSON.stringify(r.body));
    assert.equal(r.body.pricePerPerson, 50_000);
    assert.equal(r.body.joined, 1);
    assert.deepEqual(await wallet(host), { balance: 200_000, held: 50_000, available: 150_000 });
    assert.equal((await createLobby(await player(200_000), r.body.slot.id, 4)).status, 409);
  });

  test('rounding up: 100000 / 3 = 33334 per person', async () => {
    const v = await venueWithCourt();
    const r = await createLobby(await player(100_000), (await v.slot(100_000)).id, 3);
    assert.equal(r.body.pricePerPerson, 33_334);
  });

  test('join rejects low balance and low score without holding money', async () => {
    const v = await venueWithCourt();
    const lobby = (await createLobby(await player(200_000), (await v.slot()).id, 4, { minReliability: 80 })).body;
    const poor = await player(10_000);
    const r1 = await api('POST', `/lobbies/${lobby.id}/join`, { token: poor.token });
    assert.equal(r1.status, 409);
    assert.equal(r1.body.error.code, 'INSUFFICIENT_AVAILABLE_BALANCE');
    assert.deepEqual(r1.body.error.details, { required: 100_000, available: 10_000 });
    assert.equal((await wallet(poor)).held, 0);

    const shady = await player(200_000);
    await db.query('UPDATE users SET reliability_score = 65 WHERE id = $1', [shady.id]);
    const r2 = await api('POST', `/lobbies/${lobby.id}/join`, { token: shady.token });
    assert.equal(r2.status, 403);
    assert.equal(r2.body.error.code, 'SCORE_TOO_LOW');
    assert.equal((await wallet(shady)).held, 0);
  });

  test('last join captures every hold and books the slot in one go', async () => {
    const v = await venueWithCourt();
    const slot = await v.slot(400_000);
    const host = await player(200_000);
    const lobby = (await createLobby(host, slot.id, 4)).body;
    const others = [await player(200_000), await player(200_000), await player(200_000)];
    const r1 = await api('POST', `/lobbies/${lobby.id}/join`, { token: others[0].token });
    assert.equal(r1.status, 201);
    assert.equal((await api('POST', `/lobbies/${lobby.id}/join`, { token: others[0].token })).status, 200, 'retry is idempotent');
    await api('POST', `/lobbies/${lobby.id}/join`, { token: others[1].token });
    const last = await api('POST', `/lobbies/${lobby.id}/join`, { token: others[2].token });
    assert.equal(last.status, 201);
    assert.equal(last.body.member.status, 'CONFIRMED');
    const retry = await api('POST', `/lobbies/${lobby.id}/join`, { token: others[2].token });
    assert.equal(retry.status, 200);
    assert.equal(retry.body.booking.bookingCode, last.body.booking.bookingCode, 'retry still returns the booking');
    assert.match(last.body.booking.bookingCode, /^SEB[0-9A-F]{6}[0-9]{3}$/);

    for (const p of [host, ...others]) assert.deepEqual(await wallet(p), { balance: 100_000, held: 0, available: 100_000 });
    const detail = (await api('GET', `/lobbies/${lobby.id}`, { token: host.token })).body;
    assert.equal(detail.status, 'CONFIRMED');
    const b = await db.query('SELECT * FROM bookings WHERE lobby_id = $1', [lobby.id]);
    assert.equal(b.rows[0].platform_fee, 20_000);
    assert.equal(b.rows[0].venue_payout, 380_000);
    assert.equal((await db.query('SELECT status FROM court_slots WHERE id = $1', [slot.id])).rows[0].status, 'BOOKED');
    // Done by confirm_lobby in the DB: payout to the venue and one check-in ticket per player.
    assert.equal((await db.query('SELECT amount FROM venue_payouts WHERE booking_id = $1', [b.rows[0].id])).rows[0].amount, 380_000);
    assert.equal((await db.query('SELECT count(*)::int AS n FROM checkins WHERE booking_id = $1', [b.rows[0].id])).rows[0].n, 4);
    const mine = await api('GET', '/me/bookings', { token: others[2].token });
    assert.equal(mine.body.items[0].bookingCode, last.body.booking.bookingCode);
    assert.equal((await api('POST', `/lobbies/${lobby.id}/join`, { token: (await player(200_000)).token })).body.error.code, 'LOBBY_FULL');
  });

  test('20 concurrent joins on quota 8: exactly 7 succeed, one booking', async () => {
    const v = await venueWithCourt();
    const lobby = (await createLobby(await player(200_000), (await v.slot(400_000)).id, 8)).body;
    const players = await Promise.all(Array.from({ length: 20 }, () => player(200_000)));
    const results = await Promise.all(players.map((p) => api('POST', `/lobbies/${lobby.id}/join`, { token: p.token })));
    assert.equal(results.filter((r) => r.status === 201).length, 7);
    assert.ok(results.filter((r) => r.status !== 201).every((r) => r.body.error.code === 'LOBBY_FULL'));
    const members = await db.query(`SELECT count(*)::int AS n FROM lobby_members WHERE lobby_id = $1 AND status = 'CONFIRMED'`, [lobby.id]);
    assert.equal(members.rows[0].n, 8);
    const bookings = await db.query('SELECT count(*)::int AS n FROM bookings WHERE lobby_id = $1', [lobby.id]);
    assert.equal(bookings.rows[0].n, 1);
    const held = await Promise.all(players.map(wallet));
    assert.ok(held.every((w) => w.held === 0), 'losers keep no hold');
  });

  test('crossing filling joins on two lobbies do not deadlock', async () => {
    const v = await venueWithCourt();
    const pairs = await Promise.all(
      Array.from({ length: 10 }, async () => {
        const [a, b] = [await player(500_000), await player(500_000)];
        const l1 = (await createLobby(await player(200_000), (await v.slot()).id, 3)).body;
        const l2 = (await createLobby(await player(200_000), (await v.slot()).id, 3)).body;
        await api('POST', `/lobbies/${l1.id}/join`, { token: b.token });
        await api('POST', `/lobbies/${l2.id}/join`, { token: a.token });
        return { a, b, l1, l2 };
      }),
    );
    const results = await Promise.all(
      pairs.flatMap(({ a, b, l1, l2 }) => [
        api('POST', `/lobbies/${l1.id}/join`, { token: a.token }),
        api('POST', `/lobbies/${l2.id}/join`, { token: b.token }),
      ]),
    );
    assert.deepEqual(results.map((r) => r.status), Array(20).fill(201));
  });

  test('leave releases the hold; host cancel refunds all and costs 15 points', async () => {
    const v = await venueWithCourt();
    const host = await player(200_000);
    const lobby = (await createLobby(host, (await v.slot()).id, 4)).body;
    const p = await player(200_000);
    await api('POST', `/lobbies/${lobby.id}/join`, { token: p.token });
    const left = await api('DELETE', `/lobbies/${lobby.id}/members/me`, { token: p.token });
    assert.deepEqual(left.body, { released: 100_000 });
    assert.equal((await wallet(p)).held, 0);
    const rejoin = await api('POST', `/lobbies/${lobby.id}/join`, { token: p.token });
    assert.equal(rejoin.body.error.code, 'ALREADY_JOINED', 'leaving is final (one member row per user)');

    assert.equal((await api('DELETE', `/lobbies/${lobby.id}`, { token: p.token })).status, 403);
    const cancel = await api('DELETE', `/lobbies/${lobby.id}`, { token: host.token });
    assert.deepEqual(cancel.body, { refundedMembers: 1 });
    assert.equal((await wallet(host)).held, 0);
    assert.equal((await wallet(p)).held, 0);
    assert.equal((await api('GET', '/me', { token: host.token })).body.reliabilityScore, 85);
  });

  test('leave and cancel guards: host, confirmed, past deadline', async () => {
    const v = await venueWithCourt();
    const host = await player(200_000);
    const lobby = (await createLobby(host, (await v.slot(200_000)).id, 2)).body;
    assert.equal((await api('DELETE', `/lobbies/${lobby.id}/members/me`, { token: host.token })).status, 409, 'host cannot leave');
    const p = await player(200_000);
    await api('POST', `/lobbies/${lobby.id}/join`, { token: p.token });
    assert.equal((await api('DELETE', `/lobbies/${lobby.id}/members/me`, { token: p.token })).status, 409, 'confirmed cannot leave');
    assert.equal((await api('DELETE', `/lobbies/${lobby.id}`, { token: host.token })).status, 409, 'confirmed cannot be cancelled');

    const open = (await createLobby(host, (await v.slot()).id, 4)).body;
    const q = await player(200_000);
    await api('POST', `/lobbies/${open.id}/join`, { token: q.token });
    await db.query(`UPDATE lobbies SET join_deadline = now() - interval '1 minute' WHERE id = $1`, [open.id]);
    assert.equal((await api('DELETE', `/lobbies/${open.id}/members/me`, { token: q.token })).status, 410);
    assert.equal((await api('DELETE', `/lobbies/${open.id}`, { token: host.token })).status, 410);
    assert.equal((await api('GET', '/me', { token: host.token })).body.reliabilityScore, 100, 'no penalty past deadline');
  });

  test('insufficient balance on create reports the numbers', async () => {
    const v = await venueWithCourt();
    const r = await createLobby(await player(10_000), (await v.slot(400_000)).id, 4);
    assert.equal(r.status, 409);
    assert.deepEqual(r.body.error.details, { required: 100_000, available: 10_000 });
  });

  test('expiry job releases holds of lobbies past their deadline', async () => {
    const v = await venueWithCourt();
    const host = await player(200_000);
    const lobby = (await createLobby(host, (await v.slot()).id, 4)).body;
    await db.query(`UPDATE lobbies SET join_deadline = now() - interval '1 minute' WHERE id = $1`, [lobby.id]);
    assert.equal((await api('POST', `/lobbies/${lobby.id}/join`, { token: (await player(200_000)).token })).status, 410);
    await tx(expireStaleLobbies);
    assert.equal((await db.query('SELECT status FROM lobbies WHERE id = $1', [lobby.id])).rows[0].status, 'EXPIRED');
    assert.deepEqual(await wallet(host), { balance: 200_000, held: 0, available: 200_000 });
  });

  test('ledger always reconciles with wallet balances', async () => {
    const { rows } = await db.query(`
      SELECT w.id FROM wallets w LEFT JOIN wallet_ledger l ON l.wallet_id = w.id
       GROUP BY w.id
      HAVING w.balance <> COALESCE(sum(CASE WHEN l.entry_type IN ('TOPUP', 'REFUND') THEN l.amount
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

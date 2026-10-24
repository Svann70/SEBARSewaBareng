// Demo data (SDD §17.3): 1 venue admin, 8 players with balance, 1 venue in Bandung with courts set up
// once (opening hours, weekday/weekend price, a multi-purpose court), and 3 demo rooms made through the
// same service code as the app: one half full, one full (auto-booked), one with only the host.
// Idempotent: re-running skips rows that already exist. Never run against production data.
import { hashPassword, verifyPassword } from '../src/lib/password.js';
import { pool, tx } from '../src/db/pool.js';
import { creditTopup } from '../src/modules/wallet/wallet.service.js';
import * as lobbies from '../src/modules/lobbies/lobbies.service.js';

// Outside localhost the seed needs ALLOW_SEED=1 and its own SEED_PASSWORD (the default one is public).
const local = ['localhost', '127.0.0.1', '::1'].includes(new URL(process.env.DATABASE_URL).hostname);
if (process.env.NODE_ENV === 'production') throw new Error('Refusing to seed in production');
if (!local && (process.env.ALLOW_SEED !== '1' || !process.env.SEED_PASSWORD)) {
  throw new Error('Non-local database: set ALLOW_SEED=1 and SEED_PASSWORD to seed');
}
const password = process.env.SEED_PASSWORD ?? 'sebar12345';
const hash = await hashPassword(password);

async function upsertUser(c, email, fullName, role, topup) {
  const { rows } = await c.query(
    `INSERT INTO users (email, full_name, password_hash, role) VALUES ($1, $2, $3, $4)
     ON CONFLICT (email) DO NOTHING RETURNING id`,
    [email, fullName, hash, role],
  );
  if (!rows[0]) {
    // Re-run: reuse only the account the seed itself created (same role, same password).
    // Anyone could have registered this email through the API; never hand them the demo venue.
    const existing = (await c.query('SELECT id, role, password_hash FROM users WHERE email = $1', [email])).rows[0];
    if (existing.role !== role || !(await verifyPassword(password, existing.password_hash))) {
      throw new Error(`${email} already exists and was not created by this seed; refusing to reuse it`);
    }
    return existing.id;
  }
  const id = rows[0].id;
  await c.query('INSERT INTO wallets (user_id) VALUES ($1)', [id]);
  if (topup) await creditTopup(c, id, topup, `SEED:${id}`);
  return id;
}

const ids = await tx(async (c) => {
  const adminId = await upsertUser(c, 'venue@sebar.test', 'Admin GOR C-Tra', 'VENUE_ADMIN');
  const players = [];
  for (let i = 1; i <= 8; i++) players.push(await upsertUser(c, `pemain${i}@sebar.test`, `Pemain ${i}`, 'PLAYER', 500_000));

  let venue = (await c.query('SELECT id FROM venues WHERE owner_id = $1 AND name = $2', [adminId, 'GOR C-Tra'])).rows[0];
  venue ??= (
    await c.query(
      `INSERT INTO venues (owner_id, name, address, city, description) VALUES ($1, 'GOR C-Tra', 'Jl. Cikutra No. 1', 'Bandung', 'GOR demo SEBAR') RETURNING id`,
      [adminId],
    )
  ).rows[0];

  // Set up once: every hour inside open–close is bookable, no slots opened by hand.
  // [name, [[sport, capacity], ...] (first = main sport), weekday price, weekend price, open, close]
  const courts = [
    ['Badminton A', [['BADMINTON', 4]], 100_000, 125_000, '07:00', '23:00'],
    ['Badminton B', [['BADMINTON', 4]], 100_000, 125_000, '07:00', '23:00'],
    ['Futsal 1', [['FUTSAL', 14]], 250_000, 300_000, '08:00', '24:00'],
    ['Serbaguna 1', [['FUTSAL', 10], ['BASKETBALL', 10]], 200_000, 250_000, '08:00', '22:00'],
  ];
  const courtIds = {};
  for (const [name, sports, price, weekend, open, close] of courts) {
    const [[sport, capacity]] = sports;
    const court = (
      await c.query(
        `INSERT INTO courts (venue_id, name, sport_type, capacity, price_per_hour, price_weekend, open_time, close_time)
         VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
         ON CONFLICT (venue_id, name) DO UPDATE SET sport_type = EXCLUDED.sport_type, capacity = EXCLUDED.capacity,
           price_per_hour = EXCLUDED.price_per_hour, price_weekend = EXCLUDED.price_weekend,
           open_time = EXCLUDED.open_time, close_time = EXCLUDED.close_time
         RETURNING id`,
        [venue.id, name, sport, capacity, price, weekend, open, close],
      )
    ).rows[0];
    for (const [s, cap] of sports) {
      await c.query(
        `INSERT INTO court_sports (court_id, sport_type, capacity) VALUES ($1, $2, $3)
         ON CONFLICT (court_id, sport_type) DO UPDATE SET capacity = EXCLUDED.capacity`,
        [court.id, s, cap],
      );
    }
    courtIds[name] = court.id;
  }
  return { players, courtIds };
});

// WIB calendar date `days` from today (optionally the next Saturday on/after it) at `hour`.
function wibStart(days, hour, saturday = false) {
  const d = new Date(Date.now() + 7 * 3600_000);
  d.setUTCDate(d.getUTCDate() + days);
  while (saturday && d.getUTCDay() !== 6) d.setUTCDate(d.getUTCDate() + 1);
  return `${d.toISOString().slice(0, 10)}T${String(hour).padStart(2, '0')}:00:00+07:00`;
}

// Demo rooms via the app's own service (wallet holds, auto-booking when full, all DB rules apply).
const [p1, p2, p3, p4, p5, p6, p7, p8] = ids.players;
const rooms = [
  { host: p1, court: 'Futsal 1', startAt: wibStart(2, 19), hours: 2, sport: 'FUTSAL', title: 'Futsal Malam Santai', quota: 10, joiners: [p2, p3, p4] },
  { host: p5, court: 'Badminton A', startAt: wibStart(2, 9, true), hours: 2, sport: 'BADMINTON', title: 'Badminton Ganda Sabtu', quota: 4, joiners: [p6, p7, p8] },
  { host: p2, court: 'Serbaguna 1', startAt: wibStart(3, 16), hours: 2, sport: 'BASKETBALL', title: 'Basket Sore', quota: 10, joiners: [] },
];
for (const room of rooms) {
  const exists = await pool.query(
    `SELECT 1 FROM lobbies WHERE host_id = $1 AND title = $2 AND status IN ('OPEN', 'FILLED', 'CONFIRMED')`,
    [room.host, room.title],
  );
  if (exists.rows[0]) continue;
  const { host, court, joiners, ...input } = room;
  const lobby = await lobbies.create(host, { ...input, courtId: ids.courtIds[court], minReliability: 0 });
  for (const player of joiners) await lobbies.join(lobby.id, player);
}

console.log(`seeded. login: venue@sebar.test / pemain1..8@sebar.test, password ${process.env.SEED_PASSWORD ? '(SEED_PASSWORD)' : password}`);
await pool.end();

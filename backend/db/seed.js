// Demo data (SDD §17.3): 1 venue admin, 8 players with balance, 1 venue in Bandung, slots for the next 7 days.
// Idempotent: re-running skips rows that already exist. Never run against production data.
import { hashPassword, verifyPassword } from '../src/lib/password.js';
import { pool, tx } from '../src/db/pool.js';
import { creditTopup } from '../src/modules/wallet/wallet.service.js';

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

await tx(async (c) => {
  const adminId = await upsertUser(c, 'venue@sebar.test', 'Admin GOR C-Tra', 'VENUE_ADMIN');
  for (let i = 1; i <= 8; i++) await upsertUser(c, `pemain${i}@sebar.test`, `Pemain ${i}`, 'PLAYER', 500_000);

  let venue = (await c.query('SELECT id FROM venues WHERE owner_id = $1 AND name = $2', [adminId, 'GOR C-Tra'])).rows[0];
  venue ??= (
    await c.query(
      `INSERT INTO venues (owner_id, name, address, city, description) VALUES ($1, 'GOR C-Tra', 'Jl. Cikutra No. 1', 'Bandung', 'GOR demo SEBAR') RETURNING id`,
      [adminId],
    )
  ).rows[0];

  const courts = [
    ['Badminton A', 'BADMINTON', 100_000, 8],
    ['Badminton B', 'BADMINTON', 100_000, 8],
    ['Futsal 1', 'FUTSAL', 250_000, 14],
  ];
  for (const [name, sport, price, capacity] of courts) {
    const court = (
      await c.query(
        `INSERT INTO courts (venue_id, name, sport_type, price_per_hour, capacity) VALUES ($1, $2, $3, $4, $5)
         ON CONFLICT (venue_id, name) DO UPDATE SET price_per_hour = EXCLUDED.price_per_hour RETURNING id`,
        [venue.id, name, sport, price, capacity],
      )
    ).rows[0];
    // Two-hour slots at 08:00, 16:00 and 20:00 WIB for the next 7 days.
    await c.query(
      `INSERT INTO court_slots (court_id, start_at, end_at, price)
       SELECT $1, t, t + interval '2 hours', $2
         FROM generate_series(1, 7) AS d, unnest(ARRAY[8, 16, 20]) AS h,
              LATERAL (SELECT (((now() AT TIME ZONE 'Asia/Jakarta')::date + d) + make_interval(hours => h)) AT TIME ZONE 'Asia/Jakarta' AS t) x
       ON CONFLICT (court_id, start_at) DO NOTHING`,
      [court.id, price * 2],
    );
  }
});
console.log(`seeded. login: venue@sebar.test / pemain1..8@sebar.test, password ${process.env.SEED_PASSWORD ? '(SEED_PASSWORD)' : password}`);
await pool.end();

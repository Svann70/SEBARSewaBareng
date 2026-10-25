# SEBAR — Sewa Bareng

Split-the-cost booking for sports venues. One player opens a **lobby** for a court slot, SEBAR
splits the price per person, locks everyone's share in a wallet hold, and **auto-books the slot the
moment the lobby is full** — no more chasing friends for bank transfers.

- **Players** browse venues and open slots, create or join lobbies, and get a confirmed booking with
  a ticket when the quota fills. Backing out is handled by clear refund rules, not awkward chats.
- **Venue admins** publish courts, hourly slots and weekend rates, and watch confirmed bookings
  (and revenue) appear in their schedule.
- **Money rules live in the database**: wallet holds, refunds, the 5% platform fee and lobby expiry
  are enforced by PostgreSQL triggers and functions, so a half-paid booking cannot exist.

| Layer | Tech |
|---|---|
| Mobile app | Flutter (Android / iOS / web), Riverpod — [`mobile/`](mobile/) |
| REST API | Node.js 22 + Express 5, plain JavaScript (ESM), zod validation, JWT + rotating refresh tokens — [`backend/`](backend/) |
| Database | PostgreSQL (Supabase in production), raw SQL via `pg` — schema in [`backend/db/`](backend/db/) |

Full design document: [`SDD_SEBAR.md`](SDD_SEBAR.md) · API reference: [`backend/README.md`](backend/README.md) · Screens & design tokens: [`mobile/README.md`](mobile/README.md)

## Requirements

- **Node.js ≥ 22**
- **Docker** — for the local database and the API integration tests
- **Flutter SDK** (stable) — only if you want to run the mobile app; on Windows desktop or Chrome you
  don't need an Android SDK

## Quick start (~15 minutes)

### 1. Database

Start a throwaway Postgres and load the full schema (tables, triggers, functions, views):

```bash
docker run -d --name sebar-pg -e POSTGRES_PASSWORD=sebar -e POSTGRES_DB=sebar -p 5432:5432 postgres:17-alpine
docker exec -i sebar-pg psql -U postgres -d sebar < backend/test/fixtures/schema.sql
```

> Using **Supabase** instead? The schema lives in `backend/db/` (run `00_extensions.sql` →
> `01_enums.sql` → `tables/` → `functions/` → `triggers/` → `views/` in order) and the connection
> needs its session-pooler URL + CA certificate — see [backend/README.md](backend/README.md) for the
> exact steps.

### 2. Backend

```bash
cd backend
npm install
cp .env.example .env
```

Edit `.env`:

```env
DATABASE_URL=postgresql://postgres:sebar@127.0.0.1:5432/sebar
DATABASE_SSL_CA=
JWT_SECRET=<paste 32+ random chars, see comment in .env.example>
```

`ALLOW_SANDBOX_TOPUP=1` (already set in the example) lets the wallet top up work without a payment
gateway — keep it for local/demo use.

Start the API and seed the demo data (venue, courts, slots for the next 7 days, accounts below):

```bash
npm run seed
npm run dev
curl http://localhost:3000/health      # → {"ok":true}
```

### 3. Mobile app

```bash
cd mobile
flutter pub get
flutter run -d chrome                  # fastest check; API defaults to http://localhost:3000
```

Other targets:

```bash
flutter run                            # Android emulator (API via http://10.0.2.2:3000)
cp env.json.example env.json           # physical phone: set SEBAR_API_URL to your PC's LAN IP
flutter run --dart-define-from-file=env.json
```

Env changes need a full rebuild — hot reload does not reprocess `--dart-define`. For an installable
build: `flutter build apk --debug` → `build/app/outputs/flutter-apk/`.

## Test accounts

Created by `npm run seed`. Password for all of them: **`sebar12345`** (override with the
`SEED_PASSWORD` env var before seeding).

| Role | Email | Notes |
|---|---|---|
| Venue admin | `venue@sebar.test` | Owns **GOR C-Tra** (Bandung): 2 badminton courts + 1 futsal court, slots for the next 7 days |
| Player | `pemain1@sebar.test` … `pemain8@sebar.test` | 8 players, each with Rp 500,000 wallet balance |

You can also register fresh accounts in the app (Register screen) or via `POST /auth/register`.

## Running the tests

Mobile (21 unit & widget tests, no setup needed):

```bash
cd mobile
flutter test
```

Backend (30+ integration tests: booking transaction, wallet holds, concurrency, rate limits; needs
Docker, uses its own Postgres on port 55432):

```bash
docker run -d --name sebar-test-pg -e POSTGRES_PASSWORD=test -e POSTGRES_DB=sebar_test -p 127.0.0.1:55432:5432 postgres:17-alpine
docker exec -i sebar-test-pg psql -U postgres -d sebar_test < backend/test/fixtures/schema.sql
cd backend
echo 'TEST_DATABASE_URL=postgresql://postgres:test@127.0.0.1:55432/sebar_test' > .env.test
npm test
```

## Demo walkthrough

1. Log in as `pemain1@sebar.test`, open the **Wallet**, top up (sandbox).
2. Pick an open slot in **Create room** → the split bill per person is computed from price ÷ quota.
3. Join the same lobby from 2–3 other player accounts → each join **locks a HOLD** on the wallet
   (available balance drops, balance itself untouched).
4. The join that fills the quota triggers **one database transaction**: all holds are captured, the
   booking is created, the slot is marked `BOOKED`, every member gets a ticket.
5. Log in as `venue@sebar.test` → the confirmed booking shows up in the **Schedule**.
6. Robustness, live: joining with too little balance → `INSUFFICIENT_AVAILABLE_BALANCE`; joining
   twice → rejected; a lobby that passes its deadline (slot start − 6 h) **expires and releases
   every hold**; the venue admin cannot touch another admin's courts.

## Money rules (short version)

- Price per person = `CEIL(total / quota)` — surplus from rounding goes to the venue, platform fee 5%.
- Join = wallet hold; last join atomically converts all holds into the booking + venue payout.
- Leave: always a 100% refund, only before the deadline, and final (no rejoining that lobby).
- Host cancels: everyone refunded, host loses 15 reliability points. Max 3 open lobbies per host.
- Quota not filled by the deadline: lobby expires, all holds released automatically (job every 60 s).

## Troubleshooting

- **Backend refuses to start** with a TLS/CA error: it only skips the CA certificate for localhost
  databases — keep `DATABASE_URL` on `127.0.0.1`/`localhost`, or configure `DATABASE_SSL_CA`
  (see [backend/README.md](backend/README.md)).
- **Port 5432 already in use**: you have another Postgres running — stop it or map
  `-p 5433:5432` and update `DATABASE_URL`.
- **Physical phone can't reach the API**: PC and phone must share the same Wi-Fi, `SEBAR_API_URL`
  must use the PC's LAN IP (not `localhost`), and the Windows firewall must allow inbound port 3000.

## AI usage

Disclosed per the exam rules (Section 7). This project was built with AI assistance:

- **ZCode (GLM, IDE agent)** — pair-programming while building the repo: scaffolding Express modules
  and PL/pgSQL functions, writing and fixing Flutter widget/unit tests, debugging (RenderFlex
  overflows, the auth session-refresh guard), and drafting documentation including this README.
- **Conversational LLMs (ChatGPT / Claude)** — second opinions on PostgreSQL features (exclusion
  constraints, query plans for the index evidence) and reviews of error-handling code.

Everything AI-generated was reviewed, tested and run by the team; every member can explain the parts
they committed, and the commit history shows who built what. Libraries and templates are credited in
the SDD.

<!-- TEAM: before submitting, adjust the tool list above to what you actually used. -->

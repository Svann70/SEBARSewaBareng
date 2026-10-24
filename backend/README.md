# SEBAR API (v1)

Node.js 22 + Express 5, plain JavaScript (ESM). Database: Supabase Postgres via `pg` (raw SQL).
Sudah dihubungkan ke `mobile/` (klien HTTP `mobile/lib/data/api.dart`, alamat
lewat `--dart-define=SEBAR_API_URL`, default `http://10.0.2.2:3000` di
emulator Android / `http://localhost:3000` di web-desktop).

Aturan uang dan kuota dijalankan **di database Supabase** (trigger + function PL/pgSQL, SDD §4.6).
Backend ini lapisan tipis: validasi input, cek kepemilikan, kunci baris, lalu memicu trigger/function.

| Aksi API | Yang dilakukan DB |
|---|---|
| join lobby = `INSERT lobby_members` | `trg_member_hold`: cek skor/deadline, `wallet_hold`, `confirm_lobby()` saat kuota penuh |
| keluar = `UPDATE lobby_members SET status='CANCELLED'` | `trg_member_cancel`: release 100% (≥ 6 jam) |
| host batal = `cancel_lobby_by_host()` | release semua, notifikasi, skor host −15 |
| job tiap 60 dtk = `expire_stale_lobbies()` | lobby lewat deadline → `EXPIRED`, hold dilepas |
| top up | ditulis backend (tidak ada function DB) |

Error `RAISE EXCEPTION 'SEBAR::<KODE>'` dari DB dipetakan ke HTTP di `src/middleware/error.js`.

## Setup

Seluruh skema ada di migrasi Drizzle `drizzle/` dan dijalankan dengan `npm run db:migrate` (tercatat
di `drizzle.__drizzle_migrations`, yang sudah jalan dilewati). `0000_baseline` = skema dasar (enum,
tabel, function/trigger aturan uang, view, RLS); semua migrasi idempoten, jadi aman juga untuk
Supabase yang skemanya sudah ada. Skema untuk query: `db/schema/` (satu file per tabel, enum di `enums.js`).

```bash
cd backend
npm install
cp .env.example .env      # isi DATABASE_URL, DATABASE_SSL_CA, JWT_SECRET
npm run db:migrate        # terapkan migrasi drizzle/ yang belum jalan
npm run dev               # http://localhost:3000/healthz
```

Supabase:
1. **Connect** > salin connection string **Session pooler** (port 5432) ke `DATABASE_URL`. Jangan tambah `?sslmode=`; TLS diatur `src/db/pool.js`.
2. **Database > Settings > SSL Configuration** > download sertifikat, simpan sebagai `backend/supabase-ca.crt`.
   Tanpa CA, server menolak start bila host DB bukan localhost.
3. Pastikan RLS aktif di semua tabel (Data API/anon key tidak boleh akses langsung); backend memakai koneksi owner.

Migrasi (`npm run db:migrate`, aman diulang; file yang dulu dijalankan manual di SQL Editor
juga aman karena semuanya idempoten):
- `0001_refresh_tokens` (tabel `refresh_tokens`). Tanpa ini, register/login gagal.
- `0002_court_price_weekend` (kolom `courts.price_weekend`, harga Sabtu–Minggu).
- `0003_court_setup` (jam buka–tutup, lapangan serbaguna `court_sports`, olahraga Basket/Tenis/Padel,
  kolom `court_slots.released`). Tanpa 0002 + 0003, katalog venue, buat room, dan seed gagal.

### Menambah / mengubah tabel (Drizzle)

`db/schema/` berisi **semua** 16 tabel lengkap dengan index, check, dan foreign key (hasil
`drizzle-kit pull`), satu file per tabel (mis. `court-slots.js`). Isinya harus sama persis dengan database: Drizzle membuat SQL
dari selisih `db/schema/` vs `drizzle/meta`, jadi kalau ada yang dihapus dari `db/schema/`, migrasi
berikutnya akan ikut menghapusnya dari database. Untuk tabel baru cukup tulis beberapa baris:

1. Buat file baru `db/schema/court-photos.js` (contoh: foto lapangan):
   ```js
   import { pgTable, uuid, text, smallint, timestamp } from "drizzle-orm/pg-core";
   import { courts } from "./courts.js";

   export const courtPhotos = pgTable("court_photos", {
   	id: uuid().defaultRandom().primaryKey(),
   	courtId: uuid("court_id").notNull().references(() => courts.id, { onDelete: "cascade" }),
   	url: text().notNull(),
   	sort: smallint().default(0).notNull(),
   	createdAt: timestamp("created_at", { withTimezone: true, mode: 'string' }).defaultNow().notNull(),
   }).enableRLS();
   ```
   lalu tambahkan `export * from "./court-photos.js";` di `db/schema/index.js`.
   Selalu `.enableRLS()`: Data API/anon key Supabase tidak boleh membaca tabel langsung.
2. `npm run db:generate -- --name=court_photos` → file baru `drizzle/0004_court_photos.sql` + `drizzle/meta/`.
3. **Baca SQL-nya.** Harus hanya berisi perubahan yang dimaksud (di contoh: `CREATE TABLE`, `ENABLE ROW
   LEVEL SECURITY`, foreign key). Ada `DROP` yang tidak diminta? Berhenti, cek `db/schema/`.
4. `npm run db:migrate` ke database lokal, lalu `npm test` (tes juga menjalankan migrasi).
5. Commit `db/schema/` + `drizzle/0004_*.sql` + `drizzle/meta/` dalam satu PR.
6. Setelah PR masuk `main`: `npm run db:migrate` dengan `.env` Supabase.

Mengubah kolom sama caranya: ubah definisinya di `db/schema/`, lalu langkah 2–6. Trigger, function, view,
atau constraint khusus (mis. `EXCLUDE`) tidak ditulis di `db/schema/`: `npx drizzle-kit generate --custom
--name=<nama>` lalu tulis SQL-nya sendiri di file yang dibuat (buat idempoten: `IF NOT EXISTS`,
`OR REPLACE`). **Jangan pakai `drizzle-kit push`**: Drizzle tidak mengenal trigger, function, `EXCLUDE`
anti tumpang tindih, dan RLS di database ini, jadi `push` bisa menghapusnya.

Setup lapangan sekali di awal: semua jam di dalam jam buka bisa disewa tanpa pemilik membuka slot.
Room selalu memakai tarif lapangan (weekday/weekend × durasi). Slot `OPEN` tanpa room aktif hanya
penanda jam kosong: saat jamnya dipesan, slot itu dihapus (atau `released` bila masih dirujuk room
lama yang batal/kedaluwarsa). Pemilik menutup jam lewat `POST /venue/slots` dengan `status: BLOCKED`.

Flag `.env`:
- `AUTH_RATE_LIMIT` (20/menit/IP untuk register/login, 5× itu untuk refresh/logout) dan `LOGIN_RATE_LIMIT`
  (10 login **gagal**/15 menit per email per IP) → 429 `RATE_LIMITED`. Disimpan di memori proses (cukup untuk
  satu instance). Di belakang proxy, set `TRUST_PROXY` = jumlah proxy di depan (mis. `1`). App jangan logout saat 429.
- `ALLOW_SANDBOX_TOPUP=1`: aktifkan top up tanpa payment gateway (default mati; hanya untuk dev/demo).
- `npm run seed` (data demo) hanya jalan ke DB lokal, kecuali `ALLOW_SEED=1` dan `SEED_PASSWORD` diisi.

## Struktur

```
src/
├── index.js               # start server, job kedaluwarsa lobby, shutdown
├── app.js                 # express app: request id, json, routes, error handler
├── config/env.js          # baca & validasi env
├── db/pool.js             # pg Pool, query(), tx()
├── lib/                   # errors, jwt, password (scrypt), sql helper
├── middleware/            # auth (requireAuth/requireRole), error, request-id
└── modules/
    ├── routes.js          # peta semua grup endpoint + guard-nya
    ├── auth/              # /auth
    ├── users/             # /me
    ├── wallet/            # /me/wallet
    ├── bookings/          # /me/bookings
    ├── venues/            # /venues (katalog pemain)
    ├── venue-admin/       # /venue (khusus VENUE_ADMIN)
    └── lobbies/           # /lobbies (+ membership.service.js: hold/capture/release)
```

Tiap modul: `*.routes.js` (path → handler), `*.controller.js` (validasi input, bentuk respons),
`*.service.js` (SQL; aturan uang ada di DB), `*.schema.js` (skema zod).

## Tes

Tes integrasi butuh Postgres sekali pakai, **bukan** Supabase. Database boleh kosong: tes menjalankan
migrasi `drizzle/` sendiri sebelum mulai.

```bash
docker run -d --name sebar-test-pg -e POSTGRES_PASSWORD=test -e POSTGRES_DB=sebar_test -p 127.0.0.1:55432:5432 postgres:17-alpine
echo 'TEST_DATABASE_URL=postgresql://postgres:test@127.0.0.1:55432/sebar_test' > .env.test
npm test
```

## Lingkup v1

Ada: auth (register pemain/venue, login dengan cek peran, refresh token berotasi, logout), dompet (top up sandbox, hold, ledger), katalog venue/slot, jadwal slot
untuk venue admin, lobby (buat, cari, detail, join, keluar, batal host), auto-booking saat kuota penuh,
job kedaluwarsa lobby tiap 60 detik. Maksimal 3 lobby `OPEN` per host.

Belum (v2, lihat SDD): endpoint QR check-in (baris `checkins` sudah dibuat DB), batal setelah booking
(penalti 50%), no-show, analytics venue, notifikasi, rate limit selain `/auth`, pencairan venue, verifikasi email.

## API

Semua kecuali `/auth/*` dan `/healthz` butuh `Authorization: Bearer <token>`.
Uang = integer rupiah. Tanggal = ISO 8601; filter `date` = tanggal WIB (`YYYY-MM-DD`).

| Method | Path | Peran | Body / Query | Sukses | Error utama |
|---|---|---|---|---|---|
| GET | `/healthz` | - | - | 200 | |
| POST | `/auth/register` | - | email, password (≥8), fullName, phone?, role? (`PLAYER`/`VENUE_ADMIN`), venue? (wajib untuk `VENUE_ADMIN`: name, address, city, description?) | 201 token + `user` | 409, 422 |
| POST | `/auth/login` | - | email, password, role? (tab yang dipilih di app) | 200 token + `user` | 401, 403 `WRONG_ACCOUNT_TYPE` |
| POST | `/auth/refresh` | - | refreshToken | 200 token baru (refresh token lama tidak berlaku lagi) | 401 |
| POST | `/auth/logout` | - | refreshToken | 204 | |
| GET | `/me` | semua | - | 200 profil + skor | 401 |
| PATCH | `/me` | semua | fullName?, phone? (null = hapus; minimal satu field) | 200 profil baru | 401, 409 nomor telepon dipakai, 422 |
| POST | `/me/password` | semua | currentPassword, newPassword (≥8, ≠ lama) | 204 (semua refresh token dicabut, semua perangkat wajib login ulang) | 401 password saat ini salah, 422 |
| GET | `/me/wallet` | semua | - | 200 `{balance, held, available}` | |
| POST | `/me/wallet/topup` | semua | amount (10.000–10.000.000), header `Idempotency-Key` | 201 entri ledger (200 bila key diulang) | 422, 422 `IDEMPOTENCY_KEY_REUSED`, 403 bila sandbox mati |
| GET | `/me/wallet/ledger` | semua | page | 200 `{items, page}` | |
| GET | `/me/bookings` | semua | - | 200 `{items}` | |
| GET | `/venues` | semua | city?, sport? | 200 `{items}` + courts | |
| GET | `/venues/:id/slots` | semua | date | 200 `{items}` | 422 |
| GET | `/venues/:id/availability` | semua | date | 200 `{date, weekend, courts[]}`; tiap court + `rate` (harga/jam hari itu) + `hours[] {hour, start, status}` dengan status `FREE`/`TAKEN`/`CLOSED`/`PAST` | 422 |
| GET | `/lobbies` | semua | city?, sport?, date?, minScore?, page? | 200 `{items, page}` | |
| POST | `/lobbies` | PLAYER | title, quota (2–30), minReliability?, **dan** slotId **atau** courtId + startAt (awal jam) + hours (1–3) + sport? | 201 lobby (host ikut + hold). Mode courtId: slot dibuat otomatis, harga = tarif weekday/weekend × hours | 409 jam terisi/ditutup (`SLOT_NOT_OPEN`) / >3 lobby aktif, 409 saldo, 422 di luar jam buka / kuota > kapasitas olahraga / olahraga tidak ada di lapangan |
| GET | `/lobbies/:id` | semua | - | 200 lobby + members | 404 |
| POST | `/lobbies/:id/join` | PLAYER | - | 201 `{member, booking}` (200 bila sudah join; `booking` terisi bila lobby penuh) | 409 `LOBBY_FULL`, 409 `INSUFFICIENT_AVAILABLE_BALANCE`, 409 `ALREADY_JOINED` (pernah keluar), 403 `SCORE_TOO_LOW`, 410 `DEADLINE_PASSED` |
| DELETE | `/lobbies/:id/members/me` | semua | - | 200 `{released}` | 409 sudah confirm / host, 410 |
| DELETE | `/lobbies/:id` | host | - | 200 `{refundedMembers}` | 403, 409, 410 lewat deadline |
| GET | `/venue/venues` | VENUE_ADMIN | - | 200 venue + courts milik sendiri | 403 |
| POST | `/venue/venues` | VENUE_ADMIN | name (3–120), address (5–300), city (2–60), description? | 201 venue (untuk akun yang belum punya venue) | 403, 422 |
| PATCH | `/venue/venues/:id` | VENUE_ADMIN | name?, address?, city?, description? (minimal satu) | 200 venue | 404 bukan milik, 422 |
| POST | `/venue/courts` | VENUE_ADMIN | venueId, name, sports `[{sport, capacity}]` (atau sport + capacity), pricePerHour (weekday), priceWeekend?, openTime? (`HH:00`, default 06:00), closeTime? (`HH:00`, ≤ 24:00, default 22:00). sport: `BADMINTON`/`FUTSAL`/`VOLLEY`/`MINISOCCER`/`BASKETBALL`/`TENNIS`/`PADEL` | 201 court | 404 venue bukan milik, 409 nama dobel, 422 |
| PATCH | `/venue/courts/:id` | VENUE_ADMIN | name?, sports? (ganti semua), pricePerHour?, priceWeekend?, capacity?, openTime?, closeTime?, status? (`ACTIVE`/`MAINTENANCE`) | 200 court | 404 bukan milik, 422 jam tutup ≤ jam buka |
| GET | `/venue/slots` | VENUE_ADMIN | date, venueId? | 200 `{items}` | 403 |
| POST | `/venue/slots` | VENUE_ADMIN | courtId, startAt, endAt, price, status? (`OPEN`/`BLOCKED`; `BLOCKED` = tutup jam itu) | 201 slot | 409 bentrok, 404 bukan milik |
| PATCH | `/venue/slots/:id` | VENUE_ADMIN | status? (`OPEN`/`BLOCKED`), price? | 200 slot | 409 sudah ada lobby/booking |

Rencana perubahan DB + endpoint untuk desain baru ada di `DESIGN_CHANGES.md`.
Khusus alur **Buat room** (wizard 3 langkah) ada di `CREATE_ROOM_CHANGES.md`.

Respons token (register, login, refresh):

```json
{ "accessToken": "eyJ…", "accessExpiresIn": "15m", "refreshToken": "…", "refreshExpiresAt": "2026-11-20T…", "user": { "id": "…", "role": "PLAYER", "…": "…" } }
```

- `accessToken` (JWT, 15 menit) dikirim di header `Authorization: Bearer`.
- `refreshToken` (acak, 30 hari) disimpan di secure storage. Saat 401, panggil `/auth/refresh` **sekali**
  (jangan paralel): tiap refresh token hanya bisa dipakai sekali. Memakai token lama lagi dianggap
  pencurian (kecuali dalam 10 detik setelah rotasi = dua refresh paralel), dan semua sesi turunan login itu
  dicabut, jadi user harus login ulang. Sesi berlaku maksimal 30 hari sejak login (rotasi tidak memperpanjang).
- `user` hanya ada di register/login.

Format error (SDD §9.3):

```json
{ "error": { "code": "LOBBY_FULL", "message": "Lobby sudah penuh.", "requestId": "req_…" } }
```

## Aturan uang (ringkas)

- `pricePerPerson = CEIL(priceTotal / quota)` (generated column).
- Join = hold (`held_balance` naik, `balance` tetap). Saldo tersedia = `balance - held`.
- Peserta terakhir join → satu transaksi di DB: capture semua hold, booking, payout venue `PENDING`, 1 check-in per peserta, slot `BOOKED`, lobby `CONFIRMED`.
- Fee platform 5% dari harga lapangan; sisa pembulatan (`rounding_surplus`) masuk ke venue.
- `join_deadline = start - 6 jam`. Lewat deadline dan belum penuh → `EXPIRED`, semua hold dilepas.
- Keluar hanya sebelum deadline (selalu refund 100%) dan bersifat final: tidak bisa join lagi ke lobby yang sama.
- Host batal → semua refund, skor host −15. Maksimal 3 lobby `OPEN` per host.
- Belum di v1: batal setelah booking terkonfirmasi (penalti 50%), no-show, scan QR, analytics.

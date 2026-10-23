# Perubahan DB + Backend untuk Desain "SEBAR Mobile — Hijau"

Sumber acuan: `DesignReference/SEBAR Mobile — Hijau.html` (21 halaman).
Frontend Flutter sudah memakai palet/komponen baru. Dokumen ini hanya
**daftar perubahan database + endpoint** yang masih kurang agar layar desain
berfungsi penuh. Belum ada kode backend yang diubah.

Status sekarang: auth, venue (multi-venue, court, slot), lobby (create/join/leave),
booking, wallet topup sandbox, ledger, payout view sudah ada.

---

## 1. Database — tabel & kolom baru

### 1.1 `venues`
| Perubahan | Alasan (layar desain) |
|---|---|
| `lat numeric(9,6)`, `lng numeric(9,6)` | tombol **Maps** di Detail room |
| `open_hour smallint`, `close_hour smallint` (0–23) | Venue · Jadwal, Beranda |
| `photos text[]` **atau** tabel `venue_photos` | foto header Venue Beranda |

Tabel alternatif (lebih rapi, mendukung urutan + hapus):

```sql
CREATE TABLE venue_photos (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  venue_id uuid NOT NULL REFERENCES venues(id) ON DELETE CASCADE,
  url text NOT NULL,
  sort smallint NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
```

### 1.2 `courts`
| Perubahan | Alasan |
|---|---|
| `weekend_price_per_hour numeric(12,2)` (nullable, default = `price_per_hour`) | Venue · Lapangan & foto: **Weekday /jam** dan **Weekend /jam** |
| tabel `court_photos (id, court_id, url, sort, created_at)` | Venue · Jadwal: tombol **Ganti foto** di header tiap lapangan & sheet detail slot (venue pilih foto bawaan / tempel tautan; foto sama dipakai kartu room pemain). UI memakai **satu foto utama** per court → ambil `sort = 0` sebagai cover, atau tambah kolom `courts.cover_photo_url text` |
| `courts.capacity` sudah ada (2–30) | Dipakai "8 orang" |

`price_per_hour` tetap harga weekday. Saat `POST /venue/slots`, server memilih
weekend rate bila `start_at` jatuh Sabtu/Minggu (zona waktu venue, default
`Asia/Jakarta`) dan menyimpannya sebagai snapshot `court_slots.price` — room
berjalan tetap memakai harga lama sesuai teks desain.

### 1.3 `lobbies`
| Kolom baru | Tipe | Alasan |
|---|---|---|
| `access` | enum `lobby_access` (`OPEN`,`LINK`,`PASSWORD`), default `OPEN` | label **PUBLIK / PAKAI SANDI** di kartu room |
| `join_code` | `varchar(8)` unique, null bila `OPEN` | join "pakai sandi" (`SBR-7K2Q`) |
| `cancelled_at` | `timestamptz` | audit pembatalan host |

```sql
CREATE TYPE lobby_access AS ENUM ('OPEN','LINK','PASSWORD');
ALTER TABLE lobbies
  ADD COLUMN access lobby_access NOT NULL DEFAULT 'OPEN',
  ADD COLUMN join_code varchar(8) UNIQUE,
  ADD COLUMN cancelled_at timestamptz;
```

Saat ini `access`/`secret` hanya ada di model Flutter (lokal) — harus pindah ke server.

### 1.4 `bookings` + `checkins`
| Perubahan | Alasan |
|---|---|
| `bookings.checkin_code varchar(12) UNIQUE NOT NULL` | kode besar di Tiket QR (`SBR-7K2Q`) |
| `bookings.checked_in_at timestamptz` (opsional, cermin `checkins.scanned_at`) | status "Selesai" di tab Tiket |

`checkins.token_hash` tetap dipakai untuk token QR; `checkin_code` untuk input manual petugas.
Tambahkan unique index `(booking_id, user_id)` di `checkins` bila belum ada.

### 1.5 Pembayaran top up (desain Dompet + Top up)
Sekarang `POST /me/wallet/topup` hanya jalan bila `ALLOW_SANDBOX_TOPUP=1` dan langsung menambah saldo.
Untuk QRIS / transfer bank perlu:

```sql
CREATE TYPE topup_status AS ENUM ('PENDING','PAID','FAILED','EXPIRED');

CREATE TABLE wallet_topups (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid NOT NULL REFERENCES wallets(id),
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  method text NOT NULL CHECK (method IN ('QRIS','BANK_TRANSFER')),
  status topup_status NOT NULL DEFAULT 'PENDING',
  external_ref text UNIQUE,
  idempotency_key text UNIQUE NOT NULL,
  paid_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE wallet_withdrawals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  wallet_id uuid NOT NULL REFERENCES wallets(id),
  amount numeric(12,2) NOT NULL CHECK (amount > 0),
  bank_account text NOT NULL,
  status topup_status NOT NULL DEFAULT 'PENDING',
  created_at timestamptz NOT NULL DEFAULT now()
);
```

Ledger `TOPUP` hanya ditulis saat status berubah `PENDING → PAID` (idempoten lewat `external_ref`).

### 1.6 Pencairan venue
`venue_payouts` + `payout_status` sudah ada. Tambahkan:

```sql
ALTER TABLE venue_payouts
  ADD COLUMN requested_at timestamptz,
  ADD COLUMN reference text;   -- bukti transfer
```

`status` perlu nilai `REQUESTED` (atau pakai `PENDING` + `requested_at`).

### 1.7 View analytics
`vw_venue_monthly_revenue` sudah ada. Tambah satu view untuk okupansi:

```sql
CREATE VIEW vw_venue_occupancy AS
SELECT c.venue_id,
       date_trunc('day', s.start_at) AS hari,
       count(*) AS slot_total,
       count(*) FILTER (WHERE s.status <> 'OPEN') AS slot_terisi,
       round(100.0 * count(*) FILTER (WHERE s.status <> 'OPEN') / count(*), 1) AS okupansi_pct
FROM court_slots s
JOIN courts c ON c.id = s.court_id
GROUP BY 1, 2;
```

---

## 2. Endpoint yang perlu ditambah / diubah

### 2.1 Venue (role `VENUE_ADMIN`)
| Method + path | Body / query | Guna |
|---|---|---|
| `PATCH /venue/venues/:id` | `name, address, city, description, openHour, closeHour, lat, lng` | edit profil venue |
| `POST /venue/venues/:id/photos` | `{ url }` | tambah foto venue |
| `DELETE /venue/venues/:id/photos/:photoId` | — | hapus foto |
| `POST /venue/courts/:id/photos` | `{ url }` | tombol **Ganti foto** lapangan (header tab Jadwal & detail slot) |
| `DELETE /venue/courts/:id/photos/:photoId` | — | hapus foto lapangan |
| `PATCH /venue/courts/:id` (tambah field) | `weekendPricePerHour` | form **Weekday / Weekend** di Lapangan & foto |
| `DELETE /venue/slots/:id` | — | hapus slot yang belum punya lobby (`409` bila sudah dipakai) |
| `GET /venue/analytics?range=7d\|month\|3m` | — | `{ revenue, bookings, occupancyPct, perCourt[], peakHours[], payoutReady }` |
| `GET /venue/payouts` | — | daftar payout + saldo siap cair |
| `POST /venue/payouts/withdraw` | `{ amount }` | tombol **Cairkan** |
| `POST /venue/checkin` | `{ code }` | Venue · Scan: validasi `checkins`, balas `{ booking, status }`; `409` bila sudah discan |

Catatan:
- `POST /venue/checkin` wajib transaksional: `SELECT ... FOR UPDATE`, ubah `checkins.status = 'USED'`, isi `scanned_by`, `scanned_at`; tolak token kedaluwarsa (`token_expires_at`).
- Foto saat ini di frontend masih URL `picsum`. Kalau mau upload asli, endpoint terima `multipart/form-data` dan simpan ke object storage; `url` yang disimpan di DB.
- `GET /venue/venues` dan `GET /venues` harus ikut mengirim `photos`, `openHour`, `closeHour`, `lat`, `lng`, plus `courts[]` (id, name, sport, pricePerHour, capacity, photos).

### 2.2 Pemain
| Method + path | Body / query | Guna |
|---|---|---|
| `GET /me/tickets?status=ready\|waiting\|done` | — | tab **Siap dipakai / Menunggu / Selesai**; `waiting` = lobby belum penuh |
| `GET /me/wallet/topups/:id` | — | status pembayaran setelah QRIS/VA dibuat |
| `POST /me/wallet/topup` (ubah) | `{ amount, method: 'QRIS'\|'BANK_TRANSFER', idempotencyKey }` | balas `{ topupId, status, qrString / vaNumber, expiresAt }` |
| `POST /me/wallet/withdraw` | `{ amount, bankAccount }` | tombol **Tarik dana** |
| `POST /lobbies` (ubah) | tambah `access`, `joinCode` | buat room 3 · atur room |
| `POST /lobbies/join` | `{ code }` | join via sandi |
| `GET /lobbies/:id` | — | kirim `access`, `joinCode`, refund policy, `venue.address/lat/lng/photos` |

### 2.3 Pembayaran (webhook, publik)
| Method + path | Guna |
|---|---|
| `POST /payments/webhook` | verifikasi signature gateway, `UPDATE wallet_topups`, tulis ledger `TOPUP` sekali |
| Cron / job | tandai `EXPIRED` setelah `expires_at`; no-show: `lobbies` lewat `join_deadline` → refund/denda sesuai aturan 6 jam |

Aturan uang yang harus tetap di server (desain menampilkannya):
- batal ≥ 6 jam: refund 100%;
- batal < 6 jam: denda 15%, refund 85%;
- tidak datang: hangus 100%.

Saat ini aturan ini ada di `mobile/lib/core/money.dart` (pratinjau UI) — server harus jadi sumber final dan mengembalikan `refundAmount`/`penaltyAmount` di DTO pembatalan.

---

## 3. Perubahan DTO (dampak frontend)

- Semua nominal uang: kirim **number JSON**, bukan string `"100000.00"`. Frontend sudah tahan string (`_asInt`), tapi angka lebih aman.
- `Lobby`: `access`, `joinCode`, `venue: {address, lat, lng, photos[]}`.
- `Booking`: `checkinCode`, `checkedInAt`, `status`.
- `Court`: `photos[]`.
- `Wallet`: `available`, `balance`, `held`, `pendingTopup`.
- `Analytics`: `revenue`, `bookings`, `occupancyPct`, `payoutReady`, `perCourt[]`, `peakHours[]`.

---

## 4. Urutan kerja yang disarankan

1. Migrasi kolom `lobbies.access`, `join_code`, `bookings.checkin_code`, foto venue/court.
2. Endpoint foto + `PATCH /venue/venues/:id` + `DELETE /venue/slots/:id`.
3. `GET /venue/analytics` + `GET /venue/payouts` + `POST /venue/payouts/withdraw`.
4. `POST /venue/checkin` (scan QR/manual).
5. Topup gateway + webhook + withdrawal.
6. `GET /me/tickets` dengan filter status.
7. Job no-show/expired.

Tanpa langkah 1–4, layar Venue · Scan, Analytics, dan Lapangan & foto hanya bisa tampil sebagai data contoh.

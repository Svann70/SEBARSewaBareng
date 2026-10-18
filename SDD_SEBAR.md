# Software Design Description (SDD)
## SEBAR — Sewa Bareng

| Field | Value |
|---|---|
| Nama Produk | SEBAR (Sewa Bareng) |
| Versi Dokumen | 1.0 |
| Tanggal | 18 Oktober 2026 |
| Status | Baseline untuk Final Exam IK301 + IK102 |
| Platform | Mobile app (Flutter, Android + iOS) + REST API (Node.js/TypeScript) |
| **Database** | **PostgreSQL 16** — satu-satunya database yang dipakai (tidak ada MongoDB/MySQL) |
| Referensi | `IK301-IK102_Final_Exam_Brief_Startup_Pitch.docx`, `pitch/SEBAR_Pitch_Deck.pptx` |
| Pemilik Dokumen | Tim SEBAR (5 anggota) |

---

## 1. Pendahuluan

### 1.1 Tujuan
Dokumen ini mendeskripsikan desain perangkat lunak SEBAR: arsitektur, model data, desain komponen, desain antarmuka, aturan bisnis, keamanan, dan rencana pengujian. Dokumen ini menjadi acuan tunggal untuk implementasi, demo, dan tanya jawab teknis pada ujian akhir.

### 1.2 Ruang Lingkup
SEBAR adalah aplikasi mobile untuk **patungan sewa lapangan olahraga** (badminton, futsal, voli, minisoccer). Ruang lingkup versi MVP mencakup enam fitur:

1. Match Lobby & Auto-Split Bill
2. Upfront Wallet Hold
3. Instant Auto-Booking (100% kuota)
4. Anti-Ghosting & Penalti Otomatis
5. Skor Reputasi & QR Check-in
6. Dashboard Venue & Analytics

Di luar ruang lingkup MVP: integrasi payment gateway produksi (diganti top-up sandbox), chat real-time, turnamen, multi-venue chain, dan aplikasi web.

### 1.3 Definisi & Akronim
| Istilah | Arti |
|---|---|
| Lobby | Room patungan untuk satu slot lapangan pada satu jam tertentu |
| Slot | Satu unit jadwal lapangan (court + tanggal + jam) yang dijual |
| Hold | Penguncian saldo tanpa pemotongan; dana tidak bisa dipakai transaksi lain |
| Capture | Pemotongan saldo hasil hold saat kuota penuh |
| Release | Pelepasan hold tanpa pemotongan |
| Ghosting | Peserta yang mendaftar lalu tidak datang / menghilang |
| Reliability Score | Skor keandalan 0–100 per pemain |
| GOR | Gedung Olahraga; dalam dokumen ini = venue |
| ACID | Atomicity, Consistency, Isolation, Durability |

### 1.4 Referensi
- Final Exam Brief IK301 + IK102 (9 Oktober 2026)
- Pitch Deck SEBAR (17 slide, `pitch/pitch_deck.js`)
- ERD: `docs/erd.png` (dihasilkan dari `server/src/db/migrations`)
- Seed & dump: `server/src/db/seeds/`, `db/dump/sebar_demo.sql`

### 1.5 Daftar Gambar
| No | Gambar | Letak |
|---|---|---|
| 1 | Arsitektur sistem SEBAR | §2.1 |
| 2 | ERD SEBAR — 14 tabel | §4.2 |
| 3 | Target kinerja query dan peran index | §4.7 |
| 4 | Peta fitur ke modul dan tabel | §5.1 |
| 5 | Alur join sampai booking otomatis | §5.2 |
| 6 | Siklus dana: hold, capture, release | §5.4 |
| 7 | State machine lobby | §5.5 |
| 8 | Kebijakan anti-ghosting menurut waktu pembatalan | §5.6 |
| 9 | Cakupan bukti terhadap minimum rubrik | §13 |
| 10 | Rencana demo 7 menit | §14 |

Sumber gambar: `docs/figures/make_figures.py` (matplotlib). Jalankan `python docs/figures/make_figures.py` untuk regenerasi.

---

## 2. Ringkasan Sistem

### 2.1 Konteks
Pemain rekreasi kesulitan mengumpulkan orang dan menagih patungan; pemilik GOR kehilangan pendapatan pada jam sepi dan dirugikan oleh no-show. SEBAR menyatukan tiga hal yang saat ini terpisah: pencarian pemain, penagihan patungan, dan jaminan kehadiran.

![Gambar 1. Arsitektur sistem SEBAR](figures/fig01-architecture.png)

*Gambar 1 — Arsitektur tiga lapis: Flutter app, REST API, PostgreSQL. Semua aturan uang dan kuota berada di dua lapis kanan.*

### 2.2 Aktor
| Aktor | Deskripsi | Hak Utama |
|---|---|---|
| Player | Pemain rekreasi 18–35 tahun | Cari/buat lobby, join, wallet, QR check-in |
| Host | Pemain yang membuat lobby | Kelola lobby, batalkan lobby (dengan konsekuensi), lihat peserta |
| Venue Admin | Pengelola GOR | Kelola lapangan & slot, scan QR, lihat analytics |
| Super Admin | Operator SEBAR | Kelola venue, sengketa, monitoring |

### 2.3 Tujuan Desain (Design Goals)
| Prioritas | Goal | Ukuran |
|---|---|---|
| G1 | Tidak ada double-booking | 0 kasus pada uji 60 join paralel |
| G2 | Uang tidak pernah "melayang" | Setiap perubahan saldo punya baris ledger; sum(ledger) = balance |
| G3 | Komitmen nyata sebelum main | 100% peserta berstatus HOLDING/CONFIRMED punya dana terkunci |
| G4 | Alur join < 3 tap | Join dari lobby detail selesai ≤ 3 interaksi |
| G5 | Bukti teknis dapat didemokan | Semua item rubrik IK301/IK102 punya artefak |

### 2.4 Batasan (Constraints)
- Satu codebase Flutter untuk Android & iOS; APK wajib installable tanpa bantuan tim.
- Database relasional wajib mendukung transaksi multi-step, trigger, function, index, dan query analitik (rubrik IK301).
- Waktu pengerjaan 2 minggu; tim 5 orang; tidak ada budget infrastruktur berbayar.
- Demo harus berjalan tanpa internet stabil: gunakan data seed lokal + server yang sudah di-deploy.

---

## 3. Arsitektur Sistem

### 3.1 Gaya Arsitektur
**Client–server berlapis (layered) + clean architecture pada klien.**

| Lapisan | Klien (Flutter) | Server (Node.js) |
|---|---|---|
| Presentation | Widget, Screen, Provider (Riverpod) | Route + Controller (HTTP) |
| Application/Domain | Usecase, Entity, Repository interface | Service (business rules) |
| Data | Repository impl, Remote Datasource (Dio), DTO | Repository + raw SQL / pg |
| Infrastructure | Secure storage, QR, kamera, connectivity | PostgreSQL, JWT, logger, scheduler |

Prinsip: **business rule yang menyangkut uang dan kuota berada di server/database**, bukan di klien. Klien hanya menampilkan hasil dan menangani UX.

### 3.2 Keputusan Arsitektur (ADR)
| ID | Keputusan | Alternatif | Alasan |
|---|---|---|---|
| ADR-01 | Flutter untuk mobile | React Native, native | Satu codebase, deliverable APK, `flutter test` satu command, widget test untuk bukti IK102 |
| ADR-02 | PostgreSQL 16 | MySQL, MongoDB | Butuh transaksi ACID multi-baris, `SELECT … FOR UPDATE`, constraint, trigger, function, window function, `EXPLAIN ANALYZE` |
| ADR-03 | REST + JWT | GraphQL, Firebase | Permukaan kecil, mudah diuji, mudah dijelaskan di Q&A, tanpa vendor lock-in |
| ADR-04 | Hold dihitung di DB (trigger + function) | Logika hold di service | Menutup race condition: dua join bersamaan tidak bisa menembus saldo |
| ADR-05 | Uang disimpan sebagai `NUMERIC(14,2)` + ledger append-only | `FLOAT`, satu kolom saldo | Presisi uang; ledger = audit trail; saldo dapat direkonsiliasi |
| ADR-06 | Riverpod + go_router | BLoC, Provider | Sedikit boilerplate, testable, mendukung async state (loading/error) |
| ADR-07 | Idempotency key pada endpoint uang | Tanpa idempotency | Retry jaringan tidak menggandakan hold/capture |
| ADR-08 | QR token HMAC bertanda tangan, disimpan sebagai hash | QR berisi ID polos | Token tidak bisa dipalsukan; hash mencegah kebocoran dari dump |

### 3.3 Deployment (Demo)
```
[HP Android]  ──HTTPS──►  [API: api.sebar.app (VPS/ Railway)]
                                  │
                          [PostgreSQL 16 terkelola]
                                  │
                    [Backup: dump SQL + video demo 2–3 menit]
```
APK di-build `flutter build apk --release --dart-define=API_BASE_URL=…`, ditandatangani, dan disertakan dalam paket LMS.

---

## 4. Desain Data

> **Database yang dipakai: PostgreSQL 16.** Seluruh data relasional (identitas, venue, lobby, wallet, ledger, booking, check-in) disimpan di satu instance PostgreSQL. Tidak ada database lain di sistem ini.

### 4.1 Mengapa PostgreSQL
SEBAR memilih PostgreSQL 16 karena inti produknya adalah **uang dan kuota yang tidak boleh salah**, dan PostgreSQL memberi empat hal yang sulit ditiru database lain dalam satu tempat. Pertama, transaksi ACID penuh dengan `SELECT … FOR UPDATE` dan isolasi `READ COMMITTED`, sehingga dua pemain yang menekan "Join" pada milidetik yang sama tidak bisa menembus kuota atau saldo — ini tidak dapat dijamin oleh database dokumen yang hanya konsisten per-dokumen. Kedua, constraint deklaratif (`UNIQUE`, `CHECK`, foreign key, unique parsial, generated column) memindahkan aturan seperti `balance >= held_balance` dan "satu slot satu lobby aktif" ke level penyimpanan, sehingga bug di application layer tidak dapat merusak data. Ketiga, PL/pgSQL memungkinkan logika multi-langkah (`wallet_hold`, `confirm_lobby`) dan trigger penalti berjalan **di dalam transaksi yang sama** dengan perubahan datanya, bukan sebagai panggilan jaringan terpisah yang bisa putus di tengah jalan. Keempat, PostgreSQL unggul untuk sisi analitik yang dibutuhkan dashboard GOR: join multi-tabel, `GROUP BY`, window function untuk persentase peak hours, index parsial, serta `EXPLAIN (ANALYZE, BUFFERS)` untuk membuktikan index benar-benar dipakai. Tipe `NUMERIC(14,2)` juga menyimpan rupiah tanpa galat pembulatan seperti `FLOAT`, dan `TIMESTAMPTZ` menjaga perbandingan 6 jam tetap benar walau perangkat pengguna berada di zona waktu lain. Alternatif yang dipertimbangkan: MySQL (ACID memadai, tetapi unique parsial dan tipe `CITEXT`/enum handling kurang nyaman), SQLite (tidak cocok untuk akses multi-pengguna bersamaan), dan MongoDB (transaksi multi-dokumen ada, namun constraint dan query analitik relasional jauh lebih lemah untuk kasus uang).

### 4.2 ERD

![Gambar 2. ERD SEBAR — 14 tabel](figures/fig02-erd.png)

*Gambar 2 — ERD 14 tabel. Tanda ● = primary key / unique. Uang selalu `NUMERIC(14,2)`.*

Relasi inti:

| Dari | Ke | Kardinalitas | Arti |
|---|---|---|---|
| `users` | `wallets` | 1 : 1 | satu pemain satu dompet |
| `wallets` | `wallet_ledger` | 1 : N | setiap mutasi saldo tercatat |
| `users` | `venues` | 1 : N | pemilik GOR |
| `venues` | `courts` | 1 : N | satu GOR punya banyak lapangan |
| `courts` | `court_slots` | 1 : N | slot jadwal per lapangan |
| `court_slots` | `lobbies` | 1 : 1 | satu slot hanya satu lobby aktif |
| `lobbies` | `lobby_members` | 1 : N | peserta lobby |
| `lobbies` | `bookings` | 1 : 1 | lobby penuh menghasilkan satu booking |
| `bookings` | `checkins` | 1 : N | satu QR per peserta |
| `bookings` | `venue_payouts` | 1 : 1 | pembayaran ke GOR |
| `users` | `reliability_events` | 1 : N | riwayat perubahan skor |

### 4.3 Kamus Data

#### 4.3.1 `users`
| Kolom | Tipe | Constraint | Keterangan |
|---|---|---|---|
| id | UUID | PK, default `gen_random_uuid()` | |
| email | CITEXT | UNIQUE, NOT NULL | Login |
| phone | VARCHAR(20) | UNIQUE | Untuk kontak darurat peserta |
| full_name | VARCHAR(80) | NOT NULL | |
| password_hash | TEXT | NOT NULL | Argon2id |
| role | user_role | NOT NULL DEFAULT 'PLAYER' | `PLAYER`, `VENUE_ADMIN`, `SUPER_ADMIN` |
| reliability_score | NUMERIC(5,2) | NOT NULL DEFAULT 100, CHECK 0–100 | |
| is_active | BOOLEAN | NOT NULL DEFAULT TRUE | |
| created_at / updated_at | TIMESTAMPTZ | NOT NULL DEFAULT now() | |

#### 4.3.2 `wallets`
| Kolom | Tipe | Constraint |
|---|---|---|
| id | UUID | PK |
| user_id | UUID | UNIQUE, FK → users, ON DELETE RESTRICT |
| balance | NUMERIC(14,2) | NOT NULL DEFAULT 0, CHECK ≥ 0 |
| held_balance | NUMERIC(14,2) | NOT NULL DEFAULT 0, CHECK ≥ 0 |
| version | INTEGER | NOT NULL DEFAULT 0 (optimistic lock opsional) |

**Aturan:** `balance >= held_balance` (CHECK). Saldo tersedia = `balance - held_balance`.

#### 4.3.3 `wallet_ledger` (append-only)
| Kolom | Tipe | Constraint |
|---|---|---|
| id | UUID | PK |
| wallet_id | UUID | FK → wallets |
| entry_type | ledger_type | `TOPUP`,`HOLD`,`RELEASE`,`CAPTURE`,`REFUND`,`PAYOUT`,`PENALTY` |
| amount | NUMERIC(14,2) | CHECK > 0 |
| balance_after | NUMERIC(14,2) | Snapshot setelah entri |
| held_after | NUMERIC(14,2) | Snapshot hold setelah entri |
| ref_type / ref_id | TEXT / UUID | Referensi ke lobby/booking |
| idempotency_key | TEXT | UNIQUE (partial, NOT NULL) |
| created_at | TIMESTAMPTZ | DEFAULT now() |

#### 4.3.4 `venues`
`id` PK, `owner_id` FK users, `name` VARCHAR(120) NOT NULL, `address` TEXT NOT NULL, `city` VARCHAR(60) NOT NULL, `description` TEXT, `photo_url` TEXT, `status` venue_status (`ACTIVE`,`INACTIVE`), `created_at`.
Index: `idx_venues_city_status (city, status)`.

#### 4.3.5 `courts`
`id` PK, `venue_id` FK venues ON DELETE CASCADE, `name` VARCHAR(60) NOT NULL, `sport_type` sport_type (`BADMINTON`,`FUTSAL`,`VOLLEY`,`MINISOCCER`), `price_per_hour` NUMERIC(12,2) CHECK > 0, `capacity` SMALLINT CHECK 2–30, `status` court_status (`ACTIVE`,`MAINTENANCE`).
UNIQUE `(venue_id, name)`.

#### 4.3.6 `court_slots`
| Kolom | Tipe | Constraint |
|---|---|---|
| id | UUID | PK |
| court_id | UUID | FK → courts |
| start_at | TIMESTAMPTZ | NOT NULL |
| end_at | TIMESTAMPTZ | NOT NULL, CHECK > start_at |
| price | NUMERIC(12,2) | NOT NULL, CHECK > 0 |
| status | slot_status | `OPEN`,`LOBBY_FULL`,`BOOKED`,`BLOCKED`,`PAST` |
| created_at | TIMESTAMPTZ | |

UNIQUE `(court_id, start_at)` — **mencegah dua slot identik**.
Index parsial: `idx_slots_open (start_at) WHERE status = 'OPEN'`.

#### 4.3.7 `lobbies`
| Kolom | Tipe | Constraint |
|---|---|---|
| id | UUID | PK |
| slot_id | UUID | FK → court_slots, **UNIQUE parsial** `WHERE status IN ('OPEN','FILLED','CONFIRMED')` |
| host_id | UUID | FK → users |
| title | VARCHAR(100) | NOT NULL |
| min_reliability | NUMERIC(5,2) | DEFAULT 0, CHECK 0–100 |
| quota | SMALLINT | NOT NULL, CHECK 2–30 |
| price_total | NUMERIC(12,2) | NOT NULL, = `court_slots.price` saat dibuat |
| price_per_person | NUMERIC(12,2) | **GENERATED ALWAYS AS (CEIL(price_total / quota))** STORED |
| join_deadline | TIMESTAMPTZ | NOT NULL, CHECK `join_deadline <= start_at - interval '6 hours'` |
| status | lobby_status | `OPEN`,`FILLED`,`CONFIRMED`,`CANCELLED`,`EXPIRED`,`FAILED` |
| created_at | TIMESTAMPTZ | |

UNIQUE parsial `(slot_id)` di atas memastikan **satu slot hanya punya satu lobby aktif**.

#### 4.3.8 `lobby_members`
| Kolom | Tipe | Constraint |
|---|---|---|
| id | UUID | PK |
| lobby_id | UUID | FK → lobbies ON DELETE CASCADE |
| user_id | UUID | FK → users |
| role_in_lobby | member_role | `HOST`,`PLAYER` |
| status | member_status | `HOLDING`,`CONFIRMED`,`CANCELLED`,`REFUNDED`,`PENALIZED`,`NO_SHOW` |
| hold_amount | NUMERIC(12,2) | NOT NULL CHECK > 0 |
| hold_ledger_id | UUID | FK → wallet_ledger (jejak hold) |
| joined_at | TIMESTAMPTZ | DEFAULT now() |
| cancelled_at | TIMESTAMPTZ | |
| UNIQUE `(lobby_id, user_id)` | | Tidak bisa join dua kali |

#### 4.3.9 `bookings`
| Kolom | Tipe | Constraint |
|---|---|---|
| id | UUID | PK |
| lobby_id | UUID | **UNIQUE**, FK → lobbies |
| slot_id | UUID | **UNIQUE**, FK → court_slots |
| booking_code | VARCHAR(12) | UNIQUE, NOT NULL |
| gross_amount | NUMERIC(12,2) | NOT NULL |
| platform_fee | NUMERIC(12,2) | NOT NULL (5%) |
| venue_payout | NUMERIC(12,2) | NOT NULL = gross − fee + surplus pembulatan |
| status | booking_status | `CONFIRMED`,`COMPLETED`,`CANCELLED` |
| booked_at | TIMESTAMPTZ | DEFAULT now() |

`UNIQUE(slot_id)` adalah **pertahanan terakhir anti double-booking** di level constraint.

#### 4.3.10 `venue_payouts`
| Kolom | Tipe | Constraint |
|---|---|---|
| id | UUID | PK |
| booking_id | UUID | UNIQUE, FK → bookings |
| venue_id | UUID | FK → venues |
| amount | NUMERIC(12,2) | CHECK > 0 |
| status | payout_status | PENDING, PAID |
| disbursed_at | TIMESTAMPTZ | NULL selama PENDING |
| created_at | TIMESTAMPTZ | DEFAULT now() |

#### 4.3.11 `checkins`
| Kolom | Tipe | Constraint |
|---|---|---|
| id | UUID | PK |
| booking_id | UUID | FK → bookings |
| user_id | UUID | FK → users |
| token_hash | CHAR(64) | NOT NULL, UNIQUE (SHA-256) |
| token_expires_at | TIMESTAMPTZ | NOT NULL |
| status | checkin_status | `PENDING`,`SCANNED`,`EXPIRED`,`NO_SHOW` |
| scanned_by | UUID | FK → users (venue admin) |
| scanned_at | TIMESTAMPTZ | |
| UNIQUE `(booking_id, user_id)` | | Satu tiket per peserta per booking |

#### 4.3.12 `reliability_events`
`id` PK, `user_id` FK, `lobby_id` FK NULL, `delta` NUMERIC(5,2) CHECK delta <> 0, `reason` reliability_reason (`CHECKIN`,`LATE_CANCEL`,`NO_SHOW`,`HOST_CANCEL`,`MANUAL_ADJUST`), `score_after` NUMERIC(5,2), `created_at`.
Index `idx_reliability_user_created (user_id, created_at DESC)`.

#### 4.3.13 `notifications`
`id` PK, `user_id` FK, `type` TEXT, `payload` JSONB, `read_at` TIMESTAMPTZ, `created_at`.

#### 4.3.14 `audit_log`
`id` BIGSERIAL PK, `actor_id` UUID, `action` TEXT, `entity` TEXT, `entity_id` UUID, `before` JSONB, `after` JSONB, `created_at`. Dipakai untuk sengketa & demo "server-side logic".

**Total: 14 tabel** (melebihi minimum 6 tabel rubrik IK301).

### 4.4 Integritas Data
| Aturan | Implementasi |
|---|---|
| Email unik | `UNIQUE(email)` |
| Satu user satu wallet | `UNIQUE(wallets.user_id)` |
| Tidak bisa join dua kali | `UNIQUE(lobby_members.lobby_id, user_id)` |
| Tidak bisa double-booking | `UNIQUE(bookings.slot_id)` + `SELECT … FOR UPDATE` pada slot |
| Saldo tidak negatif | `CHECK (balance >= 0)`, `CHECK (balance >= held_balance)` |
| Uang selalu > 0 | `CHECK (amount > 0)` pada ledger, hold, payout |
| Kuota valid | `CHECK (quota BETWEEN 2 AND 30)` |
| Deadline join logis | `CHECK (join_deadline <= start_at - interval '6 hours')` |
| Slot tidak tumpang tindih | `UNIQUE(court_id, start_at)` + validasi durasi saat pembuatan slot |
| Hold tidak melebihi saldo | Function `wallet_hold()` memakai `FOR UPDATE` + `RAISE EXCEPTION` |
| Skor dalam rentang | `CHECK (reliability_score BETWEEN 0 AND 100)` + clamp di trigger |

### 4.5 Transaksi Multi-Step (bukti ACID)
Operasi **`confirm_lobby(lobby_id)`** — all-or-nothing:

```
BEGIN;
  SELECT * FROM lobbies   WHERE id = $1 FOR UPDATE;
  SELECT * FROM court_slots WHERE id = slot FOR UPDATE;
  -- 1. validasi status OPEN/FILLED, deadline, jumlah member = quota
  -- 2. untuk setiap member HOLDING: kurangi balance & held_balance
  -- 3. insert wallet_ledger CAPTURE per member
  -- 4. insert booking (UNIQUE slot_id)
  -- 5. update court_slots.status = 'BOOKED'
  -- 6. insert venue_payouts
  -- 7. insert checkins + token hash
  -- 8. update lobbies.status = 'CONFIRMED'
  -- 9. insert notifications
COMMIT;
-- jika ada langkah gagal → ROLLBACK penuh, tidak ada saldo terpotong
```
Demo kegagalan terkontrol: paksa `RAISE EXCEPTION` pada langkah 7 → tunjukkan saldo peserta **tidak berubah** dan slot tetap `OPEN`.

### 4.6 Server-Side Logic
| Objek | Tipe | Fungsi |
|---|---|---|
| `confirm_lobby(uuid)` | FUNCTION (PL/pgSQL) | Transaksi auto-booking 9 langkah di atas |
| `wallet_hold(uuid, numeric, text, uuid)` | FUNCTION | Kunci saldo + validasi saldo tersedia |
| `trg_member_hold` | TRIGGER AFTER INSERT ON lobby_members | Panggil `wallet_hold`, isi `hold_ledger_id`, set slot `LOBBY_FULL` bila penuh, panggil `confirm_lobby` bila kuota 100% |
| `trg_member_cancel` | TRIGGER BEFORE UPDATE ON lobby_members | Hitung selisih jam; release penuh (≥6 jam) atau denda 50% + skor −10 (<6 jam) |
| `trg_reliability_clamp` | TRIGGER BEFORE UPDATE ON users | Clamp skor 0–100, catat `reliability_events` |
| `trg_no_show` | TRIGGER AFTER UPDATE ON court_slots (→PAST) | Tandai checkin `NO_SHOW`, sita hold 100%, skor −25 |
| `expire_stale_lobbies()` | FUNCTION + scheduler | Lobby lewat deadline & kuota < 100% → release 100%, status `EXPIRED` |
| `fn_peak_hours(uuid, date, date)` | FUNCTION | Agregasi jam tersibuk untuk dashboard |

Contoh trigger inti (disederhanakan, SQL sebenarnya di migrasi):
```sql
CREATE OR REPLACE FUNCTION trg_member_hold() RETURNS TRIGGER AS $$
DECLARE v_lobby lobbies; v_filled INT;
BEGIN
  SELECT * INTO v_lobby FROM lobbies WHERE id = NEW.lobby_id FOR UPDATE;
  PERFORM wallet_hold(NEW.user_id, v_lobby.price_per_person, 'HOLD', NEW.lobby_id);
  SELECT count(*) INTO v_filled FROM lobby_members
    WHERE lobby_id = NEW.lobby_id AND status = 'HOLDING';
  IF v_filled = v_lobby.quota THEN
    UPDATE lobbies SET status = 'FILLED' WHERE id = v_lobby.id;
    PERFORM confirm_lobby(v_lobby.id);   -- transaksi yang sama
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;
```

### 4.7 Index & Bukti Performa

![Gambar 3. Target kinerja query dan peran index](figures/fig03-index-performance.png)

*Gambar 3 — Target sebelum/sesudah index. Angka final diisi dari `EXPLAIN ANALYZE` nyata.*

| Index | Definisi | Query yang dilayani |
|---|---|---|
| `idx_slots_open` | `(start_at) WHERE status='OPEN'` | Daftar slot tersedia hari ini |
| `idx_lobbies_search` | `(status, min_reliability, created_at DESC)` + join slot | Filter lobby |
| `idx_ledger_wallet` | `(wallet_id, created_at DESC)` | Mutasi wallet |
| `idx_bookings_venue_date` | `(slot_id)` + join | Analytics venue |
| `uq_bookings_slot` | `UNIQUE(slot_id)` | Anti double-booking |

Bukti (diisi saat implementasi, ditampilkan di demo):
```sql
EXPLAIN (ANALYZE, BUFFERS)
SELECT l.id, l.title, l.price_per_person, s.start_at
FROM lobbies l
JOIN court_slots s ON s.id = l.slot_id
JOIN courts c ON c.id = s.court_id
JOIN venues v ON v.id = c.venue_id
WHERE l.status = 'OPEN' AND s.start_at > now()
  AND v.city = 'Bandung' AND l.min_reliability <= 80
ORDER BY s.start_at LIMIT 20;
-- Sebelum index: Seq Scan, ~45 ms (10.000 slot)
-- Sesudah index: Index Scan, ~1.8 ms
```
Angka final wajib diisi dari hasil `EXPLAIN ANALYZE` nyata, bukan estimasi.

### 4.8 Query Analytics (join + agregasi)
Pendapatan per venue dan peak hours:
```sql
SELECT v.name,
       date_trunc('month', b.booked_at) AS bulan,
       count(*)                        AS total_booking,
       sum(b.gross_amount)             AS omzet,
       sum(b.platform_fee)             AS fee_sebar
FROM bookings b
JOIN lobbies l      ON l.id = b.lobby_id
JOIN court_slots s  ON s.id = b.slot_id
JOIN courts c       ON c.id = s.court_id
JOIN venues v       ON v.id = c.venue_id
WHERE v.id = $1 AND b.status <> 'CANCELLED'
GROUP BY v.name, 2
ORDER BY 2 DESC;

SELECT extract(hour FROM s.start_at) AS jam,
       count(*) AS booking,
       round(100.0 * count(*) / sum(count(*)) OVER (), 1) AS persen
FROM bookings b JOIN court_slots s ON s.id = b.slot_id
JOIN courts c ON c.id = s.court_id
WHERE c.venue_id = $1
GROUP BY 1 ORDER BY 2 DESC;
```

---

## 5. Desain Fitur

### 5.1 Peta Fitur → Modul

![Gambar 4. Peta fitur ke modul dan tabel](figures/fig04-feature-map.png)

*Gambar 4 — Enam fitur MVP dan modul/tabel yang menyokongnya.*

| # | Fitur | Modul Klien | Modul Server | Tabel Utama |
|---|---|---|---|---|
| 1 | Match Lobby & Auto-Split Bill | `features/lobby` | `modules/lobby` | lobbies, court_slots, courts, venues |
| 2 | Upfront Wallet Hold | `features/wallet` | `modules/wallet` | wallets, wallet_ledger, lobby_members |
| 3 | Instant Auto-Booking | `features/booking` | `modules/booking` | bookings, venue_payouts, checkins |
| 4 | Anti-Ghosting & Penalti | `features/booking`, `features/profile` | trigger DB | lobby_members, reliability_events |
| 5 | Reputasi & QR Check-in | `features/checkin`, `features/profile` | `modules/checkin` | checkins, users |
| 6 | Dashboard Venue & Analytics | `features/venue` | `modules/venue`, `modules/analytics` | courts, court_slots, bookings |

### 5.2 Alur Utama (happy path)

![Gambar 5. Alur join sampai booking otomatis](figures/fig05-join-sequence.png)

*Gambar 5 — Sequence diagram join. Langkah capture, booking, payout, dan QR berada dalam satu `COMMIT`.*

### 5.3 Fitur 1 — Match Lobby & Auto-Split Bill
**Tujuan:** membuat dan menemukan room main dengan biaya patungan transparan sebelum join.

**Aturan bisnis**
- BR-1.1 `price_per_person = CEIL(price_total / quota)`, dihitung database (generated column), bukan klien.
- BR-1.2 Sisa pembulatan (`price_per_person × quota − price_total`) masuk ke `venue_payout` sebagai surplus; tidak diambil platform.
- BR-1.3 Satu slot hanya boleh punya satu lobby aktif (unique parsial).
- BR-1.4 `min_reliability` 0–100; hanya host yang dapat menetapkan; tidak dapat diubah setelah ada member pertama.
- BR-1.5 Lobby otomatis `EXPIRED` pada `join_deadline` bila kuota < 100%.

**Endpoint**
| Method | Path | Keterangan |
|---|---|---|
| GET | `/lobbies?city=&sport=&date=&minScore=&page=` | Daftar lobby, cursor pagination |
| POST | `/lobbies` | Buat lobby (host otomatis join) |
| GET | `/lobbies/:id` | Detail + peserta + sisa slot |
| PATCH | `/lobbies/:id` | Ubah judul/min score (sebelum ada member lain) |
| DELETE | `/lobbies/:id` | Host batalkan lobby |

**Contoh respons**
```json
{
  "id": "6f1c…",
  "title": "Badminton Sabtu Pagi",
  "venue": { "name": "GOR C-Tra", "city": "Bandung" },
  "slot": { "startAt": "2026-10-24T08:00:00+07:00", "endAt": "2026-10-24T10:00:00+07:00" },
  "priceTotal": 400000,
  "quota": 8,
  "pricePerPerson": 50000,
  "minReliability": 70,
  "joined": 5,
  "joinDeadline": "2026-10-24T02:00:00+07:00",
  "status": "OPEN"
}
```

### 5.4 Fitur 2 — Upfront Wallet Hold
**Tujuan:** join lobby = komitmen dana; tidak ada pendaftaran kosong.

![Gambar 6. Siklus dana: hold, capture, release](figures/fig06-wallet-flow.png)

*Gambar 6 — Siklus dana pada dompet peserta. HOLD mengunci, CAPTURE memotong, RELEASE mengembalikan.*

**Aturan bisnis**
- BR-2.1 Join ditolak bila `balance − held_balance < price_per_person` → `409 INSUFFICIENT_AVAILABLE_BALANCE`.
- BR-2.2 Hold menaikkan `held_balance`, tidak mengubah `balance`; tercatat di ledger sebagai `HOLD`.
- BR-2.3 Hold idempoten per `(lobby_id, user_id)`; retry tidak menggandakan.
- BR-2.4 Hold dilepas saat: batal ≥6 jam, lobby `EXPIRED`, lobby `CANCELLED` oleh host, atau lobby `FAILED`.
- BR-2.5 Hold dikonversi menjadi capture hanya lewat `confirm_lobby()`.

**State wallet**
```
available = balance - held_balance
HOLD:     held_balance += x        (balance tetap)
CAPTURE:  balance -= x; held -= x
RELEASE:  held_balance -= x        (balance tetap)
REFUND:   balance += x             (dana eksternal/gagal capture)
```

### 5.5 Fitur 3 — Instant Auto-Booking (100% Kuota)
**Tujuan:** kuota penuh → booking terjadi tanpa campur tangan manusia.

**Aturan bisnis**
- BR-3.1 Trigger join memanggil `confirm_lobby()` pada transaksi yang sama; commit tunggal.
- BR-3.2 Bila salah satu capture gagal (saldo berubah), seluruh transaksi rollback; lobby tetap `OPEN` dan join ditolak dengan pesan jelas.
- BR-3.3 Booking sukses: slot `BOOKED`, lobby `CONFIRMED`, payout `PENDING`, 1 QR per peserta.
- BR-3.4 Kuota tidak penuh sampai deadline → `expire_stale_lobbies()` melepas 100% hold, lobby `EXPIRED`, slot kembali `OPEN`.
- BR-3.5 Fee platform 5% dari `gross_amount`; `venue_payout = gross − fee + surplus`.

**State machine lobby**

![Gambar 7. State machine lobby](figures/fig07-lobby-state.png)

*Gambar 7 — Status lobby dan transisinya. Hanya FILLED → CONFIRMED yang memotong uang.*

### 5.6 Fitur 4 — Anti-Ghosting & Penalti Otomatis
**Tujuan:** membatalkan mendadak menjadi mahal; membatalkan awal tetap gratis.

![Gambar 8. Kebijakan anti-ghosting menurut waktu pembatalan](figures/fig08-penalty.png)

*Gambar 8 — Tiga zona waktu pembatalan dan konsekuensinya. Dihitung di database dengan `start_at - now()`.*

| Kondisi | Refund | Denda | Reliability | Eksekusi |
|---|---|---|---|---|
| Batal ≥ 6 jam sebelum mulai | 100% | 0 | 0 | Trigger `trg_member_cancel` |
| Batal < 6 jam | 50% | 50% (ke venue) | −10 | Trigger |
| No-show (QR tidak discan ≤ 30 menit setelah mulai) | 0% | 100% | −25 | Trigger `trg_no_show` |
| Host batalkan lobby | 100% semua peserta | 0 | Host −15 | Service + trigger |
| Lobby gagal penuh | 100% | 0 | 0 | `expire_stale_lobbies()` |
| Check-in sukses | — | — | +2 (maks 100) | Trigger checkin |

**Aturan**
- BR-4.1 Denda dikreditkan ke `venue_payout` booking terkait (venue tidak dirugikan).
- BR-4.2 Semua penalti menghasilkan baris `reliability_events` + `wallet_ledger` — dapat diaudit.
- BR-4.3 Aturan penalti ditampilkan di layar join **sebelum** konfirmasi (transparansi).
- BR-4.4 Skor di-clamp 0–100 di database, bukan di klien.

### 5.7 Fitur 5 — Skor Reputasi & QR Check-in
**Tujuan:** penyaringan peserta dan bukti kehadiran.

**Aturan**
- BR-5.1 Join ditolak bila `users.reliability_score < lobbies.min_reliability` → `403 SCORE_TOO_LOW`.
- BR-5.2 QR berisi `base64url(payload).HMAC_SHA256(payload, secret)`; `payload = {checkinId, bookingId, userId, exp}`; `exp = start_at + 2 jam`.
- BR-5.3 Database menyimpan **hash** token (`token_hash`), bukan token; token hanya dikirim sekali ke pemilik tiket.
- BR-5.4 Scan valid: `status = SCANNED`, `scanned_by` = venue admin, skor +2, ledger `CHECKIN` event.
- BR-5.5 Scan ganda → `409 ALREADY_CHECKED_IN` (idempoten, tidak menambah skor).
- BR-5.6 QR kedaluwarsa → `410 TICKET_EXPIRED`.
- BR-5.7 Profil menampilkan riwayat skor (delta + alasan + tanggal) untuk transparansi.

### 5.8 Fitur 6 — Dashboard Venue & Analytics
**Tujuan:** pengelola GOR mengatur jadwal dan membaca performa.

**Fitur layar**
1. **Jadwal**: daftar slot per lapangan per hari; buat slot (jam + harga), blokir slot (maintenance), lihat status (OPEN/LOBBY_FULL/BOOKED).
2. **Ringkasan**: total booking, omzet, fee, okupansi, jumlah no-show.
3. **Peak hours**: bar chart booking per jam + persentase.
4. **Pendapatan**: tren bulanan + rincian per lapangan.
5. **Scan tiket**: kamera → validasi QR → hasil (valid / ganda / kedaluwarsa).

**Aturan**
- BR-6.1 Venue admin hanya dapat mengakses data venue miliknya (row-level check di service).
- BR-6.2 Slot yang sudah `BOOKED` tidak dapat dihapus; hanya dapat dibatalkan lewat alur refund.
- BR-6.3 Analytics dihitung dari `bookings` berstatus `CONFIRMED`/`COMPLETED` (bukan dari input manual).
- BR-6.4 Semua agregasi memakai query join + `GROUP BY` di database (bukti rubrik).

---

## 6. User Stories & Acceptance Criteria

| ID | User Story | Acceptance Criteria (ringkas) |
|---|---|---|
| **US-01** | Sebagai pemain, saya ingin mendaftar dan masuk dengan email agar dapat menyimpan saldo dan riwayat. | Diberikan email baru, ketika mendaftar dengan password ≥ 8 karakter, maka akun + wallet dibuat dan skor awal 100. Password < 8 karakter → 422. |
| **US-02** | Sebagai pemain, saya ingin melihat daftar lobby dengan filter olahraga, kota, tanggal, dan skor minimum. | Diberikan 3 lobby di Bandung, ketika filter `city=Bandung&sport=BADMINTON`, maka hanya lobby cocok yang tampil dengan harga per orang dan sisa slot. Filter kosong → semua lobby `OPEN` tampil. |
| **US-03** | Sebagai host, saya ingin membuat lobby dan langsung melihat patungan per orang. | Diberikan slot Rp400.000, ketika membuat lobby kuota 8, maka `pricePerPerson` = Rp50.000 dan host otomatis terdaftar sebagai member HOLDING. Kuota < 2 → 422. |
| **US-04** | Sebagai pemain, saya ingin join lobby dan saldo saya terkunci agar komitmen tercatat. | Diberikan saldo tersedia Rp100.000, ketika join lobby Rp50.000, maka `held_balance` naik Rp50.000, `balance` tetap, dan muncul baris ledger HOLD. |
| **US-05** | Sebagai pemain, saya ingin diberi tahu bila saldo kurang dan bisa top-up. | Diberikan saldo tersedia Rp20.000, ketika join lobby Rp50.000, maka muncul error `INSUFFICIENT_AVAILABLE_BALANCE` dengan tombol Top Up; tidak ada hold yang terbentuk. |
| **US-06** | Sebagai peserta, saya ingin booking otomatis saat kuota penuh agar tidak perlu konfirmasi manual. | Diberikan lobby 7/8, ketika pemain ke-8 join, maka dalam satu transaksi saldo 8 peserta terpotong, booking dibuat, slot `BOOKED`, dan semua menerima QR. |
| **US-07** | Sebagai peserta, saya ingin refund otomatis bila kuota tidak penuh. | Diberikan lobby 5/8 melewati deadline, ketika job expire berjalan, maka seluruh hold dilepas 100%, status `EXPIRED`, saldo tersedia kembali. |
| **US-08** | Sebagai peserta, saya ingin uang kembali utuh bila batal jauh hari. | Diberikan jadwal 48 jam lagi, ketika saya batal, maka hold dilepas 100% dan skor tidak berubah. |
| **US-09** | Sebagai peserta, saya ingin tahu konsekuensi batal mendadak. | Diberikan jadwal 3 jam lagi, ketika saya batal, maka 50% hold menjadi denda, 50% dilepas, dan skor turun 10 (maksimum 0). |
| **US-10** | Sebagai venue, saya ingin peserta yang tidak datang dikenai penalti otomatis. | Diberikan slot sudah lewat 30 menit dan QR belum discan, ketika status slot menjadi PAST, maka checkin `NO_SHOW`, hold disita 100%, skor −25, dan tercatat di riwayat. |
| **US-11** | Sebagai host, saya ingin menyaring peserta berdasarkan skor minimum. | Diberikan lobby `minReliability=80`, ketika pemain berskor 65 join, maka ditolak `403 SCORE_TOO_LOW` tanpa hold. |
| **US-12** | Sebagai peserta, saya ingin tiket QR untuk masuk lapangan. | Diberikan booking `CONFIRMED`, ketika membuka tiket, maka QR tampil dan dapat discan sekali; scan kedua → 409. |
| **US-13** | Sebagai venue admin, saya ingin mengatur jadwal dan harga slot. | Diberikan lapangan aktif, ketika membuat slot 20:00–22:00 Rp300.000, maka slot tampil `OPEN` dan dapat dilamar lobby. Slot bertabrakan → 409. |
| **US-14** | Sebagai venue admin, saya ingin melihat pendapatan dan jam tersibuk. | Diberikan 30 booking pada bulan berjalan, ketika membuka analytics, maka total omzet, fee, okupansi, dan bar chart per jam tampil sesuai data booking. |
| **US-15** | Sebagai venue admin, saya ingin memvalidasi tiket di pintu. | Diberikan QR valid milik booking hari ini, ketika discan, maka status `SCANNED`, nama peserta tampil, dan skor peserta +2. |
| **US-16** | Sebagai host, saya ingin membatalkan lobby dengan adil. | Diberikan lobby 6/8, ketika host membatalkan, maka semua hold dilepas 100%, host −15 skor, dan peserta mendapat notifikasi. |

**Total 16 user stories** (minimum rubrik: 8).

---

## 7. Desain Antarmuka (Mobile)

### 7.1 Design Token
| Token | Nilai | Pemakaian |
|---|---|---|
| `color.brand.dark` | `#0B3D2E` | App bar gelap, cover |
| `color.brand.primary` | `#15803D` | CTA utama, angka penting |
| `color.brand.accent` | `#FACC15` | Badge, highlight |
| `color.brand.tint` | `#F0FDF4` | Background layar |
| `color.state.warning` | `#B45309` | Denda < 6 jam |
| `color.state.danger` | `#DC2626` | No-show, error |
| `radius.card` | 16 | Kartu lobby |
| `radius.pill` | 999 | Chip filter, tombol |
| `space.unit` | 4 | Grid 4/8/12/16/24 |
| `font.heading` | Inter/Arial Bold | Judul |
| `font.body` | Inter/Calibri | Isi |

### 7.2 Peta Navigasi
```
Splash
  └─ sudah login? ─┬─ belum ─► Login / Register
                   └─ sudah ─► Home: Cari Lobby
Home
  ├─ Lobby Detail ─► Join Confirm Sheet ─► Tiket QR
  ├─ Buat Lobby
  ├─ Wallet
  ├─ Booking Saya ─► Tiket QR
  ├─ Profil & Reputasi
  └─ Mode Venue
       ├─ Jadwal Slot
       ├─ Analytics
       └─ Scan QR ─► Hasil Scan
```

### 7.3 Layar & Komponen Utama
| Layar | Komponen kunci | State |
|---|---|---|
| Home | Search bar, chip olahraga, kartu lobby (harga/orang, sisa slot, skor min), pull-to-refresh | loading / empty / error / data |
| Lobby Detail | Header venue, countdown deadline, progress kuota, daftar peserta + skor, CTA sticky "Join — Rp50.000" | |
| Join Confirm Sheet | Rincian split bill, saldo tersedia, aturan penalti 3 tingkat, checkbox setuju | |
| Wallet | Saldo tersedia, saldo terkunci, riwayat mutasi (ledger), tombol Top Up sandbox | |
| Tiket QR | QR besar, kode booking, jam & lapangan, tombol simpan | |
| Profil | Skor + progress bar, riwayat delta, statistik main | |
| Venue Jadwal | Kalender harian, grid slot berwarna per status | |
| Venue Analytics | Kartu KPI, bar chart peak hours, line chart pendapatan, filter rentang | |
| Scan QR | Viewfinder kamera, input manual kode, hasil valid/ganda/kedaluwarsa | |

### 7.4 Prinsip UX
- **Harga selalu terlihat sebelum komitmen** (split bill di kartu lobby, bukan setelah join).
- **Satu CTA utama per layar**; aksi destruktif (batal) memakai dialog konfirmasi berisi konsekuensi nominal.
- **Umpan balik status uang** eksplisit: "Rp50.000 dikunci" bukan "berhasil".
- **Empty state informatif**: "Belum ada lobby di kotamu — buat yang pertama."
- Aksesibilitas: target sentuh ≥ 48dp, kontras WCAG AA, dukungan font scale 1.3.

---

## 8. Desain Klien (Flutter)

### 8.1 Struktur Proyek
```
lib/
├── main.dart
├── app.dart                      # MaterialApp.router, theme
├── bootstrap.dart                # env, dependency override
├── core/
│   ├── config/env.dart
│   ├── network/api_client.dart   # Dio + interceptor JWT + refresh
│   ├── network/api_exception.dart
│   ├── router/app_router.dart    # go_router + guard
│   ├── theme/app_theme.dart
│   ├── utils/formatter.dart      # Rupiah, tanggal WIB
│   └── widgets/                  # AppButton, EmptyState, ErrorView, ShimmerCard
├── features/
│   ├── auth/{data,domain,presentation}
│   ├── lobby/{data,domain,presentation}
│   ├── wallet/{data,domain,presentation}
│   ├── booking/{data,domain,presentation}
│   ├── checkin/{data,domain,presentation}
│   ├── venue/{data,domain,presentation}
│   └── profile/{data,domain,presentation}
└── shared/models/                # DTO lintas fitur
```
Setiap fitur: `data/dto`, `data/datasources`, `data/repositories`, `domain/entities`, `domain/repositories`, `domain/usecases`, `presentation/screens`, `presentation/widgets`, `presentation/providers`.

### 8.2 Dependensi
| Paket | Fungsi |
|---|---|
| `flutter_riverpod` | State management & DI |
| `go_router` | Navigasi deklaratif + guard auth |
| `dio` | HTTP client, interceptor token |
| `freezed`, `json_serializable` | Immutable model & serialisasi |
| `flutter_secure_storage` | Simpan access/refresh token |
| `qr_flutter` | Render QR tiket |
| `mobile_scanner` | Scan QR venue |
| `fl_chart` | Grafik analytics |
| `intl` | Format Rupiah & tanggal `id_ID` |
| `connectivity_plus` | Deteksi offline |
| `flutter_local_notifications` | Pengingat deadline & check-in |

### 8.3 State & Alur Data
`Screen → ref.watch(provider) → Usecase → Repository → RemoteDatasource(Dio) → API`

- Provider mengembalikan `AsyncValue<T>`; UI wajib menangani `loading`, `error`, `data`.
- Tidak ada perhitungan uang di klien: `pricePerPerson`, refund, dan denda berasal dari server.
- Setelah join sukses, provider `lobbyDetail` dan `wallet` di-invalidate agar angka konsisten.

### 8.4 Penanganan Error
| Kondisi | Perilaku UI |
|---|---|
| 401 token kedaluwarsa | Refresh otomatis 1×; gagal → logout + arahkan login |
| 409 `INSUFFICIENT_AVAILABLE_BALANCE` | Bottom sheet saldo kurang + CTA Top Up |
| 403 `SCORE_TOO_LOW` | Pesan skor minimum + skor saya |
| 409 `LOBBY_FULL` | Refresh detail, tombol join disabled |
| Timeout / offline | Snackbar "Koneksi bermasalah", tombol coba lagi, tanpa retry uang otomatis |
| 5xx | Layar error generik + kode korelasi (`requestId`) |

---

## 9. Desain Server (REST API)

### 9.1 Struktur
```
server/
├── src/
│   ├── index.ts                 # bootstrap, graceful shutdown
│   ├── config/env.ts
│   ├── db/{pool.ts,migrations/,seeds/}
│   ├── middleware/{auth.ts,rbac.ts,validate.ts,error.ts,rateLimit.ts}
│   ├── modules/
│   │   ├── auth/{routes,controller,service}.ts
│   │   ├── wallet/
│   │   ├── lobby/
│   │   ├── booking/
│   │   ├── checkin/
│   │   ├── venue/
│   │   └── analytics/
│   └── lib/{jwt.ts,qr.ts,money.ts,logger.ts}
└── tests/{unit,integration}/
```

### 9.2 Kontrak API
| Method | Path | Auth | Body / Query | Sukses | Error utama |
|---|---|---|---|---|---|
| POST | `/auth/register` | — | email, password, fullName, phone | 201 token | 409 email dipakai |
| POST | `/auth/login` | — | email, password | 200 token | 401 |
| POST | `/auth/refresh` | refresh | refreshToken | 200 token | 401 |
| GET | `/me` | JWT | — | 200 profil + skor | 401 |
| GET | `/me/wallet` | JWT | — | 200 balance, held, available | 401 |
| POST | `/me/wallet/topup` | JWT | amount | 201 ledger TOPUP | 422 |
| GET | `/me/wallet/ledger` | JWT | page | 200 list | |
| GET | `/venues` | JWT | city, sport | 200 list | |
| GET | `/venues/:id/slots` | JWT | date | 200 list | |
| GET | `/lobbies` | JWT | city, sport, date, minScore | 200 list | |
| POST | `/lobbies` | JWT | slotId, title, quota, minReliability | 201 lobby | 409 slot sudah dilamar |
| GET | `/lobbies/:id` | JWT | — | 200 detail | 404 |
| POST | `/lobbies/:id/join` | JWT | Idempotency-Key | 201 member (HOLDING/CONFIRMED) | 409 full, 409 saldo, 403 skor, 410 deadline |
| DELETE | `/lobbies/:id/members/me` | JWT | — | 200 refund info | 409 sudah confirm |
| DELETE | `/lobbies/:id` | JWT host | — | 200 | 403 bukan host |
| GET | `/me/bookings` | JWT | — | 200 list | |
| GET | `/bookings/:id/ticket` | JWT | — | 200 qrToken, expiresAt | 403 bukan peserta |
| POST | `/checkin/scan` | venue | token | 200 peserta + skor | 409 ganda, 410 expired |
| GET | `/venue/slots` | venue | date | 200 | 403 |
| POST | `/venue/slots` | venue | courtId, startAt, endAt, price | 201 | 409 bentrok |
| PATCH | `/venue/slots/:id` | venue | status/price | 200 | 409 sudah BOOKED |
| GET | `/venue/analytics/summary` | venue | from, to | 200 KPI | |
| GET | `/venue/analytics/peak-hours` | venue | from, to | 200 array jam | |
| GET | `/venue/analytics/revenue` | venue | from, to | 200 array bulan | |

### 9.3 Format Error
```json
{
  "error": {
    "code": "INSUFFICIENT_AVAILABLE_BALANCE",
    "message": "Saldo tersedia tidak cukup untuk join lobby ini.",
    "details": { "required": 50000, "available": 20000 },
    "requestId": "req_01H…"
  }
}
```
Kode: `VALIDATION_ERROR`, `UNAUTHORIZED`, `FORBIDDEN`, `SCORE_TOO_LOW`, `LOBBY_FULL`, `ALREADY_JOINED`, `DEADLINE_PASSED`, `INSUFFICIENT_AVAILABLE_BALANCE`, `SLOT_NOT_OPEN`, `ALREADY_CHECKED_IN`, `TICKET_EXPIRED`, `CONFLICT`, `RATE_LIMITED`, `INTERNAL`.

### 9.4 Validasi & Idempotensi
- Semua body divalidasi skema (Zod) sebelum menyentuh DB; tipe & rentang eksplisit.
- `Idempotency-Key` wajib pada `POST /join`, `/topup`, `/checkin/scan`; disimpan unik di ledger/aksi.
- Rate limit: 60 req/menit/user; 10 req/menit untuk endpoint uang.
- Nominal uang dikirim sebagai integer rupiah (JSON number) dan dikonversi ke `NUMERIC` di server.

---

## 10. Keamanan

| Aspek | Kontrol |
|---|---|
| Autentikasi | JWT access 15 menit + refresh 30 hari, Argon2id untuk password |
| Otorisasi | RBAC (`PLAYER`/`VENUE_ADMIN`/`SUPER_ADMIN`) + cek kepemilikan resource (venue, lobby, tiket) |
| Rahasia | Semua secret di environment; `.env` di `.gitignore`; tidak ada kredensial di repo (bukti rubrik) |
| Uang | Hold/capture hanya via function DB; klien tidak dapat mengirim nominal yang mengikat |
| QR | HMAC-SHA256, expiry, single-use, disimpan sebagai hash |
| Transport | HTTPS wajib; sertifikat valid; tidak ada cleartext traffic di Android manifest |
| Input | Validasi server-side, parameterized query (anti SQL injection), batas ukuran body |
| Abuse | Rate limit, unique constraint (anti spam join), audit log |
| Data pribadi | Hanya email/telepon/nama; tidak ada data pembayaran sensitif; retensi dump demo 30 hari |

---

## 11. Kinerja & Non-Functional

| Kebutuhan | Target | Cara verifikasi |
|---|---|---|
| Waktu muat daftar lobby | p95 < 800 ms | Uji 10× dengan data 10.000 slot |
| Join end-to-end | p95 < 1,5 s | Uji integrasi + log durasi |
| Join paralel | 60 request, 0 double-booking | Skrip `k6`/`autocannon` + cek `count(bookings)` |
| Ukuran APK | < 40 MB | `flutter build apk --release --analyze-size` |
| Uptime demo | 99% selama sesi | Health check `/healthz` |
| Offline | Layar error jelas, tidak ada retry uang otomatis | Uji manual mode pesawat |
| Aksesibilitas | Kontras AA, target 48dp | `flutter test` + review manual |
| Observability | Log terstruktur + `requestId` | Sampel log di demo |

---

## 12. Rencana Pengujian

### 12.1 Automated Tests (≥ 5, satu command: `flutter test` + `npm test`)
| ID | Jenis | Skenario | Bukti rubrik |
|---|---|---|---|
| T-01 | Unit (Dart) | `SplitBillCalculator` menghasilkan 50.000 untuk 400.000/8 dan membulatkan ke atas | Logika bisnis |
| T-02 | Unit (Dart) | `PenaltyPolicy` memilih refund 100% (≥6 jam), 50% + −10 (<6 jam), 100% + −25 (no-show) | Aturan penalti |
| T-03 | Widget (Flutter) | Kartu lobby menampilkan harga/orang, sisa slot, dan CTA disabled saat penuh | UI + state |
| T-04 | Integration (API) | Join sampai kuota penuh → booking dibuat, saldo 8 peserta terpotong, slot `BOOKED` | Transaksi ACID |
| T-05 | Integration (API) | Paksa error di langkah QR → seluruh transaksi rollback, saldo utuh | Atomicity |
| T-06 | Concurrency (API) | 20 user join lobby kuota 8 bersamaan → tepat 8 member, 12 ditolak `LOBBY_FULL` | Race condition |
| T-07 | Integration (API) | Join dengan skor < `minReliability` → 403 tanpa hold | Reputasi |
| T-08 | Integration (API) | Scan QR dua kali → 409, skor hanya +2 sekali | Idempotensi check-in |
| T-09 | DB test | `wallet_hold` menolak bila saldo tersedia kurang, tidak ada baris ledger | Integritas |
| T-10 | DB test | `EXPLAIN` query daftar lobby memakai index yang diharapkan | Performa |

### 12.2 Manual / Demo Checklist
1. Register → login → top up saldo.
2. Buat lobby 8 orang, tunjukkan split bill.
3. Join 7 akun seed → tunjukkan hold dan saldo tersedia turun.
4. Join akun ke-8 → booking otomatis, QR muncul.
5. Batalkan satu peserta < 6 jam → tunjukkan denda 50% + skor −10.
6. Scan QR di mode venue → status SCANNED, skor +2.
7. Buka analytics → omzet, okupansi, peak hours.
8. Tunjukkan `EXPLAIN ANALYZE` sebelum/sesudah index.

---

## 13. Traceability Matrix

| Rubrik | Kebutuhan | Artefak di dokumen ini | Bukti demo |
|---|---|---|---|
| A. Problem & monetisasi | Masalah nyata, target user, siapa bayar | §2.1, §2.2, pitch deck | Pitch + survei bertanggal |
| B. Diferensiasi | ≥3 solusi pembanding, gap analysis | pitch deck S12 | Q&A |
| C. Database (IK301) | ≥6 tabel | §4.3 (14 tabel) | ERD + dump |
| C | Integritas | §4.4 | Constraint + uji insert salah |
| C | Transaksi multi-step | §4.5, §5.5 | Rollback terkontrol |
| C | Server-side logic | §4.6 | Trigger saat join & batal |
| C | Index + query plan | §4.7 | `EXPLAIN ANALYZE` before/after |
| C | Analytics join + agregasi | §4.8 | Dashboard venue |
| D. Software (IK102) | ≥8 user stories | §6 (16 US) | Dokumen ini |
| D | Struktur kode berlapis | §8.1, §9.1 | Repo |
| D | Version control semua anggota | — | `git log`, tag `final-submission` |
| D | ≥5 automated tests | §12.1 (10 tes) | `flutter test` + `npm test` |
| D | Validasi & error handling | §8.4, §9.3, §9.4 | Demo input salah |
| D | README < 15 menit | Deliverable README | Dijalankan penguji |
| E. Pitch & demo | Alur jelas, demo jalan, anggota paham bagiannya | §5, §14 | Sesi 25 menit |

![Gambar 9. Cakupan bukti terhadap minimum rubrik](figures/fig09-rubric-coverage.png)

*Gambar 9 — Perbandingan minimum rubrik dengan artefak yang disediakan desain ini.*

### 13.1 Pemetaan Deliverable
| Deliverable | Lokasi | Status |
|---|---|---|
| Pitch deck PDF | `pitch/SEBAR_Pitch_Deck.pptx` → ekspor PDF | Ada |
| Working app | `build/app-release.apk` + hosted API | Dibangun |
| Source code | repo + tag `final-submission` | Ada |
| README (English) | `README.md` (+ bagian "AI usage") | Wajib |
| Data model | `docs/erd.png`, `db/dump/sebar_demo.sql`, `db/seeds/` | Wajib |
| Backup video | `docs/demo-backup.mp4` (2–3 menit) | Wajib |

---

## 14. Rencana Demo (7 menit)

| Menit | Isi | Penekanan teknis |
|---|---|---|
| 0:00–0:30 | Login, tunjukkan skor & wallet | Auth, RBAC |
| 0:30–2:00 | Cari lobby, buat lobby, split bill | Generated column, validasi |
| 2:00–3:30 | Join 8 akun, hold terlihat di wallet | Trigger, transaksi |
| 3:30–4:30 | Booking otomatis + QR | ACID, unique slot |
| 4:30–5:30 | Batal < 6 jam, denda & skor | Trigger penalti |
| 5:30–6:15 | Scan QR di venue, analytics | Check-in, join + agregasi |
| 6:15–7:00 | `EXPLAIN ANALYZE` + rollback | Index, atomicity |

![Gambar 10. Rencana demo 7 menit](figures/fig10-demo-timeline.png)

*Gambar 10 — Pembagian waktu demo dan bukti teknis yang ditonjolkan di tiap segmen.*

---

## 15. Risiko & Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Race condition join bersamaan | Double-booking / saldo minus | `FOR UPDATE`, unique constraint, uji T-06 |
| Data seed tidak realistis | Demo analytics kosong | Seed 3 venue, 12 lapangan, 60 slot, 40 booking |
| Top-up sandbox dianggap palsu | Kredibilitas monetisasi | Jelaskan sebagai mock payment + tunjukkan desain integrasi gateway |
| QR dapat difoto orang lain | Check-in curang | Token single-use + expiry + validasi petugas |
| Deadline job tidak jalan saat demo | Lobby menggantung | Endpoint admin `POST /admin/expire-lobbies` untuk memicu manual |
| APK tidak ter-install di perangkat penguji | Demo gagal | Uji di 2 perangkat + backup video |
| Anggota tidak bisa menjelaskan bagiannya | Nilai individu turun | Pembagian modul §16 + latihan Q&A |

---

## 16. Pembagian Kerja (indikatif)

| Peran | Modul | Bukti kontribusi |
|---|---|---|
| Team Lead / Product | Requirement, usecase, pitch, integrasi | `docs/`, `pitch/`, commit |
| Backend & Database | Migrasi, function, trigger, index, analytics | `server/src/db`, `server/src/modules` |
| Frontend Flutter | Lobby, wallet, booking, QR | `lib/features` |
| QA & DevOps | Automated tests, CI, APK build, seed | `test/`, `.github/`, `server/tests` |
| UX & Riset | Wireframe, usability, validasi pengguna | `docs/ux/`, catatan wawancara |

---

## 17. Lampiran

### 17.1 Aturan Pembulatan Uang
`price_per_person = CEIL(price_total / quota)`.
Contoh: Rp400.000 / 8 = Rp50.000 (pas). Rp350.000 / 3 = Rp116.667 → per orang Rp116.667, terkumpul Rp350.001, surplus Rp1 diteruskan ke venue.
Semua nilai disimpan `NUMERIC(14,2)`; tidak ada `FLOAT` untuk uang.

### 17.2 Format Tanggal & Zona Waktu
Database menyimpan `TIMESTAMPTZ` (UTC). Klien menampilkan `Asia/Jakarta` via `intl`. Perbandingan 6 jam dilakukan di database (`start_at - now()`), bukan di perangkat, agar tidak dapat dimanipulasi.

### 17.3 Seed Data Demo
- 1 super admin, 1 venue admin, 12 pemain (skor 40–100).
- 3 venue (Bandung, Jakarta, Surabaya), 12 lapangan, 60 slot.
- 10 lobby (2 penuh, 5 berjalan, 3 mendekati deadline).
- 40 booking historis untuk analytics.

### 17.4 Checklist Kesiapan
- [ ] Semua migrasi berjalan dari database kosong (`npm run db:migrate`)
- [ ] Seed idempoten (`npm run db:seed`)
- [ ] `flutter test` dan `npm test` hijau
- [ ] APK release terpasang di 2 perangkat
- [ ] `EXPLAIN ANALYZE` before/after terdokumentasi dengan angka nyata
- [ ] README berisi cara jalan, akun tes, dan "AI usage"
- [ ] Video backup 2–3 menit tersedia offline
- [ ] Tag `final-submission` dibuat

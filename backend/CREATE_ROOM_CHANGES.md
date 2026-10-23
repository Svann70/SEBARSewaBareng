# Backend + DB — Buat Room (wizard 3 langkah)

Sumber desain: `DesignReference/SEBAR Mobile — Hijau.pdf`, halaman 9–11
(`Pilih venue` → `Tanggal & slot` → `Atur room`).

Status: frontend wizard sudah jadi (`mobile/lib/features/create/create_lobby_screen.dart`).
Backend **belum diubah**. Dokumen ini menjawab: apa yang wajib diubah, apa yang
sudah cukup, dan apa yang opsional.

Ringkas:

| Bagian wizard | Status backend |
|---|---|
| Daftar venue + harga/lapangan | **Sudah ada** |
| Grid slot per tanggal | **Sudah ada** |
| Buat room (judul, kuota, harga, hold) | **Sudah ada** |
| Pilihan join: Publik / Via link / Pakai sandi | **Belum ada** (DB + endpoint) |

---

## 1. Sudah didukung — tidak perlu diubah

### 1.1 Langkah 1 · Pilih venue

`GET /venues` (`venues.service.js`) mengirim:

```json
{
  "items": [{
    "id": "uuid",
    "name": "GOR C-Tra Arena",
    "city": "Bandung",
    "photoUrl": "…",
    "courts": [
      { "id": "uuid", "name": "Lap. 3", "sport": "BADMINTON",
        "pricePerHour": 200000, "capacity": 12 }
    ]
  }]
}
```

Cukup untuk: nama venue, `kota · jumlah lapangan`, rentang harga
`min–max courts.pricePerHour /jam`, dan filter cabang olahraga.

### 1.2 Langkah 2 · Tanggal & slot

`GET /venues/:id/slots?date=YYYY-MM-DD` memakai `SLOT_SELECT`
(`venues/slots.shared.js`) dan mengirim `id, courtId, courtName, sport,
startAt, endAt, price, status, lobbyId`. Status `OPEN` + `lobbyId = null`
dipakai UI sebagai kotak kosong; `BOOKED/LOBBY/CLOSED` sebagai `Terisi/Tutup`.

Tidak perlu endpoint grid baru: UI menyusun kolom lapangan × baris jam dari
`venue.courts` + daftar slot ini.

Durasi slot tidak dipaksa 1 jam — `POST /venue/slots` menerima `startAt`/`endAt`
sampai 12 jam. Jadi tampilan desain `08.00–10.00` cukup dibuat venue sebagai
satu slot 2 jam. **Tidak ada perubahan skema.**

### 1.3 Langkah 3 · Atur room

`POST /lobbies` (`createSchema` + `lobbies.service.create`) sudah menangani:

- `{ slotId, title, quota, minReliability? }`;
- harga: `price_total = court_slots.price` (snapshot), `price_per_person`
  dihitung DB (`ceil(price_total / quota)`);
- `join_deadline = start_at - 6 jam` (`JOIN_CUTOFF_HOURS = 6`) — sama dengan
  teks `Batas kumpul 6 jam sebelum main` di desain;
- validasi kuota `2–30` + `quota <= courts.capacity`;
- slot harus `OPEN` dan belum punya lobby aktif (`uq_lobbies_active_slot`);
- hold saldo host + maksimal 3 lobby aktif per host, semuanya transaksional.

Artinya **footer harga dan CTA `Buat room • kunci Rp50.000` sudah akurat**
tanpa perubahan backend.

---

## 2. Wajib diubah — opsi "Siapa yang bisa join"

Saat ini frontend menonaktifkan `Via link` dan `Pakai sandi` (label `Segera`)
karena server belum menyimpan akses room. Kalau opsi ini mau hidup, kerjakan
bagian ini.

### 2.1 Migrasi database

```sql
CREATE TYPE lobby_access AS ENUM ('OPEN', 'LINK', 'PASSWORD');

ALTER TABLE lobbies
  ADD COLUMN access lobby_access NOT NULL DEFAULT 'OPEN',
  ADD COLUMN join_code varchar(8),
  ADD COLUMN cancelled_at timestamptz;

-- kode hanya wajib untuk room non-publik, dan harus unik
ALTER TABLE lobbies
  ADD CONSTRAINT lobbies_join_code_check
    CHECK ((access = 'OPEN' AND join_code IS NULL)
        OR (access <> 'OPEN' AND join_code IS NOT NULL));

CREATE UNIQUE INDEX lobbies_join_code_key
  ON lobbies (join_code) WHERE join_code IS NOT NULL;
```

Catatan:

- `DEFAULT 'OPEN'` → semua room lama otomatis publik, aman untuk rilis.
- Satu kolom `join_code` dipakai untuk dua mode: `LINK` (kode ada di URL
  undangan) dan `PASSWORD` (kode diketik). Tidak perlu `password_hash`:
  kode ini memang rahasia jangka pendek, bukan kredensial akun.
- `cancelled_at` dipakai audit + memisahkan batal host dari batal peserta
  (`lobby_members.cancelled_at` sudah ada).
- Format kode: 6–8 karakter `A–Z0–9` tanpa huruf ambigu (`O`, `0`, `I`, `1`),
  contoh `SBR7K2Q`. Dibuat server bila `access != OPEN` dan `joinCode` kosong.

### 2.2 Endpoint: buat room

`POST /lobbies` — tambah field di `lobbies.schema.js`:

```js
access: z.enum(['OPEN', 'LINK', 'PASSWORD']).default('OPEN'),
joinCode: z.string().trim().regex(/^[A-HJ-NP-Z2-9]{6,8}$/).optional(),
```

Aturan service:

- `OPEN` → `join_code = NULL`; kirim `joinCode` bersama `OPEN` = `422`.
- `LINK`/`PASSWORD` tanpa `joinCode` → server generate unik (retry 3×).
- Insert `access`, `join_code`, `cancelled_at = NULL`.
- Kode bentrok → `409 CONFLICT` (`lobbies_join_code_key`).

`lobbyDto` (`lobbies.controller.js`) tambah:

```json
{ "access": "OPEN | LINK | PASSWORD", "joinCode": "SBR7K2Q | null" }
```

`joinCode` hanya dikirim ke host dan anggota room. Di `GET /lobbies`
(daftar publik) kirim `access` saja.

### 2.3 Endpoint: join

Perilaku yang harus dijaga:

| Mode | Di daftar publik | Join |
|---|---|---|
| `OPEN` | tampil | `POST /lobbies/:id/join` tanpa kode |
| `PASSWORD` | tampil (badge sandi) | wajib `code` benar |
| `LINK` | **tidak tampil** | wajib `code` benar, biasanya lewat `/lobbies/join` |

Perubahan:

1. `lobbies.service.list` tambah `AND l.access <> 'LINK'`.
2. `POST /lobbies/:id/join` — body opsional `{ code }`:
   - `access = OPEN` → kode diabaikan/dilarang;
   - `access != OPEN` → kode wajib, `403 JOIN_CODE_REQUIRED` bila kosong,
     `403 INVALID_JOIN_CODE` bila salah (jangan bedakan "tidak ada" vs
     "salah" di pesan publik).
3. Endpoint baru `POST /lobbies/join` body `{ code }` → cari lobby
   `join_code = $1 AND status = 'OPEN' AND join_deadline > now()`, lalu
   jalankan alur join yang sama. Balas `{ lobbyId, member, booking }`.
   404 jika kode tidak dikenal; 410/409 jika room sudah penuh/kedaluwarsa.

Semua validasi kode di server; kode yang salah tidak boleh membocorkan judul
atau isi room.

### 2.4 Endpoint: detail room

`GET /lobbies/:id`:

- kirim `access` dan `joinCode` **hanya** untuk host/anggota;
- untuk non-anggota `LINK`, detail publik tetap boleh tampil (judul, venue,
  slot) tapi `joinCode` null dan join butuh kode.

### 2.5 Dampak frontend (untuk tim mobile)

- `mobile/lib/data/state.dart` → `lobbyFromApi` belum membaca `access`;
  tambahkan `access: _lobbyAccessFromApi(json['access'])`.
- `createRemote` kirim `access` (+ `joinCode` bila nanti ada input kode).
- `LobbyAccessX.hint` sudah ada; tinggal mengaktifkan radio di
  `create_lobby_screen.dart` (saat ini `enabled` hanya `OPEN`).

Perkiraan perubahan: 1 migrasi + 3 file backend (`schema`, `service`,
`controller`) + tes join kode.

---

## 3. Opsional — tidak menghalangi wizard

| Fitur desain | Perubahan | Kapan perlu |
|---|---|---|
| `Kosong: 08.00 13.00 16.00 +4` di kartu venue | `GET /venues?date=…` kirim `openTimes[]` per venue (agregasi `court_slots.status = 'OPEN'`), atau endpoint `GET /venues/:id/availability?date=…` | jika pratinjau jam di langkah 1 diminta |
| `Terdekat` + jarak `2,1 km` | `venues.lat/lng` (lihat `DESIGN_CHANGES.md` §1.1) + query `lat/lng` pengguna → hitung `distanceKm`, urutkan | jika filter jarak dipakai |
| Harga weekend `Rp100–200 rb/jam` | `courts.weekend_price_per_hour` (lihat `DESIGN_CHANGES.md` §1.2) | saat tab Lapangan venue dirombak |
| Batas kumpul bisa dipilih | kolom `lobbies.join_cutoff_hours smallint` + validasi; sekarang UI read-only 6 jam sesuai server | jika produk minta opsi 12/24 jam |
| Room `6/8` bisa join dari grid | `GET /venues/:id/slots` sertakan `joined/quota` untuk `lobbyId` | jika status room di grid ingin informatif |

Tidak perlu skema baru untuk: harga per orang (generated column), hold host,
kuota, atau pemilihan slot — semuanya sudah final di server.

---

## 4. Yang tidak berubah

- Tabel `court_slots` dan `courts` (kecuali weekend price, terpisah).
- `POST /lobbies` untuk room publik: body lama tetap valid (default `OPEN`).
- Perhitungan uang: `price_total`, `price_per_person`, `join_deadline` tetap
  dihitung server; frontend hanya menampilkan.
- Pembatalan: `DELETE /lobbies/:id` tetap ada; `cancelled_at` hanya tambahan
  audit, bukan alur baru.

---

## 5. Urutan kerja

1. Migrasi `lobby_access`, `join_code`, `cancelled_at` + constraint/index.
2. `createSchema` + insert `access`/`join_code` + generator kode.
3. `lobbyDto` + filter daftar `LINK`.
4. Validasi kode di `POST /lobbies/:id/join`; tambah `POST /lobbies/join`.
5. Aktifkan radio di frontend + `lobbyFromApi` membaca `access`.
6. Tes: buat room tiap mode, join tanpa kode (403), kode salah (403), kode
   benar (201), `LINK` tidak muncul di daftar, `PASSWORD` muncul tapi join
   butuh kode, room lama tetap `OPEN`.

Estimasi: 1 migrasi, 4 file backend, 2 file mobile.

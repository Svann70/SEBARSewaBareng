# SEBAR — Sewa Bareng (Flutter)

Frontend MVP untuk patungan sewa lapangan olahraga. Acuan desain: `../SDD_SEBAR.md`
§7 (design token, peta navigasi, layar) dengan bahasa visual dari
`DesignReference/DesignNew.jpg` (kanvas krem, kartu krem, panel pekat hijau
dan amber, angka besar, dock bawah dengan aksi utama di tengah).

## Jalan

```bash
flutter pub get
flutter run                 # Android/iOS
flutter run -d chrome       # web (cek cepat)
flutter test                # 19 tes
```

APK: `flutter build apk --debug` → `build/app/outputs/flutter-apk/`.

## Backend

Alamat API diambil dari `--dart-define=SEBAR_API_URL`; tanpa itu default
`http://10.0.2.2:3000` di emulator Android dan `http://localhost:3000` di
web/desktop (lihat `lib/data/api.dart`).

```bash
cd ../backend && npm run dev      # server di :3000
cd ../mobile && flutter run --dart-define-from-file=env.json
```

`env.json` menyimpan `SEBAR_API_URL` (contoh: `http://192.168.1.10:3000`;
lihat `env.json.example`). Untuk perangkat fisik: PC dan HP harus satu
Wi-Fi, `usesCleartextTraffic` sudah diaktifkan di debug manifest, dan
firewall Windows harus mengizinkan port 3000. Perubahan env perlu
rebuild penuh (hot reload tidak memproses dart-define).

- Token disimpan di memori `ApiClient`; 401 memicu satu kali refresh otomatis.
  Sesi hilang saat app ditutup (belum ada secure storage).
- Seed local tetap ada di provider `build()` sebagai isi sementara/offline;
  `refresh()` menimpanya dengan data `/venues`, `/lobbies`, `/me/wallet`,
  `/me/bookings`, `/venue/venues`, `/venue/slots`.
- Konflik UI vs kontrak backend: room tanpa akses/sandi/kode undangan, tanpa
  token QR + endpoint check-in (QR memakai `bookingCode`), tanpa chat, tanpa
  analytics/pencairan venue, dan top up hanya jalan bila backend
  `ALLOW_SANDBOX_TOPUP=1`.

## Layar

| Route | Layar | Isi |
|---|---|---|
| `/login` | Masuk | Satu form untuk pemain dan mitra; peran dibaca dari akun |
| `/register` | Daftar | Layar terpisah: nama, email, password, ulangi password |
| `/home` | Beranda pemain | Kolom cari, saldo, filter lingkaran olahraga, 5 room teratas + tautan ke semua room |
| `/rooms` | Semua room | Daftar penuh dikelompokkan per tanggal, cari + filter olahraga/kota |
| `/lobby/:id` | Detail room | Foto lapangan + header pekat, ringkasan tagihan bertumpuk |
| - | Sheet join | Split bill, konfirmasi dana dompet terkunci, checkbox setuju |
| `/create` | Buat room | Pilih venue + lapangan + slot dari server; harga & kuota ikut data lapangan |
| `/community` | Komunitas | Chat 4 kanal, kirim pesan, waktu lokal |
| `/ticket/:id` | Tiket QR | QR, kode booking, simulasi scan |
| - | Dompet | Saldo tersedia/terkunci, riwayat mutasi, top up |
| - | Profil | Statistik main, riwayat main, pintasan mode mitra |
| `/venue` | Shell venue | Beranda omzet + papan okupansi, jadwal slot, scan, akun venue + pencairan |
| `/venue/analytics` | Analytics venue | Omzet, okupansi, peak hours, tren pendapatan |

## Dua akun, satu aplikasi

Pola sama seperti GoFood vs GoFood Merchant, tapi satu APK dan satu pintu masuk:

- Login dan daftar dipisah supaya calon pengguna tidak bingung. Tidak ada
  pemilih peran di form; peran ditentukan dari akun (`roleForEmail`).
- Peran menentukan beranda: `AccountRole.player.home` = `/home`,
  `AccountRole.venue.home` = `/venue`.
- `DockNav` menerima daftar item, jadi dock venue berbeda: Beranda, Jadwal,
  Scan, Akun. FAB tengah membuka sheet tambah slot.
- Akun venue tidak bisa join room pemain. Untuk pindah peran, keluar dulu
  lewat Akun venue atau Profil pemain.
- Peran yang dipakai UI datang dari respons `/auth/login` (`sessionProvider`),
  bukan dari `roleForEmail` — fungsi itu hanya menebak peran saat mendaftar.

## Jadwal venue

Sumber data `venueSlotsProvider` di `lib/data/state.dart`:

- Slot punya lapangan, jam, harga, dan status (`Kosong`, `Terisi`,
  `Room berjalan`, `Ditutup`).
- Harga ditentukan **per lapangan** (`courts.price_per_hour`, dikirim API
  sebagai `pricePerHour`). Sheet buka slot menghitung `tarif × durasi`; slot
  yang sudah terbit menyimpan harganya sendiri, jadi ubah tarif tidak
  mengubah slot lama. `Ubah tarif` memanggil `PATCH /venue/courts/:id`.
- `Tambah lapangan` memanggil `POST /venue/courts` (nama, olahraga, tarif per
  jam, kapasitas) — perlu karena akun venue baru mendaftar tanpa lapangan.
- Satu akun venue bisa punya beberapa venue (`venues.owner_id`). Tab Jadwal
  menampilkan chip venue saat akun punya lebih dari satu; `selectVenue`
  memfilter slot tanpa request ulang.
- Tab Jadwal: strip 7 hari, filter lapangan, ringkasan terisi/kosong/potensi,
  daftar per lapangan. Tiap header lapangan punya tombol `Ganti foto`. Tap slot
  membuka sheet tutup/buka dan ubah harga slot.
- Slot `Terisi` terkunci; hanya slot kosong yang bisa ditutup. Validasi
  bentrok/watertight sekarang di server (unique + exclusion constraint).
- Soliditas tab Jadwal: smoke `test/jadwal_smoke.dart` render tab di 360x740
  (via dock dan langsung). Karena itu ditemukan dua bug dan sudah diperbaiki:
  shell (`HomeShell` di `app.dart`, `VenueShell` di `venue_shell.dart`) tidak
  lagi memakai `IndexedStack` yang mengganti child saat runtime — pola baru
  `Stack(fit: StackFit.expand)` + child permanen dibungkus `Offstage` +
  `RepaintBoundary`, karena Flutter 3.41 mogok menyematkan semantik saat tree
  child `IndexedStack` diganti. `GhostButton` (core/widgets.dart) diberi
  `mainAxisSize: MainAxisSize.min` supaya bisa dipakai sebagai child tidak-flex
  di `Row` (kasus: tombol `Tambah` dan `Ganti foto`); header lapangan kini
  mem-flex judul dengan ellipsis, jadi tak overflow di lebar sempit.


## Akses room

Backend hanya punya room publik: tidak ada akses link/sandi dan tidak ada
kode undangan. Enum `LobbyAccess` + `lobbyByInviteCode()` masih ada di
`lib/data/state.dart` untuk seed/offline dan tes, tetapi layar tidak lagi
menawarkannya. Tambahkan kembali saat backend punya kolomnya.

## Ikon

Semua ikon dari `Icons` Material (vector), tidak ada emoji di UI.
Olahraga memakai `sports_tennis`, `sports_soccer`, `sports_volleyball`,
`sports_football`; akses memakai `public`, `link`, `lock_outline`.
## Struktur

```
lib/
├── app.dart              # MaterialApp.router + shell dock
├── core/theme.dart       # token warna & tipografi
├── core/money.dart       # split bill, kebijakan penalti, format Rupiah
├── core/widgets.dart     # panel, pill, dock, count card, rank row, segmented
├── data/state.dart       # model + Riverpod (room, wallet, booking, chat, filter)
└── features/{auth(login,register),home,rooms,lobby,create,booking,wallet,profile,community,venue}/
```

State di `data/state.dart` menyimpan seed lalu ditimpa data server; klien HTTP
tipis ada di `data/api.dart`. UI tidak berubah karena angka uang dibaca dari
state, bukan dihitung di widget.

## Warna

Palet desain **"Hijau"** (`DesignReference/SEBAR Mobile — Hijau.html`):

- Latar `#FDFDFC`, kanvas `#FAF9F5`, garis/panel `#D9E0E2`, tinta `#10231A`.
- **Tombol utama `#04BF62`** (`C.primaryFill`), header/terisi `#3EC381`,
  centang/grafik `#0CA458`, teks hijau `#087A41` (`C.primary`, 5,4:1 di putih).
- Bidang terpilih `#E3F6EC` (`C.primarySoft`). Denda `#8A5300` +
  `#FFF1D6`; bahaya/no-show `#B3261E` + `#FCE8E6`. Kuning/merah hanya untuk
  status uang.
- Hijau terang tidak pernah jadi latar teks putih kecil (2:1). **Teks di atas
  hijau selalu tinta gelap** (6,6–7:1), termasuk panel `primaryPanel`.
- Warna tidak menjadi satu-satunya penanda status; selalu ada ikon/label.

## Bahasa visual

- **Kartu datar bergaris tipis** (`SurfaceCard`, `SportPanel`): radius 12,
  tanpa bayangan, tanpa potongan diagonal.
- **Kartu room gaya absen patungan** (`RoomCard`): label olahraga · akses,
  judul, jadwal, venue · lapangan, harga per orang, avatar + sisa slot.
- **Daftar absen bernomor** (`AttendRow`): nomor, nama, tag `host`/`kamu`,
  baris kosong bergaris putus berisi harga per orang.
- **Tiket** (`TicketTile`, `TicketScreen`): blok tanggal, judul, jadwal,
  kode QR besar; tab `Siap dipakai / Menunggu / Selesai`.
- **Dock bawah datar**: 4 tujuan + pil tengah `Buat room` (pemain) /
  `Buka slot` (venue), hijau `#00A27D` dengan teks tinta.
- **Skala tipografi** `T`: 12 label, 12 caption, 13 small, 14 body,
  16 h2, 24 h1, 28 display, 32 metrik. Tidak ada teks di bawah 12px.
- **Foto lapangan dikelola venue** (`CourtPhoto` + `courtPhotosProvider`),
  bisa diganti dari venue: tombol `Ganti foto` di header tiap lapangan (tab
  Jadwal) dan di sheet detail slot. Fallback hijau + ikon bila gagal muat.
- **Teks pengguna tanpa istilah internal**: kode ledger dipetakan ke label
  manusia (`WalletEntryX.typeLabel`), pesan scan memakai kalimat biasa.

Catatan: font desain Rubik belum dibundel (tidak ada aset font); aplikasi
memakai font sistem. Tambahkan `assets/fonts/Rubik*.ttf` + `pubspec.yaml`
bila ingin persis.

## Pembayaran & pembatalan

- Join memakai saldo dompet: dana dikunci (`HOLD`) saat join dan dikonversi
  jadi pembayaran saat kuota penuh. `join(useWallet:)` menyediakan jalur
  QRIS/transfer untuk UI berikutnya; serverannya belum ada.
- Pembatalan: batal **≥ 6 jam** refund penuh, **< 6 jam** slot terkunci (tidak
  bisa keluar), tidak datang dana hangus. Aturan tampil sebelum user setuju.

## Tes

- `test/money_test.dart` - T-01 split bill (ceil + surplus), T-02 denda 15% < 6 jam
- `test/access_test.dart` - akses room, kode undangan, peran akun mitra
- `test/screens_test.dart` - smoke semua layar di 360x740 tanpa overflow
- `test/jadwal_smoke.dart` - smoke tab Jadwal via dock + standalone, 360x740
  (menangkap overflow RenderFlex; lihat "Jadwal venue")
- `test/lobby_detail_test.dart`, `test/widget_test.dart` - render dasar

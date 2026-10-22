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

## Layar

| Route | Layar | Isi |
|---|---|---|
| `/login` | Masuk | Satu form untuk pemain dan mitra; peran dibaca dari akun |
| `/register` | Daftar | Layar terpisah: nama, email, password, ulangi password |
| `/home` | Beranda pemain | Kolom cari, saldo, filter lingkaran olahraga, 5 room teratas + tautan ke semua room |
| `/rooms` | Semua room | Daftar penuh dikelompokkan per tanggal, cari + filter olahraga/kota |
| `/lobby/:id` | Detail room | Foto lapangan + header pekat, ringkasan tagihan bertumpuk |
| - | Sheet join | Split bill, pilihan bayar (dompet / QRIS-transfer), sandi room, checkbox setuju |
| `/create` | Buat room | Pilih venue + lapangan (bukan ketik manual), foto lapangan, harga ikut tarif venue/jam, akses publik/link/sandi |
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
- Sesi disimpan di `authProvider` (in-memory). Saat API ada, ganti dengan
  penyimpanan token; layar tidak berubah.

## Jadwal venue

Sumber data `venueSlotsProvider` di `lib/data/state.dart`:

- Slot punya lapangan, jam, harga, dan status (`Kosong`, `Terisi`,
  `Room berjalan`, `Ditutup`).
- `VenueSlotsNotifier.add()` menolak slot yang tumpang tindih di lapangan
  yang sama — validasi UI sekarang, nanti pindah ke server.
- Sheet tambah slot mengikuti tarif venue: weekday/weekend per jam × durasi
  (1–3 jam), harga dihitung otomatis.
- Tab Jadwal: strip 7 hari, filter lapangan, ringkasan terisi/kosong/potensi,
  daftar per lapangan. Tap slot membuka sheet tutup/buka dan ubah harga.
- Slot `Terisi` terkunci; hanya slot kosong yang bisa ditutup.


## Akses room

Tiga mode, dipilih saat membuat room:

- `Publik` - tampil di daftar `/home`, siapa saja bisa join.
- `Via link` - tidak tampil di daftar. Join lewat kode undangan
  (`VOLI-SORE`) yang dibagikan host.
- `Pakai sandi` - tetap tampil di daftar, tapi join butuh sandi.

Aturan ada di `LobbyAccess` + `LobbiesNotifier.join()` di
`lib/data/state.dart`, jadi saat API masuk validasi pindah ke server tanpa
mengubah layar.

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

State masih in-memory (seed §17.3). Saat API disambungkan: ganti isi
`data/state.dart` dengan repository + Dio, UI tidak berubah karena angka uang
sudah dibaca dari state, bukan dihitung di widget.

## Warna

Satu warna utama, satu aksen, sisanya netral — supaya mata tidak lelah dan
layar tidak ramai:

- **Hijau `#00A27D`** (`C.primaryFill`, #00A27D): aksi, uang, status positif.
  Teks hijau di atas krem memakai `C.primary` `#00664F` (kontras 5,7:1);
  kanvas krem `#EDE8D0`, kartu `#FAF7EA`, teks ink `#1B2B26`.
- **Amber `#F1C338`** (`C.amberFill`): peringatan, denda, hal yang perlu
  ditunda. Teks amber di atas krem memakai `C.amber` `#7A5A0A` (5,2:1).
- **Merah `#A5243C`** (`C.danger`): hanya untuk aksi merusak dan tidak-datang,
  teks/ikon kecil saja. Bukan warna brand.
- Panel pekat (`C.primaryPanel`, `C.inkPanel`, `C.amberPanel`) memakai teks
  putih, rasio ≥ 4,5:1 untuk teks kecil; blok terang untuk teks ink.
- Warna terang (`primaryFill`, `amberFill`) tidak pernah dipakai sebagai
  latar teks putih/kecil — putih di `#00A27D` cuma 3,3:1, di `#F1C338` 1,9:1.
- Aturan pemakaian: maksimal satu bidang berwarna besar per layar, cabang
  olahraga dibedakan lewat ikon + label (bukan warna), dan warna tidak pernah
  jadi satu-satunya penanda status.

## Bahasa visual

Diambil dari referensi:

- **Panel pekat dengan potongan diagonal** (`SportPanel`) — hijau untuk uang
  dan CTA, netral gelap untuk header informasi, amber untuk konteks denda.
- **Angka besar sebagai fokus** (saldo, harga per orang, omzet) di panel
  paling atas tiap layar.
- **Dock bawah mengambang**: kapsul krem, 2 tujuan kiri, 2 kanan, tombol
  tengah berbentuk pil dengan ikon + teks (`Buat room` pemain, `Buka slot`
  venue) supaya aksinya jelas tanpa menebak ikon. Semua layar memakai
  `kScreenPad` (bawah 112) agar baris terakhir tidak tertutup dock + FAB.
- **Skala tipografi**: 11 ukuran saja (12, 13, 15, 15.5, 18, 20, 24, 26, 32,
  34, 40) lewat token `T`; tidak ada teks di bawah 12px.
- **Card hitung + baris peringkat** (`CountCard`, `RankRow`) untuk statistik
  dan papan okupansi; `StatRing` (cincin progres) dipakai di Profil supaya
  angka main/check-in/no-show punya konteks, bukan cuma angka.
- **Foto lapangan dikelola venue** (`CourtPhoto` + `courtPhotosProvider`).
  Venue menekan `Ganti foto` di detail slot dan memilih foto bawaan atau
  menempel tautan; kunci fotonya `venue|lapangan` sehingga room yang memakai
  lapangan itu ikut berubah seketika. Gagal muat → gradien brand + ikon, jadi
  tata letak tetap utuh.
- **Detail room**: header berfoto dengan lapisan gelap pengaman, kartu
  ringkasan bertumpuk dengan cincin kuota di tengah, lalu Detail / Lokasi /
  Peserta.
- **Teks pengguna tanpa istilah internal**: kode ledger (TOPUP/CAPTURE)
  dipetakan ke label manusia (`WalletEntryX.typeLabel`), pesan scan memakai
  kalimat biasa.

## Pembayaran & pembatalan

- Sheet join punya dua opsi: **saldo dompet** (langsung dikunci) atau
  **QRIS/transfer bank** (di luar dompet, instruksi menyusul, slot aman
  15 menit). `LobbiesNotifier.join(..., useWallet: false)` tidak menyentuh
  saldo.
- Pembatalan dua zona: batal **≥ 6 jam** refund penuh, batal **< 6 jam**
  denda **15%** (refund 85%), tidak datang dana hangus. Aturan tampil sebelum
  user setuju.

## Tes

- `test/money_test.dart` - T-01 split bill (ceil + surplus), T-02 denda 15% < 6 jam
- `test/access_test.dart` - akses room, kode undangan, peran akun mitra
- `test/screens_test.dart` - smoke semua layar di 360x740 tanpa overflow
- `test/lobby_detail_test.dart`, `test/widget_test.dart` - render dasar

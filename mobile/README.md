# SEBAR — Sewa Bareng (Flutter)

Frontend MVP untuk patungan sewa lapangan olahraga. Acuan desain: `../SDD_SEBAR.md`
§7 (design token, peta navigasi, layar) dengan bahasa visual dari
`DesignReference/DesignNew.jpg` (kanvas krem, kartu krem, panel pekat
teal/pink/ungu/amber, angka besar, dock bawah dengan aksi utama di tengah).

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
| `/login` | Auth | Pilih akun Pemain atau Venue, email/password |
| `/home` | Beranda pemain | Kolom cari, saldo, skor, filter lingkaran olahraga, linimasa room |
| `/lobby/:id` | Detail room | Header gradien + kartu ringkasan bertumpuk (AppDesign2) |
| - | Sheet join | Split bill, sandi room (jika privat), saldo, checkbox setuju |
| `/create` | Buat room | Pilih venue + lapangan (bukan ketik manual), harga ikut tarif venue/jam, akses publik/link/sandi |
| `/community` | Komunitas | Chat 4 kanal, kirim pesan, waktu lokal |
| `/ticket/:id` | Tiket QR | QR, kode booking, simulasi scan |
| - | Dompet | Saldo tersedia/terkunci, riwayat mutasi, top up |
| - | Profil | Skor + progress, riwayat delta, statistik |
| `/venue` | Shell venue | Beranda omzet, jadwal slot, scan, akun venue + pencairan |
| `/venue/analytics` | Analytics venue | Omzet, okupansi, peak hours, tren pendapatan |

## Dua akun, satu aplikasi

Pola sama seperti GoFood vs GoFood Merchant, tapi satu APK:

- Login memilih peran lewat dua kartu (bukan dropdown). Peran menentukan
  beranda: `AccountRole.player.home` = `/home`,
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
└── features/{auth,home,lobby,create,booking,wallet,profile,community,venue}/
```

State masih in-memory (seed §17.3). Saat API disambungkan: ganti isi
`data/state.dart` dengan repository + Dio, UI tidak berubah karena angka uang
sudah dibaca dari state, bukan dihitung di widget.

## Warna

Mengikuti `DesignReference/DesignNew.jpg`: kanvas krem hangat `#F6EFE7`, kartu
`#FFFCF6`, teks ink `#1C2B29`. Aksen pink `#C93F62` (`C.pinkFill` `#EE5A7E`
untuk bidang non-teks) untuk aksi utama dan saldo, teal `#2E7D70` untuk
omzet/okupansi, amber `#A9660F` (`C.amberFill` `#EFA53A`) untuk denda. Panel
pekat (`C.pinkPanel`, `C.tealPanel`, `C.amberPanel`) memakai teks putih dengan
rasio kontras ≥ 4,5:1 untuk teks kecil; blok terang memakai teks ink.

## Bahasa visual

Diambil dari referensi:

- **Panel gradien pekat dengan potongan diagonal** (`SportPanel`) — teal
  untuk saldo, pink untuk harga, ungu untuk kuota/omzet, amber untuk denda.
- **Angka besar sebagai fokus** (saldo, harga per orang, omzet) di panel
  paling atas tiap layar.
- **Dock bawah mengambang**: kapsul krem, 2 tujuan kiri, 2 kanan, FAB pink
  di tengah tanpa label. Semua layar memakai `kScreenPad` (bawah 112) supaya
  baris terakhir tidak tertutup dock + FAB.
- **Skala tipografi**: 11 ukuran saja (12, 13, 15, 15.5, 18, 20, 24, 26, 32,
  34, 40) lewat token `T`; tidak ada teks di bawah 12px.
- **Daftar room sebagai linimasa**: tanggal di rel kiri, kartu room di kanan.
- **Filter olahraga berbentuk lingkaran**, bukan chip kotak.
- **Detail room**: header gradien penuh, kartu ringkasan bertumpuk dengan
  cincin kuota di tengah, lalu Detail / Lokasi / Peserta.
- **Teks pengguna tanpa istilah internal**: kode ledger (TOPUP/CAPTURE)
  dipetakan ke label manusia (`WalletEntryX.typeLabel`), pesan scan memakai
  kalimat biasa.

## Tes

- `test/money_test.dart` - T-01 split bill (ceil + surplus), T-02 penalti 3 zona
- `test/access_test.dart` - akses room, kode undangan, peran akun mitra
- `test/screens_test.dart` - smoke semua layar di 360x740 tanpa overflow
- `test/lobby_detail_test.dart`, `test/widget_test.dart` - render dasar

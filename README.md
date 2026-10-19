# SEBAR — Sewa Bareng (Flutter)

Frontend MVP untuk patungan sewa lapangan olahraga. Acuan desain: `SDD_SEBAR.md`
§7 (design token, peta navigasi, layar) dengan bahasa visual dari
`DesignReference/` (bidang diagonal, kartu gelap, angka besar, dock bawah
dengan aksi utama di tengah).

## Jalan

```bash
flutter pub get
flutter run                 # Android/iOS
flutter run -d chrome       # web (cek cepat)
flutter test                # 11 tes
```

APK: `flutter build apk --debug` → `build/app/outputs/flutter-apk/`.

## Layar

| Route | Layar | Isi |
|---|---|---|
| `/login` | Auth | Pilih akun Pemain atau Venue, email/password |
| `/home` | Beranda pemain | Saldo, skor, filter lingkaran olahraga, linimasa room, tiket |
| `/lobby/:id` | Detail room | Header gradien + kartu ringkasan bertumpuk (AppDesign2) |
| - | Sheet join | Split bill, sandi room (jika privat), saldo, checkbox setuju |
| `/create` | Buat room | Split bill live, akses publik/link/sandi, kuota/harga/skor |
| `/community` | Komunitas | Chat 4 kanal, kirim pesan, waktu lokal |
| `/ticket/:id` | Tiket QR | QR, kode booking, simulasi scan |
| - | Dompet | Saldo tersedia/terkunci, ledger, top up sandbox |
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
  yang sama — balasan 409 di server nanti, validasi UI sekarang.
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
├── core/widgets.dart     # SportPanel, Pill, dock, sheet, badge skor
├── data/state.dart       # model + Riverpod (room, wallet, booking, chat, filter)
└── features/{auth,home,lobby,create,booking,wallet,profile,community,venue}/
```

State masih in-memory (seed §17.3). Saat API disambungkan: ganti isi
`data/state.dart` dengan repository + Dio, UI tidak berubah karena angka uang
sudah dibaca dari state, bukan dihitung di widget.

## Warna

Mengikuti `DesignReference/AppDesign1..4.png`: latar nyaris hitam `#0A0A0D`,
kartu `#141419`, aksen pink `#FF5F7E` untuk aksi utama dan FAB, ungu
`#8A7BF7` untuk panel info, hijau `#2FD08A` untuk status aman dan omzet,
oranye `#F2A25C` untuk zona denda. Teks putih `#FFFFFF`, muted `#9A9AA8`.

## Bahasa visual

Diambil langsung dari referensi:

- **Kartu gradien dengan potongan diagonal** (`SportPanel`) - pink untuk
  saldo, ungu untuk kuota/harga, hijau untuk omzet, oranye untuk kartu
  lobby ketiga.
- **Angka besar sebagai fokus** (saldo, harga per orang, omzet) di panel
  paling atas tiap layar.
- **Dock bawah**: 2 tujuan kiri, 2 kanan, FAB pink di tengah tanpa label
  supaya tidak menutupi ikon (perbaikan `BugDesignNavbar.png`).
- **Daftar room sebagai linimasa**: tanggal di rel kiri, kartu room di kanan.
  Kuota digambar sebagai titik, bukan progress bar (variasi bentuk).
- **Filter olahraga berbentuk lingkaran gradien**, bukan chip kotak.
- **Detail room bergaya AppDesign2**: header gradien penuh, kartu ringkasan
  bertumpuk dengan cincin kuota di tengah, lalu Detail / Lokasi / Peserta.
- **Pil status kecil** di atas latar transparan putih.
- **Tiap layar beda bentuk**: Home linimasa + lingkaran, detail kartu
  bertumpuk, wallet ledger baris, komunitas bubble, venue tile aksi.

## Tes

- `test/money_test.dart` - T-01 split bill (ceil + surplus), T-02 penalti 3 zona
- `test/access_test.dart` - akses room, kode undangan, peran akun mitra
- `test/screens_test.dart` - smoke semua layar di 360x740 tanpa overflow
- `test/lobby_detail_test.dart`, `test/widget_test.dart` - render dasar

# Patungan v2 — spesifikasi teknis

Aturan bisnis: `revisi/aturan-patungan-v2.md`. Dokumen ini menjelaskan cara aturan itu dijalankan
dengan uang di dompet (hold / release / capture) dan job terjadwal.

## Prinsip uang

- `P` = harga room (tarif lapangan × durasi). Total yang di-capture dari semua orang **selalu tepat P**.
- **Kursi berbayar** = anggota `ACTIVE` + kursi `VACANT` (ditinggal setelah masa bebas, belum ada pengganti).
  `n` = jumlah kursi berbayar.
- Porsi: `s = floor(P / n)`. Kursi host membayar `P − s × (n − 1)` (receh ke host).
- **Pembuat room (penjamin)** hold `P` penuh saat membuat room, dan hold itu tetap utuh sampai join ditutup.
  Saat join ditutup, penjamin hanya di-capture sisa yang belum dibayar anggota lain, lalu sisanya di-release.
- Anggota lain hold porsinya saat join. Hold itu tidak pernah turun sebelum join ditutup.
  - Porsi turun (ada yang join): tidak ada release dulu; selisihnya kembali saat join ditutup.
    Dengan begitu uang yang ditahan tidak bisa ditarik lalu kurang saat porsi naik lagi.
  - Porsi naik di atas hold (ada yang keluar di masa bebas atau di-kick): sistem mencoba hold selisihnya.
    Kalau saldo tidak cukup, anggota itu otomatis `LEFT` dengan refund penuh (`AUTO_LEFT`), lalu porsi
    dihitung ulang. Jaminan penjamin tidak pernah menanggung anggota; hanya kursi `VACANT` yang porsinya
    naik setelah ditinggal yang selisihnya jatuh ke penjamin.
- Join ditutup = `start − 30 menit`, **atau saat host mengunci room** (`POST /lobbies/:id/lock`, kapan saja
  sebelum join ditutup: `closeLobby(..., { early: true })` memajukan `join_deadline` ke `now()`). Capture: tiap kursi non-host dipotong `min(porsi, hold)`,
  penjamin dipotong `P − jumlah itu`. Lalu booking dan payout venue dibuat (fee platform 5% seperti sekarang).

## Status anggota (baru)

| Status | Arti | Bayar room? |
|---|---|---|
| `ACTIVE` | Anggota aktif (termasuk host) | Ya, porsi |
| `VACANT` | Keluar setelah masa bebas, menunggu pengganti | Ya, porsi (hangus kalau tidak diganti) |
| `REPLACED` | Kursinya diisi pengganti | Tidak. Denda `min(10.000, hold)` tetap di-hold sampai room selesai |
| `LEFT` | Keluar di masa bebas, keluar lewat perlindungan, atau di-kick | Tidak, refund penuh |
| `ABSENT` | Keluar setelah join ditutup, atau host yang keluar di hari H | Ya, uang tidak kembali |

- Masa bebas: `free_until = min(joined_at + 2 jam, join_deadline)`. Pengganti tidak dapat masa bebas.
- Join saat ada kursi `VACANT`: joiner mengisi kursi yang paling lama kosong (pengganti), dan `n` tetap.
- Perlindungan: kalau `n` turun karena keluar di masa bebas atau kick, setiap anggota `ACTIVE` non-host yang
  porsi barunya lebih besar dari `share_at_join` mendapat jendela `protect_until = min(sekarang + 30 menit,
  join_deadline)`. Dalam jendela itu, keluar = refund penuh, selama porsi masih di atas `share_at_join`.
  Tidak memilih = lanjut.
- Join ulang room yang sama diblokir 10 menit setelah keluar. Constraint unik `(lobby, user)` diganti dengan
  unik parsial untuk status aktif.

## Host

- **Bubar** boleh sampai `H-1 23.59 WIB`. Room yang dibuat di hari H tidak bisa dibubarkan.
  - Di bawah 2 jam setelah dibuat, atau host sendirian: gratis.
  - Selain itu: denda = porsi kursi host saat itu.
    - 50% dikreditkan ke **dompet pemilik venue**.
    - 50% dibagi rata ke anggota non-host, termasuk yang di-kick host (`kicked`). Receh ke venue.
  - Semua anggota, kursi `VACANT`, dan denda `REPLACED` yang masih di-hold dikembalikan penuh.
- **Host keluar di hari H** (sebelum join ditutup): host jadi `ABSENT`, seperti tidak datang. Kursinya tetap
  dibayar dan tidak bisa diisi pengganti. Hak host pindah ke anggota `ACTIVE` yang paling lama join. Kalau tidak
  ada anggota lain, room tetap jalan dan lapangan tetap terbayar.
- **Kick** sampai join ditutup: refund penuh, `n` turun, aturan perlindungan berlaku. Host yang keluar
  di hari H tidak bisa kick lagi; anggota pertama yang join setelahnya menjadi host.

## Job terjadwal (tiap menit, `setInterval` yang sudah ada)

1. Pengingat 15 menit sebelum `free_until` (sekali per anggota).
2. Jendela perlindungan yang habis ditutup (dianggap lanjut).
3. Join ditutup: capture + booking + payout.
4. Room selesai (`end_at` lewat): denda `REPLACED` di-capture dan dibagi rata ke anggota `ACTIVE`
   (yang masih ikut). Receh ke host.

## Notifikasi (in-app, tabel `notifications`)

`SHARE_CHANGED`, `FREE_PERIOD_ENDING`, `SHARE_PROTECTION`, `AUTO_LEFT`, `KICKED`, `REPLACED`,
`LOBBY_CANCELLED`, `HOST_TRANSFERRED`, `FINE_RECEIVED`, `BOOKING_CONFIRMED`.
API baru: `GET /me/notifications`, `POST /me/notifications/read`, `DELETE /lobbies/:id/members/:userId` (kick).

## Perubahan teknis

- Migrasi `0006_patungan_v2` + `0007_member_kicked`:
  - Enum baru: status anggota (`ACTIVE`, `VACANT`, `REPLACED`, `LEFT`, `ABSENT`) dan ledger `COMPENSATION`.
  - Kolom baru: `lobbies.creator_id`, `lobbies.settled_at`, `lobby_members.share_at_join`, `fine_amount`,
    `free_until`, `protect_until`, `reminded_at`, `kicked`. Join ditutup = `lobbies.join_deadline`
    (sekarang `start − 30 menit`), waktu keluar = `cancelled_at`.
  - Unik `(lobby, user)` diganti index parsial `cancelled_at IS NULL` (boleh join lagi setelah keluar).
  - Fungsi `wallet_credit`; EXECUTE semua fungsi `wallet_*` dicabut dari `PUBLIC`/`anon`/`authenticated`.
  - Membatalkan room `OPEN` sisa data tes (belum ada user asli).
  - Fungsi v1 (`confirm_lobby`, `expire_stale_lobbies`, `cancel_lobby_by_host`, `trg_no_show`) tidak dipakai lagi.
- Trigger lama `trg_member_hold` / `trg_member_cancel` dan cek "deadline 6 jam" di `trg_lobby_validate` dihapus.
  Aturan v2 dijalankan di backend (`lobbies/patungan.service.js`) dalam satu transaksi dengan kunci baris,
  memakai primitif DB `wallet_hold` / `wallet_release` / `wallet_capture` / `wallet_credit`.
- `price_per_person` (kolom generated dari kuota) tidak dipakai lagi. Kuota = batas maksimal kursi.
- Mobile:
  - Teks buat room ("kunci Rp P sebagai host").
  - Detail room: fase, porsi sekarang, tombol keluar dengan penjelasan akibatnya, pilihan perlindungan,
    kick, dan bubar dengan pratinjau denda.
  - Layar notifikasi.

## Yang tidak dikerjakan sekarang

- Push notification (FCM).
- Pembatalan oleh sistem/venue (aturan 9): belum ada jalur pemicunya di app.
  Fungsinya disiapkan nanti saat fitur itu ada.

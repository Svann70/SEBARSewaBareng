List Revisi :
1. Konten tertutup dock dan tombol + di Home, Profil, Scan, dan Jadwal. Padding bawah list cuma 24 (features/home/home_screen.dart:30).
2. Kontras teks putih di panel berwarna gagal WCAG. Di pink rasionya 2,9:1, di ungu 3,3:1, di hijau 2,0:1. Minimal untuk teks kecil 4,5:1.
3. Teks developer muncul ke pengguna, misalnya "dihitung database", "HMAC… ALREADY_CHECKED_IN", "sum(ledger)", "GROUP BY", dan kode TOPUP/CAPTURE.
4. Font terlalu kecil dan ukurannya terlalu banyak. Ada 23 ukuran berbeda, dan 56 tempat pakai font di bawah 12px.
5. Home tidak punya search bar, padahal SDD §7.3 memintanya.
6. Buat room: venue dan lapangan diketik bebas, tidak dipilih dari slot venue yang ada.
7. Scan: teks "Arahkan kamera…" menimpa garis bingkai kamera.
8. untuk pembuatan room dibuat fields form aja, terutama untuk harga lapangan mengikuti harga lapangan nya, biasanya harga lapangan itu per jam dan weekend atau weekdays.



revisi terbaru:
- hapus slogan di auth
- hapus status card saldo
- login pemain dan venue dijadiin satu
- tampilan authentication nya diubah, jadi login sama register dibuat beda biar ngga bingung
- pembayaran bisa dua opsi, dari dompet atau metode pembayaran lainnya (qris, transfer, dsb.)
- nambahin gambar di setiap detail lapangan
-  Denda 15%  dibawah 6 jam
- Skor Reputasi di hilangkan saja
- collor pallete merah ubah ke hijau, pahami penggunaan warna yang baik agar tidak membuat mata lelah, dan terkesan ramai

revisi terbaru ke 2:
1. pov venue bisa customize foto lapangan nya agar bisa terupdate di room yang memilih lapangan tersebut maupun di tempat lain
2. buat page untuk full isinya room, ketika room ada lebih dari 20 room akan susah jika cuman scroll card gitu saja
3. Icon + tambahkan text create room agar lebih mudah di pahami
4. Bagian Profile user dibenerin tolong seperti lingkaran di main, check in, no show dibuat lebih baik dan lebih bagus lagi.
5. Collor pallete nya gunakan #00A27D, #EDE8D0, #F1C338
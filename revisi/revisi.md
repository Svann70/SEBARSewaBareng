List Revisi :
1. Konten tertutup dock dan tombol + di Home, Profil, Scan, dan Jadwal. Padding bawah list cuma 24 (features/home/home_screen.dart:30).
2. Kontras teks putih di panel berwarna gagal WCAG. Di pink rasionya 2,9:1, di ungu 3,3:1, di hijau 2,0:1. Minimal untuk teks kecil 4,5:1.
3. Teks developer muncul ke pengguna, misalnya "dihitung database", "HMAC… ALREADY_CHECKED_IN", "sum(ledger)", "GROUP BY", dan kode TOPUP/CAPTURE.
4. Font terlalu kecil dan ukurannya terlalu banyak. Ada 23 ukuran berbeda, dan 56 tempat pakai font di bawah 12px.
5. Home tidak punya search bar, padahal SDD §7.3 memintanya.
6. Buat room: venue dan lapangan diketik bebas, tidak dipilih dari slot venue yang ada.
7. Scan: teks "Arahkan kamera…" menimpa garis bingkai kamera.
8. untuk pembuatan room dibuat fields form aja, terutama untuk harga lapangan mengikuti harga lapangan nya, biasanya harga lapangan itu per jam dan weekend atau weekdays.
9. Skor Reputasi di hilangkan saja
10. Denda 15%  dibawah 6 jam
11. 
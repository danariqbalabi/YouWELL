# Reduction UAT: rokok dan vape

Keputusan pengembang 15 Oktober 2026: pengurangan bertahap dalam demo 28 hari,
tanpa syarat berhenti total. Menggantikan bagian tangga Delay Craving lama.
Timer jeda, kenaikan durasi menunggu, dan lencana menit ditunda dihapus.

## Perjalanan dan gerak

- 28 hari kalender dari onboarding, tanpa reset karena absen atau pergantian
  path. Hari 29 hanya rekap/riwayat. Total harian yang sudah ada boleh dikoreksi.
- Minggu 1 kenali pola; minggu 2 pilih satu momen; minggu 3 ulangi yang cocok;
  minggu 4 pertahankan dan tinjau catatan.
- Kartu: satu Habit Swap + dua kategori wellness, 0–2 tambahan. Batas sama
  dengan WELLNESS: jalan tanpa lari, maksimal 1,5 km / 20 menit web, makan
  dua foto, hidrasi 2.000 ml, layar off semalam 30 menit. Santai tetap tersedia.
- Rekomendasi menyeimbangkan kategori tujuh hari terakhir, lalu memilih gerak
  saat seri di reduction. Intensitas tidak dinaikkan karena frekuensi merokok.
- Habit Swap menawarkan jalan singkat terlebih dahulu; low-impact menawarkan
  gerak sambil duduk. Pilihan non-gerak tetap tersedia. Setelah dua laporan
  cocok pada produk/pemicu yang sama dengan hasil melewatkan, strategi yang
  dilaporkan membantu dapat diurutkan lebih dahulu. Ini rule-based, bukan ML
  atau bukti efektivitas klinis. Riwayat saran dibatasi tujuh hari terakhir.

## Pemicu → aktivitas → hasil

- Jenis penggunaan: rokok / vape / keduanya. Setiap momen hanya satu jenis.
- Pemicu sama-sama tersedia, urutan berbeda: rokok mulai dari setelah makan
  dan kopi; vape mulai dari layar/game dan bosan. Satu momen boleh punya
  lebih dari satu pemicu (keputusan 17 Okt 2026), sama seperti aktivitas.
  Pengguna boleh menyimpan satu rencana pemicu–aktivitas per jenis tanpa
  dianggap sudah melakukannya.
- Hasil: melewatkan momen, sudah mencoba tetapi tetap menggunakan, atau belum
  mencoba. Dua hasil mencoba memerlukan aktivitas dan menyelesaikan misi
  latihan dengan XP sama. Belum mencoba tersimpan tanpa menyelesaikan misi.
- Bukti dilaporkan sendiri; jalan singkat Habit Swap tidak otomatis memenuhi
  misi jarak GPS/timer gerak. Percobaan hari yang sama sebelum memilih kartu
  dihitung sekali saat commit. Tidak ada XP tambahan dari pengulangan momen.
- Satu ID pengiriman hanya tersimpan sekali. Momen berbeda boleh berdekatan,
  tanpa cooldown sepuluh menit. Form dikosongkan setelah pengiriman berhasil.
- Arsip Habit Swap lama tanpa hasil tetap arsip, tidak dianggap melewatkan.

## Total harian dan target

- Rokok dihitung batang/hari; vape dihitung sesi/hari. Sesi: satu momen memakai
  vape sampai alat disimpan dan pengguna beralih aktivitas. Definisi ditampilkan
  agar digunakan konsisten. Sesi bukan jumlah puff, dosis nikotin, atau batang.
- Keduanya mempunyai kolom terpisah. Tidak ada konversi, penjumlahan, estimasi
  dosis nikotin, atau klaim pengurangan risiko kesehatan dari hitungan ini.
- Satu total sepanjang hari yang dikonfirmasi per tanggal. Nol harus diisi
  eksplisit; kosong/tidak tercatat tetap tidak diketahui. Koreksi menimpa tanggal
  yang sama, tanpa reward. Input harus integer 0–500; batas ini validasi teknis.
- Rata-rata per minggu hanya menggunakan hari yang dikonfirmasi untuk jenis
  tersebut. Perbandingan persentase butuh >=4 hari pada masing-masing minggu.
  Ini ambang cakupan demo, bukan validasi klinis. Baseline nol tidak menghasilkan
  persentase. Minggu 1 menjadi referensi observasi, bukan baseline eksperimen
  tanpa intervensi. Empat minggu ditampilkan beserta jumlah hari tercatat.
- Setelah minggu 1 cukup tercatat, pengguna boleh memilih batas harian untuk
  minggu berjalan, mempertahankan jumlah, atau menghapus target. Tidak ada
  penurunan otomatis berdasarkan XP, misi, atau hasil momen. Batas diinput dalam
  unit masing-masing dari 0 sampai ceil rata-rata awal; tidak dipresentasikan
  sebagai kuota yang perlu dihabiskan. Target rokok dan vape disimpan terpisah.

## Data dan privasi

`reductionSettings`, `reductionPlans`, `habitSwaps`, `nicotineDays`, dan
`reductionTargets` tetap lokal. Ekspor pribadi atas tindakan pengguna mencakup
data ini. Ekspor riset tidak menambahkan konsumsi, produk, pemicu, atau hasil
mentah. `habit_swap_count` menghitung aktivitas dicoba (arsip lama tetap dihitung),
tidak memasukkan laporan belum mencoba. Kolom timer lama tetap terbaca untuk
arsip; tidak ada pencatatan timer baru. Integrasi Supabase/auth masih ditunda.

## Dasar pemilihan fitur

- [Smokefree: aktivitas fisik untuk menghadapi keinginan merokok](https://smokefree.gov/challenges-when-quitting/cravings-triggers/fight-cravings-exercise)
  mendukung pemilihan gerak singkat sebagai strategi pendamping. Aplikasi tidak
  menjanjikan olahraga menghilangkan keinginan atau otomatis menurunkan konsumsi.
- [NHS: mengurangi/berhenti vaping](https://www.nhs.uk/better-health/quit-smoking/ready-to-quit-smoking/vaping-to-quit-smoking/how-to-quit-vaping/)
  membahas konteks, waktu, dan ruang bebas vape. Aplikasi menawarkan pemicu dan
  rencana pengguna; tidak meresepkan penurunan kadar nikotin atau perpindahan produk.

Verifikasi: `reduction_logic_test.dart`, `reduction_diary_test.dart`,
`reduction_support_test.dart`, `retired_delay_test.dart`, ditambah regresi WELLNESS.

# YouWell – Spesifikasi Sistem Challenge

Dokumen ini adalah pelengkap `CLAUDE.md` dan ditaruh di `docs/CHALLENGE_SPEC.md`. Isinya keputusan desain challenge hasil diskusi tim TRIAD (Oktober 2026).

**Aturan utama:** semua personalisasi berbasis aturan (*rule-based*) dan bisa dijelaskan ke pengguna. **Tanpa machine learning.**

## Penghapusan timer path rokok/vape (15 Oktober 2026)

Permintaan terbaru pengembang menggantikan tangga Jeda/timer di bagian lama
dokumen ini: Delay Craving, misi menunggu 2–60 menit, statistik menit ditunda,
dan lencananya dihapus dari alur aktif. Setiap kartu reduction berisi satu
Habit Swap (catat aktivitas pengganti yang sudah dicoba) + dua kategori
wellness. Habit Swap tidak naik menjadi durasi menunggu yang lebih panjang.
Satu catatan hanya menyelesaikan satu misi; extra/bonus baru tidak menduplikasi
Habit Swap inti. Quest timer lama yang masih terbuka/draft dimigrasikan,
sementara quest selesai, XP, dan log historis tetap tersimpan.

Kolom `delay_craving_count`/`delay_craving_completed` dan `ladder_jeda` tetap
dibaca demi kompatibilitas ekspor lama; catatan timer baru tidak dibuat.
`ladder_jeda` pada kartu baru merujuk key Reduction yang tetap di tingkat 1,
bukan kemampuan menunggu. Implementasi lanjutan pada hari yang sama menambahkan
jurnal konsumsi, target opsional, serta periode reduction 28 hari. Aturan
lengkap dan sumber ada di [REDUCTION_UAT.md](REDUCTION_UAT.md): kedua path memakai
batas wellness ringan dan rekomendasi; reduction mengutamakan gerak saat seri.
Habit Swap memerlukan pemicu, aktivitas, jenis penggunaan, serta hasil yang
dilaporkan pengguna. Pengiriman duplikat ditolak berdasarkan ID, tanpa cooldown.
Percobaan sebelum memilih kartu dihitung sekali saat commit; catatan lama
tanpa hasil tidak otomatis menjadi bukti. Kedua hasil mencoba mendapat XP
yang sama; belum mencoba dan total konsumsi tidak memberi XP.

## Penyesuaian WELLNESS UAT 28 hari (14 Oktober 2026)

Bagian ini awalnya berlaku untuk WELLNESS pada 14 Oktober. Pada 15 Oktober,
batas periode dan latihan ringan juga diterapkan pada reduction; alur khusus
rokok/vape mengikuti REDUCTION_UAT.md dan keputusan terbaru di atas.
Tabel tangga lengkap di bawah tetap menjadi referensi jangka panjang.

- Periode adalah 28 **hari kalender** sejak onboarding, bukan 28 hari aktif.
  Melewatkan hari tidak mengulang periode. Hari ke-28 tetap dapat dikerjakan
  sampai akhir hari; mulai hari ke-29 aplikasi menampilkan rekap empat minggu
  dan tidak membuat challenge, bonus, atau catatan aktivitas baru.
- Fokus mingguan: Mulai pelan → Ulangi langkah kecil → Temukan ritmemu →
  Jaga yang cocok. Ini panduan, bukan empat tugas baru yang wajib selesai.
- Arah ritme tetap satu misi pada 4 dari 7 hari; bonus Hari Penuh opsional.
  XP dan progres yang sudah didapat tidak dicabut karena absen.
- Tempo awal tetap 1/2/3. Batas UAT: Gerak 4 (jalan 1,5 km atau 20 menit web,
  tanpa misi lari), Makan 5 (maksimal dua foto), Istirahat 4 (layar off 30 menit
  tentang semalam), Hidrasi 5 (2.000 ml). Kenaikan bukan target wajib.
- Ukuran deck tetap 3/3/4/4/5, dengan Fisher–Yates deterministik per tanggal.
  Rekomendasi mengikuti tempo 3/4/5 misi, mengutamakan kategori yang jarang
  diambil, lalu beban aktivitas lebih ringan. Rekomendasi dapat dibuka sebelum
  reveal acak. Estimasi waktu aktivitas tidak menjumlahkan hidrasi atau jeda
  layar semalam sebagai sesi kerja terus-menerus.
- Naik tetap membutuhkan minimal 3 hari kategori diambil dan completion ≥80%.
  **Hanya bukti dari anak tangga saat ini** yang dihitung. Menerima tawaran
  memulai periode evaluasi baru selama tujuh hari, termasuk penerimaan terlambat.
  Quest kartu yang sudah diambil sebelum naik tetap pada tingkat aslinya.
- Saat kartu dikonfirmasi, air, foto valid, dan sesi gerak yang sudah dicatat
  pada hari yang sama diperiksa. Bukti sebagian tampil sebagai progres; bukti
  lengkap menyelesaikan quest dan memberikan XP sekali. Catatan tanpa foto,
  GPS yang tidak valid, dan aktivitas hari sebelumnya tidak menjadi bukti.
- Draft makan diperiksa lagi saat reveal/konfirmasi. Jika waktunya sudah lewat,
  gunakan alternatif kapan saja di anak tangga yang sama. Kartu yang sudah
  diambil tidak berubah. Jika deadline lewat setelah reveal, tampilkan versi
  baru dan minta konfirmasi ulang tanpa menghabiskan kesempatan ganti.
- Latihan hari Santai ikut menyeimbangkan kategori rekomendasi, tetapi tetap
  tidak menjadi bukti untuk kenaikan tangga.
- Misi tambahan/bonus tetap ringan (≤5 menit); Cahaya Pagi tidak ditawarkan
  setelah tengah hari. Foto dan rute tetap mengikuti batas privasi sebelumnya.

Regression tests dan simulasi 28 hari ada di `test/wellness_uat_test.dart`.

---

## 0. Prinsip desain (berlaku untuk semua misi)

1. **Kecil dan cepat.** Misi harian sebaiknya ≤ 10 - 15 menit kerja aktif.
2. **Target jelas.** Angka atau batas yang konkret ("jalan 10 menit", "minum 1.250 ml"), bukan anjuran umum.
3. **Ada pilihan.** Pengguna memilih fokus, tempo, kartu, dan boleh menolak kenaikan tingkat (otonomi, SDT).
4. **Naik pelan, turun tanpa malu.** Tidak ada streak yang putus, tidak ada hukuman, tidak ada XP yang dikurangi.
5. **Menambah, bukan membatasi.** Terutama untuk makan: **tanpa** kalori, berat badan, atau larangan makan.
6. **Bahasa netral.** Pakai ajakan ("Yuk", "Coba"). Jangan pernah memakai "gagal", "kambuh", "pecandu", atau "malas".
7. **Aman.** Tidak pernah menyarankan tidur lebih sedikit atau olahraga berat bagi pengguna *low-impact*. Quest fisik berat diberi catatan "berhenti jika pusing atau nyeri".

Dasar teori yang dirujuk proposal:
- *graded tasks*, *goal setting*, *self-monitoring*, *feedback on behaviour*, *behaviour substitution* (BCT Ontology, Marques et al., 2024);
- Fogg Behavior Model (*ability* + *prompt*);
- SDT (otonomi, kompetensi, keterhubungan).

---

## 1. Tiga lapis challenge

| Lapis | Fungsi | Frekuensi | Masuk evaluasi tangga? |
|---|---|---|---|
| **Misi tangga** | Inti; makin sulit sesuai kemampuan | Harian, 3 misi per kartu dari **kategori yang diacak** | **Ya** |
| **Misi tambahan** | Variasi ringan | Harian, 0 - 2 misi (sesuai ukuran kartu) | Tidak |
| **Kartu Bonus** | Tambahan XP untuk yang masih semangat | Opsional, maks. 1× per hari, setelah Hari Penuh | Tidak |
| **Tantangan mingguan** | Rasa perjalanan 30 hari (P1) | 1 per minggu (4 fase) | Tidak |

---

## 2. Kategori

**Jalur Better Daily Rhythm** punya 4 kategori hidup sehat, masing-masing dengan tangga sendiri:
- 🚶 **Gerak** (jalan/lari, jarak GPS)
- 🍽️ **Makan** (sarapan, tidak telat makan, buah/sayur, Isi Piringku; validasi foto)
- 💧 **Hidrasi**
- 🌙 **Istirahat** (sementara, lihat §5.2a; nanti diganti **Tidur & Bangun**, P1)

**Jalur Kurangi Rokok/Vape:** ⏸️ **Jeda** selalu ada di setiap kartu, ditambah **2 kategori acak** dari empat kategori di atas.

**Pengacakan (rule-based, bisa dijelaskan):**
- Setiap kartu berisi misi tangga dari **3 kategori berbeda** (rokok/vape: Jeda + 2).
- Kombinasi kategori diurutkan dari yang **paling jarang dikerjakan dalam 7 hari terakhir**, jadi kategori yang tertinggal muncul di sebagian besar kartu (Better Daily Rhythm: minimal 4 dari 5 kartu; setiap kategori minimal di 3 kartu).
- Seri imbang diacak berdasarkan tanggal (deterministik, tanpa ML).
- Setiap kategori menyimpan posisi tangganya sendiri; posisi tidak hilang meski kategori jarang muncul.

---

## 3. Onboarding: input dan pengaruhnya

| Input | Pengaruh |
|---|---|
| Login Google | Akun (lihat `CLAUDE.md` §2) |
| Usia | Tiga pilihan: **Di atas 22 / 18 - 22 / Di bawah 18** (tanpa pertanyaan lanjutan, keputusan tim 7 Okt 2026). Di jalur rokok/vape, "Di bawah 18" dan "18 - 22" memakai copy **"menuju berhenti"** (PP 28/2024 Pasal 434); "Di atas 22" memakai copy biasa |
| Jalur | Better Daily Rhythm / Kurangi Rokok/Vape |
| Jenis & frekuensi (khusus rokok/vape) | Rokok / vape / keduanya; perkiraan sesi per hari. Dipakai untuk tangga Jeda anak tangga 8 - 9. **Hanya disimpan di HP, tidak disinkronkan** (§10a) |
| Kategori | Tidak dipilih di onboarding; diacak per kartu (§2) |
| Tempo | Santai / Sedang / Siap gerak = 1 / 2 / 3 → **anak tangga awal** semua kategori, dan kartu yang ditandai **"Cocok buatmu"** (3 / 4 / 5 misi) |
| Aktivitas ringan (*low-impact*) | Tangga Gerak dibatasi maksimal di anak tangga 4 |
| Jam tidur & bangun biasa, jam bangun target | Wajib jika fokus Tidur & Bangun dipilih (P1). Menjadi dasar target relatif (§5.2). **Hanya disimpan di HP, tidak disinkronkan** (§10a) |
| Alias & companion | Tampilan saja; tidak memengaruhi misi |

---

## 4. Alur harian

1. **Buka aplikasi di hari baru.** Hari dicatat sebagai "dibuka" (dipakai untuk `active_days`). Evaluasi tangga berjalan jika sudah ≥ 7 hari sejak evaluasi terakhir (§8).
2. **Pilih mode hari ini: Normal / Santai.**
   - Santai: semua kartu berisi 3 misi, misi tangga turun 1 anak tangga (minimal 1), dan ditandai `practiceOnly = true`.
3. **Draw kartu.** 5 kartu, isinya **3, 3, 4, 4, 5 misi** (urutan diacak per tanggal). Pengguna boleh ganti 1 kali; setelah diambil, misi terkunci untuk hari itu. Teks UI: **"Pilih fokus tambahan hari ini"**.
   - Judul kartu = kombinasi kategorinya, misalnya "Gerak · Makan · Hidrasi". Label ukuran: **Ringan** (3) / **Sedang** (4) / **Penuh** (5).
   - Isi kartu: **3 misi tangga** dari kategori kartu itu + **0 - 2 misi tambahan**.
   - **Tempo** tidak lagi menentukan jumlah misi; tempo hanya menandai satu kartu **"Cocok buatmu"** (Santai 3, Sedang 4, Siap gerak 5). Kartu lain tetap boleh dipilih.
4. **Kerjakan misi.** Validasi mengikuti §7.
5. **Hari Penuh.** Semua misi kartu selesai memberi +20 XP (sekali sehari) dan layar "Kerja bagus!".
6. **Kartu Bonus (opsional).** Setelah Hari Penuh, muncul tawaran 1 Kartu Bonus: 3 misi ringan, masing-masing +15 XP, tanpa misi tangga, tanpa misi berat, dan tidak mengulang misi yang sudah ada hari itu. Maksimal 1× per hari, tanpa bonus Hari Penuh kedua.

---

## 5. Tangga per kategori

Setiap kategori punya `maxStep` sendiri. XP misi tangga = **15 + 5 × anak tangga**.

### 5.1 🚶 Gerak (maxStep 10; *low-impact* maksimal 4)

**Semua misi dihitung dari jarak GPS.** Waktu saja tidak pernah menyelesaikan misi (tidak ada jalan pintas durasi). Tanpa izin lokasi, misi Gerak tidak bisa selesai; aplikasi meminta lokasi dinyalakan dengan teks "Rute tidak disimpan". Sesi tetap menghitung jarak saat layar terkunci atau aplikasi di latar belakang. **Versi web (iPhone):** browser tidak bisa melacak GPS saat layar terkunci, jadi setiap anak tangga punya kembaran berbasis waktu (400 m ↔ 5 menit … 5 km ↔ 40 menit) dan misi selesai dari lama sesi.

| # | Misi | Target jarak | Perkiraan waktu |
|---|---|---|---|
| 1 | Jalan 400 m | 400 m | ±5 menit |
| 2 | Jalan 800 m | 800 m | ±10 menit |
| 3 | Jalan cepat 1,2 km | 1.200 m | ±15 menit |
| 4 | Jalan 1,5 km | 1.500 m | ±20 menit |
| 5 | Interval jalan-lari 2 km (1 menit lari / 2 menit jalan) | 2.000 m | ±20 menit |
| 6 | Interval jalan-lari 2,5 km | 2.500 m | ±25 menit |
| 7 | Lari santai 2 km | 2.000 m | ±16 menit |
| 8 | Lari 3 km | 3.000 m | ±24 menit |
| 9 | Lari 4 km | 4.000 m | ±30 menit |
| 10 | Lari 5 km | 5.000 m | ±38 menit |

Anak tangga 3 ke atas diberi catatan "berhenti jika pusing atau nyeri".

### 5.2 🌙 Tidur & Bangun (maxStep 10, target **relatif**)

**Input:**
- `usualBed` = jam tidur biasa
- `usualWake` = jam bangun biasa
- `targetWake` = jam bangun yang diinginkan

**Pergeseran:** jam tidur target = `usualBed − shift`, dengan `shift` naik 15 menit per tahap (15, 30, 45, 60 menit).

**Batas aman:**
- Jangan majukan jam tidur lagi jika durasi tidur yang direncanakan (`targetWake − jam tidur target`) sudah ≥ 8 jam.
- Jangan pernah membuat rencana tidur < 7 jam atau > 9 jam. Jika `usualBed` sudah memenuhi 7 - 9 jam, misi pergeseran diganti misi **konsistensi**.

| # | Misi | Contoh (biasa tidur 01.00, bangun 08.00; target bangun 07.00) |
|---|---|---|
| 1 | Catat jam tidur & bangun (tanpa target) | Titik awal |
| 2 | Layar off 15 menit sebelum tidur | — |
| 3 | Tidur 15 menit lebih awal dari biasa | Sebelum 00.45 |
| 4 | Bangun di jam target ±30 menit | 06.30 - 07.30 |
| 5 | Tidur 30 menit lebih awal + layar off 30 menit | Sebelum 00.30 |
| 6 | Bangun di jam target 2 hari berturut | — |
| 7 | Tidur 45 menit lebih awal | Sebelum 00.15 |
| 8 | Jam tidur & bangun konsisten 3 hari (±30 menit) | — |
| 9 | Tidur 60 menit lebih awal **atau** durasi tidur 7 - 9 jam | Sebelum 00.00 |
| 10 | Ritme stabil 5 dari 7 hari, termasuk akhir pekan (selisih ≤ 1 jam) | — |

**Definisi hari (penting):** misi tidur di kartu hari ini **selalu tentang semalam**. Contohnya: "Semalam tidur sebelum 00.45?". Misi ini diselesaikan lewat **check-in pagi hari ini**, jadi satu misi hanya milik satu kartu dan Hari Penuh tetap bisa dicapai di hari yang sama. Tidak ada jendela lintas hari.

**Validasi lewat check-in pagi:**
- Saat aplikasi pertama dibuka sebelum pukul 12.00, tanyakan: "Semalam tidur jam berapa? Bangun jam berapa?"
- **Misi tidur dan layar off (tentang semalam):** selesai dari jawaban check-in.
- **Misi bangun:** semi-otomatis jika waktu check-in jatuh di jendela target. Selain itu, pakai jawaban check-in.
- **Kalau check-in terlewat (aplikasi baru dibuka setelah 12.00):** pertanyaan tetap bisa dijawab sampai pukul 23.59 hari itu.
- **Konsistensi (6, 8, 10):** dihitung otomatis dari riwayat check-in.
- Jam tidur dan bangun mentah **hanya disimpan di HP**. Yang disinkronkan hanya status misi selesai atau tidak.

### 5.2a 🌙 Istirahat (sementara, berlaku sampai Tidur & Bangun siap)

Tangga Istirahat: layar off 10 → 15 → 20 → 30 → 45 → 60 menit sebelum tidur, lalu jam tidur tetap.
- Misi selalu **tentang semalam**: "Semalam: layar off 15 menit sebelum tidur". Pengguna tidak perlu memegang HP menjelang tidur untuk mencentang.
- Bisa dicentang **kapan saja di hari itu** (idealnya pagi). Tidak ada kunci jam.
- Misi tetap milik kartu hari itu.

### 5.3 💧 Hidrasi (maxStep 5 untuk UAT; anak tangga 6 - 7 = P1)

| # | Misi | Validasi |
|---|---|---|
| 1 | Minum 1.000 ml | Tombol +250 ml |
| 2 | Minum 1.250 ml | 〃 |
| 3 | Minum 1.500 ml | 〃 |
| 4 | Minum 1.750 ml | 〃 |
| 5 | Minum 2.000 ml | 〃 |
| 6 | 2.000 ml, gelas pertama sebelum 09.00 *(P1: butuh jam per ketukan +250 ml)* | 〃 + waktu |
| 7 | 2.000 ml tersebar pagi, siang, dan sore (masing-masing ≥ 500 ml) | 〃 + waktu |

### 5.4 🍽️ Makan (maxStep 10, **tanpa** kalori atau larangan)

Validasi: **foto dari kamera** (bukan galeri). Jam foto dipakai sebagai bukti waktu. Isi foto **tidak dinilai** (penilaian isi butuh ML, di luar cakupan proposal).

| # | Misi | Foto | Jendela waktu |
|---|---|---|---|
| 1 | Sarapan sebelum 10.00 | 1 | 04.00 - 10.00 |
| 2 | Makan siang tepat waktu | 1 | 10.00 - 14.00 |
| 3 | Tambah 1 porsi buah atau sayur | 1 | kapan saja |
| 4 | Sarapan & makan siang tepat waktu | 2 | 04.00 - 10.00 dan 10.00 - 14.00 |
| 5 | 2 porsi buah atau sayur hari ini | 2 | kapan saja |
| 6 | Ganti 1 minuman manis dengan air putih | 1 | kapan saja |
| 7 | Makan 3 kali dengan jam teratur | 3 | pagi < 10.00, siang 10.00 - 15.00, malam 17.00 - 21.00 |
| 8 | 1 piring "Isi Piringku" (setengah sayur dan buah) | 1 | kapan saja |
| 9 | 3 porsi buah atau sayur hari ini | 3 | kapan saja |
| 10 | 2 piring "Isi Piringku" hari ini | 2 | kapan saja |

Aturan:
- Setiap jendela butuh fotonya sendiri; satu foto tidak dihitung dua kali.
- Jika sebagian foto sudah ada, misi tampil "1/2 foto" dan dihitung **sebagian** di evaluasi tangga.
- Jika saat kartu dibuat jendela waktunya **sudah lewat** (misalnya kartu dibuat pukul 13.00 untuk "Sarapan"), misi diganti versi **kapan saja di anak tangga yang sama**: 1 & 2 → "Tambah 1 porsi buah atau sayur", 4 → "2 porsi buah atau sayur", 7 → "3 porsi buah atau sayur".
- Kartu misi menampilkan syarat fotonya, misalnya "Foto 10.00–14.00."
- Izin kamera ditolak → misi Makan tetap di anak tangga yang sama tapi cukup dicentang.

### 5.5 ⏸️ Jeda (khusus jalur rokok/vape, maxStep 10)

| # | Misi | Validasi |
|---|---|---|
| 1 | Tunda 2 menit saat dorongan muncul | Timer |
| 2 | Tunda 5 menit | Timer |
| 3 | Tunda 10 menit | Timer |
| 4 | Tunda 15 menit + catat pemicunya | Timer + pilihan pemicu |
| 5 | Tunda rokok/vape pertama 30 menit setelah bangun | Centang |
| 6 | Tunda yang pertama 1 jam | Centang |
| 7 | Satu "zona bebas" seharian (dipilih pengguna) | Centang |
| 8 | Kurangi 1 sesi dari biasanya | Centang |
| 9 | Kurangi 2 sesi | Centang |
| 10 | Satu hari penuh bebas rokok/vape | Centang |

Aturan timer:
- Tercatat penuh jika timer habis.
- Jika dihentikan, catat "ditunda X menit" sebagai nilai **sebagian**, bukan kegagalan.

---

## 6. Misi tambahan (+20 XP, ≤ 5 menit)

Jumlah per kartu = ukuran kartu − 3 (kartu 3 misi: 0, kartu 4: 1, kartu 5: 2). Hari Santai: 0.

Pool saat ini: Rapikan postur · Stretching ringan · Ubah posisi sebentar · Cari cahaya pagi · Jeda layar · Cari udara segar · Tambahkan buah atau sayur · Catat satu momen makan (foto) · Satu gelas air · (rokok/vape) Coba 1 Habit Swap · Kenali satu pemicu · Rencana Habit Swap. Di jalur rokok/vape, Habit Swap diutamakan.

Larangan (supaya satu aksi tidak memberi XP dua kali):
- Tidak ada misi air tambahan di kartu yang memuat tangga **Hidrasi**.
- Tidak ada misi makan tambahan ("Catat satu momen makan", "Tambahkan buah atau sayur") di kartu yang memuat tangga **Makan**. Aturan yang sama berlaku untuk Kartu Bonus.
- Misi foto tidak muncul jika kamera tidak tersedia.

Validasi misi tambahan: centang sendiri, kecuali Meal Snap (foto) dan segelas air (tombol +250 ml).

Pool baru di versi awal dokumen ini (naik tangga, bangun tanpa *snooze*, dll.) masuk **P1**.

---

## 7. Validasi (ringkas)

| Jenis | Aturan |
|---|---|
| **GPS** | Selesai jika **jarak ≥ target**; durasi tidak pernah menggantikan jarak. Tolak sesi dengan kecepatan rata-rata > 20 km/jam. Kurang dari target: "tercapai sebagian X%". Penyaring derau: titik GPS di dalam lingkaran akurasinya diabaikan (duduk diam tidak menambah jarak), lompatan > 7 m/detik diabaikan. Simpan hanya meter & durasi; **rute tidak disimpan** |
| **Timer** | Delay Craving: timer harus habis |
| **Foto (Makan & Meal Snap)** | **Wajib dari kamera**, jam foto mengikuti jendela misi (§5.4). Catatan tanpa foto masuk jurnal tapi tidak menyelesaikan misi. Foto tetap di perangkat dan tidak diunggah. **Izin kamera ditolak:** misi foto berubah jadi centang |
| **Tombol air** | Akumulasi +250 ml |
| **Centang** | Mandiri. Misi Istirahat tentang semalam, bisa dicentang kapan saja hari itu |

---

## 8. Evaluasi tangga mingguan (per kategori)

Evaluasi berjalan saat ≥ 7 hari sejak evaluasi terakhir kategori itu.

**Data yang dihitung:** misi tangga yang diambil dalam 7 hari terakhir. Misi latihan (hari Santai) dan sesi yang dihapus **tidak dihitung**.

**Rumus:**
- `completion` = (misi selesai + jumlah nilai sebagian) ÷ misi yang diambil
- `cardDays` = jumlah hari **kategori ini** dikerjakan (misi tangganya ada di kartu yang diambil) dalam 7 hari (**bukan** `active_days` di §10)

Penilaian usaha *Ringan / Pas / Berat* **dihapus** (revisi 7 Okt 2026): tangga dievaluasi hanya dari selesai atau tidaknya misi. Misi yang terlalu berat terlihat dari penyelesaian yang turun (termasuk jarak GPS sebagian), dan kenaikan tetap hanya ditawarkan.

| Kondisi | Hasil |
|---|---|
| Tidak menyelesaikan misi apa pun ≥ 5 hari | **Turun 1** + pesan "Selamat datang lagi" |
| `completion` < 50% | **Turun 1** |
| `cardDays` ≥ 3 **dan** `completion` ≥ 80% | **Tawarkan naik 1** (pengguna memilih "Naik" atau "Tetap di level ini") |
| Selain itu, atau belum ada misi | **Tahan** |

**Batasan:**
- Naik maksimal 1 anak tangga per minggu.
- Tidak boleh kurang dari 1 atau melebihi `maxStep`, termasuk batas *low-impact*.
- Menerima tawaran naik membuat ulang kartu hari ini, **asalkan** kartu belum diambil.
- Setiap keputusan menyimpan **alasan** yang tampil di halaman Perjalanan, misalnya "Naik karena 6 dari 7 quest Gerak selesai."

```dart
LadderDecision evaluate({
  required int current, required int maxStep,
  required double completion, required int cardDays,
  required int inactiveDays,
}) {
  if (inactiveDays >= 5) return LadderDecision.down(current, maxStep, reason: 'welcome_back');
  if (completion < .5) return LadderDecision.down(current, maxStep, reason: 'too_hard');
  // 3, not 4: categories rotate across cards (revisi 7 Okt 2026).
  if (cardDays >= 3 && completion >= .8) {
    return LadderDecision.offerUp(current, maxStep, reason: 'ready');
  }
  return LadderDecision.hold(current, reason: cardDays < 3 ? 'need_more_days' : 'steady');
}
```

---

## 9. XP, level, dan fase 30 hari

**XP:**

| Sumber | XP |
|---|---|
| Misi tangga | 15 + 5 × anak tangga |
| Misi tambahan | 20 |
| Hari Penuh | 20 (sekali sehari) |

**Level dengan kurva naik:**
- Level 1 → 2 butuh 100 XP, 2 → 3 butuh 150 XP, dan seterusnya bertambah 50 XP per level.
- Rumus: XP untuk naik dari level *n* = 100 + 50 × (*n* − 1).
- Perkiraan: pengguna tempo Sedang mencapai ±level 9 jika aktif ±20 hari, dan ±level 11 jika aktif penuh 30 hari. Target realistis **±8 - 11 level dalam 30 hari**.
- Level hanya naik, tidak pernah turun.
- **Migrasi:** simpan `levelFloor` = level tertinggi yang pernah dicapai (diisi dari level lama saat migrasi). Level yang tampil = `max(levelFloor, levelDariXP)`. Bar progres menghitung XP menuju level berikutnya di atas level yang tampil.
- **Companion tumbuh mengikuti level** (tahap tumbuh dan hadiah per level, seperti di kode sekarang).
- **Ambang tahap companion: level 1 / 3 / 5 / 7 / 9.** Diukur dari kasus paling lambat (Santai, tidak pernah naik tangga, semua misi selesai tiap hari = 80 XP/hari ≈ 2.240 XP di hari ke-28 = level 9), jadi siapa pun yang mengerjakan semua misi setiap hari mencapai tahap 5 paling lambat di minggu ke-4.

**Fase mingguan** (dihitung dari tanggal mulai):

| Minggu | Fase | Tantangan (cukup 4 dari 7 hari, tanpa streak) | Hadiah |
|---|---|---|---|
| 1 | Mulai | Ambil kartu & selesaikan ≥ 1 misi tangga | Lencana "Mulai" |
| 2 | Bangun ritme | Selesaikan semua misi tangga | Lencana "Ritme" |
| 3 | Konsisten | Lengkapi Hari Penuh | Lencana "Konsisten" |
| 4 | Mantap | Coba 1 misi di anak tangga baru | Lencana "Mantap" |

Fase **tidak** menggerakkan companion. Setelah minggu ke-4, fase berulang mulai dari "Bangun ritme" dengan ringkasan bulan sebelumnya.

**Lencana otomatis:**
- misi pertama;
- Hari Penuh pertama;
- ritme 4 hari dalam satu minggu;
- 7 hari hidrasi;
- naik tangga pertama;
- check-in pagi 5 kali;
- fase pertama selesai.

---

## 10. Dampak ke data penelitian (`research_logs`)

Tambahkan kolom posisi tangga per kategori. Kolom boleh kosong (*nullable*) jika kategori tidak dipilih:

```
ladder_gerak, ladder_tidur, ladder_hidrasi, ladder_makan, ladder_jeda
```

**Aturan perhitungan:**
- `opened_days`: jumlah **hari** aplikasi dibuka dalam minggu itu (0–7). Ini kolom "Frekuensi membuka aplikasi" di tabel log; yang dihitung hari, bukan berapa kali dibuka.
- `active_days`: hari aplikasi **dibuka** atau ≥ 1 misi selesai. Ini sesuai definisi "aktif" di proposal.
- `active`: `active_days` > 0 (kolom "Status aktif ya/tidak").
- `delay_craving_count`: semua pemakaian Delay Craving, termasuk timer yang dihentikan ("ditunda X menit", bukan kegagalan). `delay_craving_completed`: hanya timer yang selesai penuh.
- `quests_done`: semua misi kartu yang selesai, **termasuk** misi latihan di hari Santai, **tidak termasuk** misi Kartu Bonus. Misi latihan hanya dikecualikan dari evaluasi tangga.
- `ladder_makan` terisi dari tangga Makan; `ladder_tidur` masih kosong sampai Tidur & Bangun dibuat.

**Larangan:** jangan tambahkan jam tidur mentah, foto, lokasi, atau teks bebas ke `research_logs`.

### 10a. Data yang hanya disimpan di HP (tidak disinkronkan)

| Data | Alasan |
|---|---|
| Jenis & frekuensi rokok/vape | Data pribadi spesifik (UU PDP Pasal 4 ayat 2); tidak tercantum di Tabel 3.3 proposal |
| Jam tidur/bangun biasa & jawaban check-in | Tidak tercantum di Tabel 3.3; cukup status misinya yang disinkronkan |
| Foto Meal Snap | Sudah diatur di proposal |

Yang disinkronkan ke `progress_days` hanya posisi tangga, status misi, XP, dan jarak/durasi, sesuai baris "Data progres aplikasi" di Tabel 3.3.

Jika kelak data di atas perlu disinkronkan, **wajib** ada layar persetujuan eksplisit, dan proposal (Tabel 3.3) harus diperbarui dulu.

---

## 11. Prioritas implementasi

UAT dimulai sekitar 24 Oktober 2026. Pekerjaan infrastruktur (Supabase, Login Google, sinkronisasi, Community nyata, admin, pengiriman `research_logs`) tetap lebih prioritas dan dikerjakan setelah ini.

**Sudah dikerjakan (7 Okt 2026):**
1. Kategori acak per kartu (Gerak, Makan, Hidrasi, Istirahat; rokok/vape: Jeda + 2), diprioritaskan kategori yang paling jarang dikerjakan (§2).
2. Kartu 3/3/4/4/5 misi + kartu "Cocok buatmu" dari tempo (§4).
3. Kartu Bonus 1× per hari setelah Hari Penuh (§4, §6).
4. Tangga Makan 10 anak tangga dengan foto & jendela waktu + versi kapan saja (§5.4).
5. Gerak wajib jarak GPS + penyaring derau GPS (§5.1, §7).
6. Istirahat "tentang semalam", tanpa kunci jam (§5.2a).
7. Syarat naik `cardDays` ≥ 3 per kategori (§8).
8. Larangan XP ganda air & makan (§6).
9. Meal Snap kamera saja + pengganti centang jika kamera ditolak (§7).
10. Kurva level + `levelFloor`, tahap companion di level 1/3/5/7/9 (§9).
11. Kolom `research_logs` per kategori termasuk `ladder_makan`; `quests_done` tanpa Kartu Bonus (§10).

**P1:**
- Kategori **Tidur & Bangun** + check-in pagi (§5.2), menggantikan Istirahat.
- Pool misi tambahan baru, Hidrasi anak tangga 6 - 7, tangga Jeda 7 - 10.
- Tantangan mingguan + lencana fase.

**P2:**
- Pengenalan foto makanan on-device (butuh ML; proposal harus diubah dulu).
- Pedometer untuk Gerak dalam ruangan.

**Konsekuensi ke dokumen lain:** Danar perlu tahu bahwa syarat naik kini ≥ 3 kali per kategori, `ladder_makan` terisi, dan `quests_done` tidak memuat Kartu Bonus.

---

## 12. Uji penerimaan (contoh kasus)

Semua kasus di bawah dijalankan otomatis di `test/challenge_spec_test.dart`.

| Kasus | Harapan |
|---|---|
| Kartu hari ini | 5 kartu berisi 3, 3, 4, 4, 5 misi |
| Isi kartu | 3 misi tangga dari 3 kategori berbeda |
| Better Daily Rhythm | Setiap kategori ada di minimal 3 kartu |
| Rokok/vape | Jeda di setiap kartu + 2 kategori lain |
| Istirahat tidak pernah diambil 3 hari | Istirahat muncul di minimal 4 dari 5 kartu |
| Tempo Santai / Sedang / Siap gerak | Satu kartu 3 / 4 / 5 misi bertanda "Cocok buatmu" |
| Hari Santai | Semua kartu 3 misi, anak tangga − 1, ditandai latihan |
| Kartu memuat Hidrasi / Makan | Tidak ada misi air / makan tambahan |
| Kategori dikerjakan 2 kali seminggu, semua selesai | **Tahan** (butuh minimal 3 kali) |
| Kategori dikerjakan 3 kali, semua selesai | **Tawaran naik** |
| *Low-impact* | Berhenti di anak tangga 4, tidak ditawari lari |
| Jalan 1 jam, 0 meter | Misi tidak selesai |
| Jalan 400 dari 800 m | Sebagian 50%; 800 m → selesai |
| 800 m dalam 1 menit | Ditolak (> 20 km/jam) |
| Foto sarapan 08.30 | Selesai; foto 11.00 tidak dihitung sebagai sarapan |
| Misi 2 foto, baru 1 | Sebagian (1/2 foto) |
| Catatan tanpa foto | Misi makan tidak selesai |
| Kartu dibuat pukul 13.00, tangga Makan 1 | Diganti "Tambah 1 porsi buah atau sayur" |
| Kamera ditolak | Misi Makan jadi centang, anak tangga tetap |
| Misi Istirahat pukul 08.00 | Bisa dicentang ("Semalam: …") |
| Kartu Bonus | Hanya setelah semua misi kartu selesai, 3 misi × 15 XP, sekali sehari |
| Kartu Bonus diselesaikan | Tidak menambah `quests_done`, Hari Penuh tetap tercatat |
| Pengguna lama 715 XP | Tetap tampil level 8 |
| Semua misi tiap hari, Santai, tidak pernah naik | Companion tahap 5 paling lambat minggu ke-4 |
| Hari Santai seminggu | `quests_done` 21, tangga tidak berubah |
| Jalur vape, usia "18 - 22" / "Di atas 22" | "Berhenti" / "Kurangi" |

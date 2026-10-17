# Sinkron profil dan progres — tahap 2

## Aktifkan pada Supabase

Tahap 1 Google Login harus sudah berhasil. Pada project yang sama, buka SQL
Editor dan jalankan seluruh isi file ini sekali:

`supabase/migrations/20261016120000_create_progress_sync.sql`

Migration tidak menghapus data yang sudah ada. Ia menambahkan:

- `public.youwell_progress`: satu snapshot per UID, revision, payload JSON dan waktu server.
- RPC `save_youwell_progress`: menulis snapshot + alias secara atomik, dengan
  pengecekan versi; tidak menerima parameter UID dari aplikasi.
- RLS read-own; client tidak diberi izin tulis langsung ke progres/alias.
- Pemeriksaan field yang hanya boleh ada di perangkat, termasuk di JSON nested.

Setelah migration dan deploy terbaru, buka aplikasi lalu selesaikan onboarding
atau tunggu sinkron progres lama. Table Editor akan menampilkan satu baris alias
di `youwell_profiles` dan satu snapshot di `youwell_progress` untuk setiap akun
yang mempunyai profil. Quest/log berada di dalam `payload`, bukan satu tabel
baru untuk setiap quest. Login saja tanpa membuat profil belum membuat baris.

## Yang disinkronkan

Alias, jalur, companion, rentang usia/preferensi onboarding, tanggal mulai,
quest/kartu yang dipilih, task selesai, XP, level, tangga, lencana, reward,
hidrasi, hari aplikasi dibuka, dan metadata aktivitas (durasi/meter, waktu
check-in foto, jumlah/durasi Delay Craving lama, serta ID + tanggal Habit Swap).

File foto, `photoPath`, rute/koordinat, catatan bebas, isi Habit Swap pribadi,
komunitas demo, teks Micro-Vent/fokus lama, P-code/persetujuan penelitian,
token auth, dan offset simulasi hari **tidak dikirim dalam snapshot**.
Jurnal konsumsi, jenis produk, target mingguan, rencana pengganti, serta detail
pemicu/aktivitas/hasil Habit Swap juga tetap lokal. Saat menerapkan cloud,
detail momen dan ID pengiriman lokal dipertahankan hanya untuk ID momen yang
cocok; perangkat lain hanya menerima tanggal momen (bukan jam atau hasil),
agar cloud tidak menyimpan log jam craving. Client dan server sama-sama menolak
kunci mentah rokok/vape (`product`, `trigger`, `outcome`, `nicotineDays`, ...).
Tidak ada upload ke Supabase Storage. Teks judul/deskripsi quest adalah katalog
aplikasi, bukan catatan pengguna. Research logs terpisah dari snapshot ini
(migration tahap 3, lihat `SUPABASE_SETUP.md`).

Jika balasan simpan hilang tetapi server sudah menyimpan, salinan cloud yang
sama persis dengan unggahan terakhir dianggap tersimpan (bukan konflik).
Perubahan yang dibuat saat sinkron berjalan dikirim pada putaran berikutnya.
Cache lokal yang tidak bisa dibaca disimpan terpisah (`.unreadable`) lalu akun
mengambil salinan cloud, sehingga cache rusak tidak pernah menimpa cloud.

Metadata `photoCaptured` menjaga bukti quest tanpa memindahkan file fotonya.
Foto/catatan yang ID-nya cocok tetap terbaca pada perangkat asal; perangkat
lain hanya melihat check-in tanpa gambar/catatan. Pengaturan izin kamera tetap
lokal. Progress reset bukan penghapusan akun Supabase.

## Perilaku sinkron

1. Login membaca cache per akun + cloud dengan batas waktu. Cache tetap bisa
   digunakan bila cloud/migration belum tersedia; ada status belum sinkron.
2. Perangkat baru memakai cloud. Cache yang terakhir diketahui bersih bisa
   diperbarui dari cloud pada awal sesi; salinan lokal sebelumnya dicadangkan.
3. Progres tamu/versi lama yang berbeda dengan cloud meminta pilihan eksplisit.
   Tidak memilih berdasarkan XP terbesar atau jam perangkat.
4. Perubahan disimpan ke cache dahulu; upload dikelompokkan dengan debounce
   dua detik. Aplikasi memeriksa versi cloud saat kembali aktif dan tiap 30
   detik di foreground. Poll hanya membaca revision kecil bila tidak berubah.
5. Penulisan memakai expected revision. Versi yang berubah menghasilkan konflik,
   bukan penimpaan. Retry setelah respons hilang mengenali snapshot identik
   sehingga tidak menambah reward/revisi dua kali.
6. Update cloud saat aplikasi sedang dipakai tidak mengganti timer/draw yang
   terbuka. Banner dan panel Profil meminta pengguna memilih salinan.
7. Sebelum menerapkan pilihan, aplikasi menutup route interaktif, menunggu cache
   lokal selesai, lalu memeriksa revisi lagi. Pilihan lama tidak boleh menimpa
   update baru dari perangkat lain. Resolusi cloud dapat kembali ke Home.
8. Request mengikat JWT akun pada saat dikirim. Respons terlambat setelah logout
   tidak diterapkan; payload akun A tidak dikirim memakai identitas akun B.

Ini **snapshot sync**, bukan merge event otomatis atau validasi klinis di
server. Gunakan satu tab aktif per origin saat bekerja offline; jangan membuat
perubahan offline paralel di beberapa tab yang berbagi cache browser yang sama.
Preview berbingkai (`MOBILE_PREVIEW=true`) dan data admin tidak menyinkronkan
progres. Untuk menguji sync lewat browser gunakan `MOBILE_WEB=true`.
Batas snapshot saat ini 2 MiB. Histori panjang jalur reduction kelak perlu
dipartisi; versi UAT 28 hari tetap diuji terhadap batas ini.

## Status dan konflik

Di Profil tersedia Sinkron sekarang dan status cloud. Banner ringkas muncul
ketika pending, offline, atau konflik; tidak memakai snackbar putih.

- **Gunakan cloud:** mengganti progres lokal dengan salinan cloud; catatan/file
  lokal yang masih memiliki ID cocok tetap dipertahankan.
- **Gunakan progres perangkat ini:** mengganti cloud dengan progres lokal,
  hanya bila revision yang ditampilkan belum berubah.
- Sebelum penggantian, versi lokal dicadangkan ke cache akun. Saat menimpa
  cloud, salinan cloud sebelumnya juga dicadangkan lokal. Keduanya bisa diekspor
  dari panel Profil untuk pemulihan manual. File foto tidak masuk ekspor.
- Hanya cadangan penggantian terakhir disimpan untuk masing-masing jenis, bukan
  histori versi cloud tak terbatas. Cadangan cache hilang bila data browser/app dihapus.
- Reset progres memerlukan konfirmasi bahwa reset dikirim ke cloud. Akun,
  whitelist admin dan data pengguna lain tidak dihapus. Jika ada konflik,
  selesaikan pemilihan salinan sebelum menganggap reset telah tersinkron.

## Android ↔ web

Kartu yang sudah di-commit tidak dibuat ulang. Satu pengecualian: misi
jalan/lari yang **belum selesai** selalu mengikuti cara validasi perangkat
yang membukanya (keputusan 17 Okt 2026). Web selalu memakai lama sesi karena
browser tidak menghitung GPS di latar belakang; APK selalu memakai jarak GPS.
Judul, target, dan menitnya diambil dari anak tangga yang sama, jadi posisi
tangga untuk riset tidak berubah. Misi yang sudah selesai tetap seperti saat
divalidasi. Tidak ada estimasi jarak dari durasi. Log menyimpan meter/durasi,
bukan rute GPS.

## Checklist uji pada project nyata

1. Jalankan migration kedua, tunggu Render memakai commit terbaru, refresh.
2. Di web Render buat profil/selesaikan satu quest, cek Profil → status sinkron.
3. Cek Table Editor: alias + progress revision bertambah, tanpa field foto/catatan.
4. Masuk akun sama pada browser berbeda/APK terbaru; pastikan kartu, XP, level
   dan status task sama. APK lama harus di-rebuild agar memuat kode sync ini.
5. Buat perubahan offline, sambungkan kembali dan Sinkron sekarang.
6. Buat perubahan berbeda pada dua perangkat; pastikan konflik muncul, dan
   pilihan salinan memerlukan konfirmasi tanpa menggandakan XP.
7. Akun B tidak boleh membaca progres A; admin tidak mempunyai akses khusus
   ke progres peserta. Anonymous select/RPC harus ditolak.
8. Foto hanya bisa dilihat di perangkat asal. Bukti metadata tetap menyelesaikan
   quest yang memang sudah memiliki check-in sah.

SQL diuji pada PostgreSQL terisolasi dengan fixture Auth/RLS. Tes tersebut tidak
menggantikan penerapan migration, pengujian akun nyata di Supabase, atau uji APK
dan browser Safari/Android. Server juga belum memverifikasi bahwa aktivitas
fisik benar-benar dilakukan; snapshot hanya hasil aturan validasi di aplikasi.

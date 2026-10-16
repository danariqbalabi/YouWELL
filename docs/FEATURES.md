# Cakupan produk lokal

## Sudah tersedia

| Area | Implementasi |
| --- | --- |
| Login (tahap 1) | Google OAuth PKCE, pemulihan sesi, logout, timeout/coba lagi; membutuhkan konfigurasi Supabase |
| Isolasi akun | Cache per project/surface/UID, impor progres tamu eksplisit tanpa menghapus backup |
| Sinkron progres (tahap 2) | Profil + snapshot quest/XP/reward, cache offline, expected revision, konflik eksplisit, backup sebelum penggantian; perlu migration kedua |
| Onboarding | Pilih arah wellness/reduction, pace, low-impact, alias, companion |
| Home mobile | Companion hero animasi/sentuh, feedback XP, 3–5 quest, tawaran tangga |
| Companion mobile | 5 tahap tumbuh, evolusi visual, lemari aksesori/latar, target hadiah berikutnya |
| Reward mobile | Bonus Hari Penuh 20 XP sekali per hari, ID persisten, lencana privat |
| Daily Card | Lima kartu collectible, spin acak, swipe, reveal, satu kali ganti, commit; mobile punya Santai/Normal dan tema |
| WELLNESS UAT | 28 hari kalender, panduan empat minggu, batas latihan ringan, rekomendasi sebelum reveal, rekap setelah hari ke-28 |
| Aktivitas mobile | Foto/catatan makan lokal, timer/GPS foreground, hidrasi, riwayat detail, koreksi/hapus |
| Reduction UAT | 28 hari kalender; pemicu–aktivitas–hasil, rencana pengganti, jurnal batang/sesi terpisah, rekap empat minggu, target opsional pilihan pengguna |
| Habit Swap | Gerak ringan diprioritaskan dengan pilihan low-impact; hasil mencoba dihargai sama; ID pengiriman mencegah duplikat tanpa cooldown; XP misi hanya sekali |
| Perjalanan mobile | Ritme 4/7, kalender 28 hari, lencana, tangga wellness, XP, aktivitas, jumlah Habit Swap |
| Community mobile | Encouragement Wall lokal, post menunggu review, reaksi cepat, laporan; seed post berlabel contoh |
| Admin web | Google Login + allowlist server + TOTP saat auth aktif; moderasi masih data demo lokal, bukan post peserta |
| Profile | Tema, path, low-impact, kurangi animasi, getaran, ekspor/hapus lokal, persetujuan dan kode UAT |
| Web iPhone | AppShell mobile tanpa bingkai, timer gerak tanpa GPS, build Render tersendiri |

## Sengaja ditunda

- Pengiriman UAT dan hapus akun server (login/sinkron progres sudah tahap 1–2).
- Identitas komunitas nyata, matching real-time, dan moderasi server.
- Squad, Buddy, dan Vibe Map nyata: tetap roadmap, demo tidak ditampilkan di mobile.
- Push notification dan reminder terjadwal.
- Machine learning. Personalisasi saat ini rule-based dan transparan.
- Integrasi HealthKit/Google Fit dan tracking otomatis.
- Analytics produksi, crash reporting, dan release signing.

Tidak tersedia: estimasi kalori/AI makanan, upload foto ke cloud, tracking GPS
background, komentar bebas, peringkat kompetitif, dan hukuman karena absen.
Workspace desktop, landing, Focus Station, dan recap publik sudah dihapus.

## Penyederhanaan mobile

- Check-in energi dan panel energi dihapus; catatan lama tetap ikut ekspor lokal.
- Fokus/Pomodoro sudah dihapus dari UI. Koleksi sesi fokus lama tetap bisa diekspor.
- Lima tema mobile: Gerak Ringan, Energi Segar, Istirahat, Hidrasi & Makan,
  Udara Segar. Quest pendamping produktivitas/relasi tidak masuk pool mobile.
- Core Quest, tangga Istirahat/Hidrasi, dan quest reduction tetap ada.
  Pada jalur reduction, Habit Swap memakai pemicu, aktivitas, dan hasil momen;
  tidak ada kenaikan durasi menunggu atau intensitas berdasarkan konsumsi.
- Kartu yang sudah dibuka atau di-commit tidak diganti diam-diam.
- Di WELLNESS, deadline makan yang lewat sebelum commit menampilkan alternatif
  dan meminta konfirmasi ulang. ID kartu dan kesempatan ganti tetap sama.
- Kenaikan WELLNESS dimulai dari tanggal penerimaan dan hanya menggunakan
  bukti pada tingkat saat ini; aktivitas valid sebelum commit tetap dihitung.
- Reset dihapus dari mobile; Habit Swap tersedia pada halaman sendiri.
  Napas sebagai opsi Habit Swap tetap tersedia khusus jalur reduction.

## Aturan data dan penelitian

- Reward mobile aktif di Android dan web iPhone melalui AppShell.
- Koreksi/hapus jurnal tidak mencabut XP dan tidak mencetak reward baru.
- Durasi/jarak sesi gerak tidak bisa diedit, baik di UI maupun API controller;
  hanya catatan pribadi yang dapat diubah. Hapus sesi jika keliru.
- Menghapus sesi menghitung ulang bukti quest dan progress parsial. Quest yang
  kehilangan bukti dikeluarkan dari evaluasi tangga dan `quests_done`/`quest_days`
  penelitian, tanpa mencabut status reward, XP, atau level yang sudah diterima.
  Bukti lain yang masih memenuhi target tetap sah. Tawaran naik yang belum
  diterima dicek ulang, termasuk saat snapshot lama dibuka.
- Angka durasi/jarak yang pernah dikoreksi manual oleh versi lama tidak menjadi
  bukti quest. Mengedit catatan saja pada versi baru tidak membatalkan bukti.
- `opened_days`, `activity_days`, dan `quest_days` di ringkasan UAT dibedakan.
  `active_days` berarti hari unik membuka aplikasi, sama dengan `opened_days`.
  Tidak harus selesai quest untuk dihitung aktif. Ritme gamifikasi 4/7 tetap
  menggunakan hari quest selesai, bukan ukuran keterlibatan penelitian.
- Ekspor ringkasan sekarang memakai `schema_version: 2`. Ringkasan yang sudah
  diekspor sebelumnya harus diekspor ulang untuk memakai definisi yang benar.
- Persetujuan UAT bisa ditarik lokal tanpa menghalangi penggunaan aplikasi.
  Penarikan ini tidak menghapus salinan yang sudah dibagikan secara manual.
- Tes otomatis tidak menggantikan tujuh skenario UAT native iOS/Android atau
  evaluasi calon pengguna. Community multi-user menunggu backend.

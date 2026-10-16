# YouWELL

YouWell adalah **better-life companion** untuk membangun ritme harian lewat
langkah kecil, companion, dan progress yang tidak menghukum. Produk saat ini
local-first. Google Login, cache per akun, dan sinkron profil/progres Supabase
tersedia, dengan konflik versi yang meminta pilihan pengguna. Migration tahap 1
dan 2 perlu diterapkan. Admin memakai allowlist + TOTP; komunitas/moderasi masih
demo lokal dan belum mempunyai pengguna komunitas nyata.

Panduan langkah demi langkah: [Supabase Setup](docs/SUPABASE_SETUP.md).
Hosting uji coba: [Render Deployment](docs/RENDER_DEPLOYMENT.md).
Sinkron lintas perangkat: [Progress Sync](docs/PROGRESS_SYNC.md).

## Produk saat ini

- Mobile: **Hari ini, Aktivitas, Perjalanan, Komunitas**; Profil dari avatar.
- Android: aplikasi mobile melalui APK.
- iPhone: aplikasi mobile melalui web Render (`MOBILE_WEB=true`).
- Web admin: hanya antrean moderasi, setujui/tolak post, dan laporan; tanpa onboarding pengguna.
- `MOBILE_PREVIEW=true`: alat pengembangan di browser desktop dengan bingkai HP.
- Core loop: pilih 1 dari 5 Daily Card berisi 3–5 quest adaptif, selesaikan,
  dapatkan XP, dan tumbuhkan companion.
- Path reduction opsional untuk habit swap rokok/vape; bukan identitas utama.

## Gamifikasi mobile

WELLNESS UAT kini berlangsung **28 hari kalender** sejak onboarding. Empat
minggunya memandu mulai pelan, pengulangan, menemukan ritme, dan mempertahankan
kebiasaan yang cocok. Satu misi pada 4 dari 7 hari menjadi arah ritme, tanpa
streak atau kenaikan wajib. Setelah hari ke-28 tersedia rekap dan riwayat,
tanpa challenge baru. Path rokok/vape belum direvisi pada tahap ini.

Gerak WELLNESS dibatasi sampai jalan 1,5 km / 20 menit web, tanpa lari; Makan
sampai dua foto, Istirahat sampai layar off 30 menit, dan Hidrasi sampai tangga
2.000 ml. Tempo awal tetap 1/2/3. Rekomendasi terlihat sebelum reveal; deck
diacak konsisten per tanggal. Kenaikan memakai bukti pada tingkat saat ini
dan berjarak minimal tujuh hari sejak penerimaan. Aktivitas hari ini yang
sudah dicatat ikut dihitung saat memilih kartu; draft makan yang kedaluwarsa
diperbarui sebelum konfirmasi. Detail ada di `docs/CHALLENGE_SPEC.md`.

- Quest selesai: XP melayang menuju companion, respons senang, dan getaran
  opsional. Feedback berupa panel kecil bertema, bukan snackbar putih.
- Companion punya 5 tahap (level 1, 2, 4, 7, 10), animasi ringan, respons sentuh,
  serta lemari aksesori/latar. Hadiah dibuka pada level 2, 3, 4, 6, dan 8.
- Semua quest harian selesai: bonus **20 XP sekali per hari**. Reward/lencana
  memakai ID persisten; membuka ulang aplikasi tidak menggandakan bonus.
- Ritme mingguan menargetkan **4 dari 7 hari** menyelesaikan minimal satu quest.
  Tidak ada progress yang dicabut karena absen. Perjalanan punya kalender 28
  hari sejak onboarding dan koleksi pencapaian privat.
- Draw mobile menawarkan **Santai / Normal** sebelum reveal pertama, 5 tema
  fisik/wellness dengan reward sebanding, dan satu kesempatan ganti. Tema:
  Gerak Ringan, Energi Segar, Istirahat, Hidrasi & Makan, Udara Segar.
  Mode Santai tidak
  mengubah tangga permanen; latihan yang diringankan tidak dipakai sebagai
  bukti untuk menaikkan tangga yang lebih tinggi.
- Aktivitas memiliki riwayat foto/catatan dan sesi gerak. Bisa koreksi/hapus
  catatan; XP/quest yang sudah selesai tidak dicabut atau diberikan ulang.
  Durasi/jarak tidak bisa diedit manual. Menghapus bukti sesi mengeluarkan quest
  yang tidak lagi valid dari evaluasi tangga dan hitungan quest penelitian.
- Meal Snap bisa diganti catatan tanpa foto. Jalan/lari mendukung timer tanpa
  GPS; sesi valid terakumulasi untuk target harian. GPS tetap foreground-only.
- Profil: kurangi animasi, matikan getaran, serta persetujuan UAT opsional dan
  kode P1–P10. Ekspor ringkasan UAT hanya angka + kode, tanpa alias/foto/lokasi.
  Belum ada pengiriman otomatis atau cloud sync.
- Mobile tidak menampilkan check-in energi atau timer fokus. Hidrasi ada di
  Aktivitas; Jeda fisik dibuka dari Home. Panduan postur/stretch/ubah posisi 60s
  dan bantuan reduction tetap tersedia. Workspace desktop, Pomodoro, landing,
  dan recap publik sudah dikeluarkan dari kode aktif.
- Ringkasan UAT `active_days` menghitung hari unik membuka aplikasi; `quest_days`
  tetap terpisah. Ekspor lama perlu dibuat ulang (schema ringkasan versi 2).

Data versi lokal sebelumnya tetap didukung. Quest yang sudah di-commit tidak
diganti oleh pembaruan. Pengingat terjadwal, backend, dan UAT native lengkap
iOS/Android masih tahap berikutnya. Login, MFA admin, dan whitelist server sudah
memiliki implementasi tahap 1; pengujian OAuth/MFA langsung belum selesai. Moderasi saat ini hanya demo
lokal; belum menerima post dari perangkat lain.

## Menjalankan

Tema memakai [palet Color Hunt](https://colorhunt.co/palette/576a8fb7bdf7fff8deff7444):
biru `#576A8F`, lavender `#B7BDF7`, krem `#FFF8DE`, dan oranye `#FF7444`.
Tekan ikon bulan/matahari untuk mengganti light/dark mode. Pilihan **Sistem**,
**Terang**, dan **Gelap** tersedia di **Profil & Settings > Tampilan** dan
tersimpan lokal. Tema berlaku pada mobile, preview iPhone, dan web.

```bash
# Pratinjau web admin
bash scripts/preview.sh

# iOS/Android simulator atau device
bash scripts/run-mobile.sh -d "NAMA-ATAU-ID-DEVICE"
```

Di Windows, preview UI mobile dapat dibuka pada alamat localhost yang tetap:

```powershell
.\scripts\preview-mobile.cmd
# Web admin: http://localhost:8081
.\scripts\preview-admin.cmd
# Tampilan yang dipakai iPhone di Render (tanpa bingkai): http://localhost:8082
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-web.ps1 -Target mobile -Port 8082
```

Setelah pesan `lib\main.dart is being served` muncul, buka
<http://localhost:8080>. Tekan `r` di terminal untuk hot reload dan `q` untuk
mematikan server. Kompilasi pertama dapat memerlukan sekitar 1–2 menit.

Untuk hot reload, jalankan dari VS Code/terminal lalu tekan `r`, atau simpan
file saat sesi debug VS Code aktif. Push GitHub tidak diperlukan untuk melihat
perubahan lokal.

Konfigurasi lokal ada di `config/env/development.json` dan diabaikan Git.
Salin dari `config/env/development.example.json` setelah clone.

## Distribusi untuk peserta

- **Android:** APK dari `flutter build apk --release` (butuh Android SDK).
- **iPhone:** aplikasi web di Render, tanpa App Store/TestFlight. Peserta
  membuka link di Safari → **Bagikan → Tambah ke Layar Utama**, lalu membuka
  YouWELL dari ikonnya (layar penuh).

Deploy web memakai [`render.yaml`](render.yaml) (static site gratis). Build-nya
menyiapkan dua static site: `youwell` menjalankan `scripts/render-build.sh mobile`,
dan `youwell-admin` menjalankan `scripts/render-build.sh admin`. Keduanya memakai
Flutter 3.47.7. Blueprint ini belum dipublikasikan dari sesi pengembangan.
Isi `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY` pada kedua site di Render.
Ikuti migration dan pengaturan redirect pada `docs/SUPABASE_SETUP.md`.

Perbedaan versi web iPhone:

- Browser menghentikan GPS saat layar terkunci, jadi misi jalan/lari dihitung
  dari **lama sesi**, bukan jarak. Anak tangganya sama (Jalan 400 m ↔ Jalan
  5 menit), sehingga `ladder_gerak` tetap sebanding dengan Android.
- Foto Meal Snap dipakai sebagai bukti saat check-in lalu dibuang.
- Setelah migration tahap 2, profil/progres tersinkron per akun; foto/catatan
  pribadi tetap lokal. Jika cache dan cloud berbeda, pilih salinan di Profil.

Web admin memakai storage key `.admin-preview`, sehingga tidak membaca profil
atau progres pribadi peserta. Pratinjau berbingkai memakai `.mobile-preview`.
Data Android/web iPhone tetap memakai key lokal lama agar progres tidak terhapus.
Pada admin development, tombol **Tambah contoh post** menyiapkan post berlabel
contoh untuk menguji setujui/tolak. Ini tidak membuat post komunitas sungguhan.

## File utama

Jika **Jalur kurangi rokok / vape** aktif di **Profil & Settings > Preferensi**,
kartu **Kurangi rokok / vape** muncul di bawah companion pada **Hari ini**.
Tekan **Buka bantuan rokok / vape** untuk timer jeda 5 menit dan ide
aktivitas pengganti. Tombol yang sama juga tersedia langsung di Preferensi.
Sesi jeda yang selesai tercatat di **Perjalanan > Jeda rokok / vape**.
Mengganti preferensi tidak mengubah quest yang sudah dipilih hari ini;
quest pada kartu harian berikutnya mengikuti jalur yang aktif.

| Kebutuhan | File |
| --- | --- |
| Navigasi mobile | `lib/app/app_shell.dart` |
| Aktivitas, Meal Snap, dan jalan/lari mobile | `lib/features/activity/` |
| Home | `lib/features/home/presentation/home_page.dart` |
| Companion, animasi, aksesori, feedback reward | `lib/features/companion/` |
| Aturan reward mobile | `lib/application/wellness_gamification.dart` |
| Daily Card popup | `lib/features/home/presentation/daily_card_draw_dialog.dart` |
| Aturan quest adaptif | `lib/features/home/domain/daily_card_generator.dart` |
| Delay Craving & Habit Swap | `lib/features/reduction/presentation/delay_craving_panel.dart` |
| Progress | `lib/features/progress/presentation/progress_page.dart` |
| Community Wall lokal | `lib/features/community/presentation/community_page.dart` |
| Antrean Admin | `lib/features/community/presentation/admin_moderation_page.dart` |
| Onboarding | `lib/features/onboarding/presentation/onboarding_page.dart` |
| Profile & settings | `lib/features/profile/presentation/profile_page.dart` |
| Web khusus admin | `lib/features/community/presentation/admin_shell.dart` |
| Pemilihan target & storage | `lib/core/config/app_mode.dart` |
| Semua perubahan data | `lib/application/wellness_controller.dart` |
| Skema data lokal | `lib/data/models/wellness_snapshot.dart` |

## Verifikasi

```bash
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn \
  --output=build/admin-web --dart-define-from-file=config/env/production.example.json
# Tampilan HP untuk iPhone (sama seperti build Render)
flutter build web --release --no-web-resources-cdn --dart-define=MOBILE_WEB=true \
  --output=build/mobile-web --dart-define-from-file=config/env/production.example.json
flutter build ios --simulator --no-codesign \
  --dart-define-from-file=config/env/development.example.json
```

Di Windows dengan SDK lokal:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1 -BuildWeb
```

Script juga menangani path SDK yang mengandung spasi untuk menjalankan native
test hooks. APK memerlukan Android SDK; build iOS
native tetap memerlukan Mac dan Xcode dan bukan distribusi iPhone yang dipakai saat ini.

Detail arsitektur ada di [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md)
dan panduan mobile di [docs/MOBILE_DEVELOPMENT.md](docs/MOBILE_DEVELOPMENT.md).

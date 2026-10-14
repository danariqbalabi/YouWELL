# YouWELL

YouWell adalah **better-life companion** untuk membangun ritme harian lewat
langkah kecil, companion, dan progress yang tidak menghukum. Produk saat ini
local-first: belum ada Google Auth, Supabase, pengguna komunitas nyata, atau
data cloud.

## Produk saat ini

- Mobile: **Hari ini, Aktivitas, Perjalanan, Komunitas**; Profil dari avatar.
- Web: landing, Home, Focus Station, Progress, Community, Admin, dan recap.
- Core loop: pilih 1 dari 5 Daily Card berisi 3–5 quest adaptif, selesaikan,
  dapatkan XP, dan tumbuhkan companion.
- Path reduction opsional untuk habit swap rokok/vape; bukan identitas utama.

## Gamifikasi mobile

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
  dan bantuan reduction tetap tersedia, sedangkan Pomodoro tetap di web.
- Ringkasan UAT `active_days` menghitung hari unik membuka aplikasi; `quest_days`
  tetap terpisah. Ekspor lama perlu dibuat ulang (schema ringkasan versi 2).

Data versi lokal sebelumnya tetap didukung. Quest yang sudah di-commit tidak
diganti oleh pembaruan. Pengingat terjadwal, backend, dan UAT native lengkap
iOS/Android masih tahap berikutnya. UI web tidak direvisi dalam iterasi ini.

## Menjalankan

Tema memakai [palet Color Hunt](https://colorhunt.co/palette/576a8fb7bdf7fff8deff7444):
biru `#576A8F`, lavender `#B7BDF7`, krem `#FFF8DE`, dan oranye `#FF7444`.
Tekan ikon bulan/matahari untuk mengganti light/dark mode. Pilihan **Sistem**,
**Terang**, dan **Gelap** tersedia di **Profil & Settings > Tampilan** dan
tersimpan lokal. Tema berlaku pada mobile, preview iPhone, dan web.

```bash
# Web preview
bash scripts/preview.sh

# iOS/Android simulator atau device
bash scripts/run-mobile.sh -d "NAMA-ATAU-ID-DEVICE"
```

Di Windows, preview UI mobile dapat dibuka pada alamat localhost yang tetap:

```powershell
.\scripts\preview-mobile.cmd
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
menjalankan `scripts/render-build.sh`, yang memasang Flutter lalu membangun
tampilan HP (`--dart-define=MOBILE_WEB=true`). Isi `SUPABASE_URL` dan
`SUPABASE_PUBLISHABLE_KEY` di dashboard Render; keduanya memang publik.
**Jangan pernah** memasukkan service role key.

Perbedaan versi web iPhone:

- Browser menghentikan GPS saat layar terkunci, jadi misi jalan/lari dihitung
  dari **lama sesi**, bukan jarak. Anak tangganya sama (Jalan 400 m ↔ Jalan
  5 menit), sehingga `ladder_gerak` tetap sebanding dengan Android.
- Foto Meal Snap dipakai sebagai bukti saat check-in lalu dibuang.
- Data lokal terhapus jika ikon dihapus, jadi sinkronisasi Supabase wajib.

## File utama

Jika **Jalur kurangi rokok / vape** aktif di **Profil & Settings > Preferensi**,
kartu **Kurangi rokok / vape** muncul di bawah companion pada **Hari ini**
(atau **Home** di web). Tekan **Buka bantuan rokok / vape** untuk timer jeda 5 menit dan ide
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
| Workspace web | `lib/features/web/presentation/web_workspace_page.dart` |
| Focus Station web | `lib/features/web/presentation/pomodoro_page.dart` |
| Semua perubahan data | `lib/application/wellness_controller.dart` |
| Skema data lokal | `lib/data/models/wellness_snapshot.dart` |

## Verifikasi

```bash
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn \
  --dart-define-from-file=config/env/development.example.json
# Tampilan HP untuk iPhone (sama seperti build Render)
flutter build web --release --no-web-resources-cdn --dart-define=MOBILE_WEB=true \
  --dart-define-from-file=config/env/development.example.json
flutter build ios --simulator --no-codesign \
  --dart-define-from-file=config/env/development.example.json
```

Detail arsitektur ada di [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md)
dan panduan mobile di [docs/MOBILE_DEVELOPMENT.md](docs/MOBILE_DEVELOPMENT.md).

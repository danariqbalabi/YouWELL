# YouWell Mobile Development

Project native tersedia di `ios/` dan `android/`. UI dan business logic tetap
ditulis dengan Flutter di `lib/`; Xcode dipakai untuk simulator, signing,
capability iOS, archive, dan distribusi.

## Status fondasi

- Bundle/Application ID awal: `com.youwell.app`.
- Minimum iOS deployment target: iOS 15.
- iPhone menggunakan orientasi portrait.
- Penyimpanan masih local-first melalui `SharedPreferences`.
- Gamifikasi mobile terpisah di `lib/features/companion/` dan
  `lib/application/wellness_gamification.dart`. Web iPhone memakai mobile reward
  host yang sama; web admin hanya menampilkan moderasi.
- Reward/lencana dan preferensi animasi/getaran tersimpan lokal. Kalender
  perjalanan 28 hari dan ritme 4/7 menggunakan quest yang selesai.
- Tab mobile: **Hari ini**, **Aktivitas**, **Perjalanan**, **Komunitas**. Jeda cepat
  dibuka dari Hari ini; Profil melalui avatar di kanan atas.
- Check-in energi dan Fokus 5m tidak ada di mobile. Jeda fisik 60s memandu
  postur, stretching, dan ubah posisi; hidrasi berada di Aktivitas.
  Workspace desktop dan Fokus/Pomodoro sudah dihapus dari kode aktif.
- Aktivitas memiliki Meal Snap (foto lokal di penyimpanan aplikasi) dan
  jalan/lari dengan timer serta perkiraan jarak GPS hanya saat layar sesi aktif.
  Aplikasi tidak menghitung kalori, tidak menyimpan koordinat/rute, dan belum
  mendukung tracking saat aplikasi berjalan di background.
- Foto Meal Snap tidak ikut dalam ekspor JSON. Menghapus data lokal dari Profil
  juga menghapus foto-foto Meal Snap pada perangkat tersebut.
- Riwayat aktivitas bisa membuka foto, koreksi, dan hapus catatan. Menghapus
  satu Meal Snap juga menghapus file foto miliknya. XP tetap tersimpan;
  hanya catatan yang bisa diedit, bukan durasi/jarak. Hapus sesi keliru untuk
  membatalkan bukti evaluasi tanpa mencabut XP atau menambah reward.
- Persetujuan UAT P1–P10 tersedia di Profil; ringkasan angka diekspor manual.
  `active_days` = hari unik membuka aplikasi, bukan hari quest selesai.
  Buat ulang ekspor lama; schema ringkasan terbaru versi 2.
  Login Supabase/Google tersedia tahap 1; pengiriman ringkasan server belum aktif.
- Ekspor data dan buka tautan sudah memakai API native.
- Konfigurasi Google Login, cache akun dan callback APK ada di
  `docs/SUPABASE_SETUP.md`. Callback membutuhkan full rebuild. Sinkron progres
  perlu migration tahap 2 (`docs/PROGRESS_SYNC.md`); push notification dan
  production signing belum aktif.
- App icon dan launch screen masih placeholder Flutter dan harus diganti
  sebelum TestFlight.

## Preview tampilan iPhone dari Windows

Untuk melihat dan mencoba UI mobile tanpa Android SDK atau Mac, jalankan dari
PowerShell di root project:

```powershell
.\scripts\preview-mobile.cmd
```

Tunggu sampai terminal menampilkan `lib\main.dart is being served`, lalu buka
<http://localhost:8080>. Script memakai port tetap agar alamat tidak berubah
setiap dijalankan. Kompilasi pertama dapat memerlukan sekitar 1–2 menit.

Port lain dapat dipilih bila `8080` sedang dipakai:

```powershell
.\scripts\preview-mobile.cmd 8081
```

Preview membuka alur mobile yang sama (onboarding, Home, Aktivitas, Perjalanan,
Komunitas, dan Profil) dalam frame portrait 393 × 852 dengan tema platform iOS.
Data preview disimpan terpisah dari data web biasa. Ini preview UI di browser;
fitur perangkat seperti permission iOS, kamera, dan GPS tetap perlu diuji pada
iPhone atau simulator iOS di Mac. Tanpa flag mobile, web membuka admin moderasi.
Build `MOBILE_WEB=true` adalah aplikasi untuk iPhone melalui Safari/Render,
tanpa bingkai pratinjau. Distribusi native iOS berikut ini tetap opsional;
distribusi peserta memakai APK Android dan web iPhone.

## Setup Mac satu kali

Pastikan Xcode berada di `/Applications/Xcode.app`, lalu jalankan:

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
xcodebuild -downloadPlatform iOS
flutter doctor -v
```

Jika perintah pertama mengatakan path tidak ditemukan, pindahkan instalasi
Xcode ke folder `/Applications` dan pastikan nama aplikasinya `Xcode.app`.
Perintah `sudo xcode-select` meminta password akun Mac dan harus dijalankan
langsung oleh pemilik perangkat.

## Setup setelah clone

Bagian ini hanya untuk perangkat yang **belum memiliki project YouWELL**.
Jika folder project sudah terbuka di VS Code, jangan jalankan `git clone` lagi
di dalamnya; langsung mulai dari `flutter pub get` pada root project.

```bash
git clone https://github.com/zalfredz/YouWELL.git
cd YouWELL
cp config/env/development.example.json config/env/development.json
flutter pub get
open ios/Runner.xcworkspace
```

Jangan membuka `Runner.xcodeproj`; gunakan `Runner.xcworkspace` agar integrasi
plugin Flutter ikut dimuat.

## Menjalankan di iPhone Simulator

1. Buka Simulator dari Xcode: **Xcode > Open Developer Tool > Simulator**.
2. Di terminal, jalankan `flutter devices` dan salin ID simulator.
3. Jalankan:

```bash
bash scripts/run-mobile.sh -d "ID-ATAU-NAMA-SIMULATOR"
```

Contoh jika Flutter menampilkan perangkat bernama `iPhone 17 Pro`:

```bash
bash scripts/run-mobile.sh -d "iPhone 17 Pro"
```

Saat proses aktif, tekan `r` untuk hot reload, `R` untuk hot restart, dan `q`
untuk berhenti.

## Menjalankan lewat VS Code

1. Buka root folder `YouWELL`, bukan folder `ios`.
2. Nyalakan iPhone Simulator.
3. Pilih simulator pada device selector VS Code.
4. Tekan `F5`.

Jika perlu build-time environment, gunakan script terminal di atas supaya
`config/env/development.json` otomatis ikut dipakai.

## Signing di Xcode

Di `Runner.xcworkspace`, pilih **Runner > TARGETS Runner > Signing &
Capabilities**:

1. Aktifkan **Automatically manage signing**.
2. Pilih Apple Developer Team.
3. Pastikan Bundle Identifier unik. Ganti `com.youwell.app` jika identifier
   tersebut bukan milik akunmu.

Simulator tidak memerlukan paid developer account. Perangkat fisik memerlukan
Apple ID/signing, sedangkan TestFlight dan App Store memerlukan Apple Developer
Program.

## File mobile yang biasa diubah

| Kebutuhan | File/folder |
| --- | --- |
| UI dan logic bersama | `lib/` |
| Implementasi API perangkat | `lib/core/platform/platform_native.dart` |
| Nama dan permission iOS | `ios/Runner/Info.plist` |
| Bundle ID/signing iOS | `ios/Runner.xcodeproj/project.pbxproj` / Xcode |
| App icon iOS | `ios/Runner/Assets.xcassets/AppIcon.appiconset/` |
| Konfigurasi Android | `android/app/build.gradle.kts` |
| Permission Android | `android/app/src/main/AndroidManifest.xml` |
| Environment lokal | `config/env/development.json` |

Jangan commit `config/env/development.json`, signing key, provisioning profile,
`local.properties`, atau credential layanan.

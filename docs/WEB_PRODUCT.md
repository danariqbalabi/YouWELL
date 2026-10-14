# Akses web YouWELL

Produk memiliki tiga akses: web admin, APK Android, dan aplikasi web untuk
iPhone di Render. Android dan web iPhone memakai AppShell mobile yang sama.
Workspace desktop, landing, Pomodoro, dan recap publik sudah dihapus.

| Build | Hasil |
| --- | --- |
| Android native | Aplikasi peserta: Hari ini, Aktivitas, Perjalanan, Komunitas |
| Web dengan `MOBILE_WEB=true` | Aplikasi peserta tanpa bingkai, untuk Safari/iPhone |
| Web tanpa flag mobile | AdminShell: antrean post dan laporan, tanpa onboarding |
| Web dengan `MOBILE_PREVIEW=true` | Alat pengembangan desktop dengan bingkai HP |

Flag MOBILE_WEB dan MOBILE_PREVIEW tidak boleh aktif bersamaan. Lebar layar
dan user agent tidak menentukan apakah seseorang membuka admin atau aplikasi.

## Status saat ini

Semua data masih lokal. Admin belum login dan belum menerima post dari Android
atau browser peserta lain. Storage admin `.admin-preview` terpisah dari profil
peserta. Tombol Tambah contoh post hanya tersedia saat preview tools aktif;
post fixture ditandai Contoh lokal. Setujui/tolak dan penanganan laporan tetap
dapat diuji di pratinjau ini.

Rute `/admin` di build peserta hanya menampilkan keterangan bahwa moderasi
tersedia di web admin. Rute `/app` di build admin tetap membuka moderasi;
tidak ada alur wellness terselip di web admin.

## Menjalankan di Windows

```powershell
# Admin, http://localhost:8081
.\scripts\preview-admin.cmd

# Web mobile tanpa bingkai, http://localhost:8082
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\run-web.ps1 -Target mobile -Port 8082

# Pratinjau berbingkai, http://localhost:8080
.\scripts\preview-mobile.cmd

# Analyze, semua tes, dan kedua release build
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1 -BuildWeb
```

`render.yaml` menyiapkan dua static site: youwell (mobile) dan youwell-admin
(admin). Keduanya menggunakan script yang sama dengan argumen build berbeda.
Konfigurasi ini belum menerapkan login atau mempublikasikan deployment.

## Tahap integrasi terakhir

Sesuai urutan kerja, Supabase dan Google Auth baru diimplementasikan setelah
alur aplikasi stabil. Rencana integrasinya:

1. Login Google untuk aplikasi peserta dan web admin.
2. Daftar Gmail admin tersimpan di database, kosong hingga pengelola mengisinya.
3. Server memeriksa identitas Google terverifikasi, whitelist, dan MFA; setiap
   operasi moderasi diperiksa lagi. URL atau daftar email dalam Flutter tidak
   boleh memberikan hak admin.
4. Post baru pending, hanya approved yang terlihat di komunitas peserta.
5. Moderator hanya mengakses data komunitas, tanpa profil wellness, progres,
   foto, lokasi, atau data penelitian peserta.
6. Cache lokal per akun, RLS, audit moderasi, dan penghapusan akun.

Foto Meal Snap dan rute GPS tidak diunggah. Service-role key hanya untuk
komponen server, tidak berada dalam build APK/web atau repository.

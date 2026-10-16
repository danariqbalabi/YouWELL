# Supabase + Google Login — tahap 1

## Status dan batasan

Kode login memakai `supabase_flutter` + OAuth PKCE, dengan pemulihan sesi,
logout, dan pesan error/coba lagi. Android memakai browser eksternal lalu
callback kembali ke APK. Web kembali ke origin build yang sedang dibuka.

**Belum ada sinkronisasi progres, pengiriman UAT, community multi-user, atau
hapus akun server.** Progres masih di perangkat, dipisahkan per project,
surface, dan UID Supabase. Masuk di HP lain belum memindahkan progres.
Migration tahap 1 menyiapkan alias privat dan otorisasi admin; aplikasi belum
mengirim alias ke tabel tersebut. Moderasi tetap demo lokal, meskipun pintu
masuk admin sekarang bisa dilindungi autentikasi + MFA.

## 1. Konfigurasi project

Di Supabase aktifkan Data API dan Google provider. Matikan otomatis expose
tabel baru, aktifkan automatic RLS. Credential Google OAuth hanya disimpan
di konfigurasi provider Supabase, tidak di Flutter.

Di Google Cloud, Web OAuth client memakai Callback URL yang disalin dari
halaman provider Google Supabase sebagai Authorized redirect URI. Origins
lokal: `http://localhost:8082` dan `http://localhost:8081`. Tambahkan Google
test users jika OAuth consent masih Testing.

Jika authorize endpoint menampilkan **`Unsupported provider: missing OAuth secret`**,
Google Provider memang aktif tetapi Client Secret belum tersimpan. Salin secret
dari Web OAuth client Google Cloud ke Supabase → Google Provider → Client Secret,
pastikan Client ID pasangannya benar, lalu Save. Jangan taruh secret itu di chat,
Flutter, Render client config atau Git. Status provider enabled saja belum
membuktikan alur OAuth lengkap berfungsi.

Supabase → Authentication → URL Configuration:

- Site URL lokal: `http://localhost:8082/`.
- Redirect URLs: `http://localhost:8082/`, `http://localhost:8081/`,
  **`com.youwell.app://login-callback/`**.
- Jika mencoba preview berbingkai di port 8080, izinkan origin + redirect
  `http://localhost:8080/` secara terpisah.
- Saat deploy, tambahkan origin HTTPS mobile/admin ke Google Cloud dan
  redirect root HTTPS ke Supabase. Ubah Site URL ke web mobile produksi.
  Hindari wildcard untuk domain produksi.

## 2. Migration (manual, satu kali)

Kode tidak menjalankan DDL otomatis. Buka SQL Editor pada **project yang
benar**, buat query baru, tempel seluruh isi:

`supabase/migrations/20261016090000_create_auth_foundation.sql`

Lalu Run. Migration transaksional ini tidak menghapus pengguna/data lama.
Schema `private` tidak boleh ditambahkan ke daftar exposed schemas.

Tabel `public.youwell_profiles` memakai RLS pemilik (`auth.uid() = user_id`)
dan izin eksplisit. Tidak ada email/nama Google/role admin di tabel profil.
Allowlist ada di `private.youwell_admins`; client tidak bisa membacanya atau
mengangkat dirinya sendiri menjadi admin. RPC `youwell_admin_access` hanya
mengembalikan status caller: `denied`, `needs_mfa`, atau `allowed`.

Pemeriksaan metadata read-only yang bisa dijalankan setelah migration:

```sql
select relrowsecurity from pg_class
where oid = 'public.youwell_profiles'::regclass; -- true
select has_table_privilege('anon', 'public.youwell_profiles', 'SELECT'); -- false
select has_schema_privilege('authenticated', 'private', 'USAGE'); -- false
select has_function_privilege('anon', 'public.youwell_admin_access()', 'EXECUTE'); -- false
```

## 3. Konfigurasi Flutter

Isi `config/env/development.json` (diabaikan Git):

```json
{
  "APP_NAME": "YouWELL",
  "APP_ENV": "development",
  "LOCAL_STORAGE_KEY": "youwell.local.v3",
  "SHOW_PREVIEW_TOOLS": "true",
  "AUTH_ENABLED": "true",
  "SUPABASE_URL": "https://PROJECT.supabase.co",
  "SUPABASE_PUBLISHABLE_KEY": "sb_publishable_...",
  "AUTH_REDIRECT_URL": "com.youwell.app://login-callback/"
}
```

Jangan memakai secret/service-role key, password database atau Google Client
Secret di konfigurasi client. Nilai build client dapat dibaca dari APK/web.
`development.example.json` sengaja memakai `AUTH_ENABLED=false` untuk demo UI
offline; ubah ke true dan isi project sendiri untuk mencoba login.
Production default mewajibkan auth: credential hilang menampilkan pesan
konfigurasi, bukan diam-diam masuk sebagai tamu/admin.

Web mobile lokal (tanpa membuka browser otomatis):

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8082 \
  --dart-define=MOBILE_WEB=true --dart-define=MOBILE_PREVIEW=false \
  --dart-define-from-file=config/env/development.json
```

Buka **http://localhost:8082/** (bukan 127.0.0.1, agar origin sesuai allowlist).
Admin: port 8081, `MOBILE_WEB=false`, `MOBILE_PREVIEW=false`.
APK/simulator: `bash scripts/run-mobile.sh -d DEVICE_ID`.
Perubahan dependency/deep link memerlukan full rebuild, bukan hot reload saja.

## 4. Progres tamu dan pergantian akun

Setelah login, akun dengan cache kosong ditawari impor progres tamu bila ada.
Pengguna harus memilih: gunakan progres tamu atau mulai baru. Impor tidak
menimpa cache akun yang sudah ada, tidak menghapus salinan lama, dan hanya
bisa diklaim satu akun/project. Tidak ada upload foto atau progres otomatis.

Logout langsung menyembunyikan navigator/data akun, mempertahankan cache
akun dan foto. Reset dari Profil menghapus catatan/foto milik akun pada
perangkat, **bukan akun Supabase**, dan tidak menghapus foto akun lain.
Cache lokal adalah isolasi aplikasi, bukan enkripsi/pengaman terhadap orang
yang memiliki akses penuh ke perangkat atau developer tools.

## 5. Admin (allowlist + TOTP)

Allowlist awal kosong, jadi semua akun ditolak. Setelah pengelola memutuskan
email admin, jalankan sendiri di SQL Editor (ganti placeholder):

```sql
insert into private.youwell_admins(email)
values (lower('EMAIL-ADMIN-YANG-DISETUJUI'))
on conflict (email) do nothing;
```

Admin login Google, lalu menambahkan kunci setup TOTP ke authenticator dan
memasukkan kode 6 digit. Kunci TOTP hanya ditampilkan saat setup; jangan
bagikan, screenshot, log, atau commit. Bukan kode SMS/Google OTP.
Server memeriksa akun Google terhubung, email terkonfirmasi, allowlist, dan
JWT `aal2` sebelum UI moderasi. Hapus baris allowlist untuk mencabut akses;
akses diperiksa kembali saat masuk/refresh sesi. Phase 2 wajib menerapkan
cek yang sama dalam policy setiap operasi moderasi server, bukan hanya UI.

## 6. Render

`render.yaml` menyiapkan mobile dan admin sebagai dua static site. Di
keduanya isi environment `SUPABASE_URL` dan `SUPABASE_PUBLISHABLE_KEY`.
Build script menolak credential kosong/salah jenis. Tidak ada secret key.
Lalu tambahkan alamat HTTPS final sesuai langkah 1 dan deploy ulang.
Pengaturan provider/SQL/Render belum dilakukan otomatis oleh kode.

## Checklist uji manual sebelum dipakai peserta

1. Login Google berhasil, batal login dapat dicoba ulang, refresh menyimpan sesi.
2. Akun A/B punya progres terpisah; logout tidak menampilkan halaman/foto akun A.
3. Impor progres tamu dikonfirmasi, salinan lama tetap ada, tidak bisa diambil B.
4. Tanpa koneksi tidak loading terus; cache akun yang sesinya valid masih tersedia.
5. Callback Android kembali ke APK setelah full rebuild; web kembali ke origin benar.
6. Admin non-whitelist ditolak; whitelist tanpa MFA tidak masuk; TOTP benar diizinkan.
7. Uji RLS dengan dua akun setelah migration; client B tidak dapat membaca/mengubah alias A.

Tes otomatis tidak membuktikan Google OAuth callback, RLS pada project remote,
atau TOTP nyata telah berhasil. Perlu akun uji dan SQL pada project target.

Referensi resmi: [OAuth Flutter](https://supabase.com/docs/reference/dart/auth-signinwithoauth),
[Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls),
[MFA](https://supabase.com/docs/guides/auth/auth-mfa),
[RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[Flutter deep links](https://docs.flutter.dev/release/breaking-changes/deep-links-flag-change).

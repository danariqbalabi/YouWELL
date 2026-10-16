# Deploy uji coba YouWELL ke Render

Tujuan: menerbitkan dua **Static Site**, bukan Web Service/backend baru.
Database dan Google Login tetap Supabase; Render hanya menyajikan Flutter web.
Ini build uji coba: progres masih lokal per akun/perangkat, community dan
moderasi masih demo lokal. Jangan menganggapnya sinkronisasi produksi.

## 1. Hubungkan GitHub

1. Pastikan perubahan login dan `render.yaml` sudah di-push ke `main`.
2. Masuk ke https://dashboard.render.com/ dan hubungkan GitHub.
3. Pilih **New → Blueprint**, lalu repo `zalfredz/YouWELL`.
4. Branch: `main`; Blueprint path: `render.yaml`; root directory repo tetap kosong.
5. Tinjau resource: `youwell` dan `youwell-admin`, keduanya `runtime: static`.
   Jangan tambahkan database Render atau layanan berbayar untuk setup ini.

Blueprint sudah mengatur:

| Site | Build command | Publish directory |
| --- | --- | --- |
| Mobile web | `bash scripts/render-build.sh mobile` | `build/web` |
| Admin | `bash scripts/render-build.sh admin` | `build/web` |

Jika membuat Static Site manual alih-alih Blueprint, gunakan nilai yang sama,
dan tambahkan Rewrite `/*` → `/index.html`. Static Site tidak membutuhkan
Start Command atau `node scripts/serve.mjs`.

## 2. Isi environment pada kedua site

Blueprint meminta dua nilai, ambil dari project Supabase yang sudah dipakai:

- `SUPABASE_URL`: Project URL.
- `SUPABASE_PUBLISHABLE_KEY`: publishable key dengan awalan `sb_publishable_`.

Gunakan nilai dari `config/env/development.json`, tetapi **jangan upload file
konfigurasi lokal itu**. Jangan masukkan Google Client Secret, password DB,
secret key, atau service-role key ke build web. Public key memang dapat dibaca
dari aplikasi; perlindungan data harus tetap melalui grants/RLS/server.

Klik Deploy Blueprint setelah meninjau konfigurasi. Tunggu status Live pada
kedua site, lalu salin **alamat HTTPS aktual** yang diberikan Render. Nama
domain dapat memperoleh suffix; jangan menganggap nama layanan sama dengan
alamat final yang tersedia.

Jika environment diubah kemudian, pilih **Save, rebuild, and deploy**:
Flutter memasukkan nilainya saat build, bukan saat web sedang berjalan.

## 3. Izinkan domain hasil deploy untuk login

Misalkan alamat final adalah `https://ALAMAT-MOBILE.onrender.com` dan
`https://ALAMAT-ADMIN.onrender.com` (ganti placeholder dengan alamat aktual).

Google Cloud → Google Auth Platform → Clients → Web OAuth client:

- Tambahkan kedua origin HTTPS ke Authorized JavaScript origins, tanpa path.
- Authorized redirect URI **tetap Callback URL Supabase** `/auth/v1/callback`.
  Jangan menggantinya dengan domain Render.

Supabase → Authentication → URL Configuration:

- Site URL: root HTTPS site mobile, dengan trailing `/`.
- Redirect URLs: root HTTPS mobile dan admin, masing-masing trailing `/`.
- Localhost boleh dipertahankan selama pengembangan; APK tetap memakai
  `com.youwell.app://login-callback/`.
- Jangan memakai wildcard domain produksi.

## 4. Uji di URL Render

1. Buka mobile web, masuk Google, coba refresh dan logout/login.
2. Bila consent Google masih Testing, daftarkan Gmail penguji di Test users.
3. Progres localhost **tidak otomatis muncul** di domain Render. Ini origin
   dan cache berbeda; sinkronisasi progres cloud belum diimplementasikan.
4. Admin non-whitelist harus ditolak. Admin whitelist harus melalui TOTP.
   Semua setup SQL/whitelist dijelaskan pada `SUPABASE_SETUP.md`.
5. Halaman admin yang antreannya kosong saat ini wajar: post peserta belum
   tersinkron ke server, dan fixture demo mati pada build produksi.
6. Pada iPhone, baru coba Safari → Bagikan → Tambah ke Layar Utama setelah
   login pada URL HTTPS berhasil.

## Jika build/login bermasalah

- Lihat **Events / build logs** pada site yang gagal, kirim pesan error-nya.
- Credential build kosong: isi dua environment tadi dan **rebuild**.
- Login kembali ke localhost: periksa Site URL, Redirect URLs, dan bahwa
  build memakai commit terbaru (kode memakai origin web aktif sebagai tujuan).
- `redirect_uri_mismatch`: callback Supabase di Google Cloud harus persis.
- `Unsupported provider: missing OAuth secret`: isi Client Secret hanya di
  Google Provider Supabase, bukan Render.
- Perubahan konfigurasi tidak terlihat: pastikan deploy baru berhasil, lalu
  reload. Hot reload lokal tidak memperbarui website Render.

Panduan resmi: [Blueprint](https://render.com/docs/infrastructure-as-code),
[Static Sites](https://render.com/docs/static-sites),
[Environment](https://render.com/docs/configure-environment-variables),
[Supabase Redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls).

# Struktur project YouWell

```text
lib/
├── app/                 # bootstrap, root app, mobile shell
├── application/         # WellnessController sebagai use-case boundary
├── core/                # config, theme, platform adapter, utility
├── data/                # snapshot dan repository lokal
├── features/
│   ├── activity/        # gerak, Meal Snap, hidrasi, riwayat
│   ├── auth/            # gateway Google OAuth, cache akun, UI login/MFA
│   ├── companion/       # evolusi, aksesori, animasi reward mobile
│   ├── community/       # Wall (post, reaksi, lapor), Admin
│   ├── home/            # companion, quest, Daily Card
│   ├── onboarding/      # personalisasi awal
│   ├── profile/         # preferences dan kontrol data
│   ├── progress/        # insight progress mobile
│   └── reduction/       # Delay Craving & Habit Swap (jalur rokok/vape)
└── shared/widgets/      # komponen visual lintas fitur
```

## Aliran data

```text
UI → WellnessController → WellnessRepository → SharedPreferences
```

Widget tidak menulis storage secara langsung. State versi 3 hanya menyimpan
profil, rencana harian, reward/aksesori, aktivitas, sesi fokus web, habit delay,
dan state prototype komunitas. Check-in energi tidak lagi tersedia; snapshot
lama tetap mempertahankan catatannya untuk ekspor. Struktur
ini sengaja kecil agar UX dapat diubah cepat sebelum kontrak backend dibekukan.

## Tiga akses produk

- Android native → `AppShell`, penyimpanan lokal lama.
- Web iPhone (`MOBILE_WEB=true`) → `AppShell`, tampilan mobile penuh tanpa bingkai.
- Web biasa → `AdminShell`, hanya moderasi, storage terpisah `.admin-preview`.

`MOBILE_PREVIEW=true` hanya alat pengembangan desktop. Jika kedua flag web
mobile dan preview aktif sekaligus, aplikasi menolak konfigurasi itu.
Workspace desktop, landing, Pomodoro, dan recap publik sudah dihapus.

## Integrasi backend bertahap

Login Google, cache per akun, whitelist server dan MFA sudah memiliki implementasi
tahap 1; lihat `docs/SUPABASE_SETUP.md` dan `supabase/migrations/`. Repository
progres cloud dan community multi-user belum dihubungkan. Admin hanya boleh
mengakses data komunitas. Post peserta harus berstatus
`pending`, lalu `approved`/`rejected` melalui keputusan server. Role tidak boleh
ditentukan dari URL, alias, metadata yang bisa diubah pengguna, atau daftar email
di Flutter. Foto dan rute GPS tidak diunggah.

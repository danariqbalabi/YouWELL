# YouWELL

**Teman kecil untuk hidup lebih sehat, tanpa rasa dihakimi.**

YouWELL membantu remaja dan dewasa muda (15–22 tahun) membangun kebiasaan
sehat lewat misi harian kecil, companion yang ikut tumbuh, dan progres yang
tidak pernah dicabut. Ini prototipe penelitian tim TRIAD (ICT4D, Fasilkom UI 2026).

## Dua jalur

- **Better Daily Rhythm**: gerak ringan, hidrasi, makan, dan istirahat.
- **Kurangi / Berhenti Rokok & Vape**: Habit Swap (coba aktivitas pengganti
  saat ingin merokok/vape) dan catatan konsumsi harian. Bahasanya netral,
  tanpa label dan tanpa hukuman.

## Cara kerjanya

1. **Onboarding**: pilih alias, jalur, tempo, dan companion.
2. **Kartu hari ini**: ambil 1 dari 5 kartu, masing-masing berisi 3–5 misi.
3. **Selesaikan misi**: dapat XP, dan companion naik level.
4. **Naik tangga pelan-pelan**: tantangan naik hanya kalau kamu mau
   (aturannya berbasis aturan sederhana, tanpa AI).
5. **Community**: berbagi kemenangan kecil dengan alias. Semua post
   dicek admin dulu.

Program berjalan **28 hari**, lalu menampilkan rekap.

## Teknologi

Flutter (Android APK + web untuk iPhone) · Supabase (login Google, sinkron,
Community) · data lokal dulu, baru disinkronkan saat online.

## Menjalankan

```bash
cp config/env/development.example.json config/env/development.json
flutter run --dart-define-from-file=config/env/development.json
```

Di Windows: `.\scripts\preview-mobile.cmd` (tampilan HP) atau
`.\scripts\preview-admin.cmd` (web admin).

Verifikasi sebelum rilis: `flutter analyze` dan `flutter test`.

## Distribusi

- **Android**: APK dari `flutter build apk --release`.
- **iPhone**: buka web app di Safari, lalu **Bagikan → Tambah ke Layar Utama**.
- **Admin**: web terpisah untuk moderasi Community dan dashboard peneliti.

## Dokumen lain

| Topik | File |
|---|---|
| Setup Supabase, migration, dan admin | [docs/SUPABASE_SETUP.md](docs/SUPABASE_SETUP.md) |
| Aturan misi dan tangga | [docs/CHALLENGE_SPEC.md](docs/CHALLENGE_SPEC.md) |
| Jalur rokok/vape | [docs/REDUCTION_UAT.md](docs/REDUCTION_UAT.md) |
| Sinkron progres | [docs/PROGRESS_SYNC.md](docs/PROGRESS_SYNC.md) |
| Deploy ke Render | [docs/RENDER_DEPLOYMENT.md](docs/RENDER_DEPLOYMENT.md) |
| Struktur kode | [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md) |

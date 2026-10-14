# YouWell – Konteks Proyek untuk Claude Code

Dokumen ini merangkum keputusan desain YouWell yang sudah dikunci di proposal penelitian TRIAD (ICT4D A, 2026). Taruh file ini di root repo `zalfredz/YouWELL` sebagai `CLAUDE.md`.

**Aturan utama:** jangan membuat perubahan yang bertentangan dengan proposal. Kalau kode dan proposal berbeda, tanyakan dulu ke tim sebelum mengubah salah satunya.

---

## 1. Ringkasan produk

YouWell adalah prototipe fungsional (MVP) aplikasi seluler Flutter. Fungsinya: pendamping gaya hidup sehat untuk remaja dan dewasa muda usia 15 - 22 tahun, dengan pendekatan *wellness-first*, rendah stigma, dan tidak terasa klinis.

Aplikasi punya dua jalur:

- **Better Daily Rhythm:** rutinitas sehat harian (aktivitas, hidrasi, tidur, stretching).
- **Kurangi Rokok/Vape:** dukungan pengurangan rokok/vape lewat Delay Craving (timer tunda 5 menit) dan Habit Swap (aktivitas pengganti).

Alur inti: Login Google → Onboarding (alias, jalur, tempo, *low-impact*, companion) → Daily Card (pilih 1 dari 5 kartu berisi 3 - 5 quest) → Core Quest → XP → companion tumbuh.

Fitur yang dievaluasi di penelitian:

- Onboarding
- Home/Companion
- Core Quest
- Daily Card Draw
- Progress
- Community (alias, reaksi pilihan, pelaporan, moderasi admin)
- Delay Craving & Habit Swap

**Di luar cakupan:** versi rilis publik, analisis bisnis, *web workspace* (tidak dievaluasi), penyaringan konten berbasis AI, dan **machine learning** apa pun.

**Distribusi (keputusan tim 8 Okt 2026):** Android lewat APK; iPhone lewat aplikasi web (tampilan HP, `MOBILE_WEB=true`) di Render yang dipasang lewat "Tambah ke Layar Utama", karena tim tidak memakai Apple Developer Program berbayar. *Web workspace* desktop tetap di luar cakupan.

---

## 2. Arsitektur target (hybrid, sudah dikunci di proposal)

```
Pengguna ↔ Aplikasi Flutter (HP)
            ├─ Fitur (UI)
            ├─ Personalisasi Adaptif (rule-based, tanpa ML)
            ├─ Validasi Quest (GPS & timer dicek di HP)
            └─ Cache Lokal (offline-first; foto Meal Snap HANYA di HP)
                    ↕ Sinkron (HTTPS)
            Supabase (region Singapura, ap-southeast-1)
            ├─ Supabase Auth: Login Google
            ├─ Postgres + Row Level Security
            │    profiles(alias), progress/log, community
            └─ research_logs (ringkasan mingguan berkode P1 - P10, khusus UAT)
                    ↕
            Admin web (moderasi Community, akun MFA, TANPA akses data pribadi)
            Tim peneliti: hanya baca research_logs + kuesioner anonim (Google Forms)
```

### Status repo per commit `0bc9ee9` (5 Okt 2026)

- Semua data masih lokal (`shared_preferences`, key `youwell.local.v3`). **Belum ada Supabase atau auth.**
- Community masih simulasi: ada seed post (`daunpagi`, `awanbiru`), Squad/Buddy disimulasikan, dan halaman Admin hanya membaca state browser yang sama.
- Personalisasi ada di `lib/features/home/domain/daily_card_generator.dart`. Saat ini hanya bisa *turun* (≤ 2 hari pemakaian atau penyelesaian < 40% → level 1). Belum ada mekanisme naik bertahap.
- Meal Snap (kamera, `image_picker`) dan jalan/lari (`geolocator`) masih ada di kode, padahal `docs/FEATURES.md` menyebut keduanya sudah dihapus. Dokumen ini perlu disinkronkan.
- Ekspor JSON di Profil sudah membuang `photoPath`. "Hapus data" sudah menghapus folder foto.

---

## 3. Daftar pekerjaan (urut prioritas, harus selesai sebelum UAT ±24 Okt 2026)

1. **Supabase + Login Google**
   - Tambah `supabase_flutter`. Login Google lewat Supabase Auth.
   - Email hanya dipakai untuk autentikasi. Email tidak pernah ditampilkan, dan Community hanya menampilkan alias.
   - **Service role key tidak boleh ada di aplikasi.**
2. **Sinkronisasi offline-first**
   - Cache lokal tetap dipakai, lalu disinkronkan saat online.
   - Yang disinkronkan: profil alias, jalur, tempo, quest, XP, posisi tangga, log Delay Craving & Habit Swap, jarak & durasi jalan/lari.
   - **Foto dan rute GPS tidak pernah diunggah.**
3. **Community nyata**
   - Tabel `posts`, `reactions`, `reports`.
   - Post baru berstatus `pending` dan baru tampil setelah `approved` oleh admin.
   - Hapus seed post dan simulasi Squad/Buddy, atau beri label "contoh".
4. **Admin web**
   - Hanya membaca dan menulis tabel Community. Wajib MFA.
5. **Hapus akun**
   - Menghapus semua data pengguna di Supabase (auth user, profile, progress, posts, reactions, reports) dan seluruh data lokal termasuk foto.
   - Dasar: UU PDP Pasal 8 & 9.
6. **research_logs (khusus partisipan UAT)**
   - Partisipan memasukkan kode P1 - P10 dan menyetujui pengiriman ringkasan.
   - Seminggu sekali aplikasi mengirim **angka saja**: hari dibuka, hari aktif + status aktif, Core Quest selesai, posisi tangga per kategori, jumlah Delay Craving (total & selesai penuh), jumlah Habit Swap. Kolomnya mengikuti tabel log mingguan penelitian (keputusan 8 Okt 2026).
   - Tabel ini **tidak boleh** berisi `user_id`, email, alias, teks bebas, foto, atau lokasi.
7. **Tangga quest (personalisasi adaptif)** → lihat §4.
8. **Validasi quest** → lihat §5.
9. **Sinkronkan dokumen** `README.md` dan `docs/FEATURES.md` dengan kondisi kode.

### Sketsa skema SQL (sesuaikan)

```sql
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  alias text not null unique,
  path text check (path in ('wellness','reduction')),
  pace int check (pace between 1 and 3),
  low_impact boolean default false,
  created_at timestamptz default now()
);

create table progress_days (
  user_id uuid references auth.users on delete cascade,
  day date,
  data jsonb not null,           -- quest, xp, cardDraw, dll
  primary key (user_id, day)
);

create table capacity (
  user_id uuid primary key references auth.users on delete cascade,
  gerak int, istirahat int, tidur int, hidrasi int, makan int, jeda int, -- null = kategori tidak dipilih
  level_floor int default 1,
  updated_at timestamptz default now()
);

create table posts (
  id uuid primary key default gen_random_uuid(),
  author uuid references auth.users on delete cascade,
  alias text not null,
  body text not null check (char_length(body) <= 280),
  status text default 'pending' check (status in ('pending','approved','rejected')),
  created_at timestamptz default now()
);

create table reactions (
  post_id uuid references posts on delete cascade,
  user_id uuid references auth.users on delete cascade,
  reaction text not null,
  primary key (post_id, user_id)
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  post_id uuid references posts on delete cascade,
  reporter uuid references auth.users on delete cascade,
  reason text not null,
  created_at timestamptz default now()
);

-- research_logs: SENGAJA tanpa user_id
create table research_logs (
  id bigserial primary key,
  participant_code text check (participant_code ~ '^P([1-9]|10)$'),
  week int check (week between 1 and 4),
  opened_days int,            -- "Frekuensi membuka aplikasi": hari app dibuka (0-7)
  active_days int,            -- hari app dibuka ATAU >= 1 misi selesai
  active boolean,             -- "Status aktif": active_days > 0
  quests_done int,            -- termasuk misi latihan (hari Santai)
  ladder_gerak int, ladder_istirahat int, ladder_tidur int,
  ladder_hidrasi int, ladder_makan int, ladder_jeda int,
  delay_craving_count int,    -- semua pemakaian, termasuk timer dihentikan
  delay_craving_completed int,-- timer selesai penuh
  habit_swap_count int,
  submitted_at timestamptz default now()
);
```

Aturan RLS:

- `profiles`, `progress_days`, `capacity`: hanya `auth.uid() = id/user_id`.
- `posts`: siapa pun yang login boleh `select` jika `status = 'approved'` atau miliknya sendiri. `insert/update/delete` hanya milik sendiri. Perubahan status hanya oleh role admin.
- `reactions`: insert/delete milik sendiri. Yang ditampilkan ke publik hanya agregat jumlah.
- `reports`: insert oleh pengguna login; select hanya admin.
- `research_logs`: insert untuk pengguna login (*insert-only*); select hanya role peneliti.

Akses dashboard Supabase dibatasi untuk **1 anggota tim** dengan MFA, karena dashboard tidak terkena RLS.

---

## 4. Personalisasi adaptif: tangga quest (rule-based, TANPA ML)

> **Spesifikasi lengkap dan terbaru ada di `docs/CHALLENGE_SPEC.md`.** Bagian ini hanya ringkasan; jika berbeda, ikuti CHALLENGE_SPEC.md.

Setiap kategori punya tangga sendiri: Gerak, Istirahat (sementara; nanti Tidur & Bangun), Hidrasi, Makan (P1), dan Jeda. Posisi pengguna disimpan per kategori. Di kode, kuncinya masih `Body`, `Energy`, `Lifestyle`, `Reduction` dan dipetakan ke nama kolom penelitian saat ekspor.

**Contoh tangga Body:**

| Anak tangga | Quest |
|---|---|
| 1 | Jalan 400 m |
| 2 | Jalan 800 m |
| 3 | Jalan cepat 1,2 km |
| 4 | Jalan 1,5 km |
| 5 | Interval jalan-lari (1 menit lari / 2 menit jalan) 2 km |
| 6 | Interval jalan-lari 2,5 km |
| 7 | Lari santai 2 km |
| 8 | Lari 3 km |
| 9 | Lari 4 km |
| 10 | Lari 5 km |

**Contoh tangga Reduction:** Delay Craving 2 → 5 → 10 → 15 menit → tunda rokok/vape pertama hari ini 30 menit → 1 jam.

**Aturan, dievaluasi tiap 7 hari per kategori:**

- **Naik** 1 anak tangga (ditawarkan): kategori itu dikerjakan ≥ 3 hari dalam seminggu (`cardDays` ≥ 3, karena kategori diacak per kartu) **dan** penyelesaian ≥ 80%.
- **Turun** 1 anak tangga: penyelesaian < 50%.
- **Tahan:** kondisi selain dua di atas.
- **Tidak aktif ≥ 5 hari:** turun 1 anak tangga, tanpa hukuman.

**Batasan:**

- Naik maksimal 1 anak tangga per minggu.
- Mode *low-impact* tidak pernah masuk tangga lari.
- Pengguna boleh menolak kenaikan ("Tetap di level ini").
- Quest fisik berat diberi catatan "berhenti jika pusing atau nyeri".

**Input yang dipakai:**

- Penyelesaian quest.
- Jarak GPS aktual dibanding target.

Alasan kenaikan/penurunan harus bisa ditampilkan ke pengguna, misalnya "Naik karena 6 dari 7 quest selesai." (Penilaian usaha Ringan/Pas/Berat dihapus 7 Okt 2026; perlu dikonfirmasi ke Danar.)

```dart
int nextStep(int current, int maxStep, {
  required double completion,   // 0..1, 7 hari terakhir
  required int cardDays,        // hari kategori ini dikerjakan (bukan active_days)
  required int inactiveDays,
}) {
  if (inactiveDays >= 5) return (current - 1).clamp(1, maxStep);
  if (cardDays >= 3 && completion >= .8) return (current + 1).clamp(1, maxStep); // ditawarkan
  if (completion < .5) return (current - 1).clamp(1, maxStep);
  return current;
}
```

`DailyCardGenerator` memilih quest per kategori dari `capacity[kategori]`, bukan dari level global. Setiap kartu memuat 3 kategori acak (rokok/vape: Jeda + 2), diprioritaskan kategori yang paling jarang dikerjakan minggu itu; kartu berisi 3/3/4/4/5 misi, ditambah Kartu Bonus opsional setelah Hari Penuh (detail di CHALLENGE_SPEC §2, §4).

Dasar teori di proposal: *graded tasks* (BCT Ontology, Marques et al., 2024), aspek *ability* Fogg Behavior Model (Sittig et al., 2020), dan kebutuhan kompetensi SDT (Ryan & Deci, 2020).

---

## 5. Validasi quest

| Tingkat | Cara | Contoh |
|---|---|---|
| Otomatis | Diukur aplikasi | Jalan/lari (GPS), Delay Craving (timer harus selesai), langkah (pedometer, opsional) |
| Bukti | Pengguna memberi bukti | Meal Snap (foto wajib, isi tidak dinilai) |
| Mandiri | Centang sendiri | Minum air, tidur, stretching, Habit Swap |

**Jalan/lari:**

- Dianggap selesai jika jarak GPS ≥ target. **Durasi tidak pernah menggantikan jarak**; tanpa izin lokasi misi tidak selesai.
- Titik GPS di dalam lingkaran akurasinya diabaikan (diam tidak menambah jarak).
- Tolak jika kecepatan rata-rata > 20 km/jam (kemungkinan naik kendaraan).
- Jika tercapai sebagian, catat "selesai sebagian". Data ini masuk ke aturan tangga.
- Yang disimpan hanya meter & durasi. **Rute tidak disimpan.**
- Sesi tetap berjalan saat layar terkunci atau aplikasi di latar belakang (Android: foreground service + notifikasi; iOS: `UIBackgroundModes` location + indikator biru). Izin tetap *when in use*, tidak meminta izin lokasi "selalu".
- **Versi web (peserta iPhone, keputusan tim 8 Okt 2026):** tidak ada GPS. Misi jalan/lari dihitung dari **lama sesi** (`timedWorkouts`, `LadderRung.timedTitle`), anak tangga tetap sama. Lihat README "Distribusi untuk peserta".

**Delay Craving:**

- Tercatat penuh hanya jika timer habis.
- Jika dihentikan di tengah, catat "ditunda X menit". Ini bukan kegagalan.

**Meal Snap:**

- Foto wajib dari kamera; jam foto harus masuk jendela misi (misalnya sarapan sebelum 10.00). Isi foto tidak dinilai. Jika izin kamera ditolak, misi diganti misi centang setara.
- Foto tetap di HP, tidak pernah diunggah, dan tidak ikut ekspor.
- Pengenalan gambar on-device (misalnya ML Kit) adalah **rencana iterasi berikutnya**. Jangan diimplementasikan sekarang, karena akan bertentangan dengan klaim "tanpa ML" di proposal.

Tidak ada papan peringkat, dan XP hanya untuk diri sendiri. Validasi tidak perlu anti-curang yang berat.

---

## 6. Aturan privasi (tidak boleh dilanggar)

- Jenis/frekuensi rokok/vape dan jam tidur mentah **hanya disimpan di HP, tidak disinkronkan** (lihat CHALLENGE_SPEC §10a).
- Data kebiasaan rokok/vape = **data pribadi spesifik** (UU PDP No. 27/2022, Pasal 4 ayat 2). Terapkan minimisasi data.
- **Tanpa** SDK analitik, crash reporting pihak ketiga, maupun iklan.
- Peserta penelitian berusia 18 - 22 tahun. Onboarding tidak meminta izin wali (keputusan tim, 7 Okt 2026). Jalur rokok/vape untuk pengguna < 21 tahun diarahkan ke dukungan **berhenti** (PP 28/2024 Pasal 434 ayat 1); di aplikasi, rentang "Di bawah 18" dan "18 - 22" memakai copy "menuju berhenti".
- Admin moderator tidak boleh punya akses ke data pribadi.
- Pemegang daftar kode P1 - P10 ↔ identitas ≠ admin moderator.
- Jika terjadi kebocoran data: pemberitahuan tertulis ≤ 3 × 24 jam (UU PDP Pasal 46).
- Teks izin lokasi harus tetap menyatakan "Rute tidak disimpan", dan kode harus benar-benar begitu.

---

## 7. Konteks penelitian (agar perubahan kode tidak merusak desain studi)

**Tahap 1, kuesioner daring:**

- Minimal 100 responden usia 18 - 22 tahun.
- Login Google → mencoba alur utama → isi Google Forms (anonim, skala 1 - 6).
- Item: K1 - K4, R1 - R4, N1 - N4, B1 - B4, ditambah T1 - T5 untuk jalur rokok/vape.

**Tahap 2, UAT:**

- 10 partisipan, kelompok **berbeda** dari responden kuesioner: 4 Better Daily Rhythm; 6 Kurangi Rokok/Vape (3 perokok + 3 pengguna vape).
- Urutan: 7 skenario + *think-aloud* → pemakaian 4 minggu → kuesioner pasca-pemakaian + wawancara semiterstruktur.

**Tujuh skenario UAT yang harus bisa dijalankan tanpa bug:**

1. Buat alias & pilih companion.
2. Pilih jalur, tempo, opsi aktivitas ringan.
3. Buka Home dan selesaikan 1 Core Quest.
4. Daily Card Draw.
5. Buka Progress.
6. Buat post, beri reaksi, coba laporkan (Community).
7. Delay Craving atau Habit Swap (khusus jalur rokok/vape).

**Kriteria yang bergantung pada data aplikasi:**

- **Keterlibatan:** ≥ 6 dari 10 partisipan aktif di minggu ke-4. "Aktif" = membuka aplikasi atau menyelesaikan minimal 1 aktivitas di minggu tersebut. Data diambil dari `research_logs`.

**Jadwal:**

| Kegiatan | Tanggal |
|---|---|
| Pengembangan | 10 - 17 Okt 2026 |
| Kuesioner | 17 - 24 Okt |
| UAT + 4 minggu pemakaian | 24 Okt - 21 Nov |
| Wawancara | 21 - 24 Nov |

**PIC:**

- Alfredo: pengembangan prototipe.
- Rakhel: rekrutmen UAT.
- Danar: metode & analisis data.

---

## 8. Konvensi

- Bahasa UI: Indonesia, nada netral dan tidak menghakimi. Hindari kata "gagal", "kambuh", "pecandu".
- Nama fitur ditulis konsisten: Core Quest, Daily Card Draw, Delay Craving, Habit Swap, Community, Progress.
- Verifikasi sebelum commit: `flutter analyze` dan `flutter test`, lalu build web/iOS sesuai `README.md`.
- Jangan pernah menulis kunci Supabase ke repo. Gunakan `config/env/*.json` (sudah di-*gitignore*), dan hanya *anon key*.

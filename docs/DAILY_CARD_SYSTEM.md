# Daily Card System

Daily Card adalah pintu masuk rencana harian. Satu kartu berisi satu paket quest.

```text
5 paket kartu tersaring sesuai path, pace, dan progres
        ↓
buka rekomendasi atau spin/swipe → reveal → maksimal 1 kali ganti → commit
        ↓
3–5 quest hari ini → complete → XP → companion tumbuh
```

Setiap paket berisi tiga misi tangga dari kategori berbeda. WELLNESS memilih
tiga dari Gerak, Makan, Hidrasi, Istirahat; path reduction memakai Habit Swap
tanpa timer + dua kategori sehat (keputusan 15 Okt 2026). Habit Swap tidak
naik durasi dan tidak diduplikasi dalam misi tambahan. Deck Normal berisi
3/3/4/4/5 misi. Tempo awal 1/2/3 menentukan
tangga awal dan ukuran rekomendasi 3/4/5, bukan mengunci semua kartu.

Kedua path UAT berlangsung 28 hari kalender, lalu rekap. Kenaikan opsional,
menggunakan bukti pada tingkat saat ini, dengan tujuh hari sejak penerimaan.
Gerak dibatasi jalan tanpa lari, Makan dua foto, Istirahat layar off 30 menit,
dan Hidrasi sampai tangga 2.000 ml. Lihat batas lengkap di CHALLENGE_SPEC.
Reduction mengutamakan kategori gerak jika paparan kategori rekomendasi seri,
tanpa menambah intensitas. Habit Swap memakai pemicu–aktivitas–hasil dengan
XP sekali untuk percobaan, termasuk saat tetap menggunakan. Jurnal jumlah
konsumsi terpisah dari quest dan tidak memberikan XP; lihat REDUCTION_UAT.md.
Pengacakan ukuran menggunakan Fisher–Yates deterministik per tanggal.
Kategori jarang diambil diprioritaskan; saat seri, rekomendasi memilih beban
aktivitas lebih ringan. Waktu hidrasi/istirahat tidak ditampilkan sebagai sesi
aktif yang harus dikerjakan sekaligus. Semua personalisasi berbasis aturan.

Kartu yang dilewati menjadi abu-abu dan nonaktif. Paket yang telah di-commit
tidak dapat diganti. Progress menghitung quest dalam paket terpilih tanpa streak
reset atau freeze token. Draft lama tanpa quest selesai dimigrasikan tanpa
menghapus air atau pilihan yang sudah dilewati; hari lama yang sudah dimainkan
tetap dipertahankan.

Saat konfirmasi WELLNESS, aktivitas valid yang telah dicatat pada hari yang
sama ikut menyelesaikan misi. XP dan bonus Hari Penuh tetap sekali. Draft makan
yang melewati batas waktu diperbarui sebelum konfirmasi; jika sudah direveal,
pengguna melihat alternatif dan mengonfirmasi ulang. Kartu yang sudah diambil
tidak berubah. Hari Santai berisi tiga misi satu tingkat lebih ringan dan
tidak menjadi bukti untuk kenaikan tingkat.

File utama:

- `features/home/domain/daily_card_generator.dart`: pool dan filter.
- `features/home/presentation/daily_card_draw_dialog.dart`: ritual swipe/reveal.
- `application/wellness_controller.dart`: state transition dan persistence.
- `features/home/domain/progress_calculator.dart`: XP dan completion rate.

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

class WellnessProgramCard extends StatelessWidget {
  const WellnessProgramCard({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final program = controller.uatProgram;
    if (program == null) return const SizedBox.shrink();
    final c = context.colors;
    final summaries = [
      if (program.complete)
        for (var week = 1; week <= 4; week++) controller.researchSummary(week),
    ];
    final questDays = summaries.fold(0, (sum, row) => sum + row.questDayCount);
    final quests = summaries.fold(0, (sum, row) => sum + row.questsDone);
    return GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            program.complete
                ? 'Perjalanan 28 hari selesai'
                : 'Hari ${program.dayNumber}/28 · Minggu ${program.week}',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          if (program.complete) ...[
            Text(
              '$questDays hari dengan misi selesai · $quests misi',
              style: TextStyle(color: c.success, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Terima kasih sudah mencoba langkah kecil selama perjalanan ini. '
              'Pilih kebiasaan yang terasa cocok untuk kamu lanjutkan. Riwayat dan progresmu tetap tersimpan.',
            ),
            const SizedBox(height: 12),
            for (final row in summaries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'Minggu ${row.week}: ${row.questDayCount} hari dengan misi selesai · ${row.questsDone} misi',
                ),
              ),
          ] else ...[
            Text(
              controller.reduction
                  ? switch (program.week) {
                      1 => 'Kenali pola dan pemicu',
                      2 => 'Ubah satu momen rutin',
                      3 => 'Ulangi yang membantu',
                      _ => 'Jaga ritme yang cocok',
                    }
                  : program.phase,
              style: TextStyle(color: c.accent, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              controller.reduction
                  ? 'Catat dengan jujur. Coba gerak ringan atau aktivitas pengganti yang cocok. '
                        'Kamu boleh mempertahankan target.'
                  : program.message,
            ),
            const SizedBox(height: 8),
            Text(
              'Arah ritme: satu misi pada 4 dari 7 hari. Hari yang terlewat tidak menghapus progres.',
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: program.dayNumber / 28,
              color: c.accent,
              backgroundColor: c.raised,
            ),
          ],
        ],
      ),
    );
  }
}

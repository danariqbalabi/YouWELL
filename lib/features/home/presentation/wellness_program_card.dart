import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

class WellnessProgramCard extends StatelessWidget {
  const WellnessProgramCard({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final WellnessController controller;

  /// Home shows the day; Perjalanan also shows the week and final recap.
  final bool compact;

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
    if (compact && program.complete) {
      // After day 28 the app keeps working; Home only notes the recap.
      return GameCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            Icon(Icons.flag_rounded, color: c.success),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Periode 28 hari selesai. Rekap ada di Progres; '
                'aplikasi tetap bisa kamu pakai.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      );
    }
    if (compact) {
      return GameCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hari ${program.dayNumber}/28',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: program.dayNumber / 28,
              color: c.accent,
              backgroundColor: c.raised,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ),
      );
    }
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
              'Kartu harian, aktivitas, dan Habit Swap tetap bisa kamu pakai. '
              'Rekap ini hanya menghitung 28 hari pertama.',
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
            LinearProgressIndicator(
              value: program.dayNumber / 28,
              color: c.accent,
              backgroundColor: c.raised,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ],
        ],
      ),
    );
  }
}

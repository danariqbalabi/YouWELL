import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/features/reduction/presentation/habit_swap_panel.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/reduction/presentation/reduction_diary.dart';
import 'package:youwell/features/reduction/presentation/reduction_progress.dart';

void openReductionSupport(
  BuildContext context,
  WellnessController controller, {
  int initialTab = 0,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ReductionSupportPage(controller: controller, initialTab: initialTab),
    ),
  );
}

/// A visible entry into Habit Swap, independent of today's card.
class ReductionSupportPage extends StatelessWidget {
  const ReductionSupportPage({
    super.key,
    required this.controller,
    this.initialTab = 0,
  });
  final WellnessController controller;
  final int initialTab;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: const Text('Rokok / vape'),
        actions: [
          if (controller.reduction && !controller.uatProgramComplete)
            IconButton(
              tooltip: 'Ubah jenis penggunaan',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => SimpleDialog(
                  title: const Text('Jenis penggunaan'),
                  children: [
                    for (final entry in nicotineProductLabels.entries)
                      SimpleDialogOption(
                        onPressed: () {
                          controller.setNicotineProduct(entry.key);
                          Navigator.pop(dialogContext);
                        },
                        child: Text(entry.value),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: !controller.reduction
              ? (controller.hasOpenHabitSwapMission
                    ? HabitSwapPanel(controller: controller)
                    : const Padding(
                        padding: EdgeInsets.all(22),
                        child: Text(
                          'Misi Habit Swap sudah dicatat. Kamu bisa kembali ke Hari ini.',
                        ),
                      ))
              : controller.nicotineProduct == null &&
                    !controller.uatProgramComplete
              ? ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    Text(
                      'Apa yang kamu gunakan?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Rokok dicatat dalam batang. Vape dicatat dalam sesi. '
                      'Jika memakai keduanya, catat masing-masing secara terpisah.',
                    ),
                    const SizedBox(height: 20),
                    for (final entry in nicotineProductLabels.entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: OutlinedButton(
                          onPressed: () =>
                              controller.setNicotineProduct(entry.key),
                          child: Text(entry.value),
                        ),
                      ),
                  ],
                )
              : DefaultTabController(
                  key: ValueKey(controller.nicotineProduct),
                  length: 3,
                  initialIndex: initialTab,
                  child: Column(
                    children: [
                      const TabBar(
                        tabs: [
                          Tab(text: 'Momen'),
                          Tab(text: 'Catatan harian'),
                          Tab(text: 'Progres'),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            HabitSwapPanel(controller: controller),
                            ReductionDiary(controller: controller),
                            ReductionProgress(controller: controller),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    ),
  );
}

class ReductionEntryCard extends StatelessWidget {
  const ReductionEntryCard({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GameCard(
      borderColor: c.reduction.withValues(alpha: .45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.reduction.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.smoke_free_rounded, color: c.reduction),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  controller.reductionLabel,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${controller.swapAttemptsToday.length}',
                style: const TextStyle(
                  fontSize: 34,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'aktivitas dicoba hari ini',
                    style: TextStyle(
                      color: c.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            controller.uatProgramComplete
                ? 'Perjalanan 28 hari selesai. Lihat kembali catatan dan rekapmu.'
                : 'Saat ingin merokok/vape, catat pemicunya dan coba satu pengganti.',
            style: TextStyle(color: c.muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => openReductionSupport(context, controller),
              icon: const Icon(Icons.swap_horiz_rounded),
              label: Text(
                controller.uatProgramComplete
                    ? 'Lihat catatan & rekap'
                    : 'Buka Habit Swap',
              ),
            ),
          ),
          if (!controller.uatProgramComplete)
            TextButton(
              onPressed: () =>
                  openReductionSupport(context, controller, initialTab: 1),
              child: const Text('Catat konsumsi hari ini'),
            ),
        ],
      ),
    );
  }
}

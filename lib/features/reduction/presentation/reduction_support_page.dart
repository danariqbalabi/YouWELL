import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/features/reduction/presentation/habit_swap_panel.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/reduction/presentation/reduction_diary.dart';
import 'package:youwell/features/reduction/presentation/reduction_progress.dart';

/// [product] preselects "Saya ingin merokok/vape" for users of both.
void openReductionSupport(
  BuildContext context,
  WellnessController controller, {
  int initialTab = 0,
  String? product,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ReductionSupportPage(
        controller: controller,
        initialTab: initialTab,
        product: product,
      ),
    ),
  );
}

/// A visible entry into Habit Swap, independent of today's card.
class ReductionSupportPage extends StatelessWidget {
  const ReductionSupportPage({
    super.key,
    required this.controller,
    this.initialTab = 0,
    this.product,
  });
  final WellnessController controller;
  final int initialTab;
  final String? product;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(controller.reductionLabel),
        actions: [
          if (controller.reduction)
            IconButton(
              tooltip: 'Ubah jenis penggunaan',
              icon: const Icon(Icons.tune_rounded),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (dialogContext) => SimpleDialog(
                  title: const Text('Jenis penggunaan'),
                  children: [
                    for (final entry in nicotineChoiceLabels.entries)
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
                        child: Text('Misi Habit Swap sudah tercatat.'),
                      ))
              : controller.nicotineProduct == null
              ? ListView(
                  padding: const EdgeInsets.all(22),
                  children: [
                    Text(
                      'Apa yang kamu gunakan?',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    const Text('Rokok dihitung per batang, vape per sesi.'),
                    const SizedBox(height: 20),
                    for (final entry in nicotineChoiceLabels.entries)
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
                            HabitSwapPanel(
                              controller: controller,
                              product: product,
                            ),
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
          Text(
            '${controller.swapAttemptsToday.length} kali mencoba kegiatan '
            'pengganti hari ini',
            style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (controller.activeSwapMoment != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => openReductionSupport(context, controller),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Lanjutkan momen'),
              ),
            )
          else if (controller.nicotineProduct == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => openReductionSupport(context, controller),
                icon: const Icon(Icons.swap_horiz_rounded),
                label: const Text('Buka Habit Swap'),
              ),
            )
          else
            // One button per product: "keduanya" picks which craving now.
            for (final product in productsFor(controller.nicotineProduct))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => openReductionSupport(
                      context,
                      controller,
                      product: product,
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(cravingLabel(product)),
                  ),
                ),
              ),
          if (controller.swapsAwaitingOutcome.isNotEmpty)
            TextButton(
              onPressed: () => openReductionSupport(context, controller),
              child: Text(
                '${controller.swapsAwaitingOutcome.length} hasil momen '
                'belum diisi',
              ),
            ),
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

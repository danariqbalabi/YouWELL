import 'package:flutter/material.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/companion/presentation/mobile_companion.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/features/home/presentation/wellness_program_card.dart';
import 'package:youwell/features/progress/presentation/journey_rewards.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/features/reduction/presentation/reduction_support_page.dart';

class ProgressPage extends StatelessWidget {
  const ProgressPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final level = controller.level;

    final badges = visibleBadges(controller).toList();
    final earned = badges
        .where((entry) => controller.achievements.containsKey(entry.key))
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          'Perjalanan',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          'Semua langkah kecil tetap dihitung.',
          style: TextStyle(color: c.muted),
        ),
        const SizedBox(height: 16),
        if (controller.uatProgram != null) ...[
          WellnessProgramCard(controller: controller),
          const SizedBox(height: 14),
        ],
        GameCard(
          child: Column(
            children: [
              Row(
                children: [
                  MobileCompanion(controller: controller, size: 104),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          companionStageName(companionStage(level)),
                          style: text.titleLarge,
                        ),
                        Text(
                          'Tahap ${companionStage(level)} dari 5',
                          style: TextStyle(
                            color: c.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        XpBar(value: controller.levelProgress),
                        const SizedBox(height: 4),
                        Text(
                          '${controller.xpToNextLevel} XP lagi ke Level ${level + 1}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  LevelBadge(level, size: 64),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Stat(
                      icon: Icons.bolt_rounded,
                      value: '${controller.xp}',
                      label: 'Total XP',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat(
                      icon: Icons.local_fire_department_rounded,
                      value: '${controller.activeDaysIn(7)}/7',
                      label: 'Hari aktif',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _Stat(
                      icon: Icons.workspace_premium_rounded,
                      value: '$earned/${badges.length}',
                      label: 'Lencana',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        JourneyRewards(controller: controller),
        const SizedBox(height: 14),
        GameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tangga quest', style: text.titleMedium),
              Text(
                'Dicek tiap 7 hari. Naik hanya jika kamu setuju.',
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
              for (final category in ladderCategories(
                reduction: controller.reduction,
              ).where((category) => category != 'Reduction'))
                _LadderRow(
                  category: category,
                  entry: controller.capacity[category],
                  maxStep: controller.ladderMaximum(category),
                  timed: controller.timedWorkouts,
                ),
            ],
          ),
        ),
        if (controller.reduction) ...[
          const SizedBox(height: 14),
          GameCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(controller.reductionLabel, style: text.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        icon: Icons.swap_horiz_rounded,
                        value:
                            '${controller.habitSwaps.where(isSwapAttempt).length}',
                        label: 'Total dicoba',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Stat(
                        icon: Icons.date_range_rounded,
                        value: '${_habitSwapsThisWeek()}',
                        label: 'Dicoba, 7 hari',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _Stat(
                        icon: Icons.swap_horiz_rounded,
                        value: '${controller.swapAttemptsToday.length}',
                        label: 'Dicoba hari ini',
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: () =>
                      openReductionSupport(context, controller, initialTab: 2),
                  child: const Text('Lihat konsumsi & hasil momen'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  int _habitSwapsThisWeek() {
    final from = shiftDayKey(controller.today, -6);
    return controller.habitSwaps.where((row) {
      final day = row['day'].toString();
      return isSwapAttempt(row) &&
          day.compareTo(from) >= 0 &&
          day.compareTo(controller.today) <= 0;
    }).length;
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: c.raised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: c.primary, size: 20),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// A ladder drawn as steps: filled blocks up to the current rung.
class _LadderRow extends StatelessWidget {
  const _LadderRow({
    required this.category,
    required this.entry,
    required this.maxStep,
    required this.timed,
  });
  final String category;
  final Map<String, dynamic>? entry;
  final int maxStep;
  final bool timed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = c.category(category);
    final step = ((entry?['step'] as num?)?.toInt() ?? 1).clamp(1, maxStep);
    final rung = ladders[category]![step - 1];
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(questIcon({'category': category}), color: color, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  ladderLabels[category] ?? category,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                'Lv $step / $maxStep',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 1; index <= maxStep; index++) ...[
                  if (index > 1) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 8 + 22 * index / maxStep,
                      decoration: BoxDecoration(
                        color: index <= step
                            ? color
                            : color.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(5),
                        border: index == step
                            ? Border.all(color: c.text, width: 1.5)
                            : null,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sekarang: ${rung.titleFor(timed: timed)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (entry?['reason'] != null)
            Text(
              entry!['reason'].toString(),
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
        ],
      ),
    );
  }
}

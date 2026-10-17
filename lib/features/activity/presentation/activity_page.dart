import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/activity/presentation/activity_history_page.dart';
import 'package:youwell/features/activity/presentation/meal_snap_page.dart';
import 'package:youwell/features/activity/presentation/workout_page.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key, required this.controller});
  final WellnessController controller;

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (controller.uatProgramComplete) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Aktivitas', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text(
            'Perjalanan 28 hari selesai. Catatan sebelumnya tetap bisa dilihat; tidak ada challenge baru.',
          ),
          const SizedBox(height: 16),
          _ActivityAction(
            icon: Icons.history_rounded,
            color: c.accent,
            title: 'Riwayat aktivitas',
            detail: 'Lihat langkah-langkah yang sudah kamu catat.',
            onTap: () =>
                _open(context, ActivityHistoryPage(controller: controller)),
          ),
        ],
      );
    }
    final todayWorkouts = controller.workoutSessions
        .where((row) => row['day'] == controller.today)
        .toList();
    final todayMeals = controller.mealCheckIns
        .where((row) => row['day'] == controller.today)
        .length;
    final meters = todayWorkouts.fold<int>(
      0,
      (sum, row) => sum + ((row['meters'] as num?)?.toInt() ?? 0),
    );
    final minutes =
        todayWorkouts.fold<int>(
          0,
          (sum, row) => sum + ((row['seconds'] as num?)?.toInt() ?? 0),
        ) ~/
        60;
    final timed = controller.workoutUsesTimer;
    // The open quest each action below finishes, shown on that action.
    Map<String, dynamic>? openQuest(Set<String> kinds) => controller.quests
        .where(
          (task) =>
              task['status'] != 'completed' &&
              kinds.contains(task['activityKind']),
        )
        .firstOrNull;
    final moveQuest = openQuest(const {'walk', 'run'});
    final mealQuest = openQuest(const {'meal_snap'});
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Text(
          'Aktivitas',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text('Gerak, makan, dan hidrasi.', style: TextStyle(color: c.muted)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _TodayMetric(
                icon: Icons.directions_walk_rounded,
                color: c.body,
                value: timed
                    ? '$minutes mnt'
                    : meters >= 1000
                    ? '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km'
                    : '$meters m',
                label: timed ? 'gerak hari ini' : 'jarak hari ini',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TodayMetric(
                icon: Icons.restaurant_rounded,
                color: c.reduction,
                value: '$todayMeals',
                label: 'Meal Snap',
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _HydrationCard(controller: controller),
        const SizedBox(height: 14),
        _ActivityAction(
          icon: Icons.directions_run_rounded,
          color: c.body,
          title: controller.workoutDraft != null
              ? 'Lanjutkan sesi gerak'
              : 'Jalan atau lari',
          detail: controller.workoutDraft != null
              ? 'Ada sesi yang belum disimpan. Ketuk untuk lanjut atau simpan.'
              : timed
              ? 'Dihitung dari waktu. Boleh kunci layar.'
              : 'Boleh kunci layar. Rute tidak disimpan.',
          quest: moveQuest,
          onTap: () => _open(context, WorkoutPage(controller: controller)),
        ),
        const SizedBox(height: 10),
        _ActivityAction(
          icon: Icons.photo_camera_rounded,
          color: c.reduction,
          title: 'Meal Snap',
          detail: 'Foto makan tetap di HP-mu.',
          quest: mealQuest,
          onTap: () => _open(context, MealSnapPage(controller: controller)),
        ),
        const SizedBox(height: 10),
        _ActivityAction(
          icon: Icons.history_rounded,
          color: c.accent,
          title: 'Riwayat aktivitas',
          detail:
              '${controller.workoutSessions.length} sesi gerak · '
              '${controller.mealCheckIns.length} Meal Snap',
          onTap: () =>
              _open(context, ActivityHistoryPage(controller: controller)),
        ),
      ],
    );
  }
}

class _HydrationCard extends StatelessWidget {
  const _HydrationCard({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // One number: today's Hidrasi step, the same target as its quest.
    final goal = controller.waterTarget;
    final top = controller.waterTop;
    final water = controller.water.toInt();
    final quest = controller.quests
        .where((task) => task['ladder'] == 'Lifestyle')
        .firstOrNull;
    return GameCard(
      child: Row(
        children: [
          RingProgress(
            value: water / goal,
            size: 92,
            stroke: 10,
            color: c.lifestyle,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.water_drop_rounded, color: c.lifestyle, size: 22),
                Text(
                  '${(water / goal * 100).clamp(0, 100).round()}%',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hidrasi', style: Theme.of(context).textTheme.titleMedium),
                Text(
                  '$water / $goal ml',
                  style: TextStyle(color: c.muted, fontWeight: FontWeight.w700),
                ),
                if (quest != null)
                  Text(
                    quest['status'] == 'completed'
                        ? 'Misi hidrasi selesai!'
                        : 'Misi hari ini',
                    style: TextStyle(
                      color: quest['status'] == 'completed'
                          ? c.success
                          : c.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                if (goal < top)
                  Text(
                    'Puncak tangga: $top ml',
                    style: TextStyle(color: c.muted, fontSize: 12),
                  ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: controller.addWater,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('250 ml'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayMetric extends StatelessWidget {
  const _TodayMetric({
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final Color color;
  final String value, label;
  @override
  Widget build(BuildContext context) => GameCard(
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: context.colors.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActivityAction extends StatelessWidget {
  const _ActivityAction({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
    required this.onTap,
    this.quest,
  });
  final IconData icon;
  final Color color;
  final String title, detail;
  final VoidCallback onTap;

  /// An open quest this action finishes; shown with its XP and progress.
  final Map<String, dynamic>? quest;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final quest = this.quest;
    final partial = (quest?['partial'] as num?)?.toDouble();
    return GameCard(
      onTap: onTap,
      color: quest == null ? null : c.xpSoft,
      borderColor: quest == null ? null : c.xp.withValues(alpha: .5),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quest == null
                      ? detail
                      : partial == null
                      ? 'Misi: ${quest['title']}'
                      : 'Misi: ${quest['title']} · '
                            '${(partial * 100).round()}%',
                  style: TextStyle(
                    color: quest == null ? c.muted : c.text,
                    fontSize: 13,
                    fontWeight: quest == null ? null : FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (quest != null)
            XpPill((quest['xp'] as num?)?.toInt() ?? 0)
          else
            Icon(Icons.chevron_right_rounded, color: c.muted),
        ],
      ),
    );
  }
}

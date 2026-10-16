import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/core/utils/date_label.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

/// Icon and unlock hint for each personal badge.
const badgeVisuals = <String, (IconData, String)>{
  'first-quest': (Icons.flag_rounded, 'Selesaikan 1 misi'),
  'full-day': (Icons.emoji_events_rounded, 'Selesaikan semua misi sehari'),
  'weekly-rhythm': (
    Icons.local_fire_department_rounded,
    'Aktif 4 hari dalam 7 hari',
  ),
  'hydration-7': (Icons.water_drop_rounded, 'Capai target minum 7 hari'),
  'first-ladder': (Icons.stairs_rounded, 'Naik 1 anak tangga'),
};

/// Badges that apply to this user's path.
Iterable<MapEntry<String, String>> visibleBadges(WellnessController c) =>
    achievementNames.entries;

class JourneyRewards extends StatelessWidget {
  const JourneyRewards({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final active = controller.activeDaysIn(7);
    final start =
        DateTime.tryParse(controller.profile?['started']?.toString() ?? '') ??
        controller.now;
    final doneDays = controller.activeDays.toSet();
    final fullDays = controller.completedDays.toSet();
    final sessions = controller.workoutSessions
        .where(
          (row) =>
              row['day'].toString().compareTo(
                    shiftDayKey(controller.today, -6),
                  ) >=
                  0 &&
              row['day'].toString().compareTo(controller.today) <= 0,
        )
        .length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameCard(
          child: Row(
            children: [
              RingProgress(
                value: active / 4,
                size: 84,
                stroke: 9,
                color: active >= 4 ? c.success : c.primary,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$active/7',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'hari',
                      style: TextStyle(
                        fontSize: 11,
                        color: c.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ritme mingguan', style: text.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      active >= 4
                          ? 'Target 4 hari tercapai!'
                          : '${4 - active} hari lagi menuju target',
                      style: TextStyle(
                        color: active >= 4 ? c.success : c.amber,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Hari terlewat tidak menghapus progress.',
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        GameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('28 hari perjalananmu', style: text.titleMedium),
              const SizedBox(height: 2),
              Text(
                'Mulai ${shortDate(dayKey(start))} · $sessions sesi gerak dalam 7 hari terakhir',
                style: TextStyle(color: c.muted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 28,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 7,
                  crossAxisSpacing: 7,
                ),
                itemBuilder: (context, index) {
                  final day = shiftDayKey(dayKey(start), index);
                  final full = fullDays.contains(day),
                      done = doneDays.contains(day),
                      today = day == controller.today;
                  final future = day.compareTo(controller.today) > 0;
                  final state = full
                      ? 'hari penuh'
                      : done
                      ? 'aktif'
                      : future
                      ? 'belum tiba'
                      : 'istirahat';
                  return Tooltip(
                    message: '${dayLabel(day, controller.now)} · $state',
                    child: Semantics(
                      label: 'Hari ${index + 1}, $state',
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: full
                              ? c.success
                              : done
                              ? c.xp
                              : future
                              ? c.raised.withValues(alpha: .5)
                              : c.raised,
                          borderRadius: BorderRadius.circular(10),
                          border: today
                              ? Border.all(color: c.text, width: 2)
                              : null,
                        ),
                        child: full
                            ? Icon(Icons.star_rounded, color: c.card, size: 20)
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: done
                                      ? const Color(0xff3b1a02)
                                      : future
                                      ? c.muted.withValues(alpha: .6)
                                      : c.muted,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _Legend(color: c.success, label: 'Hari penuh'),
                  _Legend(color: c.xp, label: 'Ada misi selesai'),
                  _Legend(color: c.raised, label: 'Istirahat'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        BadgeGrid(controller: controller),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 6),
      Text(
        label,
        style: TextStyle(
          fontSize: 12.5,
          color: context.colors.muted,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

/// Medallion grid: earned badges in color, locked ones with an unlock hint.
class BadgeGrid extends StatelessWidget {
  const BadgeGrid({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final badges = visibleBadges(controller).toList();
    final earned = badges
        .where((entry) => controller.achievements.containsKey(entry.key))
        .length;
    return GameCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Koleksi lencana',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '$earned/${badges.length}',
                style: TextStyle(color: c.muted, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          Text(
            'Hanya untukmu. Tidak ada peringkat.',
            style: TextStyle(color: c.muted, fontSize: 13),
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: badges.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 14,
              crossAxisSpacing: 10,
              mainAxisExtent: 128,
            ),
            itemBuilder: (context, index) {
              final entry = badges[index];
              final unlocked = controller.achievements[entry.key];
              final (icon, hint) =
                  badgeVisuals[entry.key] ??
                  (Icons.workspace_premium_rounded, '');
              return Semantics(
                label: unlocked == null
                    ? '${entry.value}, terkunci. $hint'
                    : '${entry.value}, terbuka',
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: unlocked == null ? c.raised : c.xp,
                        border: Border.all(
                          color: unlocked == null ? c.border : c.card,
                          width: 3,
                        ),
                      ),
                      child: Icon(
                        unlocked == null ? Icons.lock_rounded : icon,
                        color: unlocked == null
                            ? c.muted
                            : const Color(0xff3b1a02),
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.value,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        color: unlocked == null ? c.muted : c.text,
                      ),
                    ),
                    Text(
                      unlocked == null ? hint : shortDate(unlocked.toString()),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.2,
                        color: c.muted,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

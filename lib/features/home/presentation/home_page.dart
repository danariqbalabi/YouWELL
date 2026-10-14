import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/companion/presentation/companion_page.dart';
import 'package:youwell/features/companion/presentation/mobile_companion.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/features/home/presentation/wellness_program_card.dart';
import 'package:youwell/features/reduction/presentation/reduction_support_page.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

/// Bonus XP for finishing every quest of the day (see wellness_gamification).
const _fullDayBonus = 20;

class HomePage extends StatelessWidget {
  const HomePage({
    super.key,
    required this.controller,
    required this.onOpenDraw,
    required this.onOpenActivity,
    this.companionKey,
  });

  final WellnessController controller;
  final VoidCallback onOpenDraw;
  final VoidCallback onOpenActivity;
  final GlobalKey? companionKey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final started = DateTime.tryParse(
      controller.profile?['started']?.toString() ?? '',
    );
    final dayNumber = started == null
        ? 1
        : controller.now.difference(started).inDays + 1;
    Widget questCard(Map<String, dynamic> task) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _QuestCard(
        task: task,
        onComplete: switch (task['activityKind']) {
          null => () => controller.completeCard(task['id'].toString()),
          'delay' ||
          'habit_swap' => () => openReductionSupport(context, controller),
          _ => onOpenActivity,
        },
      ),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
      children: [
        Text(
          'Hai, ${controller.profile!['alias']}!',
          style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          controller.wellnessUat
              ? '28 hari membangun langkah kecil'
              : 'Hari ke-$dayNumber perjalananmu',
          style: text.bodyMedium?.copyWith(
            color: c.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        if (controller.wellnessUat) ...[
          WellnessProgramCard(controller: controller),
          const SizedBox(height: 16),
        ],
        _PlayerCard(controller: controller, companionKey: companionKey),
        if (controller.ladderOffers.isNotEmpty) ...[
          const SizedBox(height: 16),
          _LadderBanner(controller: controller),
        ],
        if (!controller.wellnessProgramComplete) ...[
          const SizedBox(height: 32),
          _TodayHeader(controller: controller),
          if (controller.quests.isEmpty && controller.needsDailyCardDraw)
            _DrawPrompt(onOpenDraw: onOpenDraw)
          else ...[
            _FullDayMeter(controller: controller),
            const SizedBox(height: 20),
            for (final task in controller.coreQuests) questCard(task),
            if (controller.canDrawBonusCard) ...[
              const SizedBox(height: 8),
              _BonusOffer(controller: controller),
            ],
            if (controller.bonusQuests.isNotEmpty) ...[
              const SizedBox(height: 24),
              const SectionTitle('Kartu Bonus', icon: Icons.star_rounded),
              for (final task in controller.bonusQuests) questCard(task),
            ],
          ],
        ],
        if (controller.reduction) ...[
          const SizedBox(height: 20),
          ReductionEntryCard(controller: controller),
        ],
      ],
    );
  }
}

/// Companion, level, XP to the next level, and the next reward. Tap the
/// companion for a short reaction.
class _PlayerCard extends StatefulWidget {
  const _PlayerCard({required this.controller, this.companionKey});
  final WellnessController controller;
  final GlobalKey? companionKey;
  @override
  State<_PlayerCard> createState() => _PlayerCardState();
}

class _PlayerCardState extends State<_PlayerCard> {
  int _greeting = 0;
  static const _greetings = [
    'Ayo, satu misi lagi!',
    'Senang kamu mampir!',
    'Satu langkah juga berarti.',
    'Aku tumbuh bareng kamu.',
  ];

  WellnessController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = Theme.of(context).textTheme;
    final kind = controller.profile!['companion'].toString();
    final name =
        const {'plant': 'Mori', 'cat': 'Milo', 'cloud': 'Awan'}[kind] ?? 'Mori';
    final level = controller.level;

    final next = companionUnlocks
        .where((item) => item.level > level)
        .firstOrNull;
    void openCompanion() => Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => CompanionPage(controller: controller),
      ),
    );
    return GameCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                key: widget.companionKey,
                child: MobileCompanion(
                  controller: controller,
                  size: 112,
                  onTap: () => setState(
                    () => _greeting = (_greeting + 1) % _greetings.length,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        LevelBadge(level, size: 40),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.dailyProgress == 1
                          ? 'Hari penuh! Keren!'
                          : _greetings[_greeting],
                      style: TextStyle(
                        color: c.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    XpBar(value: controller.levelProgress),
                    const SizedBox(height: 6),
                    Text(
                      '${controller.xpToNextLevel} XP lagi ke Level ${level + 1}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Material(
            color: c.raised,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: openCompanion,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 52),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(Icons.card_giftcard_rounded, color: c.reduction),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          next == null
                              ? 'Semua hadiah terbuka. Lihat lemari'
                              : 'Hadiah berikutnya: ${next.label} (Lv ${next.level})',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: c.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One compact banner instead of a stack of ladder offer cards.
class _LadderBanner extends StatelessWidget {
  const _LadderBanner({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final offers = controller.ladderOffers;
    return GameCard(
      color: c.successSoft,
      borderColor: c.success.withValues(alpha: .45),
      onTap: () => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => AnimatedBuilder(
          animation: controller,
          builder: (sheetContext, _) => SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Siap naik anak tangga?',
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Naik hanya kalau kamu mau. Tetap di level ini juga oke.',
                    style: TextStyle(color: c.muted),
                  ),
                  const SizedBox(height: 14),
                  if (controller.ladderOffers.isEmpty)
                    Text(
                      'Semua pilihan sudah tersimpan.',
                      style: TextStyle(
                        color: c.success,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  for (final category in controller.ladderOffers)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LadderOfferCard(
                        controller: controller,
                        category: category,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.stairs_rounded, color: c.success),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${offers.length} anak tangga siap naik',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  offers.map((name) => ladderLabels[name] ?? name).join(' · '),
                  style: TextStyle(
                    color: c.success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: c.success),
        ],
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final core = controller.coreQuests;
    final total = core.length;
    final done = core.where((task) => task['status'] == 'completed').length;
    return SectionTitle(
      'Misi hari ini',
      trailing: total == 0
          ? null
          : Text(
              '$done/$total selesai',
              style: TextStyle(
                color: context.colors.muted,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

/// One bar toward the once-a-day "Hari Penuh" bonus.
class _FullDayMeter extends StatelessWidget {
  const _FullDayMeter({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final core = controller.coreQuests;
    final total = core.length;
    final done = core.where((task) => task['status'] == 'completed').length;
    if (total == 0) return const SizedBox.shrink();
    final full = done == total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        XpBar(value: done / total, height: 16),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(
              full ? Icons.emoji_events_rounded : Icons.redeem_rounded,
              size: 20,
              color: full ? c.success : c.reduction,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                full
                    ? 'Hari Penuh tercapai!'
                    : 'Selesaikan semua untuk bonus Hari Penuh',
                style: TextStyle(
                  fontSize: 13.5,
                  color: full ? c.success : c.text,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const XpPill(_fullDayBonus),
          ],
        ),
      ],
    );
  }
}

/// Optional extra card once today's missions are done (max. once a day).
class _BonusOffer extends StatelessWidget {
  const _BonusOffer({required this.controller});
  final WellnessController controller;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GameCard(
      color: c.xpSoft,
      borderColor: c.xp,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.star_rounded, color: c.onXp, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Masih semangat? Ada Kartu Bonus',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '3 misi ringan, masing-masing +$bonusQuestXp XP. Opsional, sekali sehari.',
            style: TextStyle(
              color: c.text,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ChunkyButton(
            label: 'Ambil Kartu Bonus',
            icon: Icons.style_rounded,
            onPressed: controller.drawBonusCard,
          ),
        ],
      ),
    );
  }
}

class _DrawPrompt extends StatelessWidget {
  const _DrawPrompt({required this.onOpenDraw});
  final VoidCallback onOpenDraw;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GameCard(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Icon(Icons.style_rounded, color: c.lifestyle, size: 48),
          const SizedBox(height: 12),
          Text(
            'Kartu misimu menunggu',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Pilih 1 dari 5 kartu. Tiap kartu berisi 3–5 misi.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          ChunkyButton(
            label: 'Buka kartu hari ini',
            icon: Icons.auto_awesome_rounded,
            onPressed: onOpenDraw,
          ),
        ],
      ),
    );
  }
}

/// Offers a ladder step up; the user may stay ("Tetap di level ini").
class LadderOfferCard extends StatelessWidget {
  const LadderOfferCard({
    super.key,
    required this.controller,
    required this.category,
  });
  final WellnessController controller;
  final String category;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final entry = controller.capacity[category]!;
    final next = (entry['offerStep'] as num).toInt();
    final rung = ladders[category]![next - 1];
    final color = c.category(category);
    return GameCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '${ladderLabels[category]} · anak tangga ${next - 1} → $next',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            rung.title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            entry['reason'].toString(),
            style: TextStyle(color: c.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => controller.acceptLadderStep(category),
                  icon: const Icon(Icons.trending_up_rounded),
                  label: const Text('Naik'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.declineLadderStep(category),
                  child: const Text('Tetap di level ini'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _shortLadder = {
  'Body': 'Gerak',
  'Food': 'Makan',
  'Energy': 'Istirahat',
  'Reduction': 'Jeda',
  'Lifestyle': 'Hidrasi',
};

class _QuestCard extends StatelessWidget {
  const _QuestCard({required this.task, required this.onComplete});
  final Map<String, dynamic> task;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = task['status'] == 'completed';
    final needsEvidence = task['validationInvalidated'] == true;
    final kind = task['activityKind'];
    final color = c.category(task['category']);
    final partial = task['partial'] is num && !done
        ? (task['partial'] as num).toDouble()
        : null;
    final action = needsEvidence
        ? 'Catat sesi baru tanpa mengulang XP'
        : done
        ? 'Selesai'
        : kind == null
        ? 'Tandai selesai'
        : kind == 'delay'
        ? 'Mulai timer Delay Craving'
        : kind == 'habit_swap'
        ? 'Pilih Habit Swap'
        : 'Buka Aktivitas untuk menyelesaikan';
    return GameCard(
      color: done ? c.successSoft : c.card,
      borderColor: done ? c.success.withValues(alpha: .45) : null,
      onTap: done && !needsEvidence ? null : onComplete,
      padding: const EdgeInsets.all(16),
      child: Semantics(
        button: !done || needsEvidence,
        label: '${task['title']}. $action',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: done ? c.success : color.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : questIcon(task),
                    color: done ? c.card : color,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task['title'].toString(),
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          done ? 'Selesai' : '${task['durationMinutes']} menit',
                          if (task['ladder'] != null)
                            '${_shortLadder[task['ladder']]} Lv ${task['step']}',
                        ].join(' · '),
                        style: TextStyle(
                          color: done ? c.success : c.muted,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    XpPill((task['xp'] as num?)?.toInt() ?? 0),
                    if (!done) ...[
                      const SizedBox(height: 6),
                      Icon(
                        kind == null
                            ? Icons.radio_button_unchecked_rounded
                            : Icons.arrow_forward_rounded,
                        color: c.muted,
                        semanticLabel: action,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            if (partial != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 62),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: partial,
                          minHeight: 8,
                          color: c.xp,
                          backgroundColor: c.raised,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      task['activityKind'] == 'meal_snap'
                          ? '${(partial * ((task['photoCount'] as num?) ?? 1)).round()}/${task['photoCount'] ?? 1} foto'
                          : '${(partial * 100).round()}% tercapai',
                      style: TextStyle(
                        color: c.amber,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (kind == 'meal_snap' && !done)
              _Note(icon: Icons.photo_camera_rounded, text: _photoRule(task)),
            if (task['strenuous'] == true && !done)
              _Note(
                icon: Icons.health_and_safety_outlined,
                text: 'Berhenti jika pusing atau nyeri.',
              ),
            if (needsEvidence)
              const _Note(
                icon: Icons.info_outline_rounded,
                text:
                    'Bukti sesi tidak dipakai untuk evaluasi. XP tetap tersimpan.',
              ),
          ],
        ),
      ),
    );
  }
}

/// "Foto sebelum 10.00", "2 foto", or "Foto 10.00–14.00 dan 17.00–21.00".
String _photoRule(Map<String, dynamic> task) {
  final count = (task['photoCount'] as num?)?.toInt() ?? 1;
  final windows = (task['photoWindows'] as List?)
      ?.map((window) => (window as List).cast<num>())
      .toList();
  String hour(num h) => '${h.toInt().toString().padLeft(2, '0')}.00';
  if (windows == null || windows.isEmpty) {
    return count > 1
        ? 'Butuh $count foto dari kamera.'
        : 'Butuh 1 foto dari kamera.';
  }
  final parts = [
    for (final window in windows)
      window[0] <= 4
          ? 'sebelum ${hour(window[1])}'
          : '${hour(window[0])}–${hour(window[1])}',
  ];
  return 'Foto ${parts.join(', ')}.';
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    // Lines up with the quest title, past the 48 px icon and its gap.
    padding: const EdgeInsets.only(top: 10, left: 62),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: context.colors.muted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: context.colors.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ),
      ],
    ),
  );
}

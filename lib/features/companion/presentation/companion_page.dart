import 'package:flutter/material.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/companion/presentation/mobile_companion.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

/// What the big companion shows instead of today's look, so the user can see
/// a later growth stage or a locked reward before reaching it.
class _Preview {
  const _Preview({
    required this.id,
    required this.label,
    required this.unlockLevel,
    this.stage,
    this.accessory,
    this.background,
  });
  final String id, label;
  final int unlockLevel;
  final int? stage;
  final String? accessory, background;
}

class _CompanionPageState extends State<CompanionPage> {
  _Preview? _preview;
  final _scroll = ScrollController();

  WellnessController get controller => widget.controller;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Toggles a preview and scrolls up so the big companion shows it.
  void _show(_Preview preview) {
    setState(() => _preview = _preview?.id == preview.id ? null : preview);
    if (_preview != null && _scroll.hasClients && _scroll.offset > 0) {
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final c = context.colors;
      final text = Theme.of(context).textTheme;
      final kind = controller.profile?['companion']?.toString() ?? 'plant';
      final level = controller.level;
      final stage = companionStage(level);
      final preview = _preview;

      final items = [
        const CompanionUnlock('none', 'Tanpa aksesori', 1, false),
        const CompanionUnlock('natural', 'Latar alami', 1, true),
        ...companionUnlocks,
      ];
      return Scaffold(
        appBar: AppBar(
          title: Text(controller.companionDisplayName),
          actions: [
            IconButton(
              tooltip: 'Ganti nama',
              icon: const Icon(Icons.edit_rounded),
              onPressed: () => renameCompanion(context, controller),
            ),
          ],
        ),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: preview == null
                    ? MobileCompanion(
                        key: const ValueKey('now'),
                        controller: controller,
                        size: 240,
                      )
                    : CompanionPreview(
                        key: ValueKey(preview.id),
                        kind: kind,
                        stage: preview.stage ?? stage,
                        accessory:
                            preview.accessory ?? controller.companionAccessory,
                        background:
                            preview.background ??
                            controller.companionBackground,
                        size: 240,
                      ),
              ),
            ),
            const SizedBox(height: 8),
            if (preview != null)
              _PreviewBanner(
                label: preview.label,
                unlockLevel: preview.unlockLevel,
                reached: level >= preview.unlockLevel,
                onClose: () => setState(() => _preview = null),
              )
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    companionStageName(stage),
                    style: text.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 10),
                  LevelBadge(level, size: 44),
                ],
              ),
              const SizedBox(height: 12),
              XpBar(value: controller.levelProgress),
              const SizedBox(height: 6),
              Text(
                '${controller.xpToNextLevel} XP lagi ke Level ${level + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
            const SizedBox(height: 28),
            const SectionTitle('Jalur tumbuh', icon: Icons.spa_rounded),
            Text(
              'Ketuk untuk melihat wujudnya nanti.',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 128,
              child: Row(
                children: [
                  for (var step = 1; step <= 5; step++)
                    Expanded(
                      child: _StageStep(
                        kind: kind,
                        step: step,
                        reached: step <= stage,
                        current: step == stage,
                        previewing: preview?.id == 'stage-$step',
                        unlockLevel: companionStageLevels[step - 1],
                        onTap: step == stage && preview == null
                            ? null
                            : () => step == stage
                                  ? setState(() => _preview = null)
                                  : _show(
                                      _Preview(
                                        id: 'stage-$step',
                                        label: companionStageName(step),
                                        unlockLevel:
                                            companionStageLevels[step - 1],
                                        stage: step,
                                      ),
                                    ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionTitle(
              'Lemari hadiah',
              icon: Icons.card_giftcard_rounded,
            ),
            Text(
              'Ketuk untuk memakai. Yang masih terkunci bisa dilihat dulu.',
              style: TextStyle(color: c.muted, fontSize: 13),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                mainAxisExtent: 156,
              ),
              itemBuilder: (context, index) {
                final item = items[index];
                final unlocked = level >= item.level;
                final worn =
                    (item.background
                        ? controller.companionBackground
                        : controller.companionAccessory) ==
                    item.id;
                return _RewardTile(
                  label: item.label,
                  unlocked: unlocked,
                  worn: worn,
                  previewing: preview?.id == 'item-${item.id}',
                  unlockLevel: item.level,
                  preview: CompanionPreview(
                    kind: kind,
                    stage: stage,
                    accessory: item.background
                        ? controller.companionAccessory
                        : item.id,
                    background: item.background
                        ? item.id
                        : controller.companionBackground,
                  ),
                  onTap: unlocked
                      ? () {
                          setState(() => _preview = null);
                          controller.equipCompanion(
                            item.id,
                            background: item.background,
                          );
                        }
                      : () => _show(
                          _Preview(
                            id: 'item-${item.id}',
                            label: item.label,
                            unlockLevel: item.level,
                            accessory: item.background ? null : item.id,
                            background: item.background ? item.id : null,
                          ),
                        ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

/// Names what the big companion is previewing and when it unlocks.
class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({
    required this.label,
    required this.unlockLevel,
    required this.reached,
    required this.onClose,
  });
  final String label;
  final int unlockLevel;
  final bool reached;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GameCard(
      color: c.xpSoft,
      borderColor: c.xp,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Icon(
            reached ? Icons.visibility_rounded : Icons.lock_clock_rounded,
            color: c.onXp,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pratinjau: $label',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reached
                      ? 'Sudah kamu lewati di Level $unlockLevel.'
                      : 'Terbuka di Level $unlockLevel. Terus kumpulkan XP!',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onClose, child: const Text('Kembali')),
        ],
      ),
    );
  }
}

class _StageStep extends StatelessWidget {
  const _StageStep({
    required this.kind,
    required this.step,
    required this.reached,
    required this.current,
    required this.previewing,
    required this.unlockLevel,
    required this.onTap,
  });
  final String kind;
  final int step, unlockLevel;
  final bool reached, current, previewing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
      selected: previewing,
      label:
          '${companionStageName(step)}, ${reached ? 'tercapai' : 'terbuka di level $unlockLevel'}',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.card,
                border: Border.all(
                  color: previewing
                      ? c.primary
                      : current
                      ? c.xp
                      : c.border,
                  width: current || previewing ? 3 : 1.5,
                ),
              ),
              child: Opacity(
                opacity: reached || previewing ? 1 : .3,
                child: CompanionPreview(kind: kind, stage: step, size: 56),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              companionStageName(step),
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w800,
                color: reached ? c.text : c.muted,
              ),
            ),
            Text(
              reached ? (current ? 'Sekarang' : 'Tercapai') : 'Lv $unlockLevel',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: current ? c.onXp : c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardTile extends StatelessWidget {
  const _RewardTile({
    required this.label,
    required this.unlocked,
    required this.worn,
    required this.previewing,
    required this.unlockLevel,
    required this.preview,
    required this.onTap,
  });
  final String label;
  final bool unlocked, worn, previewing;
  final int unlockLevel;
  final Widget preview;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: worn || previewing,
      label: unlocked
          ? '$label${worn ? ', sedang dipakai' : ''}'
          : '$label, terbuka di level $unlockLevel. Ketuk untuk melihat.',
      child: GameCard(
        onTap: onTap,
        color: worn ? c.xpSoft : c.card,
        borderColor: previewing
            ? c.primary
            : worn
            ? c.xp
            : null,
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: unlocked || previewing ? 1 : .35,
                  child: preview,
                ),
                if (!unlocked && !previewing)
                  Icon(Icons.lock_rounded, color: c.text, size: 26),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              !unlocked
                  ? (previewing ? 'Dilihat' : 'Level $unlockLevel')
                  : worn
                  ? 'Dipakai'
                  : 'Pakai',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: worn ? c.onXp : c.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user give the companion their own name (1–20 characters).
Future<void> renameCompanion(
  BuildContext context,
  WellnessController controller,
) => showDialog<String>(
  context: context,
  builder: (_) => TextEntryDialog(
    title: 'Beri nama companion',
    message: 'Nama ini tampil di Hari ini dan halaman companion.',
    hint: controller.companionDisplayName,
    maxLength: 20,
    maxLines: 1,
    confirmLabel: 'Simpan',
    onSubmit: (name) async =>
        controller.setCompanionName(name) ? null : 'Pakai 1–20 karakter.',
  ),
);

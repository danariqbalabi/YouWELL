import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:youwell/application/app_auth_controller.dart';
import 'package:youwell/application/progress_sync_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/home/domain/progress_calculator.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';

class ProgressSyncPanel extends StatelessWidget {
  const ProgressSyncPanel({
    super.key,
    required this.auth,
    this.compact = false,
  });
  final AppAuthController auth;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final sync = auth.progress;
    if (sync == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: sync,
      builder: (context, _) {
        final title = switch (sync.stage) {
          SyncStage.syncing => 'Menyinkronkan progres…',
          SyncStage.offline => 'Tersimpan di perangkat · belum sinkron',
          SyncStage.conflict => 'Ada progres berbeda di cloud',
          SyncStage.stopped => 'Sinkron dihentikan',
          SyncStage.idle =>
            sync.pending ? 'Menunggu sinkron' : 'Progres tersinkron',
        };
        if (compact) {
          if (sync.stage == SyncStage.idle && !sync.pending) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Icon(
                  sync.hasConflict
                      ? Icons.cloud_off_rounded
                      : Icons.cloud_sync_rounded,
                  size: 18,
                  color: context.colors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ProgressSyncPanel(auth: auth),
                      ),
                    ),
                  ),
                  child: const Text('Buka'),
                ),
              ],
            ),
          );
        }
        return GameCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                sync.error ??
                    'Profil, kartu, quest, XP, companion, dan log aktivitas tersinkron ke akunmu. Foto, rute, catatan pribadi dan data komunitas tidak ikut.',
              ),
              if (sync.lastSyncedAt case final date?) ...[
                const SizedBox(height: 8),
                Text(
                  'Versi cloud terakhir: ${date.toLocal()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 12),
              if (sync.hasConflict) ...[
                _SnapshotLine(
                  label: 'Perangkat ini',
                  payload: sync.localSummary,
                ),
                _SnapshotLine(label: 'Cloud', payload: sync.conflict?.payload),
                const SizedBox(height: 8),
                const Text(
                  'Tidak digabung otomatis. Salinan lokal sebelum penggantian disimpan sebagai cadangan pemulihan pada perangkat ini.',
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: sync.conflict == null
                      ? null
                      : () => _confirm(context, useCloud: true),
                  child: const Text('Gunakan cloud'),
                ),
                OutlinedButton(
                  onPressed: () => _confirm(context, useCloud: false),
                  child: const Text('Gunakan progres perangkat ini'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: sync.stage == SyncStage.syncing
                      ? null
                      : sync.syncNow,
                  icon: const Icon(Icons.sync_rounded),
                  label: const Text('Sinkron sekarang'),
                ),
              if (sync.recovery != null)
                TextButton.icon(
                  onPressed: () {
                    // Recovery exports never include local filesystem handles.
                    final raw =
                        jsonDecode(sync.recovery!) as Map<String, dynamic>;
                    for (final row
                        in (raw['mealCheckIns'] as List).whereType<Map>()) {
                      row.remove('photoPath');
                    }
                    platform.download(
                      'youwell-pemulihan-lokal.json',
                      utf8.encode(
                        const JsonEncoder.withIndent('  ').convert(raw),
                      ),
                      'application/json',
                    );
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Ekspor cadangan pemulihan'),
                ),
              if (sync.cloudRecovery != null)
                TextButton.icon(
                  onPressed: () => platform.download(
                    'youwell-cloud-sebelum-diganti.json',
                    utf8.encode(
                      const JsonEncoder.withIndent(
                        '  ',
                      ).convert(jsonDecode(sync.cloudRecovery!)),
                    ),
                    'application/json',
                  ),
                  icon: const Icon(Icons.download_rounded),
                  label: const Text('Ekspor cloud sebelum diganti'),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirm(BuildContext context, {required bool useCloud}) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          useCloud
              ? 'Lanjutkan progres cloud?'
              : 'Ganti cloud dengan progres perangkat ini?',
        ),
        content: SingleChildScrollView(
          child: Text(
            useCloud
                ? 'Quest dan progres pada perangkat ini akan diganti dengan salinan cloud. Catatan/foto lokal yang masih cocok tetap di perangkat. Salinan pemulihan disimpan lokal.'
                : 'Salinan cloud diganti dengan progres perangkat ini. Perubahan berbeda dari perangkat lain tidak digabung. Perangkat lain akan diminta memilih jika memiliki perubahan sendiri.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Lanjutkan'),
          ),
        ],
      ),
    );
    if (yes == true) await auth.resolveProgress(useCloud: useCloud);
  }
}

class _SnapshotLine extends StatelessWidget {
  const _SnapshotLine({required this.label, required this.payload});
  final String label;
  final Map<String, dynamic>? payload;
  @override
  Widget build(BuildContext context) {
    final data = payload;
    if (data == null) return Text('$label: belum tersedia');
    final days = Map<String, dynamic>.from((data['days'] as Map?) ?? {});
    final rewards = (data['mobileRewards'] as Map?) ?? {};
    final bonus = rewards.values.whereType<Map>().fold<int>(
      0,
      (sum, row) => sum + ((row['bonusXp'] as num?)?.toInt() ?? 0),
    );
    final xp = ProgressCalculator(days: days, now: DateTime.now()).xp + bonus;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        '$label: ${data['profile']?['alias'] ?? 'Belum ada profil'} · $xp XP · ${days.length} hari tercatat',
      ),
    );
  }
}

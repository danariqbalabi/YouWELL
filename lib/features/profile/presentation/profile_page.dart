import 'package:flutter/material.dart';
import 'package:youwell/features/companion/presentation/companion_page.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';
import 'package:youwell/application/app_auth_controller.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
import 'package:youwell/features/activity/data/meal_photo_store.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/features/companion/presentation/mobile_companion.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/reduction/presentation/reduction_support_page.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/sync/presentation/progress_sync_panel.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key, required this.controller});
  final WellnessController controller;

  Future<void> _editAlias(BuildContext context) => showDialog<String>(
    context: context,
    builder: (_) => TextEntryDialog(
      title: 'Ganti nama panggilan',
      message: 'Tampil di Community, bukan nama asli.',
      hint: controller.profile?['alias']?.toString(),
      maxLength: 20,
      maxLines: 1,
      minLength: 3,
      confirmLabel: 'Simpan',
      onSubmit: (alias) async {
        try {
          controller.setAlias(alias);
          return null;
        } on ArgumentError {
          return '3–20 karakter, diawali huruf (huruf/angka/_).';
        }
      },
    ),
  );

  /// Rokok, vape or both; history and daily totals stay per product.
  Future<void> _chooseProduct(BuildContext context) => showDialog<void>(
    context: context,
    builder: (dialogContext) => SimpleDialog(
      title: const Text('Yang kamu gunakan'),
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
  );

  void _switchPath(BuildContext context, bool enabled) =>
      controller.switchPath(enabled);

  @override
  Widget build(BuildContext context) {
    if (controller.profile == null) return const SizedBox.shrink();
    return _mobileBuild(context);
  }

  Future<void> _confirmReset(BuildContext context) async {
    final account = AccountScope.maybeOf(context);
    final syncing = account?.progress != null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          syncing ? 'Mulai ulang progres akun?' : 'Hapus semua data?',
        ),
        content: Text(
          syncing
              ? 'Quest, XP, dan progres akun akan direset di perangkat ini lalu dikirim ke cloud saat terhubung. Foto milik akun ini di perangkat akan dihapus dan tidak bisa dipulihkan. Akun Google/Supabase tidak dihapus.'
              : 'Profil, progress, dan foto Meal Snap di perangkat ini akan dihapus. '
                    'Ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd92d20),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _deletePhotos();
      await controller.reset();
      await account?.clearRecoveryCopies();
      if (context.mounted) Navigator.pop(context);
    }
  }

  /// Photos of this account only: other cached accounts keep theirs, and a
  /// path outside the Meal Snap folder is never touched.
  Future<void> _deletePhotos() async {
    for (final meal in controller.mealCheckIns) {
      if (meal['photoPath'] case final String path) {
        try {
          await MealPhotoStore.delete(path);
        } catch (_) {
          // One unreadable photo must not block deleting the rest.
        }
      }
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AppAuthController account,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus akun YouWELL?'),
        content: const SingleChildScrollView(
          child: Text(
            'Profil, progres, post, reaksi, dan laporanmu di server dihapus '
            'permanen. Data dan foto akun ini di perangkat juga dihapus. Akun '
            'Google-mu sendiri tidak terpengaruh.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd92d20),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus akun'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      // On success the signed-out screen replaces this whole app.
      await account.deleteAccount(deleteLocalFiles: _deletePhotos);
    } catch (_) {
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Akun belum terhapus. Periksa koneksi lalu coba lagi; tidak ada data yang dihapus.',
          ),
        ),
      );
    }
  }

  Widget _mobileBuild(BuildContext context) {
    final appearance = AppearanceScope.of(context);
    final c = context.colors;
    final profile = controller.profile!;
    final kind = profile['companion']?.toString() ?? 'plant';
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Profil')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.raised,
                  ),
                  child: CompanionPreview(
                    kind: kind,
                    stage: companionStage(controller.level),
                    accessory: controller.companionAccessory,
                    background: controller.companionBackground,
                    size: 72,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        profile['alias'].toString(),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      Text(
                        'Level ${controller.level} · ${controller.xp} XP',
                        style: TextStyle(
                          color: c.muted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const _Heading('Tampilan'),
            Row(
              children: [
                for (final (index, (value, label, icon)) in const [
                  ('light', 'Terang', Icons.light_mode_rounded),
                  ('dark', 'Gelap', Icons.dark_mode_rounded),
                  ('system', 'Sistem', Icons.brightness_auto_rounded),
                ].indexed) ...[
                  if (index > 0) const SizedBox(width: 10),
                  Expanded(
                    child: _ThemeOption(
                      label: label,
                      icon: icon,
                      selected: appearance.themePreference == value,
                      onTap: () => appearance.setThemePreference(value),
                    ),
                  ),
                ],
              ],
            ),
            const _Heading('Nama'),
            _Group(
              children: [
                _Row(
                  icon: Icons.badge_outlined,
                  label: 'Nama panggilan: ${profile['alias']}',
                  onTap: () => _editAlias(context),
                ),
                _Row(
                  icon: Icons.spa_outlined,
                  label: 'Nama companion: ${controller.companionDisplayName}',
                  onTap: () => renameCompanion(context, controller),
                ),
              ],
            ),
            const _Heading('Preferensi'),
            _Group(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.smoke_free_rounded),
                  title: Text(
                    'Jalur ${controller.reductionLabel.toLowerCase()}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  value: controller.reduction,
                  onChanged: (value) => _switchPath(context, value),
                ),
                if (controller.reduction) ...[
                  _Row(
                    icon: Icons.local_fire_department_outlined,
                    label:
                        'Yang kamu gunakan: ${nicotineChoiceLabels[controller.nicotineProduct] ?? 'belum dipilih'}',
                    onTap: () => _chooseProduct(context),
                  ),
                  _Row(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Buka Habit Swap',
                    onTap: () => openReductionSupport(context, controller),
                  ),
                ],
                SwitchListTile(
                  secondary: const Icon(Icons.directions_walk_rounded),
                  title: const Text(
                    'Aktivitas ringan',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Tanpa quest lari.'),
                  value: profile['lowImpact'] == true,
                  onChanged: controller.setLowImpact,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.animation_rounded),
                  title: const Text(
                    'Kurangi animasi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  value: controller.reduceMotion,
                  onChanged: controller.setReduceMotion,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vibration_rounded),
                  title: const Text(
                    'Getaran',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  value: controller.haptics,
                  onChanged: controller.setHaptics,
                ),
              ],
            ),
            const _Heading('Data & privasi'),
            _Group(
              children: [
                _Row(
                  icon: Icons.delete_outline_rounded,
                  label: AccountScope.maybeOf(context)?.progress == null
                      ? 'Hapus data & mulai ulang'
                      : 'Mulai ulang progres akun',
                  danger: true,
                  onTap: () => _confirmReset(context),
                ),
              ],
            ),
            if (AccountScope.maybeOf(context) case final account?) ...[
              const SizedBox(height: 16),
              ProgressSyncPanel(auth: account),
              const SizedBox(height: 16),
              _Group(
                children: [
                  _Row(
                    icon: Icons.person_remove_outlined,
                    label: 'Hapus akun',
                    danger: true,
                    onTap: () => _confirmDeleteAccount(context, account),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Keluar dari akun?'),
                      content: const Text(
                        'Progres yang belum tersinkron tetap tersimpan pada perangkat ini untuk akunmu. Keluar tidak menghapus akun atau progres. Pastikan status sinkron selesai sebelum berpindah perangkat.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Batal'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Keluar'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) await account.signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Keluar dari akun'),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              AccountScope.maybeOf(context)?.progress == null
                  ? 'Data tersimpan di perangkat ini. Foto Meal Snap tidak pernah diunggah.'
                  : 'Progres disinkronkan ke Supabase saat terhubung. Foto dan catatan pribadi tetap di perangkat; rute tidak diunggah.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.muted, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
    ),
  );
}

/// Bordered list group with dividers between rows.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => GameCard(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      children: [
        for (final (index, child) in children.indexed) ...[
          if (index > 0) const Divider(indent: 16, endIndent: 16),
          child,
        ],
      ],
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xffd92d20) : context.colors.text;
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w800),
      ),
      trailing: Icon(Icons.chevron_right_rounded, color: context.colors.muted),
      onTap: onTap,
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      child: GameCard(
        onTap: onTap,
        color: selected ? c.selected : c.card,
        borderColor: selected ? c.primary : null,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, size: 28, color: selected ? c.success : c.muted),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

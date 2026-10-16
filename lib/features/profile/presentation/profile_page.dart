import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/theme/appearance_scope.dart';
import 'package:youwell/features/activity/data/meal_photo_store.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/features/companion/presentation/mobile_companion.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/reduction/presentation/reduction_support_page.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/sync/presentation/progress_sync_panel.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({
    super.key,
    required this.controller,
    this.mobileExperience = false,
  });
  final WellnessController controller;
  final bool mobileExperience;

  Future<void> _researchConsent(BuildContext context) async {
    String? code = controller.researchParticipation?['code']?.toString();
    var agreed = false;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Ringkasan UAT opsional'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ringkasan berisi jumlah hari dibuka, aktivitas, quest, tingkat tangga, Delay Craving, dan Habit Swap. Tidak menyertakan alias, teks pribadi, foto, atau lokasi. Belum dikirim otomatis; ekspor dan bagikan hanya jika kamu setuju.',
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: code,
                  decoration: const InputDecoration(
                    labelText: 'Kode dari peneliti',
                  ),
                  items: [
                    for (var i = 1; i <= 10; i++)
                      DropdownMenuItem(value: 'P$i', child: Text('P$i')),
                  ],
                  onChanged: (value) => update(() => code = value),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Saya setuju menyiapkan ringkasan ini.'),
                  value: agreed,
                  onChanged: (value) => update(() => agreed = value == true),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: agreed && code != null
                  ? () {
                      controller.setResearchParticipation(code, consent: true);
                      Navigator.pop(dialogContext);
                    }
                  : null,
              child: const Text('Simpan persetujuan'),
            ),
          ],
        ),
      ),
    );
  }

  void _switchPath(BuildContext context, bool enabled) =>
      controller.switchPath(enabled);

  @override
  Widget build(BuildContext context) {
    if (controller.profile == null) return const SizedBox.shrink();
    return mobileExperience ? _mobileBuild(context) : _webBuild(context);
  }

  Future<void> _confirmReset(BuildContext context) async {
    final syncing = AccountScope.maybeOf(context)?.progress != null;
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
      // Photos belonging to other cached accounts must survive this reset.
      for (final meal in controller.mealCheckIns) {
        if (meal['photoPath'] case final String path) {
          await MealPhotoStore.delete(path);
        }
      }
      await controller.reset();
      if (context.mounted) Navigator.pop(context);
    }
  }

  /// Optional UAT summary: code, consent, export, and withdrawal.
  void _researchSheet(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => AnimatedBuilder(
      animation: controller,
      builder: (sheetContext, _) {
        final joined = controller.researchParticipation;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ringkasan penelitian',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  joined == null
                      ? 'Opsional. Kamu tetap bisa memakai aplikasi tanpa ikut penelitian.'
                      : 'Kode ${joined['code']} · hanya ringkasan angka, tanpa alias, teks, foto, atau lokasi.',
                  style: TextStyle(color: sheetContext.colors.muted),
                ),
                const SizedBox(height: 16),
                if (joined == null)
                  FilledButton(
                    onPressed: () => _researchConsent(sheetContext),
                    child: const Text('Atur persetujuan & kode'),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: () => platform.download(
                      'youwell-uat-summary.json',
                      utf8.encode(controller.exportResearchSummary()),
                      'application/json',
                    ),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Ekspor ringkasan'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () => controller.setResearchParticipation(
                      null,
                      consent: false,
                    ),
                    child: const Text('Tarik persetujuan'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tidak menarik salinan yang sudah kamu bagikan ke peneliti.',
                    style: TextStyle(
                      color: sheetContext.colors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );

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
                if (controller.reduction)
                  _Row(
                    icon: Icons.timer_outlined,
                    label: 'Buka Delay Craving & Habit Swap',
                    onTap: () => openReductionSupport(context, controller),
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.directions_walk_rounded),
                  title: const Text(
                    'Aktivitas ringan (low-impact)',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Quest lari tidak akan muncul.'),
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
                  icon: Icons.download_rounded,
                  label: 'Ekspor data',
                  onTap: () => platform.download(
                    'youwell-${controller.today}.json',
                    utf8.encode(controller.export()),
                    'application/json',
                  ),
                ),
                _Row(
                  icon: Icons.science_outlined,
                  label: 'Ringkasan penelitian (opsional)',
                  onTap: () => _researchSheet(context),
                ),
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

  Widget _webBuild(BuildContext context) {
    final appearance = AppearanceScope.of(context);
    final profile = controller.profile!;
    return Scaffold(
      appBar: AppBar(title: const Text('Profil & Pengaturan')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 36),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.colors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: context.colors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: context.colors.selected,
                    child: Text(
                      profile['alias'].toString()[0].toUpperCase(),
                      style: TextStyle(
                        color: context.colors.accent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile['alias'].toString(),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Level ${controller.level}  •  ${controller.xp} XP',
                          style: TextStyle(color: context.colors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _Section(
              title: 'Tampilan',
              children: [
                Text(
                  'Pilih tema atau ikuti pengaturan perangkat.',
                  style: TextStyle(color: context.colors.muted),
                ),
                const SizedBox(height: 14),
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'system', label: Text('Sistem')),
                    ButtonSegment(value: 'light', label: Text('Terang')),
                    ButtonSegment(value: 'dark', label: Text('Gelap')),
                  ],
                  selected: {appearance.themePreference},
                  onSelectionChanged: (selection) =>
                      appearance.setThemePreference(selection.first),
                ),
              ],
            ),
            if (mobileExperience)
              _Section(
                title: 'Animasi & getaran',
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kurangi animasi'),
                    subtitle: const Text(
                      'Reward tetap terlihat tanpa gerakan.',
                    ),
                    value: controller.reduceMotion,
                    onChanged: controller.setReduceMotion,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Getaran ringan'),
                    value: controller.haptics,
                    onChanged: controller.setHaptics,
                  ),
                ],
              ),
            _Section(
              title: 'Preferensi',
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Jalur ${controller.reductionLabel.toLowerCase()}',
                  ),
                  subtitle: Text(
                    controller.reduction
                        ? 'Aktif. Delay Craving & Habit Swap ada di bawah companion di Hari ini.'
                        : 'Tampilkan Delay Craving & Habit Swap di Hari ini dan tambahkan quest-nya ke kartu harian.',
                  ),
                  value: controller.reduction,
                  onChanged: (value) => _switchPath(context, value),
                ),
                if (controller.reduction) ...[
                  FilledButton.icon(
                    onPressed: () => openReductionSupport(context, controller),
                    icon: const Icon(Icons.smoke_free_rounded),
                    label: const Text('Buka Delay Craving & Habit Swap'),
                  ),
                  const SizedBox(height: 10),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mode aktivitas ringan (low-impact)'),
                  subtitle: const Text('Quest lari tidak akan muncul.'),
                  value: profile['lowImpact'] == true,
                  onChanged: controller.setLowImpact,
                ),
              ],
            ),
            if (mobileExperience)
              _Section(
                title: 'UAT opsional',
                children: [
                  Text(
                    controller.researchParticipation == null
                        ? 'Tetap bisa memakai aplikasi tanpa ikut penelitian.'
                        : 'Kode ${controller.researchParticipation!['code']} · hanya ringkasan angka',
                    style: TextStyle(color: context.colors.muted),
                  ),
                  TextButton(
                    onPressed: () => _researchConsent(context),
                    child: const Text('Atur persetujuan & kode'),
                  ),
                  if (controller.researchParticipation != null) ...[
                    OutlinedButton.icon(
                      onPressed: () => platform.download(
                        'youwell-uat-summary.json',
                        utf8.encode(controller.exportResearchSummary()),
                        'application/json',
                      ),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Ekspor ringkasan UAT'),
                    ),
                    TextButton(
                      onPressed: () => controller.setResearchParticipation(
                        null,
                        consent: false,
                      ),
                      child: const Text('Tarik persetujuan lokal'),
                    ),
                    Text(
                      'Tidak menarik salinan yang sudah kamu bagikan ke peneliti.',
                      style: TextStyle(
                        color: context.colors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            _Section(
              title: 'Data lokal',
              children: [
                Text(
                  'Belum ada akun atau cloud sync. Data hanya tersimpan di perangkat ini.',
                  style: TextStyle(color: context.colors.muted, height: 1.5),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => platform.download(
                    'youwell-${controller.today}.json',
                    utf8.encode(controller.export()),
                    'application/json',
                  ),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Ekspor data'),
                ),
                TextButton(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Mulai ulang?'),
                        content: const Text(
                          'Profil dan seluruh progress lokal akan dihapus.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Batal'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Hapus'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await MealPhotoStore.clear();
                      await controller.reset();
                      if (context.mounted) Navigator.pop(context);
                    }
                  },
                  child: const Text('Hapus data & mulai ulang'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.border),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    ),
  );
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

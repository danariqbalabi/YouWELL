import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/config/app_environment.dart';

class AdminModerationPage extends StatelessWidget {
  const AdminModerationPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  Widget build(BuildContext context) {
    final queue = controller.moderationQueue;
    final reports = controller.communityReports;
    return ListView(
      padding: const EdgeInsets.all(30),
      children: [
        const Text(
          'Moderasi komunitas',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          'Pratinjau lokal. Halaman ini belum menerima post dari perangkat peserta.',
          style: TextStyle(color: context.colors.muted),
        ),
        const SizedBox(height: 24),
        if (AppEnvironment.showPreviewTools) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: controller.addModerationPreviewPost,
              icon: const Icon(Icons.add),
              label: const Text('Tambah contoh post'),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _Summary(pending: queue.length, reports: reports.length),
        const SizedBox(height: 24),
        const Text(
          'Menunggu persetujuan',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (queue.isEmpty)
          const _Empty(message: 'Tidak ada post yang menunggu review.'),
        ...queue.map(
          (post) => _ModerationCard(controller: controller, post: post),
        ),
        const SizedBox(height: 24),
        const Text(
          'Laporan',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (reports.isEmpty) const _Empty(message: 'Tidak ada laporan aktif.'),
        ...reports.map(
          (report) => Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.flag_outlined, color: context.colors.amber),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${report['reason']} • ${report['postId']}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton(
                  onPressed: () => controller.resolveCommunityReport(
                    report['id'].toString(),
                  ),
                  child: const Text('Selesaikan'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.pending, required this.reports});
  final int pending, reports;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: _Number(value: '$pending', label: 'Menunggu'),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _Number(value: '$reports', label: 'Laporan'),
      ),
    ],
  );
}

class _Number extends StatelessWidget {
  const _Number({required this.value, required this.label});
  final String value, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            color: context.colors.accent,
            fontSize: 32,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(label, style: TextStyle(color: context.colors.muted)),
      ],
    ),
  );
}

class _ModerationCard extends StatelessWidget {
  const _ModerationCard({required this.controller, required this.post});
  final WellnessController controller;
  final Map<String, dynamic> post;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.colors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '@${post['alias']}',
          style: TextStyle(
            color: context.colors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (post['sample'] == true) ...[
          const Chip(label: Text('Contoh lokal')),
          const SizedBox(height: 8),
        ],
        Text(post['text'].toString(), style: const TextStyle(height: 1.5)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          children: [
            FilledButton.icon(
              onPressed: () => controller.moderateCommunityPost(
                post['id'].toString(),
                'approved',
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text('Setujui'),
            ),
            OutlinedButton.icon(
              onPressed: () => controller.moderateCommunityPost(
                post['id'].toString(),
                'rejected',
                note: 'Tidak sesuai panduan komunitas.',
              ),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Tolak'),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: context.colors.border),
    ),
    child: Text(message, style: TextStyle(color: context.colors.muted)),
  );
}

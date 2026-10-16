import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/features/community/domain/community_store.dart';
import 'package:youwell/features/community/presentation/community_page.dart';
import 'package:youwell/core/platform/platform.dart' as platform;
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/progress/domain/research_log_store.dart';

const _reasonLabels = {'unsafe': 'Tidak aman', 'spam': 'Spam'};

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage> {
  late CommunityStore _store;
  ModerationQueue? _queue;
  String? _error;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = communityStoreOf(context, widget.controller);
    if (_queue == null) _load();
  }

  Future<void> _load() async {
    try {
      final queue = await _store.moderationQueue();
      if (mounted) {
        setState(() {
          _queue = queue;
          _error = null;
        });
      }
    } on CommunityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  /// Researchers download the latest weekly logs: codes and numbers only.
  Future<void> _exportResearch(ResearchLogStore store) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final rows = await store.exportLatest();
      platform.download(
        'youwell-research-logs.csv',
        utf8.encode(researchCsv(rows)),
        'text/csv',
      );
      messenger.showSnackBar(
        SnackBar(content: Text('${rows.length} baris diunduh.')),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Ringkasan belum bisa diunduh. Periksa koneksi dan migration tahap 4.',
          ),
        ),
      );
    }
  }

  Future<void> _act(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on CommunityException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final queue = _queue;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(30),
        children: [
          const Text(
            'Moderasi komunitas',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            _store.shared
                ? 'Post peserta tampil setelah kamu setujui. Hanya alias dan isi post yang terlihat.'
                : 'Pratinjau lokal. Halaman ini tidak menerima post dari perangkat peserta.',
            style: TextStyle(color: context.colors.muted),
          ),
          const SizedBox(height: 24),
          if (AccountScope.maybeOf(context)?.researchStore case final research?) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _exportResearch(research),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Unduh ringkasan penelitian (CSV)'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (!_store.shared && AppEnvironment.showPreviewTools) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _act(() async {
                  widget.controller.addModerationPreviewPost();
                }),
                icon: const Icon(Icons.add),
                label: const Text('Tambah contoh post'),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_error != null) ...[
            _Empty(message: _error!),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _load,
                child: const Text('Coba lagi'),
              ),
            ),
          ] else if (queue == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            _Summary(
              pending: queue.pending.length,
              reports: queue.reports.length,
            ),
            const SizedBox(height: 24),
            const Text(
              'Menunggu persetujuan',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (queue.pending.isEmpty)
              const _Empty(message: 'Tidak ada post yang menunggu review.'),
            for (final post in queue.pending)
              _ModerationCard(
                post: post,
                busy: _busy,
                approveLabel: 'Setujui',
                rejectLabel: 'Tolak',
                onApprove: () =>
                    _act(() => _store.moderate(post.id, approve: true)),
                onReject: () =>
                    _act(() => _store.moderate(post.id, approve: false)),
              ),
            const SizedBox(height: 24),
            const Text(
              'Laporan',
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            if (queue.reports.isEmpty)
              const _Empty(message: 'Tidak ada laporan aktif.'),
            for (final report in queue.reports)
              _ModerationCard(
                post: report.post,
                busy: _busy,
                label: 'Dilaporkan: ${_reasonLabels[report.reason] ?? report.reason}',
                approveLabel: 'Biarkan tampil',
                rejectLabel: 'Sembunyikan',
                onApprove: () => _act(() => _store.resolveReport(report.id)),
                onReject: () async {
                  await _act(
                    () => _store.moderate(report.post.id, approve: false),
                  );
                  // The server settles reports on hide; the preview does not.
                  if (!_store.shared) {
                    await _act(() => _store.resolveReport(report.id));
                  }
                },
              ),
          ],
        ],
      ),
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
  const _ModerationCard({
    required this.post,
    required this.busy,
    required this.approveLabel,
    required this.rejectLabel,
    required this.onApprove,
    required this.onReject,
    this.label,
  });
  final CommunityPost post;
  final bool busy;
  final String approveLabel, rejectLabel;
  final String? label;
  final VoidCallback onApprove, onReject;
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
        if (label case final label?) ...[
          Row(
            children: [
              Icon(Icons.flag_outlined, color: context.colors.amber, size: 18),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
        ],
        Text(
          '@${post.alias}',
          style: TextStyle(
            color: context.colors.accent,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        if (post.sample) ...[
          const Chip(label: Text('Contoh lokal')),
          const SizedBox(height: 8),
        ],
        Text(post.body, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : onApprove,
              icon: const Icon(Icons.check_rounded),
              label: Text(approveLabel),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onReject,
              icon: const Icon(Icons.close_rounded),
              label: Text(rejectLabel),
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

import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/features/community/domain/community_store.dart';
import 'package:youwell/features/community/presentation/community_page.dart';

const _reasonLabels = {'unsafe': 'Tidak aman', 'spam': 'Spam'};

class AdminModerationPage extends StatefulWidget {
  const AdminModerationPage({super.key, required this.controller, this.store});
  final WellnessController controller;

  /// Overrides the account's store (tests).
  final CommunityStore? store;

  @override
  State<AdminModerationPage> createState() => _AdminModerationPageState();
}

class _AdminModerationPageState extends State<AdminModerationPage> {
  late CommunityStore _store;
  ModerationQueue? _queue;
  String? _error;
  bool _busy = false;

  /// Which list is shown: pending, published or reports.
  var _view = 'pending';

  // "Sudah tayang": searched, paged from the server, newest first.
  static const _pageSize = 30;
  final _search = TextEditingController();
  List<CommunityPost>? _published;
  bool _hasMore = false, _loadingMore = false;
  String? _publishedError;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadPublished({bool more = false}) async {
    if (_loadingMore) return;
    setState(() {
      _loadingMore = true;
      if (!more) _publishedError = null;
    });
    try {
      final page = await _store.publishedPosts(
        query: _search.text,
        before: more ? _published?.lastOrNull?.createdAt : null,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _published = [if (more) ...?_published, ...page];
        _hasMore = page.length == _pageSize;
      });
    } on CommunityException catch (error) {
      if (mounted) setState(() => _publishedError = error.message);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store = widget.store ?? communityStoreOf(context, widget.controller);
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

  /// Runs [action], shows its error if any, and reloads. True on success.
  Future<bool> _act(Future<void> Function() action) async {
    if (_busy) return false;
    setState(() => _busy = true);
    var ok = true;
    try {
      await action();
    } on CommunityException catch (error) {
      ok = false;
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
    await _load();
    if (mounted) setState(() => _busy = false);
    return ok;
  }

  /// Deleting cannot be undone, so it always asks first.
  Future<void> _delete(CommunityPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus post ini?'),
        content: Text(
          'Post @${post.alias} dihapus permanen beserta foto, reaksi, dan '
          'laporannya. Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // Only confirm success; a failure already showed its own message.
    if (await _act(() => _store.adminDeletePost(post.id)) && mounted) {
      setState(
        () => _published = _published?.where((p) => p.id != post.id).toList(),
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Post dihapus.')));
    }
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
            'Community',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            _store.shared
                ? 'Setujui post baru, tinjau laporan, dan hapus post yang sudah tayang. Hanya alias dan isi post yang terlihat.'
                : 'Pratinjau lokal. Halaman ini tidak menerima post dari perangkat peserta.',
            style: TextStyle(color: context.colors.muted),
          ),
          const SizedBox(height: 24),
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
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: 'pending',
                  label: Text('Menunggu (${queue.pending.length})'),
                ),
                const ButtonSegment(
                  value: 'published',
                  label: Text('Sudah tayang'),
                ),
                ButtonSegment(
                  value: 'reports',
                  label: Text('Laporan (${queue.reports.length})'),
                ),
              ],
              selected: {_view},
              onSelectionChanged: (value) {
                setState(() => _view = value.single);
                // Reload so newly approved posts show up.
                if (_view == 'published') _loadPublished();
              },
            ),
            const SizedBox(height: 20),
            ...switch (_view) {
              'published' => _publishedView(context),
              'reports' => _reportsView(queue),
              _ => _pendingView(queue),
            },
          ],
        ],
      ),
    );
  }

  List<Widget> _pendingView(ModerationQueue queue) => [
    if (queue.pending.isEmpty)
      const _Empty(message: 'Tidak ada post yang menunggu review.'),
    for (final post in queue.pending)
      _ModerationCard(
        post: post,
        busy: _busy,
        approveLabel: 'Setujui',
        rejectLabel: 'Tolak',
        onApprove: () => _act(() => _store.moderate(post.id, approve: true)),
        onReject: () => _act(() => _store.moderate(post.id, approve: false)),
        onDelete: () => _delete(post),
      ),
  ];

  List<Widget> _reportsView(ModerationQueue queue) => [
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
          await _act(() => _store.moderate(report.post.id, approve: false));
          // The server settles reports on hide; the preview does not.
          if (!_store.shared) {
            await _act(() => _store.resolveReport(report.id));
          }
        },
        onDelete: () => _delete(report.post),
      ),
  ];

  List<Widget> _publishedView(BuildContext context) {
    final posts = _published;
    return [
      TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.search_rounded),
          hintText: 'Cari alias atau isi post',
          suffixIcon: IconButton(
            tooltip: 'Cari',
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: _loadPublished,
          ),
        ),
        onSubmitted: (_) => _loadPublished(),
      ),
      const SizedBox(height: 16),
      if (_publishedError != null) ...[
        _Empty(message: _publishedError!),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _loadPublished,
            child: const Text('Coba lagi'),
          ),
        ),
      ] else if (posts == null)
        const Center(child: CircularProgressIndicator())
      else ...[
        if (posts.isEmpty)
          _Empty(
            message: _search.text.trim().isEmpty
                ? 'Belum ada post yang tayang.'
                : 'Tidak ada post tayang yang cocok.',
          ),
        for (final post in posts)
          _ModerationCard(
            post: post,
            busy: _busy,
            onDelete: () => _delete(post),
          ),
        if (_hasMore)
          Center(
            child: OutlinedButton(
              onPressed: _loadingMore ? null : () => _loadPublished(more: true),
              child: const Text('Muat lebih banyak'),
            ),
          ),
      ],
    ];
  }
}

class _ModerationCard extends StatelessWidget {
  const _ModerationCard({
    required this.post,
    required this.busy,
    required this.onDelete,
    this.approveLabel,
    this.rejectLabel,
    this.onApprove,
    this.onReject,
    this.label,
  });
  final CommunityPost post;
  final bool busy;
  final String? approveLabel, rejectLabel, label;
  final VoidCallback? onApprove, onReject;
  final VoidCallback onDelete;
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
        PostPhoto(post: post),
        if (post.body.isNotEmpty)
          Text(post.body, style: const TextStyle(height: 1.5)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (onApprove != null)
              FilledButton.icon(
                onPressed: busy ? null : onApprove,
                icon: const Icon(Icons.check_rounded),
                label: Text(approveLabel ?? 'Setujui'),
              ),
            if (onReject != null)
              OutlinedButton.icon(
                onPressed: busy ? null : onReject,
                icon: const Icon(Icons.close_rounded),
                label: Text(rejectLabel ?? 'Tolak'),
              ),
            TextButton.icon(
              onPressed: busy ? null : onDelete,
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Hapus'),
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

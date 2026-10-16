import 'package:flutter/material.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/community/data/local_community_store.dart';
import 'package:youwell/features/community/domain/community_store.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

/// The signed-in account's server Community, or the on-device preview.
CommunityStore communityStoreOf(
  BuildContext context,
  WellnessController controller,
) => AccountScope.maybeOf(context)?.community ?? LocalCommunityStore(controller);

class CommunityPage extends StatefulWidget {
  const CommunityPage({super.key, required this.controller});
  final WellnessController controller;

  @override
  State<CommunityPage> createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage> {
  late CommunityStore _store;
  List<CommunityPost>? _posts;
  String? _error;
  bool _loading = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final store = communityStoreOf(context, widget.controller);
    if (_posts == null || store.shared != _store.shared) {
      _store = store;
      _load();
    } else {
      _store = store;
    }
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final posts = await _store.feed();
      if (mounted) {
        setState(() {
          _posts = posts;
          _error = null;
        });
      }
    } on CommunityException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _say(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  /// Runs an action, then refreshes the wall; failures stay on screen.
  Future<void> _act(Future<void> Function() action) async {
    try {
      await action();
    } on CommunityException catch (error) {
      _say(error.message);
    }
    await _load();
  }

  Future<void> _compose() async {
    final controller = widget.controller;
    final sent = await showDialog<String>(
      context: context,
      builder: (_) => TextEntryDialog(
        title: 'Bagikan kemenangan kecil',
        message: 'Post masuk ke antrean moderator sebelum tampil.',
        hint: 'Hari ini aku berhasil…',
        maxLength: maxCommunityPostLength,
        maxLines: 4,
        minLength: 3,
        confirmLabel: 'Kirim untuk review',
        suggestion: (
          'Isi dengan progres hari ini',
          () =>
              'Hari ini aku menyelesaikan ${controller.completedCards.length} '
              'misi dan sekarang di Level ${controller.level}!',
        ),
        onSubmit: (text) async {
          try {
            await _store.submit(text);
            return null;
          } on CommunityException catch (error) {
            return error.message;
          }
        },
      ),
    );
    if (sent == null || !mounted) return;
    _say('Post terkirim. Tampil setelah disetujui moderator.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final posts = _posts;
    final wall = posts?.where((post) => post.status == 'approved').toList();
    final waiting = posts
        ?.where((post) => post.mine && post.status == 'pending')
        .length;
    final rejected = posts
        ?.where((post) => post.mine && post.status == 'rejected')
        .length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          Text(
            'Community',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            _store.shared
                ? 'Saling semangati dengan alias. Tidak ada peringkat.'
                : 'Pratinjau di perangkat ini: post tidak terkirim ke orang lain.',
            style: TextStyle(color: c.muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _compose,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Bagikan progres'),
            ),
          ),
          const SizedBox(height: 14),
          if ((waiting ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InfoCard(
                icon: Icons.schedule_rounded,
                title: waiting == 1
                    ? 'Post kamu sedang direview'
                    : '$waiting post kamu sedang direview',
                detail: 'Moderator mengecek post sebelum tampil.',
              ),
            ),
          if ((rejected ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _InfoCard(
                icon: Icons.visibility_off_outlined,
                title: 'Ada post yang tidak ditampilkan',
                detail:
                    'Moderator menilai post itu belum sesuai panduan komunitas. '
                    'Kamu tetap bisa berbagi post lain.',
              ),
            ),
          if (_error != null)
            _InfoCard(
              icon: Icons.cloud_off_rounded,
              title: 'Community belum terbuka',
              detail: _error!,
              action: TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('Coba lagi'),
              ),
            )
          else if (wall == null)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (wall.isEmpty)
            const _InfoCard(
              icon: Icons.forum_outlined,
              title: 'Belum ada post',
              detail: 'Jadilah yang pertama membagikan langkah kecil hari ini.',
            )
          else
            for (final post in wall)
              _PostCard(
                post: post,
                onReact: (reaction) => _act(
                  () => _store.react(
                    post.id,
                    post.myReaction == reaction ? null : reaction,
                  ),
                ),
                onReport: (reason) => _act(() async {
                  final sent = await _store.report(post.id, reason);
                  _say(
                    !sent
                        ? 'Post ini sudah kamu laporkan.'
                        : _store.shared
                        ? 'Terima kasih. Laporan dikirim ke moderator.'
                        : 'Laporan tersimpan di pratinjau perangkat ini.',
                  );
                }),
              ),
        ],
      ),
    );
  }
}

/// Stored reaction keys stay the same; they render as labelled icons.
const _reactionStyle = {
  '👏': (Icons.celebration_rounded, 'Keren'),
  '🌱': (Icons.eco_rounded, 'Tumbuh'),
  '✨': (Icons.auto_awesome_rounded, 'Semangat'),
};

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onReact,
    required this.onReport,
  });
  final CommunityPost post;
  final void Function(String reaction) onReact;
  final void Function(String reason) onReport;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GameCard(
        padding: const EdgeInsets.fromLTRB(16, 10, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 19,
                  backgroundColor: c.selected,
                  child: Text(
                    post.alias.isEmpty ? '?' : post.alias[0].toUpperCase(),
                    style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '@${post.alias}',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                if (post.sample) tag('contoh'),
                if (post.mine)
                  tag('post kamu')
                else
                  PopupMenuButton<String>(
                    tooltip: post.reported ? 'Sudah dilaporkan' : 'Laporkan post',
                    enabled: !post.reported,
                    icon: Icon(
                      post.reported
                          ? Icons.flag_rounded
                          : Icons.more_vert_rounded,
                      color: c.muted,
                    ),
                    onSelected: onReport,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'unsafe', child: Text('Tidak aman')),
                      PopupMenuItem(value: 'spam', child: Text('Spam')),
                    ],
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 10, 12),
              child: Text(
                post.body,
                style: const TextStyle(fontSize: 15.5, height: 1.5),
              ),
            ),
            Wrap(
              spacing: 6,
              runSpacing: 8,
              children: [
                for (final key in communityReactions)
                  _ReactionButton(
                    icon: _reactionStyle[key]!.$1,
                    label: _reactionStyle[key]!.$2,
                    count: post.reactions[key] ?? 0,
                    active: post.myReaction == key,
                    onTap: () => onReact(key),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: active,
      label: 'Reaksi $label, $count',
      excludeSemantics: true,
      child: Material(
        color: active ? c.xpSoft : c.card,
        shape: StadiumBorder(
          side: BorderSide(
            color: active ? c.xp : c.border,
            width: active ? 2 : 1.5,
          ),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: SizedBox(
              height: 44,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: active ? c.onXp : c.muted),
                  const SizedBox(width: 5),
                  Text(
                    count > 0 ? '$label · $count' : label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: active ? c.onXp : c.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.detail,
    this.action,
  });
  final IconData icon;
  final String title, detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => GameCard(
    padding: const EdgeInsets.all(20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: context.colors.accent, size: 30),
        const SizedBox(height: 14),
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          detail,
          style: TextStyle(color: context.colors.muted, height: 1.5),
        ),
        ?action,
      ],
    ),
  );
}

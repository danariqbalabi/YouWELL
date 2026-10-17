import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/theme/app_colors.dart';
import 'package:youwell/features/auth/presentation/account_scope.dart';
import 'package:youwell/features/community/data/community_photo.dart';
import 'package:youwell/features/community/data/local_community_store.dart';
import 'package:youwell/features/community/domain/community_store.dart';
import 'package:youwell/shared/widgets/game_widgets.dart';
import 'package:youwell/shared/widgets/ui_helpers.dart';

/// The signed-in account's server Community, or the on-device preview.
CommunityStore communityStoreOf(
  BuildContext context,
  WellnessController controller,
) =>
    AccountScope.maybeOf(context)?.community ?? LocalCommunityStore(controller);

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

  Future<void> _delete(CommunityPost post) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus post ini?'),
        content: const Text(
          'Post, fotonya, dan reaksinya dihapus untuk semua orang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    await _act(() async {
      await _store.deletePost(post.id);
      _say('Post dihapus.');
    });
  }

  Future<void> _compose() async {
    final controller = widget.controller;
    final sent = await showDialog<bool>(
      context: context,
      builder: (_) => _ComposeDialog(
        store: _store,
        suggestion: () =>
            'Hari ini aku menyelesaikan ${controller.completedCards.length} '
            'misi dan sekarang di Level ${controller.level}!',
      ),
    );
    if (sent != true || !mounted) return;
    _say('Post terkirim. Tampil setelah disetujui moderator.');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final posts = _posts;
    // Own posts waiting for review show on the wall, tagged, so they can
    // still be deleted.
    final wall = posts
        ?.where(
          (post) =>
              post.status == 'approved' ||
              (post.mine && post.status == 'pending'),
        )
        .toList();
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
                ? 'Yuk saling semangati!'
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
                onDelete: () => _delete(post),
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
  '✨': (Icons.auto_awesome_rounded, 'Semangat'),
  '🌱': (Icons.thumb_up_alt_rounded, 'Mantap'),
};

class _PostCard extends StatelessWidget {
  const _PostCard({
    required this.post,
    required this.onReact,
    required this.onReport,
    required this.onDelete,
  });
  final CommunityPost post;
  final void Function(String reaction) onReact;
  final void Function(String reason) onReport;
  final VoidCallback onDelete;

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
                if (post.mine) ...[
                  tag(
                    post.status == 'pending' ? 'menunggu review' : 'post kamu',
                  ),
                  IconButton(
                    tooltip: 'Hapus post',
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, color: c.muted),
                  ),
                ] else
                  PopupMenuButton<String>(
                    tooltip: post.reported
                        ? 'Sudah dilaporkan'
                        : 'Laporkan post',
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
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: PostPhoto(post: post),
            ),
            if (post.body.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 10, 12),
                child: Text(
                  post.body,
                  style: const TextStyle(fontSize: 15.5, height: 1.5),
                ),
              ),
            if (post.status == 'approved')
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
                      // Authors see the counts but cannot react to themselves.
                      onTap: post.mine ? null : () => onReact(key),
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
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: onTap != null,
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

/// New post: optional photo (re-encoded on the phone, so no location data)
/// and a caption that may be empty when a photo is attached.
class _ComposeDialog extends StatefulWidget {
  const _ComposeDialog({required this.store, required this.suggestion});
  final CommunityStore store;
  final String Function() suggestion;

  @override
  State<_ComposeDialog> createState() => _ComposeDialogState();
}

class _ComposeDialogState extends State<_ComposeDialog> {
  final _text = TextEditingController();
  Uint8List? _photo;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    setState(() => _error = null);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2000,
      );
      if (picked == null || !mounted) return;
      setState(() => _busy = true);
      final photo = await prepareCommunityPhoto(await picked.readAsBytes());
      if (mounted) setState(() => _photo = photo);
    } on FormatException {
      if (mounted) {
        setState(
          () => _error =
              'Foto terlalu besar meski sudah diperkecil. '
              'Coba foto lain.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _error =
              'Foto belum bisa dipakai di perangkat ini '
              '(${error.runtimeType}). Coba foto lain.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  bool get _ready {
    final length = _text.text.trim().length;
    return length <= maxCommunityPostLength && (_photo != null || length >= 3);
  }

  Future<void> _submit() async {
    if (!_ready) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.store.submit(_text.text, photo: _photo);
      if (mounted) Navigator.pop(context, true);
    } on CommunityException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final photo = _photo;
    return AlertDialog(
      title: const Text('Bagikan kemenangan kecil'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.store.supportsPhotos
                  ? 'Post dan foto dicek moderator sebelum tampil. '
                        'Hindari wajah orang lain atau info pribadi.'
                  : 'Post masuk ke antrean moderator sebelum tampil.',
              style: TextStyle(color: c.muted),
            ),
            const SizedBox(height: 12),
            if (photo != null) ...[
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: Image.memory(
                        photo,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        semanticLabel: 'Foto yang akan dibagikan',
                      ),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: IconButton.filledTonal(
                      tooltip: 'Hapus foto',
                      onPressed: _busy
                          ? null
                          : () => setState(() => _photo = null),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Wrap(
              spacing: 4,
              children: [
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () => setState(() => _text.text = widget.suggestion()),
                  icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                  label: const Text('Isi dengan progres hari ini'),
                ),
                if (widget.store.supportsPhotos && photo == null)
                  TextButton.icon(
                    onPressed: _busy ? null : _pickPhoto,
                    icon: const Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 18,
                    ),
                    label: const Text('Tambah foto'),
                  ),
              ],
            ),
            TextField(
              controller: _text,
              enabled: !_busy,
              maxLength: maxCommunityPostLength,
              maxLines: 4,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: photo == null
                    ? 'Hari ini aku berhasil…'
                    : 'Tulis keterangan (opsional)',
                errorText: _error,
                // Server reasons can be long; never cut them off.
                errorMaxLines: 5,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _busy || !_ready ? null : _submit,
          child: _busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Kirim untuk review'),
        ),
      ],
    );
  }
}

/// A post photo through its short-lived link; a broken link shows nothing.
class PostPhoto extends StatelessWidget {
  const PostPhoto({super.key, required this.post});
  final CommunityPost post;
  @override
  Widget build(BuildContext context) {
    final url = post.imageUrl;
    if (url == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 380),
          child: Image.network(
            url,
            width: double.infinity,
            fit: BoxFit.cover,
            semanticLabel: 'Foto dari @${post.alias}',
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const SizedBox(
                    height: 180,
                    child: Center(child: CircularProgressIndicator()),
                  ),
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }
}

import 'dart:typed_data';

/// Reaction keys stored on the server; the UI renders them as labelled icons.
/// Shown as Keren, Semangat, Mantap. The keys are fixed by the server's
/// check constraint, so 🌱 (formerly "Tumbuh") now reads "Mantap".
const communityReactions = ['👏', '✨', '🌱'];
const communityReportReasons = ['unsafe', 'spam'];
const maxCommunityPostLength = 280;

class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.alias,
    required this.body,
    required this.status,
    this.mine = false,
    this.sample = false,
    this.reactions = const {},
    this.myReaction,
    this.reported = false,
    this.moderationNote,
    this.imagePath,
    this.imageUrl,
    this.createdAt,
  });

  factory CommunityPost.fromJson(Map value) => CommunityPost(
    id: value['id'].toString(),
    alias: value['alias'].toString(),
    body: value['body'].toString(),
    status: value['status']?.toString() ?? 'pending',
    mine: value['mine'] == true,
    reactions: {
      for (final entry in ((value['reactions'] ?? const {}) as Map).entries)
        entry.key.toString(): (entry.value as num).toInt(),
    },
    myReaction: value['my_reaction']?.toString(),
    reported: value['reported'] == true,
    moderationNote: value['moderation_note']?.toString(),
    imagePath: value['image_path']?.toString(),
    createdAt: DateTime.tryParse(
      (value['created_at'] ?? value['time'] ?? '').toString(),
    ),
  );

  CommunityPost withImageUrl(String? url) => CommunityPost(
    id: id,
    alias: alias,
    body: body,
    status: status,
    mine: mine,
    sample: sample,
    reactions: reactions,
    myReaction: myReaction,
    reported: reported,
    moderationNote: moderationNote,
    imagePath: imagePath,
    imageUrl: url,
    createdAt: createdAt,
  );

  final String id, alias, body, status;
  final bool mine, sample, reported;

  /// Public totals per reaction, including the viewer's own.
  final Map<String, int> reactions;
  final String? myReaction, moderationNote;

  /// Storage path of the post's photo, and a short-lived link to show it.
  final String? imagePath, imageUrl;

  /// When the post was sent; the cursor for older published pages.
  final DateTime? createdAt;
}

class CommunityReport {
  const CommunityReport({
    required this.id,
    required this.reason,
    required this.post,
  });
  final String id, reason;
  final CommunityPost post;
}

class ModerationQueue {
  const ModerationQueue({
    required this.pending,
    required this.reports,
    this.published = const [],
  });
  final List<CommunityPost> pending;
  final List<CommunityReport> reports;

  /// Latest approved posts, newest first, so an admin can remove one that
  /// nobody reported.
  final List<CommunityPost> published;
}

/// A user-facing failure; [message] is safe to show as is.
class CommunityException implements Exception {
  const CommunityException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Community boundary. The server decides who may moderate; the moderation
/// calls fail for anyone who is not an allowlisted admin with MFA.
abstract interface class CommunityStore {
  /// Shared posts on other devices; false for the on-device preview.
  bool get shared;

  /// Photos need the server; the on-device preview has text only.
  bool get supportsPhotos;

  /// Approved posts plus the viewer's own posts, newest first.
  Future<List<CommunityPost>> feed();
  /// [photo] is PNG bytes from `prepareCommunityPhoto`.
  Future<void> submit(String text, {Uint8List? photo});

  /// [reaction] null removes the viewer's reaction.
  Future<void> react(String postId, String? reaction);

  /// False when the viewer already reported this post.
  Future<bool> report(String postId, String reason);

  Future<ModerationQueue> moderationQueue();
  Future<void> moderate(String postId, {required bool approve});
  Future<void> resolveReport(String reportId);

  /// Removes the viewer's own post, with its photo, reactions and reports.
  Future<void> deletePost(String postId);

  /// Admin only: removes any post, with its photo, reactions and reports.
  Future<void> adminDeletePost(String postId);

  /// Admin only: published posts, newest first, matching [query] on alias
  /// or text. Pass the last post's [CommunityPost.createdAt] as [before]
  /// for the next page.
  Future<List<CommunityPost>> publishedPosts({
    String query = '',
    DateTime? before,
    int limit = 30,
  });
}

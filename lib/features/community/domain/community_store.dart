/// Reaction keys stored on the server; the UI renders them as labelled icons.
const communityReactions = ['👏', '🌱', '✨'];
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
  );

  final String id, alias, body, status;
  final bool mine, sample, reported;

  /// Public totals per reaction, including the viewer's own.
  final Map<String, int> reactions;
  final String? myReaction, moderationNote;
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
  const ModerationQueue({required this.pending, required this.reports});
  final List<CommunityPost> pending;
  final List<CommunityReport> reports;
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

  /// Approved posts plus the viewer's own posts, newest first.
  Future<List<CommunityPost>> feed();
  Future<void> submit(String text);

  /// [reaction] null removes the viewer's reaction.
  Future<void> react(String postId, String? reaction);

  /// False when the viewer already reported this post.
  Future<bool> report(String postId, String reason);

  Future<ModerationQueue> moderationQueue();
  Future<void> moderate(String postId, {required bool approve});
  Future<void> resolveReport(String reportId);
}

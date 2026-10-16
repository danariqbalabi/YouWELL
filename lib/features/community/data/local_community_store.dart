import 'dart:typed_data';

import 'package:youwell/application/wellness_controller.dart';
import '../domain/community_store.dart';

/// On-device preview for builds without login (UI previews and tests).
/// Posts never leave this device; the UI says so.
class LocalCommunityStore implements CommunityStore {
  const LocalCommunityStore(this.controller);
  final WellnessController controller;

  @override
  bool get shared => false;

  @override
  bool get supportsPhotos => false;

  CommunityPost _post(Map<String, dynamic> row) {
    final id = row['id'].toString();
    final reaction = communityReactions
        .where((key) => controller.hasCommunityReaction(id, key))
        .firstOrNull;
    return CommunityPost(
      id: id,
      alias: row['alias'].toString(),
      body: row['text'].toString(),
      status: row['status']?.toString() ?? 'pending',
      sample: row['sample'] == true,
      mine:
          row['sample'] != true &&
          row['alias'] == controller.profile?['alias'],
      // Only this device's own reaction exists locally.
      reactions: {if (reaction != null) reaction: 1},
      myReaction: reaction,
      reported: controller.hasReportedCommunityPost(id),
      moderationNote: row['moderationNote']?.toString(),
    );
  }

  @override
  Future<List<CommunityPost>> feed() async => [
    for (final row in [...controller.communityPosts]..sort(
      (a, b) => b['time'].toString().compareTo(a['time'].toString()),
    ))
      if (row['status'] == 'approved' ||
          (row['sample'] != true &&
              row['alias'] == controller.profile?['alias']))
        _post(row),
  ];

  @override
  Future<void> submit(String text, {Uint8List? photo}) async {
    try {
      controller.submitCommunityPost(text);
    } on ArgumentError {
      throw const CommunityException(
        'Tulis 3–$maxCommunityPostLength karakter.',
      );
    }
  }

  @override
  Future<void> react(String postId, String? reaction) async =>
      controller.setCommunityReaction(postId, reaction);

  @override
  Future<bool> report(String postId, String reason) async =>
      controller.reportCommunityPost(postId, reason);

  @override
  Future<ModerationQueue> moderationQueue() async => ModerationQueue(
    pending: controller.moderationQueue.map(_post).toList(),
    reports: [
      for (final report in controller.communityReports)
        if (controller.communityPosts
                .where((post) => post['id'] == report['postId'])
                .firstOrNull
            case final post?)
          CommunityReport(
            id: report['id'].toString(),
            reason: report['reason'].toString(),
            post: _post(post),
          ),
    ],
  );

  @override
  Future<void> moderate(String postId, {required bool approve}) async =>
      controller.moderateCommunityPost(
        postId,
        approve ? 'approved' : 'rejected',
        note: approve ? '' : 'Tidak sesuai panduan komunitas.',
      );

  @override
  Future<void> resolveReport(String reportId) async =>
      controller.resolveCommunityReport(reportId);

  @override
  Future<void> deletePost(String postId) async =>
      controller.deleteCommunityPost(postId);
}

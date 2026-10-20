import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/features/community/data/local_community_store.dart';
import 'package:youwell/features/community/domain/community_store.dart';
import 'package:youwell/features/community/presentation/admin_moderation_page.dart';

import 'support/sim.dart';

/// Admins can remove any post, published ones included, after confirming.
void main() {
  test(
    'An admin deletes a published post; authors still only their own',
    () async {
      final sim = Sim();
      await sim.start();
      final store = LocalCommunityStore(sim.controller);
      await store.submit('Hari ini aku jalan sore.');
      final mine = (await store.feed()).firstWhere((post) => post.mine);
      await store.moderate(mine.id, approve: true);

      var queue = await store.moderationQueue();
      expect(queue.published.map((post) => post.id), [mine.id]);

      // Another account cannot use the author path on this post.
      await sim.controller.setup({
        ...sim.controller.profile!,
        'alias': 'other',
      });
      await store.deletePost(mine.id);
      expect((await store.moderationQueue()).published, hasLength(1));

      await store.adminDeletePost(mine.id);
      queue = await store.moderationQueue();
      expect(queue.published, isEmpty);
    },
  );

  testWidgets('Deleting asks first and can be cancelled', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sim = Sim();
    await sim.start();
    final store = LocalCommunityStore(sim.controller);
    await store.submit('Hari ini aku jalan sore.');
    await store.moderate(
      (await store.feed()).firstWhere((post) => post.mine).id,
      approve: true,
    );
    expect((await store.moderationQueue()).published, hasLength(1));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AdminModerationPage(controller: sim.controller)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah tayang'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hapus').first);
    await tester.pumpAndSettle();
    expect(find.text('Hapus post ini?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect((await store.moderationQueue()).published, hasLength(1));

    await tester.tap(find.text('Hapus').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect((await store.moderationQueue()).published, isEmpty);
    expect(find.text('Post dihapus.'), findsOneWidget);
  });

  testWidgets('A failed delete shows the error, not "Post dihapus."', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sim = Sim();
    await sim.start();
    final store = _FailingDelete(sim);
    await store.submit('Hari ini aku jalan sore.');
    await store.moderate(
      (await store.feed()).firstWhere((post) => post.mine).id,
      approve: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminModerationPage(controller: sim.controller, store: store),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sudah tayang'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hapus').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hapus'));
    await tester.pumpAndSettle();
    expect(find.text('Server sedang sibuk.'), findsOneWidget);
    expect(find.text('Post dihapus.'), findsNothing);
    expect((await store.moderationQueue()).published, hasLength(1));
  });

  test(
    'Published posts are searchable and paged beyond the first page',
    () async {
      final sim = Sim();
      await sim.start();
      final store = LocalCommunityStore(sim.controller);
      for (var i = 0; i < 5; i++) {
        sim.now = sim.now.add(const Duration(minutes: 1));
        await store.submit('Jalan pagi ke-$i');
        final post = (await store.feed()).firstWhere(
          (p) => p.mine && p.status == 'pending',
        );
        await store.moderate(post.id, approve: true);
      }
      final first = await store.publishedPosts(limit: 2);
      expect(first.map((p) => p.body), ['Jalan pagi ke-4', 'Jalan pagi ke-3']);
      final next = await store.publishedPosts(
        limit: 2,
        before: first.last.createdAt,
      );
      expect(next.map((p) => p.body), ['Jalan pagi ke-2', 'Jalan pagi ke-1']);
      expect(
        (await store.publishedPosts(query: 'KE-0')).single.body,
        'Jalan pagi ke-0',
      );
    },
  );
}

class _FailingDelete extends LocalCommunityStore {
  _FailingDelete(Sim sim) : super(sim.controller);
  @override
  Future<void> adminDeletePost(String postId) async =>
      throw const CommunityException('Server sedang sibuk.');
}

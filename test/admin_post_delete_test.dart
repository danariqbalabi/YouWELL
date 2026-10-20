import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/features/community/data/local_community_store.dart';
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
    expect(find.text('Sudah tayang'), findsOneWidget);

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
}

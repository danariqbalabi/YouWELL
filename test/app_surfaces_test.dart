import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/app/youwell_app.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_mode.dart';

void main() {
  test(
    'Build targets distinguish native, phone web, desktop preview and admin',
    () {
      expect(resolveAppSurface(isWeb: false), AppSurface.mobile);
      expect(resolveAppSurface(isWeb: true), AppSurface.admin);
      expect(resolveAppSurface(isWeb: true, phoneWeb: true), AppSurface.mobile);
      expect(
        resolveAppSurface(isWeb: true, preview: true),
        AppSurface.mobilePreview,
      );
      expect(
        () => resolveAppSurface(isWeb: true, phoneWeb: true, preview: true),
        throwsArgumentError,
      );
    },
  );

  test('Admin and preview storage cannot open the participant snapshot', () {
    final keys = AppSurface.values
        .map((s) => storageKeyForSurface('youwell.local.v3', s))
        .toSet();
    expect(keys, hasLength(3));
    expect(
      storageKeyForSurface('youwell.local.v3', AppSurface.mobile),
      'youwell.local.v3',
    );
  });

  for (final size in [const Size(393, 852), const Size(1280, 900)]) {
    testWidgets('Admin opens moderation without onboarding at $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = WellnessController();
      await tester.pumpWidget(
        YouWellApp(controller: controller, surface: AppSurface.admin),
      );
      await tester.pumpAndSettle();
      expect(find.text('Moderasi komunitas'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(controller.profile, isNull);
      expect(find.text('Focus Station'), findsNothing);

      await tester.tap(find.text('Tambah contoh post'));
      await tester.pumpAndSettle();
      expect(controller.moderationQueue, hasLength(1));
      expect(find.text('Contoh lokal'), findsOneWidget);
      await tester.ensureVisible(find.text('Setujui'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();
      expect(controller.moderationQueue, isEmpty);
      expect(
        controller.communityPosts
            .where((p) => p['alias'] == 'contohpeserta')
            .single['status'],
        'approved',
      );

      await tester.ensureVisible(find.text('Tambah contoh post'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tambah contoh post'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tolak'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tolak'));
      await tester.pumpAndSettle();
      expect(controller.moderationQueue, isEmpty);
      expect(
        controller.communityPosts.where((p) => p['status'] == 'rejected'),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets('Phone builds cannot open admin by navigating to /admin', (
    tester,
  ) async {
    final controller = WellnessController();
    await tester.pumpWidget(
      YouWellApp(controller: controller, surface: AppSurface.mobile),
    );
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Scaffold).first);
    Navigator.of(context).pushNamed('/admin');
    await tester.pumpAndSettle();
    expect(find.text('Moderasi tersedia melalui web admin.'), findsOneWidget);
    expect(find.text('Moderasi komunitas'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  test(
    'Storage failure notifies the UI and clears after a successful retry',
    () async {
      var fail = true, notifications = 0;
      final controller = WellnessController(
        persist: (_) async {
          if (fail) throw StateError('storage unavailable');
        },
      )..addListener(() => notifications++);
      await controller.setThemePreference('dark');
      expect(controller.storageError, isNotNull);
      expect(notifications, 2);
      fail = false;
      await controller.setThemePreference('light');
      expect(controller.storageError, isNull);
      expect(notifications, 4);
      controller.dispose();
    },
  );

  test(
    'Pending storage failure never notifies a disposed controller',
    () async {
      final pending = Completer<void>();
      final controller = WellnessController(persist: (_) => pending.future);
      final saving = controller.setThemePreference('dark');
      await Future<void>.delayed(Duration.zero);
      controller.dispose();
      pending.completeError(StateError('storage unavailable'));
      await saving;
    },
  );
}

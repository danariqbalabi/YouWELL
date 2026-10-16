import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/core/theme/app_theme.dart';
import 'package:youwell/features/activity/presentation/workout_page.dart';
import 'package:youwell/features/community/presentation/community_page.dart';

import 'support/sim.dart';

void main() {
  testWidgets('Community preview sends a post for review and reacts', (
    tester,
  ) async {
    final sim = Sim();
    await sim.start();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.mobileLight,
        home: Scaffold(body: CommunityPage(controller: sim.controller)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Pratinjau di perangkat ini'), findsOneWidget);

    await tester.tap(find.text('Bagikan progres'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Jalan sore 10 menit.');
    await tester.pump();
    await tester.tap(find.text('Kirim untuk review'));
    await tester.pumpAndSettle();
    expect(find.text('menunggu review'), findsOneWidget);
    expect(sim.controller.moderationQueue, hasLength(1));

    await tester.tap(find.text('Keren').first);
    await tester.pumpAndSettle();
    expect(find.text('Keren · 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('A closed walk is restored and leaving asks first', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sim = Sim(timed: true);
    await sim.start();
    sim.controller.saveWorkoutDraft({
      'kind': 'walk',
      'day': sim.controller.today,
      'bankedSeconds': 300,
      'since': null,
      'heartbeat': DateTime.now().toIso8601String(),
      'meters': 0,
    });
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        theme: AppTheme.mobileLight,
        home: const Scaffold(body: Text('Aktivitas')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => WorkoutPage(controller: sim.controller),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('Lanjutkan'), findsOneWidget);

    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Simpan sesi ini?'), findsOneWidget);
    await tester.tap(find.text('Lanjutkan sesi'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutPage), findsOneWidget);

    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buang'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutPage), findsNothing);
    expect(sim.controller.workoutDraft, isNull);
    expect(sim.controller.workoutSessions, isEmpty);
  });
}

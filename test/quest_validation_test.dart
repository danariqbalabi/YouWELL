import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/reduction/presentation/habit_swap_panel.dart';

final _now = DateTime(2026, 10, 12, 9);

JsonMap _quest(String catalogId, {String? activityKind, int minutes = 10}) => {
  'id': 'q-$catalogId',
  'catalogId': catalogId,
  'title': catalogId,
  'category': 'Body',
  'difficulty': 1,
  'durationMinutes': minutes,
  'xp': 20,
  'status': 'committed',
  'done': false,
  'activityKind': ?activityKind,
};

WellnessController _controller(List<JsonMap> quests) {
  final state = createEmptyWellnessState()
    ..['reductionSettings'] = {'product': 'cigarette'}
    ..['profile'] = {
      'alias': 'preview',
      'path': 'reduction',
      'pace': 1,
      'companion': 'plant',
      'started': dayKey(_now),
    }
    ..['days'] = {
      dayKey(_now): {
        'quests': quests,
        'water': 0,
        'cardDraw': {'committedCardId': 'card'},
      },
    };
  return WellnessController(saved: jsonEncode(state), clock: () => _now);
}

String? _status(WellnessController controller, String catalogId) => controller
    .quests
    .firstWhere((task) => task['catalogId'] == catalogId)['status']
    ?.toString();

void main() {
  test(
    'An open legacy timer becomes a Habit Swap with its ID and XP intact',
    () {
      final controller = _controller([_quest('delay', activityKind: 'delay')]);
      expect(controller.quests.single['activityKind'], 'habit_swap');
      expect(controller.quests.single['id'], 'q-delay');
      expect(controller.quests.single['xp'], 20);
      expect(_status(controller, 'delay'), 'committed');
      controller.recordHabitSwap(
        eventId: 'moment-${controller.habitSwaps.length}',
        product: 'cigarette',
        trigger: 'after_meal',
        activity: 'walk',
        outcome: 'used',
      );
      expect(_status(controller, 'delay'), 'completed');
      expect(controller.habitDelays, isEmpty);
      expect(controller.habitSwapsToday, 1);
    },
  );

  test('Logging a Habit Swap ticks the Habit Swap quest', () {
    final controller = _controller([
      _quest('habit-swap', activityKind: 'habit_swap'),
    ]);
    controller.recordHabitSwap(
      eventId: 'moment-${controller.habitSwaps.length}',
      product: 'cigarette',
      trigger: 'after_meal',
      activity: 'water',
      outcome: 'used',
    );
    expect(controller.habitSwapsToday, 1);
    expect(_status(controller, 'habit-swap'), 'completed');
  });

  test('Walks complete on target, stay partial below it', () {
    final controller = _controller([_quest('walk', activityKind: 'walk')]);
    final short = controller.recordWorkout(
      kind: 'walk',
      seconds: 6 * 60,
      meters: 500,
    );
    expect(short.partial, ['walk']);
    expect(controller.quests.single['partial'], .6);
    expect(_status(controller, 'walk'), 'committed');

    final full = controller.recordWorkout(
      kind: 'walk',
      seconds: 10 * 60,
      meters: 800,
    );
    expect(full.completed, ['walk']);
    expect(_status(controller, 'walk'), 'completed');
  });

  test('Sessions faster than 20 km/h never complete a quest', () {
    final controller = _controller([_quest('walk', activityKind: 'walk')]);
    final result = controller.recordWorkout(
      kind: 'walk',
      seconds: 10 * 60,
      meters: 5000,
    );
    expect(result.tooFast, isTrue);
    expect(_status(controller, 'walk'), 'committed');
    expect(controller.workoutSessions.single.keys, isNot(contains('route')));
  });

  test('One reaction per post and one report per post', () {
    final controller = _controller([]);
    controller.reactToCommunityPost('seed-water', '👏');
    controller.reactToCommunityPost('seed-water', '🌱');
    expect(controller.hasCommunityReaction('seed-water', '👏'), isFalse);
    expect(controller.hasCommunityReaction('seed-water', '🌱'), isTrue);
    controller.reactToCommunityPost('seed-water', '🌱');
    expect(controller.hasCommunityReaction('seed-water', '🌱'), isFalse);

    expect(controller.reportCommunityPost('seed-water', 'spam'), isTrue);
    expect(controller.reportCommunityPost('seed-water', 'spam'), isFalse);
    expect(controller.communityReports, hasLength(1));
  });

  testWidgets(
    'Habit Swap can be recorded without starting or waiting for a timer',
    (tester) async {
      final controller = _controller([_quest('delay', activityKind: 'delay')]);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: HabitSwapPanel(controller: controller)),
        ),
      );
      expect(find.text('Mulai'), findsNothing);
      expect(find.byIcon(Icons.timer_outlined), findsNothing);
      await tester.tap(find.text('Setelah makan'));
      await tester.scrollUntilVisible(
        find.text('Jalan santai sebentar'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(HabitSwapPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Jalan santai sebentar'));
      await tester.scrollUntilVisible(
        find.text('Sudah mencoba, tetap merokok'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(HabitSwapPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sudah mencoba, tetap merokok'));
      await tester.scrollUntilVisible(
        find.text('Simpan catatan momen'),
        150,
        scrollable: find
            .descendant(
              of: find.byType(HabitSwapPanel),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan catatan momen'));
      await tester.pump();

      expect(
        find.text(
          'Catatan tersimpan. Terima kasih sudah mencatat dengan jujur.',
        ),
        findsOneWidget,
      );
      expect(controller.habitDelays, isEmpty);
      expect(controller.habitSwapsToday, 1);
      expect(_status(controller, 'delay'), 'completed');
    },
  );
}

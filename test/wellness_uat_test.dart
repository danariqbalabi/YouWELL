import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/app/youwell_app.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/config/app_mode.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';
import 'package:youwell/features/home/domain/wellness_uat_program.dart';
import 'package:youwell/features/home/presentation/daily_card_draw_dialog.dart';
import 'support/sim.dart';

void main() {
  test('Day 28 includes its full calendar day; day 29 is the recap', () {
    final last = WellnessUatProgram(
      started: '2026-10-24',
      now: DateTime(2026, 11, 20, 23, 59),
    );
    expect(last.dayNumber, 28);
    expect(last.week, 4);
    expect(last.complete, isFalse);
    expect(
      WellnessUatProgram(
        started: '2026-10-24',
        now: DateTime(2026, 11, 21),
      ).complete,
      isTrue,
    );
  });

  test(
    'A legacy profile without a start date receives one persistent UAT anchor',
    () async {
      var date = DateTime(2026, 10, 24);
      final old = {
        'version': 3,
        'profile': {
          'alias': 'legacy',
          'path': 'wellness',
          'pace': 1,
          'companion': 'plant',
        },
      };
      final controller = WellnessController(
        saved: jsonEncode(old),
        clock: () => date,
      );
      expect(controller.profile!['started'], '2026-10-24');
      controller.prepareToday();
      final saved = controller.export();
      date = date.add(const Duration(days: 28));
      final reopened = WellnessController(saved: saved, clock: () => date);
      expect(reopened.wellnessProgramComplete, isTrue);
      expect(reopened.profile!['started'], '2026-10-24');
    },
  );

  test(
    'Daily shuffle varies sizes while preserving a repeatable fair deck',
    () {
      const generator = DailyCardGenerator();
      final patterns = <String>{};
      for (var day = 0; day < 365; day++) {
        final date = DateTime(
          2026,
          1,
          1,
        ).add(Duration(days: day)).toIso8601String().substring(0, 10);
        List<Map<String, dynamic>> cards() => generator.cardPacks(
          today: date,
          steps: {},
          pace: 1,
          lowImpact: false,
          reduction: false,
          wellnessUat: true,
          recentAttempts: {'Body': 4, 'Food': 4, 'Lifestyle': 4},
        );
        final first = cards();
        expect(jsonEncode(first), jsonEncode(cards()));
        patterns.add(first.map((c) => c['size']).join(','));
        expect(first.map((c) => c['size']).toList()..sort(), [3, 3, 4, 4, 5]);
        expect(
          first
              .where((c) => (c['categories'] as List).contains('Energy'))
              .length,
          greaterThanOrEqualTo(4),
        );
        for (final category in ['Body', 'Food', 'Lifestyle', 'Energy']) {
          expect(
            first
                .where((c) => (c['categories'] as List).contains(category))
                .length,
            greaterThanOrEqualTo(3),
          );
        }
      }
      expect(patterns.length, greaterThan(10));
    },
  );

  for (final timed in [false, true]) {
    for (final pace in [1, 2, 3]) {
      test(
        '28-day ${timed ? 'timer' : 'GPS'} journey at tempo $pace stays within small-habit limits',
        () async {
          final sim = Sim(timed: timed);
          sim.controller.enableMobileRewards();
          await sim.start(pace: pace);
          expect(
            sim.controller.ladderSteps.values.every((step) => step == pace),
            isTrue,
          );
          final accepted = <String, DateTime>{};
          for (var day = 0; day < 28; day++) {
            expect(sim.controller.wellnessProgram!.dayNumber, day + 1);
            for (final category in sim.controller.ladderOffers.toList()) {
              if (accepted[category] != null) {
                expect(
                  sim.now.difference(accepted[category]!).inDays,
                  greaterThanOrEqualTo(7),
                );
              }
              sim.controller.acceptLadderStep(category);
              accepted[category] = sim.now;
            }
            for (final card in sim.cards) {
              for (final task in sim.tasksOf(card)) {
                expect(task['activityKind'], isNot('run'));
                if (task['ladder'] != null) {
                  expect(
                    task['step'] as int,
                    lessThanOrEqualTo(
                      WellnessUatProgram.stepLimits[task['ladder']]!,
                    ),
                  );
                } else {
                  expect(task['durationMinutes'] as int, lessThanOrEqualTo(5));
                }
                expect(
                  task['catalogId'],
                  isNot('sunlight'),
                  reason: 'No morning sunlight quest at 20.00',
                );
              }
            }
            sim.takeCard();
            for (final task in sim.controller.coreQuests) {
              sim.finish(task);
            }
            sim.nextDay();
          }
          expect(sim.controller.wellnessProgramComplete, isTrue);
          expect(sim.controller.needsDailyCardDraw, isFalse);
          expect(sim.controller.days, hasLength(28));
          expect(sim.controller.ladderOffers, isEmpty);
          expect(sim.controller.chooseRecommendedDailyCard(), isFalse);
          expect(sim.controller.commitDailyCardPack(), isFalse);
          expect(sim.controller.drawBonusCard(), isFalse);
          final xp = sim.controller.xp;
          final count = sim.controller.workoutSessions.length;
          sim.controller.recordWorkout(kind: 'walk', seconds: 600, meters: 800);
          sim.controller.recordMeal(photoCaptured: true);
          sim.controller.addWater();
          sim.nextDay();
          expect(sim.controller.xp, xp);
          expect(sim.controller.workoutSessions, hasLength(count));
          expect(sim.controller.days, hasLength(28));
          expect(
            [
              for (var week = 1; week <= 4; week++)
                sim.controller.researchSummary(week).questDayCount,
            ],
            [7, 7, 7, 7],
          );
        },
      );
    }
  }

  test(
    'Four small successes a week are enough; no need for seven perfect days',
    () async {
      final sim = Sim();
      sim.controller.enableMobileRewards();
      await sim.start(pace: 1);
      for (var day = 0; day < 28; day++) {
        for (final category in sim.controller.ladderOffers.toList()) {
          sim.controller.acceptLadderStep(category);
        }
        if ({0, 2, 4, 6}.contains(day % 7)) {
          sim.takeCard(category: 'Body');
          sim.finish(
            sim.controller.coreQuests.firstWhere((q) => q['ladder'] == 'Body'),
          );
        }
        sim.nextDay();
      }
      expect(sim.controller.ladderSteps['Body'], 4);
      expect(
        [
          for (var week = 1; week <= 4; week++)
            sim.controller.researchSummary(week).questDayCount,
        ],
        [4, 4, 4, 4],
      );
      expect(sim.controller.wellnessProgramComplete, isTrue);
    },
  );

  testWidgets(
    'An open draw crosses the program boundary without an empty-deck crash',
    (tester) async {
      final sim = Sim();
      await sim.start(pace: 1);
      sim.now = DateTime(2026, 11, 20, 23, 59);
      sim.controller.prepareToday();
      sim.controller.setReduceMotion(true);
      await tester.pumpWidget(
        MaterialApp(
          home: DailyCardDrawDialog(
            controller: sim.controller,
            mobileExperience: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      sim.now = DateTime(2026, 11, 21);
      sim.controller.prepareToday();
      await tester.pumpAndSettle();
      expect(find.text('Perjalanan 28 hari selesai'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('Late acceptance starts a new seven-day evidence period', () async {
    final sim = Sim();
    await sim.start(pace: 1);
    sim.runWeek((_) => true);
    for (var day = 0; day < 6; day++) {
      sim.doLadder();
      sim.nextDay();
    }
    sim.controller.acceptLadderStep('Body');
    expect(
      sim.controller.capacity['Body']!['reviewedOn'],
      sim.controller.today,
    );
    sim.doLadder();
    sim.nextDay();
    expect(sim.controller.ladderOffers, isNot(contains('Body')));
    for (var day = 0; day < 6; day++) {
      sim.doLadder();
      sim.nextDay();
    }
    expect(sim.controller.capacity['Body']!['offerStep'], 3);
  });

  test(
    'Relaxed practice balances recommendations without qualifying for a step up',
    () async {
      final sim = Sim();
      await sim.start(pace: 3);
      sim.controller.setDailyPace('relaxed');
      final first = sim.cards.firstWhere(
        (card) => !sim.categoriesOf(card).contains('Body'),
      );
      sim.controller.selectDailyCard(first['id']);
      sim.controller.commitDailyCardPack();
      for (final task in sim.controller.coreQuests) {
        sim.finish(task);
      }
      sim.nextDay();
      sim.controller.setDailyPace('relaxed');
      expect(
        sim.categoriesOf(sim.controller.recommendedDailyCard!),
        contains('Body'),
      );
      for (var day = 1; day < 7; day++) {
        sim.controller.setDailyPace('relaxed');
        sim.controller.chooseRecommendedDailyCard();
        sim.controller.commitDailyCardPack();
        for (final task in sim.controller.coreQuests) {
          sim.finish(task);
        }
        sim.nextDay();
      }
      expect(
        sim.controller.ladderSteps.values.every((step) => step == 3),
        isTrue,
      );
      expect(sim.controller.ladderOffers, isEmpty);
    },
  );

  test(
    'A quest completed before acceptance is not evidence for the new step',
    () async {
      final sim = Sim();
      await sim.start(pace: 1);
      sim.runWeek((_) => true);
      sim.doLadder(); // Today's committed step-1 card cannot change.
      sim.controller.acceptLadderStep('Body');
      sim.nextDay();
      for (var day = 1; day <= 6; day++) {
        if (day <= 2) {
          sim.doLadder();
        } else {
          final card = sim.cards.firstWhere(
            (c) => !sim.categoriesOf(c).contains('Body'),
          );
          sim.controller.selectDailyCard(card['id']);
          sim.controller.commitDailyCardPack();
          for (final task in sim.controller.coreQuests) {
            sim.finish(task);
          }
        }
        sim.nextDay();
      }
      expect(sim.controller.ladderSteps['Body'], 2);
      expect(sim.controller.ladderOffers, isNot(contains('Body')));
      expect(
        sim.controller.capacity['Body']!['reason'],
        contains('minimal 3 kali'),
      );
    },
  );

  for (final timed in [false, true]) {
    test(
      'Prelogged water, photo and ${timed ? 'timer' : 'GPS'} count once at commit',
      () async {
        final sim = Sim(timed: timed);
        sim.controller.enableMobileRewards();
        await sim.start(pace: 1);
        for (var glass = 0; glass < 4; glass++) {
          sim.controller.addWater();
        }
        sim.controller.recordMeal(photoCaptured: true);
        sim.controller.recordWorkout(
          kind: 'walk',
          seconds: timed ? 300 : 360,
          meters: timed ? 0 : 500,
        );
        final card = sim.cards.firstWhere(
          (c) => sim.categoriesOf(c).toSet().containsAll([
            'Body',
            'Food',
            'Lifestyle',
          ]),
        );
        sim.controller.selectDailyCard(card['id']);
        expect(sim.controller.commitDailyCardPack(), isTrue);
        for (final task in sim.controller.coreQuests.where(
          (q) => q['ladder'] != null,
        )) {
          expect(task['status'], 'completed');
          expect(sim.controller.completeCard(task['id']), isFalse);
        }
        for (final task in sim.controller.coreQuests.where(
          (q) => q['ladder'] == null,
        )) {
          sim.finish(task);
        }
        expect(sim.controller.mobileBonusXpToday, 20);
        final xp = sim.controller.xp;
        expect(sim.controller.commitDailyCardPack(), isFalse);
        expect(sim.controller.xp, xp);
        final restored = WellnessController(
          saved: sim.controller.export(),
          clock: () => sim.now,
          timedWorkouts: timed,
        );
        restored.enableMobileRewards();
        restored.prepareToday();
        expect(restored.xp, xp);
        expect(restored.mobileBonusXpToday, 20);
      },
    );
  }

  test(
    'Partial evidence is credited, notes and invalid GPS cannot finish quests',
    () async {
      final sim = Sim();
      await sim.start(pace: 1);
      sim.controller.addWater();
      sim.controller.recordMeal(note: 'Catatan makan tanpa foto');
      sim.controller.recordWorkout(kind: 'walk', seconds: 10, meters: 1000);
      final card = sim.cards.firstWhere(
        (c) => sim.categoriesOf(c).toSet().containsAll([
          'Body',
          'Food',
          'Lifestyle',
        ]),
      );
      sim.controller.selectDailyCard(card['id']);
      sim.controller.commitDailyCardPack();
      final water = sim.controller.coreQuests.firstWhere(
        (q) => q['ladder'] == 'Lifestyle',
      );
      expect(water['partial'], .25);
      expect(
        sim.controller.coreQuests
            .where((q) => q['ladder'] != null)
            .every((q) => q['status'] != 'completed'),
        isTrue,
      );
      for (var glass = 0; glass < 3; glass++) {
        sim.controller.addWater();
      }
      expect(
        sim.controller.coreQuests.firstWhere(
          (q) => q['ladder'] == 'Lifestyle',
        )['status'],
        'completed',
      );
    },
  );

  test(
    'A selected expired meal is refreshed and needs confirmation again',
    () async {
      final sim = Sim();
      sim.now = DateTime(2026, 10, 24, 8);
      await sim.start(pace: 1);
      final card = sim.cards.firstWhere(
        (c) => sim.categoriesOf(c).contains('Food'),
      );
      sim.controller.selectDailyCard(card['id']);
      sim.now = DateTime(2026, 10, 24, 13);
      expect(sim.controller.commitDailyCardPack(), isFalse);
      final refreshed = sim.controller.selectedDailyCard!;
      expect(refreshed['id'], card['id']);
      expect(refreshed['categories'], card['categories']);
      expect(refreshed['size'], card['size']);
      expect(
        sim
            .tasksOf(refreshed)
            .firstWhere((q) => q['ladder'] == 'Food')['photoWindows'],
        isNull,
      );
      expect(sim.controller.commitDailyCardPack(), isTrue);
    },
  );

  test(
    'A new reveal gets an achievable meal; committed cards stay unchanged',
    () async {
      final sim = Sim();
      sim.now = DateTime(2026, 10, 24, 8);
      await sim.start(pace: 1);
      sim.now = DateTime(2026, 10, 24, 13);
      sim.takeCard(category: 'Food');
      expect(
        sim.controller.coreQuests.firstWhere(
          (q) => q['ladder'] == 'Food',
        )['photoWindows'],
        isNull,
      );

      final early = Sim();
      early.now = DateTime(2026, 10, 24, 8);
      await early.start(pace: 1);
      early.takeCard(category: 'Food');
      final original = jsonEncode(early.controller.quests);
      early.now = DateTime(2026, 10, 24, 13);
      early.controller.prepareToday();
      expect(jsonEncode(early.controller.quests), original);
    },
  );

  test(
    'Seven relaxed days keep capacity and XP; absences do not restart the program',
    () async {
      final sim = Sim();
      await sim.start(pace: 3);
      for (var day = 0; day < 7; day++) {
        sim.controller.setDailyPace('relaxed');
        sim.doLadder();
        sim.nextDay();
      }
      expect(sim.controller.ladderSteps['Body'], 3);
      expect(sim.controller.ladderOffers, isEmpty);
      final xp = sim.controller.xp;
      sim.now = sim.now.add(const Duration(days: 6));
      sim.controller.prepareToday();
      expect(sim.controller.wellnessProgram!.dayNumber, 14);
      expect(sim.controller.ladderSteps['Body'], 2);
      expect(sim.controller.xp, xp);
    },
  );

  test(
    'Reduction now shares the 28-day boundary and gentle UAT limits',
    () async {
      final sim = Sim();
      await sim.start(path: 'reduction', pace: 3);
      expect(sim.controller.wellnessProgram, isNull);
      expect(sim.controller.ladderMaximum('Body'), 4);
      expect(
        sim.cards.every((c) => sim.categoriesOf(c).contains('Reduction')),
        isTrue,
      );
      expect(sim.controller.uatProgram, isNotNull);
      sim.now = sim.now.add(const Duration(days: 28));
      sim.controller.prepareToday();
      expect(sim.controller.needsDailyCardDraw, isFalse);
      expect(sim.controller.uatProgramComplete, isTrue);
      expect(
        sim.cards.every((c) => sim.categoriesOf(c).contains('Reduction')),
        isTrue,
      );
    },
  );

  testWidgets('Recommended card can be opened before a blind draw', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final sim = Sim();
    await sim.start(pace: 1);
    sim.controller.setReduceMotion(true);
    final recommended = sim.controller.recommendedDailyCard!['id'];
    await tester.pumpWidget(
      MaterialApp(
        home: DailyCardDrawDialog(
          controller: sim.controller,
          mobileExperience: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buka rekomendasi · 3 misi'));
    await tester.pumpAndSettle();
    expect(sim.controller.selectedDailyCardId, recommended);
    expect(find.text('Cocok buatmu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'After day 28 the app shows a recap and no new activity actions',
    (tester) async {
      tester.view.physicalSize = const Size(393, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final sim = Sim();
      await sim.start(pace: 1);
      sim.now = sim.now.add(const Duration(days: 28));
      sim.controller.prepareToday();
      sim.controller.setReduceMotion(true);
      await tester.pumpWidget(
        YouWellApp(controller: sim.controller, surface: AppSurface.mobile),
      );
      await tester.pumpAndSettle();
      expect(find.text('Perjalanan 28 hari selesai'), findsOneWidget);
      expect(find.byType(DailyCardDrawDialog), findsNothing);
      await tester.tap(find.byType(NavigationDestination).at(1));
      await tester.pumpAndSettle();
      expect(find.text('Riwayat aktivitas'), findsOneWidget);
      expect(find.text('Jalan atau lari'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

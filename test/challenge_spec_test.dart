// Acceptance cases from docs/CHALLENGE_SPEC.md §12.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/features/progress/domain/level_curve.dart';

import 'support/sim.dart';

/// A controller with one committed card holding exactly [quests].
WellnessController withQuests(List<JsonMap> quests, DateTime Function() at) {
  final day = dayKey(at());
  final state = createEmptyWellnessState()
    ..['profile'] = {
      'alias': 'preview',
      'path': 'wellness',
      'pace': 2,
      'companion': 'plant',
      'started': day,
    }
    ..['days'] = {
      day: {
        'quests': quests,
        'water': 0,
        'cardDraw': {'committedCardId': 'card'},
      },
    };
  return WellnessController(saved: jsonEncode(state), clock: at);
}

JsonMap quest(String id, {Map<String, dynamic> extra = const {}}) => {
  'id': id,
  'catalogId': id,
  'title': id,
  'category': 'Body',
  'xp': 20,
  'durationMinutes': 10,
  'status': 'committed',
  ...extra,
};

void main() {
  group('Cards (§4)', () {
    test('Five cards with 3, 3, 4, 4, 5 missions', () async {
      final sim = Sim();
      await sim.start();
      final sizes = sim.cards.map((card) => sim.tasksOf(card).length).toList()
        ..sort();
      expect(sizes, [3, 3, 4, 4, 5]);
    });

    test('Each card: 3 ladder quests from 3 different categories', () async {
      final sim = Sim();
      await sim.start();
      for (final card in sim.cards) {
        final ladder = sim
            .tasksOf(card)
            .where((task) => task['ladder'] != null)
            .map((task) => task['ladder'])
            .toList();
        expect(ladder, hasLength(3));
        expect(ladder.toSet(), hasLength(3));
        expect(ladder.toSet(), sim.categoriesOf(card).toSet());
      }
    });

    test(
      'Healthy-living path: every category is on at least 3 cards',
      () async {
        final sim = Sim();
        await sim.start();
        for (final category in healthyCategories) {
          expect(
            sim.cards.where(
              (card) => sim.categoriesOf(card).contains(category),
            ),
            hasLength(greaterThanOrEqualTo(3)),
            reason: category,
          );
        }
      },
    );

    test(
      'Smoking/vaping path: one Habit Swap on every card, plus 2 others',
      () async {
        final sim = Sim();
        await sim.start(path: 'reduction');
        for (final card in sim.cards) {
          final categories = sim.categoriesOf(card);
          expect(categories.first, 'Reduction');
          expect(categories, hasLength(3));
          final tasks = sim.tasksOf(card);
          expect(
            tasks.where((task) => task['activityKind'] == 'habit_swap'),
            hasLength(1),
          );
          expect(
            tasks.where((task) => task['activityKind'] == 'delay'),
            isEmpty,
          );
        }
      },
    );

    test('Least-practised category appears on most cards', () async {
      final sim = Sim();
      await sim.start();
      // Three days of Body, Food and Lifestyle; Istirahat is never taken.
      for (var day = 0; day < 3; day++) {
        final card = sim.cards.firstWhere(
          (card) => !sim.categoriesOf(card).contains('Energy'),
        );
        sim.controller.selectDailyCard(card['id']);
        sim.controller.commitDailyCardPack();
        sim.nextDay();
      }
      expect(
        sim.cards.where((card) => sim.categoriesOf(card).contains('Energy')),
        hasLength(greaterThanOrEqualTo(4)),
      );
    });

    for (final (pace, size) in [(1, 3), (2, 4), (3, 5)]) {
      test('Tempo $pace recommends a $size-mission card', () async {
        final sim = Sim();
        await sim.start(pace: pace);
        final recommended = sim.cards.where(
          (card) => card['recommended'] == true,
        );
        expect(recommended, hasLength(1));
        expect(sim.tasksOf(recommended.single), hasLength(size));
      });
    }

    test('Relaxed day: 3-mission cards, one step lower, practice', () async {
      final sim = Sim();
      await sim.start(pace: 3);
      expect(sim.controller.setDailyPace('relaxed'), isTrue);
      for (final card in sim.cards) {
        final tasks = sim.tasksOf(card);
        expect(tasks, hasLength(3));
        expect(tasks.every((task) => task['step'] == 2), isTrue);
        expect(tasks.every((task) => task['practiceOnly'] == true), isTrue);
      }
    });

    test('No double reward: no water extra next to Hidrasi, no meal '
        'extra next to Makan', () async {
      final sim = Sim();
      await sim.start(pace: 3);
      for (var day = 0; day < 10; day++) {
        for (final card in sim.cards) {
          final categories = sim.categoriesOf(card);
          final extras = sim
              .tasksOf(card)
              .where((task) => task['ladder'] == null);
          if (categories.contains('Lifestyle')) {
            expect(extras.where((t) => t['activityKind'] == 'water'), isEmpty);
          }
          if (categories.contains('Food')) {
            expect(
              extras.where(
                (t) => {'meal-snap', 'fruit-veg'}.contains(t['catalogId']),
              ),
              isEmpty,
            );
          }
        }
        sim.now = sim.now.add(const Duration(days: 1));
        sim.controller.prepareToday();
      }
    });
  });

  group('Ladder review (§8)', () {
    test('Category done 2 times in the week → hold, needs 3', () async {
      final sim = Sim();
      await sim.start();
      // Days 2 and 5: never 5 quiet days in a row, so this is not a rest.
      sim.runWeek((day) => day == 1 || day == 4);
      final body = sim.controller.capacity['Body']!;
      expect(body['change'], 'hold');
      expect(body['offerStep'], isNull);
      expect(body['reason'], contains('minimal 3 kali'));
    });

    test('Category done 3 times, all finished → step up offered', () async {
      final sim = Sim();
      await sim.start();
      sim.runWeek((day) => day < 3);
      expect(sim.controller.ladderOffers, contains('Body'));
      expect(sim.controller.capacity['Body']!['offerStep'], 3);
    });

    test('Low-impact stops at step 4, never offered a run step', () async {
      final sim = Sim();
      await sim.start(pace: 3, lowImpact: true);
      for (var week = 0; week < 3; week++) {
        sim.runWeek((_) => true);
        for (final category in sim.controller.ladderOffers) {
          sim.controller.acceptLadderStep(category);
        }
      }
      expect(sim.controller.ladderSteps['Body'], lowImpactBodyMax);
      expect(sim.controller.ladderOffers, isNot(contains('Body')));
    });
  });

  group('Gerak: GPS distance (§5.1, §7)', () {
    final at = DateTime(2026, 10, 24, 17);
    JsonMap walk() => quest(
      'walk',
      extra: {'activityKind': 'walk', 'targetMeters': 800, 'ladder': 'Body'},
    );

    test('Time alone never finishes a distance walk', () {
      final controller = withQuests([walk()], () => at);
      controller.recordWorkout(kind: 'walk', seconds: 3600, meters: 0);
      expect(controller.quests.single['status'], 'committed');
    });

    test('Half the distance is partial, the full distance completes', () {
      final controller = withQuests([walk()], () => at);
      controller.recordWorkout(kind: 'walk', seconds: 300, meters: 400);
      expect(controller.quests.single['partial'], .5);
      controller.recordWorkout(kind: 'walk', seconds: 300, meters: 400);
      expect(controller.quests.single['status'], 'completed');
    });

    test('Faster than 20 km/h does not count', () {
      final controller = withQuests([walk()], () => at);
      final result = controller.recordWorkout(
        kind: 'walk',
        seconds: 60,
        meters: 800,
      );
      expect(result.tooFast, isTrue);
      expect(controller.quests.single['status'], 'committed');
    });

    test('Every walk/run rung has a distance target', () {
      expect(
        ladders['Body']!.every((rung) => rung.targetMeters != null),
        isTrue,
      );
    });
  });

  group('Makan: camera photos (§5.4, §7)', () {
    JsonMap breakfast() => quest(
      'breakfast',
      extra: {
        'category': 'Food',
        'ladder': 'Food',
        'activityKind': 'meal_snap',
        'photoCount': 1,
        'photoWindows': [
          [4, 10],
        ],
      },
    );

    test('Breakfast photo before 10.00 completes the quest', () {
      final controller = withQuests([
        breakfast(),
      ], () => DateTime(2026, 10, 24, 8, 30));
      controller.recordMeal(photoPath: '/tmp/a.jpg');
      expect(controller.quests.single['status'], 'completed');
    });

    test('A photo at 11.00 does not count as breakfast', () {
      final controller = withQuests([
        breakfast(),
      ], () => DateTime(2026, 10, 24, 11));
      controller.recordMeal(photoPath: '/tmp/a.jpg');
      expect(controller.quests.single['status'], 'committed');
    });

    test('Ephemeral web photo counts without storing a photo path', () {
      final controller = withQuests([
        breakfast(),
      ], () => DateTime(2026, 10, 24, 8, 30));
      controller.recordMeal(photoCaptured: true);

      expect(controller.quests.single['status'], 'completed');
      expect(controller.mealCheckIns.single['photoCaptured'], isTrue);
      expect(controller.mealCheckIns.single, isNot(contains('photoPath')));
    });

    test('Two-photo quest: 1 of 2 is partial', () {
      final controller = withQuests([
        quest(
          'two',
          extra: {
            'category': 'Food',
            'ladder': 'Food',
            'activityKind': 'meal_snap',
            'photoCount': 2,
          },
        ),
      ], () => DateTime(2026, 10, 24, 12));
      controller.recordMeal(photoPath: '/tmp/a.jpg');
      expect(controller.quests.single['partial'], .5);
      controller.recordMeal(photoPath: '/tmp/b.jpg');
      expect(controller.quests.single['status'], 'completed');
    });

    test('A note without a photo never finishes a meal quest', () {
      final controller = withQuests([
        breakfast(),
      ], () => DateTime(2026, 10, 24, 8));
      controller.recordMeal(note: 'Nasi dan sayur');
      expect(controller.quests.single['status'], 'committed');
    });

    test('Breakfast window passed when cards are made → anytime quest', () {
      final cards = const DailyCardGenerator().cardPacks(
        today: '2026-10-24',
        steps: const {'Food': 1, 'Body': 1, 'Lifestyle': 1, 'Energy': 1},
        pace: 1,
        lowImpact: false,
        reduction: false,
        hour: 13,
      );
      final food = cards
          .expand((card) => card['tasks'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((task) => task['ladder'] == 'Food');
      expect(food['title'], 'Tambah 1 porsi buah atau sayur');
      expect(food['photoWindows'], isNull);
      expect(food['step'], 1);
    });

    test('Camera denied → Makan ladder quest is checked off instead', () {
      final controller = withQuests([
        breakfast(),
      ], () => DateTime(2026, 10, 24, 8));
      controller.markCameraUnavailable();
      final task = controller.quests.single;
      expect(task['activityKind'], isNull);
      expect(task['ladder'], 'Food');
      expect(controller.completeCard(task['id']), isTrue);
    });
  });

  group('Istirahat: about last night (§5.2a)', () {
    test('Screen-off quest is about last night and can be done at 08.00', () {
      expect(
        ladders['Energy']!.every((rung) => rung.title.startsWith('Semalam:')),
        isTrue,
      );
      final controller = withQuests([
        quest(
          'energy',
          extra: {'catalogId': 'ladder-energy', 'ladder': 'Energy'},
        ),
      ], () => DateTime(2026, 10, 24, 8));
      expect(controller.completeCard('energy'), isTrue);
    });
  });

  group('Kartu Bonus (§6)', () {
    test('Only after the card is done, once a day, light quests', () async {
      final sim = Sim();
      await sim.start(pace: 1);
      sim.takeCard();
      expect(sim.controller.canDrawBonusCard, isFalse);
      for (final task in sim.controller.coreQuests) {
        sim.finish(task);
      }
      expect(sim.controller.coreComplete, isTrue);
      expect(sim.controller.drawBonusCard(), isTrue);
      final bonus = sim.controller.bonusQuests;
      expect(bonus, hasLength(3));
      expect(bonus.every((task) => task['xp'] == bonusQuestXp), isTrue);
      expect(bonus.every((task) => task['ladder'] == null), isTrue);
      expect(bonus.every((task) => task['strenuous'] != true), isTrue);
      if (sim.controller.coreQuests.any((task) => task['ladder'] == 'Food')) {
        expect(
          bonus.where(
            (task) => {'meal-snap', 'fruit-veg'}.contains(task['catalogId']),
          ),
          isEmpty,
        );
      }
      expect(sim.controller.canDrawBonusCard, isFalse);
      expect(sim.controller.drawBonusCard(), isFalse);
    });

    test(
      'Bonus quests stay out of quests_done and the full-day count',
      () async {
        final sim = Sim();
        await sim.start(pace: 1);
        sim.takeCard();
        for (final task in sim.controller.coreQuests) {
          sim.finish(task);
        }
        final core = sim.controller.coreQuests.length;
        sim.controller.drawBonusCard();
        final first = sim.controller.bonusQuests.first;
        sim.controller.completeCard(first['id']);
        expect(sim.controller.researchSummary(1).questsDone, core);
        expect(sim.controller.completedDays, contains(sim.controller.today));
      },
    );
  });

  group('XP & level (§9)', () {
    test('Curve: 100, 150, 200 … XP per level', () {
      expect(
        [for (var l = 1; l <= 6; l++) xpForLevel(l)],
        [0, 100, 250, 450, 700, 1000],
      );
      expect(levelForXp(2199), 8);
      expect(levelForXp(2200), 9);
    });

    test('Old user with 715 XP keeps showing level 8', () {
      final state = createEmptyWellnessState()
        ..['profile'] = {
          'alias': 'lama',
          'path': 'wellness',
          'pace': 2,
          'companion': 'plant',
          'started': '2026-10-01',
        }
        ..['days'] = {
          '2026-10-01': {
            'quests': [
              {'id': 'old', 'xp': 715, 'status': 'completed'},
            ],
          },
        };
      final controller = WellnessController(
        saved: jsonEncode(state),
        clock: () => DateTime(2026, 10, 7, 9),
      );
      expect(controller.xp, 715);
      expect(controller.level, 8);
      expect(controller.xpToNextLevel, xpForLevel(9) - 715);
    });

    test('Everything done daily reaches the last stage by week 4', () {
      // Slowest case: 3-mission card, never stepping up (80 XP a day).
      expect(companionStage(levelForXp(80 * 28)), 5);
      expect(companionStage(levelForXp(80 * 21)), lessThan(5));
    });
  });

  group('Research summary (§10)', () {
    test(
      'Relaxed-day quests count in quests_done, not in the ladder',
      () async {
        final sim = Sim();
        await sim.start(pace: 2);
        for (var day = 0; day < 7; day++) {
          expect(sim.controller.setDailyPace('relaxed'), isTrue);
          sim.doLadder();
          sim.nextDay();
        }
        expect(sim.controller.researchSummary(1).questsDone, 21);
        expect(sim.controller.ladderSteps['Body'], 2);
        expect(sim.controller.capacity['Body']!['change'], 'hold');
      },
    );

    test('Ladder columns per category, Makan included', () async {
      final sim = Sim();
      await sim.start(pace: 2);
      sim.doLadder();
      final summary = sim.controller.researchSummary(1).toJson();
      expect(summary.keys, [
        'week',
        'opened_days',
        'active_days',
        'active',
        'quests_done',
        'ladder_gerak',
        'ladder_istirahat',
        'ladder_tidur',
        'ladder_hidrasi',
        'ladder_makan',
        'ladder_jeda',
        'delay_craving_count',
        'delay_craving_completed',
        'habit_swap_count',
      ]);
      expect(summary['ladder_makan'], 2);
      expect(summary['ladder_jeda'], isNull);
    });

    test(
      'Weekly logs count Habit Swap; retired timer counters stay zero for new use',
      () async {
        final sim = Sim();
        await sim.start(path: 'reduction');
        // Opened on 3 days of week 1; nothing done on the third.
        sim.doLadder(category: 'Reduction');
        sim.nextDay();
        sim.controller.recordHabitSwap(
          eventId: 'moment-${sim.controller.habitSwaps.length}',
          product: 'cigarette',
          trigger: 'after_meal',
          activity: 'contact',
          outcome: 'used',
        );
        sim.nextDay();
        final week1 = sim.controller.researchSummary(1).toJson();
        expect(week1['opened_days'], 3);
        expect(week1['active'], isTrue);
        expect(week1['delay_craving_count'], 0);
        expect(week1['delay_craving_completed'], 0);
        expect(week1['habit_swap_count'], 2);

        final week2 = sim.controller.researchSummary(2).toJson();
        expect(week2['opened_days'], 0);
        expect(week2['active'], isFalse);
      },
    );

    test('Age 18–22 on the vape path gets quit framing', () async {
      final young = Sim();
      await young.start(path: 'reduction', pace: 1, ageGroup: '18-22');
      expect(young.controller.reductionLabel, 'Berhenti rokok / vape');
      final adult = Sim();
      await adult.start(path: 'reduction', pace: 1, ageGroup: '22plus');
      expect(adult.controller.reductionLabel, 'Kurangi rokok / vape');
    });
  });
}

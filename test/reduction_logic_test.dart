import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';

import 'support/sim.dart';

Future<Sim> reductionSim([String product = 'cigarette']) async {
  final sim = Sim();
  await sim.start(path: 'reduction', pace: 1);
  sim.controller.setNicotineProduct(product);
  sim.controller.enableMobileRewards();
  return sim;
}

bool logMoment(
  WellnessController c, {
  String? id,
  String product = 'cigarette',
  String outcome = 'used',
  String activity = 'walk',
  String? trigger,
}) => c.recordHabitSwap(
  eventId: id ?? 'event-${c.habitSwaps.length}',
  product: product,
  trigger: trigger ?? (product == 'vape' ? 'screen' : 'after_meal'),
  activity: activity,
  outcome: outcome,
);

void main() {
  test(
    'An occasional user can maintain an integer target without being forced to zero',
    () async {
      final sim = await reductionSim();
      final c = sim.controller;
      for (var day = 0; day < 7; day++) {
        if (day < 4) {
          c.saveNicotineDay(
            day: c.today,
            product: 'cigarette',
            cigarettes: day == 0 ? 0 : 1,
          );
        }
        sim.nextDay();
      }
      expect(c.consumptionWeek(1).meanFor('cigarette'), .75);
      expect(c.setReductionTarget('cigarette', 1), isTrue);
      expect(c.setReductionTarget('cigarette', 2), isFalse);
      expect(c.xp, 0);
    },
  );
  test(
    'Switching to wellness preserves a committed Habit Swap without enabling the nicotine diary',
    () async {
      final sim = await reductionSim();
      final c = sim.controller;
      sim.takeCard();
      final plan = c.quests;
      c.switchPath(false);
      expect(c.quests, plan);
      expect(logMoment(c), isTrue);
      expect(
        c.completedCards.where((task) => task['activityKind'] == 'habit_swap'),
        hasLength(1),
      );
      expect(
        c.saveNicotineDay(day: c.today, product: 'cigarette', cigarettes: 1),
        isFalse,
      );
      expect(logMoment(c), isFalse);
    },
  );
  test(
    'Honest attempts get the daily XP once; not-tried and daily totals do not',
    () async {
      final sim = await reductionSim();
      final c = sim.controller;
      sim.takeCard();
      final swap = c.coreQuests.singleWhere(
        (task) => task['activityKind'] == 'habit_swap',
      );
      expect(logMoment(c, outcome: 'not_tried'), isTrue);
      expect(c.completedCards, isEmpty);
      expect(c.xp, 0);
      expect(c.habitSwaps.single['activity'], isNull);
      expect(
        c.saveNicotineDay(day: c.today, product: 'cigarette', cigarettes: 0),
        isTrue,
      );
      expect(c.xp, 0);
      expect(logMoment(c, outcome: 'used', id: 'one'), isTrue);
      expect(c.xp, swap['xp']);
      expect(c.completedCards, hasLength(1));
      expect(logMoment(c, outcome: 'skipped', id: 'two'), isTrue);
      expect(logMoment(c, outcome: 'skipped', id: 'two'), isFalse);
      expect(c.xp, swap['xp']);
      expect(c.habitSwaps, hasLength(3));
      expect(c.swapAttemptsToday, hasLength(2));
      expect(c.researchSummary(1).habitSwapCount, 2);
    },
  );

  test(
    'Product, trigger and outcome are validated; there is no ten-minute lock',
    () async {
      final sim = await reductionSim('both');
      final c = sim.controller;
      expect(logMoment(c, id: 'same-second-1'), isTrue);
      expect(logMoment(c, id: 'same-second-2', product: 'vape'), isTrue);
      expect(logMoment(c, outcome: 'made_up'), isFalse);
      expect(logMoment(c, activity: 'made_up'), isFalse);
      expect(logMoment(c, product: 'vape', trigger: 'made_up'), isFalse);
      expect(logMoment(c, product: 'both'), isFalse);
      c.setNicotineProduct('vape');
      expect(logMoment(c, product: 'cigarette'), isFalse);
      expect(c.habitSwaps, hasLength(2));
    },
  );

  test(
    'A moment logged before choosing a card counts once on commitment and reload',
    () async {
      final sim = await reductionSim();
      final c = sim.controller;
      logMoment(c, outcome: 'used');
      expect(c.xp, 0);
      sim.takeCard();
      expect(c.completedCards, hasLength(1));
      final xp = c.xp;
      final reloaded = WellnessController(
        saved: c.export(),
        clock: () => sim.now,
      );
      reloaded.enableMobileRewards();
      reloaded.prepareToday();
      expect(reloaded.xp, xp);
      expect(reloaded.habitSwaps, hasLength(1));
      sim.nextDay();
      sim.takeCard();
      expect(
        c.completedCards,
        isEmpty,
        reason: 'Yesterday is not evidence for today.',
      );
    },
  );

  test(
    'Legacy moments with unknown outcomes do not become skipped moments or new quest evidence',
    () async {
      final sim = await reductionSim();
      final state = jsonDecode(sim.controller.export()) as Map<String, dynamic>;
      state['habitSwaps'] = [
        {'day': sim.controller.today, 'swap': 'Jalan sebentar'},
      ];
      final c = WellnessController(
        saved: jsonEncode(state),
        clock: () => sim.now,
      );
      c.enableMobileRewards();
      c.selectDailyCard(c.dailyDrawCards.first['id']);
      c.commitDailyCardPack();
      expect(c.swapAttemptsToday, isEmpty);
      expect(c.completedCards, isEmpty);
      expect(c.habitSwaps.single['outcome'], isNull);
    },
  );

  test(
    'Confirmed zeroes, missing days, corrections, future dates and invalid dates stay distinct',
    () async {
      final sim = await reductionSim('both');
      final c = sim.controller;
      expect(
        c.saveNicotineDay(day: c.today, product: 'both', cigarettes: 10),
        isFalse,
      );
      expect(
        c.saveNicotineDay(
          day: c.today,
          product: 'both',
          cigarettes: 10,
          vapeSessions: 2,
        ),
        isTrue,
      );
      expect(
        c.saveNicotineDay(
          day: c.today,
          product: 'both',
          cigarettes: 8,
          vapeSessions: 0,
        ),
        isTrue,
      );
      expect(c.nicotineDays, hasLength(1));
      expect(c.consumptionWeek(1).meanFor('cigarette'), 8);
      expect(c.consumptionWeek(1).meanFor('vape'), 0);
      expect(c.consumptionWeek(1).daysFor('vape'), 1);
      sim.nextDay();
      expect(c.nicotineDay(c.today), isNull);
      expect(c.consumptionWeek(1).meanFor('cigarette'), 8);
      expect(
        c.saveNicotineDay(day: c.today, product: 'vape', vapeSessions: -1),
        isFalse,
      );
      expect(
        c.saveNicotineDay(day: c.today, product: 'vape', vapeSessions: 501),
        isFalse,
      );
      expect(
        c.saveNicotineDay(day: '2026-02-30', product: 'vape', vapeSessions: 1),
        isFalse,
      );
      expect(
        c.saveNicotineDay(day: '2026-10-26', product: 'vape', vapeSessions: 1),
        isFalse,
      );
      expect(c.xp, 0);
    },
  );

  test(
    'Weekly comparisons need four confirmed days per product in both weeks',
    () async {
      final sim = await reductionSim('both');
      final c = sim.controller;
      for (var day = 0; day < 7; day++) {
        if (day < 4) {
          c.saveNicotineDay(day: c.today, product: 'cigarette', cigarettes: 12);
        }
        sim.nextDay();
      }
      expect(c.setReductionTarget('cigarette', 11), isTrue);
      expect(
        c.setReductionTarget('vape', 1),
        isFalse,
        reason: 'Cigarette logs do not imply vape zeroes.',
      );
      for (var day = 0; day < 3; day++) {
        c.saveNicotineDay(day: c.today, product: 'cigarette', cigarettes: 9);
        sim.nextDay();
      }
      expect(
        c.consumptionWeek(2).changeFrom(c.consumptionWeek(1), 'cigarette'),
        isNull,
      );
      c.saveNicotineDay(day: c.today, product: 'cigarette', cigarettes: 9);
      expect(
        c.consumptionWeek(2).changeFrom(c.consumptionWeek(1), 'cigarette'),
        -25,
      );
      expect(c.targetFor(2, 'cigarette')!['limit'], 11);
      expect(c.setReductionTarget('cigarette', 13), isFalse);
      expect(
        c.setReductionTarget('cigarette', 12),
        isTrue,
        reason: 'Maintaining is allowed.',
      );
      expect(c.setReductionTarget('cigarette', null), isTrue);
      expect(c.targetFor(2, 'cigarette'), isNull);
    },
  );

  test(
    'Zero baseline never produces division by zero or a claimed percentage reduction',
    () async {
      final sim = await reductionSim('vape');
      final c = sim.controller;
      for (var i = 0; i < 11; i++) {
        c.saveNicotineDay(day: c.today, product: 'vape', vapeSessions: 0);
        sim.nextDay();
      }
      expect(
        c.consumptionWeek(2).changeFrom(c.consumptionWeek(1), 'vape'),
        isNull,
      );
      expect(c.setReductionTarget('vape', 0), isTrue);
    },
  );

  test(
    'Movement suggestions adapt to low-impact, product and the matched trigger',
    () {
      expect(
        suggestedSwaps(
          lowImpact: false,
          product: 'cigarette',
          trigger: 'after_meal',
          history: [],
        ).first,
        'walk',
      );
      expect(
        suggestedSwaps(
          lowImpact: true,
          product: 'vape',
          trigger: 'screen',
          history: [],
        ).first,
        'seated',
      );
      final reports = [
        for (var i = 0; i < 2; i++)
          {
            'product': 'vape',
            'trigger': 'screen',
            'activity': 'contact',
            'outcome': 'skipped',
          },
      ];
      expect(
        suggestedSwaps(
          lowImpact: false,
          product: 'vape',
          trigger: 'screen',
          history: reports,
        ).first,
        'contact',
      );
      expect(
        suggestedSwaps(
          lowImpact: false,
          product: 'cigarette',
          trigger: 'after_meal',
          history: reports,
        ).first,
        'walk',
      );
      expect(
        suggestedSwaps(
          lowImpact: false,
          product: 'vape',
          trigger: 'boredom',
          history: reports,
        ).first,
        'walk',
      );
      // One skip among two reports is not yet a pattern.
      expect(
        suggestedSwaps(
          lowImpact: false,
          product: 'vape',
          trigger: 'screen',
          history: [
            {...reports.first, 'outcome': 'used'},
            reports.last,
          ],
        ).first,
        'walk',
      );
    },
  );

  for (final product in ['cigarette', 'vape', 'both']) {
    test(
      'Complete 28-day $product journey keeps units separate; day 29 stays open',
      () async {
        final sim = await reductionSim(product);
        final c = sim.controller;
        for (var day = 0; day < 28; day++) {
          expect(c.uatProgram!.dayNumber, day + 1);
          for (final kind in productsFor(product)) {
            logMoment(
              c,
              product: kind,
              outcome: day.isEven ? 'used' : 'skipped',
            );
          }
          sim.takeCard();
          expect(
            c.completedCards.where(
              (task) => task['activityKind'] == 'habit_swap',
            ),
            hasLength(1),
          );
          expect(
            c.coreQuests.where((task) => task['activityKind'] == 'run'),
            isEmpty,
          );
          c.saveNicotineDay(
            day: c.today,
            product: product,
            cigarettes: day < 7 ? 12 : 10,
            vapeSessions: day < 7 ? 8 : 7,
          );
          if (day == 7) {
            for (final kind in productsFor(product)) {
              expect(
                c.setReductionTarget(kind, kind == 'cigarette' ? 11 : 7),
                isTrue,
              );
            }
          }
          sim.nextDay();
        }
        expect(c.studyPeriodComplete, isTrue);
        expect(
          c.days.keys.where((day) => day.compareTo('2026-11-21') < 0),
          hasLength(28),
        );
        expect(c.nicotineDays, hasLength(28));
        expect(c.habitSwaps, hasLength(28 * productsFor(product).length));
        // Day 29: the app keeps working (decision 20 Oct 2026)...
        expect(c.needsDailyCardDraw, isTrue);
        final week4 = jsonEncode(c.researchSummary(4).toJson());
        expect(logMoment(c, product: productsFor(product).first), isTrue);
        expect(
          c.saveNicotineDay(
            day: c.today,
            product: product,
            cigarettes: 1,
            vapeSessions: 1,
          ),
          isTrue,
        );
        // ...while research data still stops at day 28.
        expect(jsonEncode(c.researchSummary(4).toJson()), week4);
        expect(
          c.saveNicotineDay(
            day: '2026-10-24',
            product: product,
            cigarettes: 11,
            vapeSessions: 6,
          ),
          isTrue,
        );
        for (final kind in productsFor(product)) {
          expect(c.consumptionWeek(4).daysFor(kind), 7);
          expect(
            c.consumptionWeek(4).changeFrom(c.consumptionWeek(1), kind),
            isNegative,
          );
        }
        final research = jsonEncode([
          for (var week = 1; week <= 4; week++) c.researchSummary(week).toJson(),
        ]);
        expect(research, isNot(contains('nicotineDays')));
        expect(research, isNot(contains('after_meal')));
        expect(research, isNot(contains('cigarette')));
        expect(
          WellnessController(
            saved: c.export(),
            clock: () => sim.now,
          ).nicotineDays,
          c.nicotineDays,
        );
      },
    );
  }
}

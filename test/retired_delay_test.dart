import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';

import 'support/sim.dart';

void main() {
  test(
    'A revealed legacy card remains usable after removing the delay ladder',
    () async {
      final sim = Sim();
      await sim.start(path: 'reduction', pace: 3);
      sim.controller.selectDailyCard(sim.cards.first['id']);
      final state = jsonDecode(sim.controller.export()) as Map<String, dynamic>;
      final selectedId = sim.controller.selectedDailyCardId;
      state['capacity']['Reduction'] = {
        'step': 6,
        'offerStep': 7,
        'reviewedOn': sim.controller.today,
      };
      for (final card in state['days'][sim.controller.today]['cardPacks']) {
        final task = (card['tasks'] as List).firstWhere(
          (task) => task['ladder'] == 'Reduction',
        );
        task
          ..remove('activityKind')
          ..['step'] = 6
          ..['title'] = 'Tunda yang pertama hari ini 1 jam'
          ..['durationMinutes'] = 60;
      }
      final restored = WellnessController(
        saved: jsonEncode(state),
        clock: () => sim.now,
      );
      expect(restored.selectedDailyCardId, selectedId);
      expect(restored.ladderSteps['Reduction'], 1);
      expect(restored.ladderOffers, isNot(contains('Reduction')));
      expect(
        restored.dailyDrawCards.map((card) => card['id']),
        sim.cards.map((card) => card['id']),
      );
      expect(restored.commitDailyCardPack(), isTrue);
      final swap = restored.quests.singleWhere(
        (task) => task['ladder'] == 'Reduction',
      );
      expect(swap['activityKind'], 'habit_swap');
      expect(swap['step'], 1);
      expect(swap['title'], 'Coba satu aktivitas pengganti');
      expect(
        restored.recordHabitSwap(
          eventId: 'restored-moment',
          product: 'cigarette',
          trigger: 'after_meal',
          activity: 'walk',
          outcome: 'used',
        ),
        isTrue,
      );
      expect(
        restored.quests.singleWhere(
          (task) => task['id'] == swap['id'],
        )['status'],
        'completed',
      );
      expect(restored.habitDelays, isEmpty);
    },
  );

  test(
    'Completed quests, XP and archived research counts survive retirement',
    () {
      final now = DateTime(2026, 10, 25, 12);
      JsonMap oldQuest(String id) => {
        'id': id,
        'title': 'Delay Craving 5 menit',
        'category': 'Reduction',
        'ladder': 'Reduction',
        'step': 2,
        'activityKind': 'delay',
        'delayMinutes': 5,
        'xp': 25,
        'status': 'completed',
        'done': true,
      };
      final state = createEmptyWellnessState()
        ..['profile'] = {
          'alias': 'preview',
          'path': 'reduction',
          'pace': 1,
          'started': '2026-10-24',
        }
        ..['days'] = {
          '2026-10-24': {
            'quests': [oldQuest('yesterday')],
          },
          '2026-10-25': {
            'quests': [oldQuest('today')],
          },
        }
        ..['habitDelays'] = [
          {'day': '2026-10-24', 'minutes': 5, 'completed': true},
        ]
        ..['achievements'] = {'delay-30': '2026-10-24'};
      final controller = WellnessController(
        saved: jsonEncode(state),
        clock: () => now,
      );
      controller.enableMobileRewards();
      expect(controller.xp, 50);
      expect(controller.quests.single, oldQuest('today'));
      expect(controller.researchSummary(1).delayCravingCount, 1);
      expect(controller.researchSummary(1).delayCravingCompleted, 1);
      expect(
        achievementNames.keys.where((key) => key.contains('delay')),
        isEmpty,
      );
      expect(controller.achievements['delay-30'], '2026-10-24');
      controller.recordHabitSwap(
        eventId: 'moment-${controller.habitSwaps.length}',
        product: 'cigarette',
        trigger: 'after_meal',
        activity: 'contact',
        outcome: 'used',
      );
      final reloaded = WellnessController(
        saved: controller.export(),
        clock: () => now,
      );
      expect(reloaded.xp, 50);
      expect(reloaded.habitDelays, controller.habitDelays);
      expect(reloaded.researchSummary(1).habitSwapCount, 1);
    },
  );

  for (final pace in [1, 2, 3]) {
    test(
      'Seven days at tempo $pace never offer waiting or a harder Habit Swap',
      () async {
        final sim = Sim();
        await sim.start(path: 'reduction', pace: pace);
        for (var day = 0; day < 7; day++) {
          for (final card in sim.cards) {
            final swaps = sim
                .tasksOf(card)
                .where((task) => task['activityKind'] == 'habit_swap');
            expect(swaps, hasLength(1));
            expect(swaps.single['step'], 1);
            expect(
              sim
                  .tasksOf(card)
                  .where((task) => task['activityKind'] == 'delay'),
              isEmpty,
            );
          }
          sim.doLadder(category: 'Reduction');
          for (final task in sim.controller.coreQuests.where(
            (task) => task['status'] != 'completed',
          )) {
            sim.finish(task);
          }
          expect(sim.controller.drawBonusCard(), isTrue);
          expect(
            sim.controller.bonusQuests.where(
              (task) => task['activityKind'] == 'habit_swap',
            ),
            isEmpty,
          );
          sim.nextDay();
        }
        expect(sim.controller.ladderSteps['Reduction'], 1);
        expect(sim.controller.ladderOffers, isNot(contains('Reduction')));
        expect(sim.controller.habitSwaps, hasLength(7));
        expect(sim.controller.habitDelays, isEmpty);
      },
    );
  }
}

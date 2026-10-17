import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';

import 'support/sim.dart';

/// Hydration has one target: the Hidrasi ladder step, never a fixed 2.000 ml.
void main() {
  test('Without a Hidrasi quest, the target is the current step', () async {
    final sim = Sim();
    await sim.start();
    final step = sim.controller.ladderSteps['Lifestyle']!;
    expect(sim.controller.waterTarget, waterRung(step).waterMl);
    expect(sim.controller.waterTop, ladders['Lifestyle']!.last.waterMl);
    expect(sim.controller.profile!.containsKey('waterGoal'), isFalse);
  });

  test('The ring target equals the Hidrasi quest on today\'s card', () async {
    final sim = Sim();
    await sim.start();
    sim.takeCard(category: 'Lifestyle');
    final quest = sim.controller.coreQuests.firstWhere(
      (task) => task['ladder'] == 'Lifestyle',
    );
    expect(sim.controller.waterTarget, quest['waterMl']);
    sim.finish(quest);
    expect(sim.controller.water, greaterThanOrEqualTo(quest['waterMl']));
    expect(sim.controller.water, lessThan(2000));
  });

  test('Seven days at the step target earn the hydration badge', () async {
    final sim = Sim();
    await sim.start();
    sim.controller.enableMobileRewards();
    for (var day = 0; day < 7; day++) {
      if (day > 0) sim.nextDay();
      while (sim.controller.water < sim.controller.waterTarget) {
        sim.controller.addWater();
      }
      expect(sim.controller.water, lessThan(2000));
    }
    expect(sim.controller.achievements.containsKey('hydration-7'), isTrue);
  });
}

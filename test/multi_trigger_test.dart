import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import 'support/sim.dart';

/// A moment can have several triggers, like its several tried activities.
void main() {
  Future<WellnessController> reduction() async {
    final sim = Sim();
    await sim.start(path: 'reduction', pace: 1);
    sim.controller.setNicotineProduct('cigarette');
    return sim.controller;
  }

  test('Several triggers are saved; the first stays readable', () async {
    final c = await reduction();
    expect(
      c.recordHabitSwap(
        eventId: 'm1',
        product: 'cigarette',
        triggers: ['after_meal', 'coffee'],
        activities: ['walk'],
        outcome: 'skipped',
      ),
      isTrue,
    );
    final row = c.habitSwaps.single;
    expect(row['trigger'], 'after_meal');
    expect(row['triggers'], ['after_meal', 'coffee']);
    expect(momentTriggers(row), ['after_meal', 'coffee']);
    expect(triggerText(row), contains(', '));
    expect(momentTriggers({'trigger': 'stress'}), ['stress']);
  });

  test('No trigger or an unknown one is refused', () async {
    final c = await reduction();
    bool log(List<String> triggers) => c.recordHabitSwap(
      eventId: 'm-${triggers.join()}',
      product: 'cigarette',
      triggers: triggers,
      activities: ['walk'],
      outcome: 'used',
    );
    expect(log([]), isFalse);
    expect(log(['after_meal', 'made_up']), isFalse);
  });

  test('A plan keeps several triggers', () async {
    final c = await reduction();
    expect(c.setSwapPlan('cigarette', ['stress', 'social'], 'walk'), isTrue);
    expect(triggerText(c.swapPlan('cigarette')!), isNotNull);
    expect(momentTriggers(c.swapPlan('cigarette')!), ['stress', 'social']);
  });

  test('Suggestions match a moment sharing any picked trigger', () {
    final history = [
      for (var i = 0; i < 2; i++)
        {
          'product': 'cigarette',
          'trigger': 'coffee',
          'triggers': ['coffee', 'stress'],
          'activity': 'water',
          'outcome': 'skipped',
        },
    ];
    final order = suggestedSwaps(
      lowImpact: false,
      product: 'cigarette',
      triggers: ['stress'],
      history: history,
    );
    expect(order.first, 'water');
  });

  test('Triggers never leave the device', () async {
    final c = await reduction();
    c.recordHabitSwap(
      eventId: 'm1',
      product: 'cigarette',
      triggers: ['after_meal', 'coffee'],
      activities: ['walk'],
      outcome: 'used',
    );
    final cloud = CloudProgress.project(c.export());
    for (final row in cloud['habitSwaps'] as List) {
      expect((row as Map).containsKey('triggers'), isFalse);
      expect(row.containsKey('trigger'), isFalse);
    }
  });
}

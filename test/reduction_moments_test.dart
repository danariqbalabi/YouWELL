import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import 'support/sim.dart';

/// Habit Swap as a moment: setup once, "Saya akan coba", "Saya sudah
/// mencoba", outcome now or later (brief of 20 Oct 2026).
void main() {
  Future<Sim> reduction(String product, {String? ageGroup}) async {
    final sim = Sim();
    await sim.start(path: 'reduction', pace: 1, ageGroup: ageGroup);
    sim.controller.setNicotineProduct(product);
    sim.controller.enableMobileRewards();
    return sim;
  }

  test('Titles, buttons and outcomes follow the chosen product', () {
    expect(reductionTitle('cigarette', quit: false), 'Kurangi rokok');
    expect(reductionTitle('cigarette', quit: true), 'Berhenti merokok');
    expect(reductionTitle('vape', quit: false), 'Kurangi vape');
    expect(reductionTitle('vape', quit: true), 'Berhenti vaping');
    expect(reductionTitle('both', quit: true), 'Kelola rokok dan vape');
    expect(cravingLabel('cigarette'), 'Saya ingin merokok');
    expect(cravingLabel('vape'), 'Saya ingin vape');
    for (final outcome in ['skipped', 'used']) {
      expect(outcomeLabel(outcome, 'cigarette'), isNot(contains('vape')));
      expect(outcomeLabel(outcome, 'vape'), isNot(contains('rokok')));
    }
    expect(nicotineChoiceLabels['both'], 'Saya memakai keduanya');
  });

  test(
    'Setup is a list of choices, editable, never a tried activity',
    () async {
      final sim = await reduction('both');
      final c = sim.controller;
      expect(c.productsNeedingSetup, ['cigarette', 'vape']);
      expect(
        c.saveSwapSetup(
          'cigarette',
          triggers: ['after_meal', 'coffee'],
          activities: ['walk'],
          customActivities: ['  cuci muka  ', ''],
        ),
        isTrue,
      );
      expect(c.productsNeedingSetup, ['vape']);
      expect(c.swapSetup('cigarette')!['customActivities'], ['cuci muka']);
      expect(c.habitSwaps, isEmpty);
      expect(c.swapAttemptsToday, isEmpty);

      // "Belum yakin, pilih nanti" never blocks the help.
      c.deferSwapSetup();
      expect(c.productsNeedingSetup, isEmpty);
      expect(c.startSwapMoment(product: 'vape', activities: ['water']), isTrue);
    },
  );

  test('An older single plan reads as setup', () async {
    final sim = await reduction('cigarette');
    final c = sim.controller;
    expect(c.setSwapPlan('cigarette', ['stress'], 'water'), isTrue);
    expect(c.productsNeedingSetup, isEmpty);
    expect(c.swapSetup('cigarette')!['activities'], ['water']);
  });

  test('A started moment survives a restart, can be resumed or cancelled, '
      'and never doubles', () async {
    final sim = await reduction('cigarette');
    final c = sim.controller;
    expect(
      c.startSwapMoment(
        product: 'cigarette',
        activities: ['walk'],
        customActivities: ['cuci muka'],
      ),
      isTrue,
    );
    expect(
      c.startSwapMoment(product: 'cigarette', activities: ['water']),
      isFalse,
      reason: 'resume or cancel the open moment first',
    );
    expect(c.habitSwaps, isEmpty, reason: 'starting is not trying');
    expect(c.quests.where((t) => t['status'] == 'completed'), isEmpty);

    final reopened = WellnessController(
      saved: c.export(),
      clock: () => sim.now,
    );
    expect(reopened.activeSwapMoment!['customActivities'], ['cuci muka']);
    reopened.cancelSwapMoment();
    expect(reopened.activeSwapMoment, isNull);
    expect(reopened.habitSwaps, isEmpty);
  });

  test(
    'Trying finishes the mission and XP once, whatever the outcome',
    () async {
      final sim = await reduction('cigarette');
      final c = sim.controller;
      sim.takeCard(category: 'Reduction');
      final mission = c.quests.firstWhere(
        (task) => task['activityKind'] == 'habit_swap',
      );
      expect(
        c.startSwapMoment(product: 'cigarette', activities: ['walk']),
        isTrue,
      );
      final xp = c.xp;
      final first = c.reportSwapTried(triggers: ['after_meal'])!;
      expect(
        c.quests.firstWhere((t) => t['id'] == mission['id'])['status'],
        'completed',
      );
      final afterFirst = c.xp;
      expect(afterFirst, greaterThan(xp));
      expect(c.swapsAwaitingOutcome.single['id'], first);

      // A second try the same day is recorded, without a second mission XP.
      c.startSwapMoment(product: 'cigarette', activities: ['water']);
      final second = c.reportSwapTried()!;
      expect(c.swapAttemptsToday, hasLength(2));
      expect(c.recordSwapOutcome(first, 'used'), isTrue);
      expect(c.recordSwapOutcome(second, 'skipped'), isTrue);
      expect(c.xp, afterFirst);
      expect(c.swapsAwaitingOutcome, isEmpty);
      expect(c.recordSwapOutcome(first, 'not_tried'), isFalse);
    },
  );

  test('With both products each moment keeps its own product; what was '
      'really used is recorded', () async {
    final sim = await reduction('both');
    final c = sim.controller;
    c.startSwapMoment(product: 'vape', activities: ['music']);
    final id = c.reportSwapTried()!;
    expect(c.recordSwapOutcome(id, 'used', usedProduct: 'cigarette'), isTrue);
    final row = c.habitSwaps.single;
    expect(row['product'], 'vape');
    expect(row['usedProduct'], 'cigarette');
    expect(c.recordSwapOutcome(id, 'skipped', usedProduct: 'vape'), isFalse);
  });

  test(
    'A skipped moment never marks the day free; only confirmed zeros do',
    () async {
      final sim = await reduction('both');
      final c = sim.controller;
      c.startSwapMoment(product: 'cigarette', activities: ['walk']);
      c.recordSwapOutcome(c.reportSwapTried()!, 'skipped');
      expect(c.dayWithoutUse(c.today), isNull, reason: 'not confirmed yet');
      c.saveNicotineDay(
        day: c.today,
        product: 'both',
        cigarettes: 0,
        vapeSessions: 2,
      );
      expect(c.dayWithoutUse(c.today), isFalse);
      c.saveNicotineDay(
        day: c.today,
        product: 'both',
        cigarettes: 0,
        vapeSessions: 0,
      );
      expect(c.dayWithoutUse(c.today), isTrue);
    },
  );

  test(
    'Older moments stay readable and are never given a guessed outcome',
    () async {
      final sim = await reduction('cigarette');
      final c = sim.controller;
      c.recordHabitSwap(
        eventId: 'old-1',
        product: 'cigarette',
        trigger: 'coffee',
        activity: 'walk',
        outcome: 'skipped',
      );
      final legacy = {...jsonDecode(c.export()) as Map<String, dynamic>};
      (legacy['habitSwaps'] as List).add({
        'id': 'old-2',
        'day': c.today,
        'product': 'cigarette',
        'swap': 'Jalan sebentar',
      });
      final restored = WellnessController(
        saved: jsonEncode(legacy),
        clock: () => sim.now,
      );
      expect(restored.habitSwaps, hasLength(2));
      expect(restored.swapsAwaitingOutcome, isEmpty);
      final old = restored.habitSwaps.firstWhere((r) => r['id'] == 'old-2');
      expect(old['outcome'], isNull);
      expect(isSwapAttempt(old), isFalse);
      expect(isSwapAttempt(restored.habitSwaps.first), isTrue);
    },
  );

  test('Setup, open moments and custom texts never leave the device', () async {
    final sim = await reduction('cigarette');
    final c = sim.controller;
    c.saveSwapSetup(
      'cigarette',
      triggers: ['coffee'],
      customTriggers: ['habis kelas'],
      activities: ['walk'],
    );
    c.startSwapMoment(
      product: 'cigarette',
      activities: ['walk'],
      customActivities: ['cuci muka'],
    );
    c.reportSwapTried(customTriggers: ['habis kelas']);
    c.startSwapMoment(product: 'cigarette', activities: ['water']);
    final cloud = jsonEncode(CloudProgress.project(c.export()));
    for (final secret in [
      'reductionSetup',
      'activeSwapMoment',
      'habis kelas',
      'cuci muka',
      'coffee',
      'cigarette',
    ]) {
      expect(cloud, isNot(contains(secret)), reason: secret);
    }
    // Only tried moments become rows, so research counts stay true.
    expect((CloudProgress.project(c.export())['habitSwaps'] as List).length, 1);
    expect(dayKey(DateTime.parse(c.habitSwaps.single['time'])), c.today);
  });
}

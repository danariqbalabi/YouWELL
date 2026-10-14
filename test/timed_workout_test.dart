import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';

import 'support/sim.dart';

/// The iPhone web app has no background GPS, so walk/run quests are timed.
void main() {
  List<Map<String, dynamic>> bodyQuests({required bool timed, int step = 1}) =>
      const DailyCardGenerator()
          .cardPacks(
            today: '2026-10-24',
            steps: {'Body': step},
            pace: 2,
            lowImpact: false,
            reduction: false,
            timedWorkouts: timed,
          )
          .expand(
            (card) => (card['tasks'] as List).cast<Map<String, dynamic>>(),
          )
          .where((task) => task['ladder'] == 'Body')
          .toList();

  test('Every Gerak rung has a timed twin of non-decreasing length', () {
    final rungs = ladders['Body']!;
    for (final (index, rung) in rungs.indexed) {
      expect(rung.timedTitle, isNotNull, reason: rung.title);
      // Interval → steady run gets shorter but harder, as with distance.
      String type(LadderRung r) => r.timedTitle!.split(' ').first;
      if (index > 0 && type(rung) == type(rungs[index - 1])) {
        expect(
          rung.timedMinutes!,
          greaterThanOrEqualTo(rungs[index - 1].timedMinutes!),
        );
      }
    }
  });

  test('Timed cards carry minutes and no distance target', () {
    for (final task in bodyQuests(timed: true, step: 2)) {
      expect(task['title'], 'Jalan 10 menit');
      expect(task['durationMinutes'], 10);
      expect(task['timed'], isTrue);
      expect(task.containsKey('targetMeters'), isFalse);
      expect(task['step'], 2, reason: 'same rung for research data');
    }
    for (final task in bodyQuests(timed: false, step: 2)) {
      expect(task['title'], 'Jalan 800 m');
      expect(task['targetMeters'], 800);
    }
  });

  test('In timed mode, session time finishes the quest without GPS', () async {
    final sim = Sim(timed: true);
    await sim.start();
    sim.takeCard(category: 'Body');
    final gerak = sim.controller.coreQuests.firstWhere(
      (task) => task['ladder'] == 'Body',
    );
    final seconds = (gerak['durationMinutes'] as int) * 60;
    sim.controller.recordWorkout(
      kind: 'walk',
      seconds: seconds ~/ 2,
      meters: 0,
    );
    var now = sim.controller.coreQuests.firstWhere(
      (t) => t['id'] == gerak['id'],
    );
    expect(now['status'], isNot('completed'));
    expect(now['partial'], closeTo(.5, .01));

    sim.controller.recordWorkout(
      kind: 'walk',
      seconds: seconds ~/ 2,
      meters: 0,
    );
    now = sim.controller.coreQuests.firstWhere((t) => t['id'] == gerak['id']);
    expect(now['status'], 'completed');
  });

  test('With GPS, time alone still never finishes a distance quest', () async {
    final sim = Sim();
    await sim.start();
    sim.takeCard(category: 'Body');
    sim.controller.recordWorkout(kind: 'walk', seconds: 3600, meters: 0);
    final gerak = sim.controller.coreQuests.firstWhere(
      (task) => task['ladder'] == 'Body',
    );
    expect(gerak['status'], isNot('completed'));
  });
}

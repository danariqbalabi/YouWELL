import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/features/community/data/local_community_store.dart';
import 'package:youwell/features/progress/domain/research_log_store.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

import 'support/sim.dart';

void main() {
  test('Calendar maths counts days, not 24-hour blocks', () {
    expect(shiftDayKey('2026-10-24', 7), '2026-10-31');
    expect(shiftDayKey('2026-10-31', 1), '2026-11-01');
    expect(shiftDayKey('2026-12-31', 1), '2027-01-01');
    expect(shiftDayKey('2026-03-01', -1), '2026-02-28');
    expect(daysBetweenKeys('2026-10-24', '2026-11-21'), 28);
    expect(daysBetweenKeys('2026-11-21', '2026-10-24'), -28);
  });

  test('After the welcome-back step, quiet weeks keep the 7-day cadence', () async {
    final sim = Sim();
    await sim.start(pace: 3);
    sim.doLadder();
    final start = sim.now;
    sim.now = start.add(const Duration(days: 6));
    sim.controller.prepareToday();
    expect(sim.controller.ladderSteps['Body'], 2);
    expect(sim.controller.capacity['Body']!['change'], 'rest');

    // Five more quiet days is not a new evaluation period yet.
    sim.now = start.add(const Duration(days: 11));
    sim.controller.prepareToday();
    expect(sim.controller.ladderSteps['Body'], 2);

    sim.now = start.add(const Duration(days: 13));
    sim.controller.prepareToday();
    expect(sim.controller.ladderSteps['Body'], 1);
  });

  test('A clock set forward and back does not freeze ladder reviews', () async {
    final sim = Sim();
    await sim.start(pace: 2);
    final start = sim.now;
    sim.now = start.add(const Duration(days: 10));
    sim.controller.prepareToday();
    sim.now = start.add(const Duration(days: 1));
    sim.controller.prepareToday();
    expect(
      sim.controller.capacity['Body']!['reviewedOn'],
      dayKey(sim.now),
      reason: 'a review date in the future is pulled back to today',
    );
    sim.now = start.add(const Duration(days: 8));
    sim.controller.prepareToday();
    expect(sim.controller.capacity['Body']!['reviewedOn'], dayKey(sim.now));
  });

  test('Ladder steps of a path left behind are not reported', () async {
    final sim = Sim();
    await sim.start(path: 'reduction', pace: 2);
    expect(sim.controller.ladderSteps, contains('Reduction'));
    sim.controller.switchPath(false);
    expect(sim.controller.ladderSteps, isNot(contains('Reduction')));
    expect(sim.controller.capacity, contains('Reduction'), reason: 'kept');
    expect(sim.controller.researchSummary(1).ladderJeda, isNull);
  });

  test('A walk saved just after midnight does not crash or vanish', () async {
    final sim = Sim();
    await sim.start();
    sim.now = DateTime(2026, 10, 25, 0, 0, 30);
    // No minute tick yet: today's day entry does not exist.
    expect(sim.controller.days[sim.controller.today], isNull);
    final result = sim.controller.recordWorkout(
      kind: 'walk',
      seconds: 600,
      meters: 800,
    );
    expect(result.tooFast, isFalse);
    expect(
      sim.controller.workoutSessions.where(
        (row) => row['day'] == '2026-10-25',
      ),
      hasLength(1),
    );
    sim.now = DateTime(2026, 10, 26, 0, 1);
    sim.controller.recordMeal(photoCaptured: true);
    expect(sim.controller.mealCheckIns, hasLength(1));
  });

  test('A walk past midnight counts for the day it started', () async {
    final sim = Sim();
    await sim.start();
    sim.takeCard(category: 'Body');
    final walk = sim.controller.coreQuests.firstWhere(
      (task) => task['activityKind'] == 'walk',
    );
    final started = sim.controller.today;
    final xpBefore = sim.controller.xp;
    sim.now = DateTime(2026, 10, 25, 0, 10);
    sim.controller.prepareToday();
    final result = sim.controller.recordWorkout(
      kind: 'walk',
      seconds: 3600,
      meters: (walk['targetMeters'] as int?) ?? 0,
      startedOn: started,
    );
    expect(result.completed, contains(walk['title']));
    final session = sim.controller.workoutSessions.single;
    expect(session['day'], started);
    final yesterday = (sim.controller.days[started]['quests'] as List)
        .firstWhere((task) => task['id'] == walk['id']);
    expect(yesterday['status'], 'completed');
    expect(sim.controller.xp, greaterThan(xpBefore));
    expect(
      sim.controller.quests.where((task) => task['status'] == 'completed'),
      isEmpty,
      reason: 'the new day is untouched',
    );
  });

  test('An unfinished walk is kept on the device only', () async {
    String? saved;
    final controller = WellnessController(
      clock: () => DateTime(2026, 10, 24, 20),
      persist: (value) async => saved = value,
    );
    await controller.setup({
      'alias': 'preview',
      'path': 'wellness',
      'pace': 1,
      'companion': 'plant',
    });
    controller.saveWorkoutDraft({
      'kind': 'walk',
      'day': controller.today,
      'bankedSeconds': 120,
      'since': null,
      'heartbeat': '2026-10-24T20:00:00.000',
      'meters': 250,
    });
    await controller.flush();
    final restored = WellnessController(saved: saved);
    expect(restored.workoutDraft?['bankedSeconds'], 120);
    expect(CloudProgress.project(saved!).containsKey('workoutDraft'), isFalse);
    controller.saveWorkoutDraft(null);
    await controller.flush();
    expect(WellnessController(saved: saved).workoutDraft, isNull);
  });

  test('Research weeks are sent daily while running and once complete', () async {
    final sim = Sim();
    await sim.start();
    final c = sim.controller;
    expect(c.researchWeeksDue, isEmpty, reason: 'no consent, nothing sent');
    c.setResearchParticipation('P3', consent: true);
    expect(c.researchWeeksDue, [1]);
    c.markResearchSent(1, complete: false);
    expect(c.researchWeeksDue, isEmpty, reason: 'once per day');
    sim.nextDay();
    expect(c.researchWeeksDue, [1]);
    for (var i = 0; i < 6; i++) {
      sim.nextDay();
    }
    expect(c.researchWeekComplete(1), isTrue);
    expect(c.researchWeeksDue, [1, 2]);
    c.markResearchSent(1, complete: true);
    c.markResearchSent(2, complete: false);
    expect(c.researchWeeksDue, isEmpty);
    final summary = c.researchSummary(1).toJson();
    expect(
      summary.keys.where((key) => key.contains('alias') || key == 'user_id'),
      isEmpty,
    );
    c.setResearchParticipation(null, consent: false);
    expect(c.researchWeeksDue, isEmpty);
  });

  test('Research CSV keeps the agreed columns and quotes safely', () {
    final csv = researchCsv([
      {'participant_code': 'P3', 'week': 1, 'active': true, 'ladder_jeda': null},
      {'participant_code': 'P1, "x"', 'week': 2},
    ]).split('\n');
    expect(csv.first, researchCsvColumns.join(','));
    expect(csv.first, isNot(contains('alias')));
    expect(csv[1], startsWith('P3,1,,,,true,'));
    expect(csv[2], startsWith('"P1, ""x""",2,'));
  });

  test('The local Community preview reacts, reports and moderates', () async {
    final sim = Sim();
    await sim.start();
    final store = LocalCommunityStore(sim.controller);
    expect(store.shared, isFalse);
    var feed = await store.feed();
    final seed = feed.firstWhere((post) => post.id == 'seed-water');
    expect(seed.sample, isTrue);

    await store.react(seed.id, '🌱');
    feed = await store.feed();
    expect(feed.firstWhere((p) => p.id == seed.id).myReaction, '🌱');
    await store.react(seed.id, null);
    feed = await store.feed();
    expect(feed.firstWhere((p) => p.id == seed.id).myReaction, isNull);

    expect(await store.report(seed.id, 'spam'), isTrue);
    expect(await store.report(seed.id, 'spam'), isFalse);

    await store.submit('Hari ini aku jalan sore.');
    feed = await store.feed();
    final mine = feed.firstWhere((post) => post.mine);
    expect(mine.status, 'pending');
    final queue = await store.moderationQueue();
    expect(queue.pending.single.id, mine.id);
    expect(queue.reports.single.post.id, seed.id);
    await store.moderate(mine.id, approve: true);
    expect((await store.moderationQueue()).pending, isEmpty);
    expect(
      (await store.feed()).firstWhere((post) => post.id == mine.id).status,
      'approved',
    );
  });
}

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';

void main() {
  Map<String, dynamic> reductionState() => {
    ...createEmptyWellnessState(),
    'profile': {
      'alias': 'tester',
      'path': 'reduction',
      'started': '2026-10-16',
    },
    'reductionSettings': {'product': 'cigarette'},
    'reductionPlans': {
      'cigarette': {'trigger': 'after_meal', 'activity': 'walk'},
    },
    'nicotineDays': [
      {'day': '2026-10-16', 'cigarettes': 2},
    ],
    'reductionTargets': [
      {'week': 2, 'product': 'cigarette', 'target': 1},
    ],
    'habitSwaps': [
      for (final outcome in ['used', 'skipped', 'not_tried'])
        {
          'id': 'moment-$outcome',
          'day': '2026-10-16',
          'time': '2026-10-16T12:00:00',
          'eventId': 'submit-$outcome',
          'product': 'cigarette',
          'trigger': 'after_meal',
          'activity': outcome == 'not_tried' ? null : 'walk',
          'outcome': outcome,
          'swap': outcome == 'not_tried' ? null : 'Jalan ringan',
        },
    ],
  };

  test('Cloud projection excludes private reduction details', () {
    final payload = CloudProgress.project(jsonEncode(reductionState()));
    for (final key in [
      'reductionSettings',
      'reductionPlans',
      'nicotineDays',
      'reductionTargets',
    ]) {
      expect(payload.containsKey(key), isFalse);
    }
    for (final row in payload['habitSwaps'] as List) {
      expect((row as Map).keys.toSet(), {'id', 'day', 'time'});
    }
  });

  test(
    'Cloud adoption preserves matching local outcomes and submission IDs',
    () {
      final device = reductionState();
      final raw = jsonEncode(device);
      final restored =
          jsonDecode(CloudProgress.apply(CloudProgress.project(raw), raw))
              as Map;
      expect(restored['habitSwaps'], device['habitSwaps']);
      for (final key in [
        'reductionSettings',
        'reductionPlans',
        'nicotineDays',
        'reductionTargets',
      ]) {
        expect(restored[key], device[key]);
      }
    },
  );

  test(
    'Another device cannot reconstruct private moments from cloud metadata',
    () {
      final payload = CloudProgress.project(jsonEncode(reductionState()));
      final other = reductionState();
      for (final row in other['habitSwaps'] as List) {
        (row as Map)['id'] = 'different-${row['id']}';
      }
      for (final local in [null, jsonEncode(other)]) {
        final restored = jsonDecode(CloudProgress.apply(payload, local)) as Map;
        for (final row in restored['habitSwaps'] as List) {
          expect((row as Map).containsKey('outcome'), isFalse);
          expect(row.containsKey('eventId'), isFalse);
          expect(row.containsKey('product'), isFalse);
          expect(row.containsKey('trigger'), isFalse);
        }
      }
    },
  );
}

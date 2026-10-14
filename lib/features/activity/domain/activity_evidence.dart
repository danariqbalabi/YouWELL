import 'dart:math';

import 'package:youwell/core/types/json_map.dart';

/// Timer/GPS evidence is separate from rewards, which are never taken back.
abstract final class ActivityEvidence {
  static bool isWorkout(JsonMap task) =>
      const {'walk', 'run'}.contains(task['activityKind']);

  static double workoutProgress(
    JsonMap task,
    Iterable<JsonMap> sessions,
    String day,
  ) {
    final targetMeters = (task['targetMeters'] as num?)?.toInt();
    final targetSeconds = max(
      1,
      ((task['durationMinutes'] as num?)?.toInt() ?? 0) * 60,
    );
    return sessions
        .where(
          (row) =>
              row['day'] == day &&
              row['countsForQuest'] != false &&
              // Old versions allowed editing metrics: those are not evidence.
              row['correctedAt'] == null &&
              (task['activityKind'] == 'walk'
                  ? const {'walk', 'run'}.contains(row['kind'])
                  : row['kind'] == 'run'),
        )
        .fold<double>(0, (sum, row) {
          final meters = (row['meters'] as num?)?.toInt() ?? 0;
          final seconds = (row['seconds'] as num?)?.toInt() ?? 0;
          // Distance quests need real GPS meters; time never stands in.
          // Timed quests (web app, no background GPS) and quests saved
          // before distance targets count session time.
          return sum +
              (targetMeters != null && targetMeters > 0
                  ? meters / targetMeters
                  : seconds / targetSeconds);
        });
  }

  /// How many of a meal quest's photos are covered by today's camera photos.
  /// With windows, each window needs its own photo taken inside it.
  static int mealPhotosMatched(
    JsonMap task,
    Iterable<JsonMap> meals,
    String day,
  ) {
    final required = (task['photoCount'] as num?)?.toInt() ?? 1;
    final times = [
      for (final row in meals)
        if (row['day'] == day &&
            (row['photoPath'] is String || row['photoCaptured'] == true))
          DateTime.tryParse(row['time']?.toString() ?? ''),
    ].whereType<DateTime>().toList()..sort();
    final windows = (task['photoWindows'] as List?)
        ?.map((window) => (window as List).cast<num>())
        .toList();
    if (windows == null) return min(times.length, required);
    final used = <int>{};
    var matched = 0;
    for (final window in windows) {
      for (final (index, time) in times.indexed) {
        final hour = time.hour + time.minute / 60;
        if (!used.contains(index) && hour >= window[0] && hour < window[1]) {
          used.add(index);
          matched++;
          break;
        }
      }
    }
    return matched;
  }
}

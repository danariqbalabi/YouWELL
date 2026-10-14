import 'package:youwell/application/wellness_controller.dart';
import 'package:youwell/core/types/json_map.dart';

/// A controller with a movable clock for multi-day challenge tests.
/// Starts in the evening so every quest can be finished the same day.
class Sim {
  /// [timed]: walk/run counts session time, as in the web app.
  Sim({this.timed = false});
  final bool timed;
  DateTime now = DateTime(2026, 10, 24, 20);
  late final controller = WellnessController(
    clock: () => now,
    timedWorkouts: timed,
  );

  Future<void> start({
    String path = 'wellness',
    int pace = 2,
    bool lowImpact = false,
    String? ageGroup,
  }) => controller.setup({
    'alias': 'preview',
    'path': path,
    'pace': pace,
    'lowImpact': lowImpact,
    'companion': 'plant',
    'ageGroup': ?ageGroup,
  });

  void nextDay() {
    now = now.add(const Duration(days: 1));
    controller.prepareToday();
  }

  List<JsonMap> get cards => controller.dailyDrawCards;

  List<JsonMap> tasksOf(JsonMap card) =>
      (card['tasks'] as List).cast<Map<String, dynamic>>();

  List<String> categoriesOf(JsonMap card) =>
      (card['categories'] as List).cast<String>();

  /// Takes the first card holding a ladder quest of [category] (or card 0).
  void takeCard({String? category}) {
    final card = cards.firstWhere(
      (card) => category == null || categoriesOf(card).contains(category),
      orElse: () => cards.first,
    );
    controller.selectDailyCard(card['id']);
    controller.commitDailyCardPack();
  }

  /// Finishes one quest through its real validation path.
  void finish(JsonMap task) {
    switch (task['activityKind']) {
      case 'walk' || 'run':
        final meters = (task['targetMeters'] as int?) ?? 0;
        controller.recordWorkout(
          kind: task['activityKind'],
          // A steady 5 km/h walk, well under the 20 km/h limit.
          seconds: task['timed'] == true
              ? (task['durationMinutes'] as int) * 60
              : (meters / 5000 * 3600).round() + 60,
          meters: meters,
        );
      case 'water':
        while (controller.water < (task['waterMl'] as int)) {
          controller.addWater();
        }
      case 'meal_snap':
        for (var i = 0; i < ((task['photoCount'] as int?) ?? 1); i++) {
          controller.recordMeal(photoPath: '/tmp/meal-$i.jpg');
        }
      default:
        controller.completeCard(task['id']);
    }
  }

  /// Takes a card with [category] and finishes its ladder quests.
  void doLadder({String category = 'Body'}) {
    takeCard(category: category);
    for (final task in controller.coreQuests) {
      if (task['ladder'] != null) finish(task);
    }
  }

  /// Seven days; [active] decides whether that day's ladder quests are done.
  void runWeek(bool Function(int day) active, {String category = 'Body'}) {
    for (var day = 0; day < 7; day++) {
      if (active(day)) doLadder(category: category);
      nextDay();
    }
  }
}

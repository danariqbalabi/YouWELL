part of 'wellness_controller.dart';

/// Private device logs; research export deliberately retains only its existing
/// consented aggregate fields. No raw product/trigger/consumption sync.
extension ReductionSupport on WellnessController {
  /// A committed card stays finishable if the path is disabled mid-day.
  bool get hasOpenHabitSwapMission => quests.any(
    (task) =>
        task['activityKind'] == 'habit_swap' && task['status'] != 'completed',
  );
  String? get nicotineProduct =>
      (_data['reductionSettings'] as Map?)?['product']?.toString();
  List<JsonMap> get nicotineDays => _rows('nicotineDays');
  List<JsonMap> get reductionTargets => _rows('reductionTargets');
  List<JsonMap> get swapAttemptsToday => habitSwaps
      .where((row) => row['day'] == today && isSwapAttempt(row))
      .toList();

  bool setNicotineProduct(String value) {
    if (!reduction ||
        uatProgramComplete ||
        !nicotineProductLabels.containsKey(value)) {
      return false;
    }
    _data['reductionSettings'] = {
      ...?(_data['reductionSettings'] as Map?),
      'product': value,
    };
    _save();
    return true;
  }

  /// Idempotency is per submitted moment, not an arbitrary ten-minute lock.
  /// A tried activity earns the daily quest equally for either honest outcome.
  bool recordHabitSwap({
    required String eventId,
    required String product,
    required String trigger,
    required String activity,
    required String outcome,
  }) {
    if ((!reduction && !hasOpenHabitSwapMission) ||
        uatProgramComplete ||
        eventId.isEmpty ||
        eventId.length > 100 ||
        !const ['cigarette', 'vape'].contains(product) ||
        (nicotineProduct != null &&
            !productsFor(nicotineProduct).contains(product)) ||
        !triggersFor(product).contains(trigger) ||
        !swapOutcomeLabels.containsKey(outcome) ||
        (outcome != 'not_tried' && !swapActivityLabels.containsKey(activity)) ||
        habitSwaps.any((row) => row['eventId'] == eventId)) {
      return false;
    }
    _add('habitSwaps', {
      'eventId': eventId,
      'product': product,
      'trigger': trigger,
      'activity': outcome == 'not_tried' ? null : activity,
      'swap': outcome == 'not_tried' ? null : swapActivityLabels[activity],
      'outcome': outcome,
    });
    _applyHabitSwapEvidence();
    return true;
  }

  void _applyHabitSwapEvidence() {
    if (uatProgramComplete || swapAttemptsToday.isEmpty) return;
    final task = quests
        .where(
          (task) =>
              task['activityKind'] == 'habit_swap' &&
              task['status'] != 'completed',
        )
        .firstOrNull;
    if (task != null) completeCard(task['id'].toString());
  }

  ConsumptionWeek consumptionWeek(int week) => ConsumptionWeek.fromLogs(
    week: week,
    started: profile?['started']?.toString() ?? today,
    logs: nicotineDays,
    through: today,
  );
  JsonMap? swapPlan(String product) {
    final value = (_data['reductionPlans'] as Map?)?[product];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  bool setSwapPlan(String product, String trigger, String activity) {
    if (!reduction ||
        uatProgramComplete ||
        !productsFor(nicotineProduct).contains(product) ||
        !triggersFor(product).contains(trigger) ||
        !swapActivityLabels.containsKey(activity)) {
      return false;
    }
    (_data['reductionPlans'] ??= <String, dynamic>{})[product] = {
      'trigger': trigger,
      'activity': activity,
      'chosenOn': today,
    };
    _save();
    return true;
  }

  JsonMap? nicotineDay(String day) =>
      nicotineDays.where((row) => row['day'] == day).firstOrNull;

  /// One confirmed full-day total per date. Zero must be entered explicitly.
  /// After the program only correction of existing records is allowed.
  bool saveNicotineDay({
    required String day,
    required String product,
    int? cigarettes,
    int? vapeSessions,
  }) {
    final start = profile?['started']?.toString() ?? today;
    final parsed = DateTime.tryParse(day);
    final activeProducts = productsFor(product);
    if (!reduction ||
        parsed == null ||
        dayKey(parsed) != day ||
        activeProducts.isEmpty ||
        day.compareTo(start) < 0 ||
        day.compareTo(today) > 0 ||
        parsed.difference(DateTime.parse(start)).inDays >= 28 ||
        (uatProgramComplete && nicotineDay(day) == null)) {
      return false;
    }
    final values = {'cigarette': cigarettes, 'vape': vapeSessions};
    if (activeProducts.any(
      (kind) =>
          values[kind] == null || values[kind]! < 0 || values[kind]! > 500,
    )) {
      return false;
    }
    final rows = (_data['nicotineDays'] ??= <dynamic>[]) as List;
    rows.removeWhere((row) => row['day'] == day);
    rows.add({
      'day': day,
      'product': product,
      'confirmed': true,
      'updatedAt': now.toIso8601String(),
      'cigarette': activeProducts.contains('cigarette') ? cigarettes : null,
      'vape': activeProducts.contains('vape') ? vapeSessions : null,
    });
    _save();
    return true;
  }

  JsonMap? targetFor(int week, String product) => reductionTargets
      .where((row) => row['week'] == week && row['product'] == product)
      .firstOrNull;

  /// Optional user choice after observing week 1; never auto-tightened by XP,
  /// quest completion or accepting a wellness ladder offer.
  bool setReductionTarget(String product, int? limit) {
    final week = uatProgram?.week ?? 1;
    final baseline = consumptionWeek(1);
    if (!reduction ||
        uatProgramComplete ||
        week == 1 ||
        !productsFor(nicotineProduct).contains(product) ||
        !baseline.comparableFor(product) ||
        (limit != null &&
            (limit < 0 || limit > baseline.meanFor(product)!.ceil()))) {
      return false;
    }
    final rows = (_data['reductionTargets'] ??= <dynamic>[]) as List;
    rows.removeWhere((row) => row['week'] == week && row['product'] == product);
    if (limit != null) {
      rows.add({
        'week': week,
        'product': product,
        'limit': limit,
        'chosenOn': today,
      });
    }
    _save();
    return true;
  }
}

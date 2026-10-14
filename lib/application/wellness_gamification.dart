part of "wellness_controller.dart";

/// Mobile reward policy kept separate from shared activity and quest state.
extension MobileWellnessRewards on WellnessController {
  void enableMobileRewards() {
    if (_mobileRewardsEnabled) return;
    _mobileRewardsEnabled = true;
    if (profile != null) _reviewLadders();
    _claimAchievements();
    if (!hasCommittedDailyCard &&
        selectedDailyCardId == null &&
        passedDailyCardIds.isEmpty) {
      _refreshDraft();
    }
  }

  RewardMoment? takeRewardMoment() =>
      _moments.isEmpty ? null : _moments.removeAt(0);
  bool get reduceMotion => _data['reduceMotion'] == true;
  bool get haptics => _data['haptics'] != false;
  String get companionAccessory =>
      _data['companionAccessory']?.toString() ?? 'none';
  String get companionBackground =>
      _data['companionBackground']?.toString() ?? 'natural';
  Map<String, dynamic> get achievements =>
      Map<String, dynamic>.from(_data['achievements'] ?? {});
  int get totalDelayMinutes => habitDelays.fold(
    0,
    (sum, row) => sum + max(0, (row['minutes'] as num?)?.toInt() ?? 0),
  );
  int get mobileBonusXp =>
      ((_data['mobileRewards'] ?? {}) as Map).values.fold<int>(
        0,
        (sum, row) =>
            sum + (row is Map ? ((row['bonusXp'] as num?)?.toInt() ?? 0) : 0),
      );
  int get mobileBonusXpToday => ((_data['mobileRewards'] ?? {}) as Map).values
      .where((row) => row is Map && row['day'] == today)
      .fold<int>(
        0,
        (sum, row) => sum + ((row['bonusXp'] as num?)?.toInt() ?? 0),
      );
  List<String> get activityDays =>
      ((_data['activityDays'] ?? []) as List).cast<String>();
  String get dailyPace => days[today]?['dailyPace']?.toString() ?? 'normal';

  void setReduceMotion(bool value) {
    _data['reduceMotion'] = value;
    _save();
  }

  void setHaptics(bool value) {
    _data['haptics'] = value;
    _save();
  }

  void equipCompanion(String id, {required bool background}) {
    if (id != (background ? 'natural' : 'none') &&
        !companionUnlocks.any(
          (item) =>
              item.id == id &&
              item.background == background &&
              level >= item.level,
        )) {
      return;
    }
    _data[background ? 'companionBackground' : 'companionAccessory'] = id;
    _save();
  }

  bool setDailyPace(String value) {
    if (wellnessProgramComplete) return false;
    if (!const ['relaxed', 'normal'].contains(value) ||
        hasCommittedDailyCard ||
        selectedDailyCardId != null ||
        passedDailyCardIds.isNotEmpty ||
        days[today] == null) {
      return false;
    }
    _data['days'][today]['dailyPace'] = value;
    _refreshDraft();
    _save();
    return true;
  }

  void _markActivity() {
    final rows = (_data['activityDays'] ??= <dynamic>[]) as List;
    if (!rows.contains(today)) rows.add(today);
  }

  List<String> _claimAchievements() {
    final stored = (_data['achievements'] ??= <String, dynamic>{}) as Map;
    final earned = <String>[];
    final hydrationDays = days.values
        .where(
          (day) =>
              day is Map &&
              ((day['water'] as num?) ?? 0) >=
                  ((profile?['waterGoal'] as num?) ?? 2000),
        )
        .length;
    final conditions = {
      'first-quest': activeDays.isNotEmpty,
      'full-day': completedDays.isNotEmpty,
      'weekly-rhythm': activeDaysIn(7) >= 4,
      'first-delay': habitDelays.any((row) => row['completed'] != false),
      'delay-30': totalDelayMinutes >= 30,
      'delay-60': totalDelayMinutes >= 60,
      'delay-300': totalDelayMinutes >= 300,
      'hydration-7': hydrationDays >= 7,
      'first-ladder': capacity.values.any((row) => row['acceptedOn'] != null),
    };
    for (final entry in conditions.entries) {
      if (entry.value && !stored.containsKey(entry.key)) {
        stored[entry.key] = today;
        earned.add(achievementNames[entry.key]!);
      }
    }
    return earned;
  }

  void _rewardCompletions(List<JsonMap> before) {
    if (!_mobileRewardsEnabled) return;
    final previousDone = before
        .where((row) => row['status'] == 'completed')
        .map((row) => row['id'])
        .toSet();
    final newDone = completedCards
        .where((row) => !previousDone.contains(row['id']))
        .toList();
    if (newDone.isEmpty) return;
    final rewards = (_data['mobileRewards'] ??= <String, dynamic>{}) as Map;
    var gained = 0;
    for (final task in newDone) {
      final id = 'quest:${task['id']}';
      if (rewards.containsKey(id)) continue;
      final amount = (task['xp'] as num?)?.toInt() ?? 15;
      rewards[id] = {'day': today, 'questXp': amount};
      gained += amount;
    }
    if (gained == 0) return;
    final oldLevel = max(levelFloor, levelForXp(xp - gained));
    var full = false;
    if (coreQuests.length >= 3 &&
        coreQuests.every((task) => task['status'] == 'completed') &&
        !rewards.containsKey('day:$today')) {
      rewards['day:$today'] = {'day': today, 'bonusXp': 20};
      gained += 20;
      full = true;
    }
    _moments.add(
      RewardMoment(
        serial: ++rewardSerial,
        xp: gained,
        dayComplete: full,
        evolved: companionStage(level) > companionStage(oldLevel),
        unlocks: companionUnlocks
            .where((item) => item.level > oldLevel && item.level <= level)
            .map((item) => item.label)
            .toList(),
        badges: _claimAchievements(),
      ),
    );
  }
}

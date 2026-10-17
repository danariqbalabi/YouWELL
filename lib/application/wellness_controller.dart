import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:youwell/core/config/app_mode.dart' as app_mode;
import 'package:youwell/core/config/app_environment.dart';
import 'package:youwell/features/activity/domain/activity_evidence.dart';
import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';
import 'package:youwell/data/models/wellness_snapshot.dart';
import 'package:youwell/features/home/domain/daily_card_generator.dart';
import 'package:youwell/features/home/domain/progress_calculator.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';
import 'package:youwell/features/home/domain/wellness_uat_program.dart';
import 'package:youwell/features/progress/domain/level_curve.dart';
import 'package:youwell/features/progress/domain/research_summary.dart';
import 'package:youwell/features/reduction/domain/reduction_policy.dart';
import 'package:youwell/features/companion/domain/companion_rewards.dart';
import 'package:youwell/features/community/domain/community_store.dart'
    show maxCommunityPostLength;

part 'wellness_gamification.dart';
part 'wellness_reduction.dart';

/// Single local-first state boundary shared by mobile and web.
/// Remote auth and sync can later replace [persist] without changing the UI.
class WellnessController extends ChangeNotifier {
  WellnessController({
    String? saved,
    this.persist,
    DateTime Function()? clock,
    this.timedWorkouts = app_mode.timedWorkouts,
  }) : clock = clock ?? DateTime.now {
    if (saved != null) {
      try {
        _data = restoreWellnessState(saved);
        if (profile != null &&
            DateTime.tryParse(profile?['started']?.toString() ?? '') == null) {
          _data['profile']['started'] = today;
        }
        // Snapshots from the flat 100-XP curve keep the level they showed.
        if (_data['profile'] != null && _data['levelFloor'] == null) {
          _data['levelFloor'] = legacyLevelForXp(xp);
        }
      } catch (_) {
        storageError = 'Data lokal tidak bisa dibaca, jadi aplikasi mulai baru.';
      }
      _replaceRetiredDelayQuests();
      _matchWorkoutMethod();
      _reconcileActivityEvidence();
      _refreshPendingLadderOffers();
    }
  }

  final Future<void> Function(String)? persist;
  final DateTime Function() clock;

  /// Walk/run quests count session time instead of GPS distance (web app).
  final bool timedWorkouts;
  JsonMap _data = createEmptyWellnessState();
  Future<void> _pending = Future.value();
  String? storageError;
  bool _mobileRewardsEnabled = false;
  final List<RewardMoment> _moments = [];
  int rewardSerial = 0;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void dismissStorageError() {
    storageError = null;
    if (!_disposed) notifyListeners();
  }

  String get themePreference => _data['themeMode']?.toString() ?? 'system';

  Future<void> setThemePreference(String value) {
    if (!const ['system', 'light', 'dark'].contains(value)) {
      throw ArgumentError.value(value, 'value', 'Unsupported theme mode');
    }
    _data['themeMode'] = value;
    return _save();
  }

  int get dayOffset => (_data['dayOffset'] as num?)?.toInt() ?? 0;
  DateTime get now => clock().add(Duration(days: dayOffset));
  String get today => dayKey(now);
  JsonMap? get profile => _data['profile'] == null
      ? null
      : Map<String, dynamic>.from(_data['profile']);
  bool get reduction => profile?['path'] == 'reduction';
  bool get wellnessUat => profile?['path'] == 'wellness';
  WellnessUatProgram? get uatProgram => profile != null
      ? WellnessUatProgram(
          started: profile?['started']?.toString() ?? today,
          now: now,
        )
      : null;
  WellnessUatProgram? get wellnessProgram => wellnessUat ? uatProgram : null;
  bool get wellnessProgramComplete => wellnessProgram?.complete == true;
  bool get uatProgramComplete => uatProgram?.complete == true;
  int ladderMaximum(String category) => ladderMax(
    category,
    lowImpact: profile?['lowImpact'] == true,
    wellnessUat: profile != null,
  );

  /// Under 21 the reduction path speaks about quitting (PP 28/2024 Ps. 434).
  /// The 18–22 bucket crosses 21, so it is treated as quit framing too;
  /// '18-20' is kept for profiles made before the buckets changed.
  bool get quitFraming =>
      const {'under18', '18-22', '18-20'}.contains(profile?['ageGroup']);
  String get reductionLabel =>
      quitFraming ? 'Berhenti rokok / vape' : 'Kurangi rokok / vape';
  Map<String, dynamic> get days => Map<String, dynamic>.from(_data['days']);

  List<JsonMap> _rows(String key) => ((_data[key] ?? const []) as List)
      .whereType<Map>()
      .map((row) => Map<String, dynamic>.from(row))
      .toList();

  List<JsonMap> get quests => _questsOn(today);
  List<JsonMap> _questsOn(String day) =>
      ((days[day]?['quests'] ?? const []) as List)
          .whereType<Map>()
          .map((task) => Map<String, dynamic>.from(task))
          .toList();
  List<JsonMap> get dailyDrawCards =>
      ((days[today]?['cardPacks'] ?? days[today]?['bonusCards'] ?? const [])
              as List)
          .whereType<Map>()
          .map((card) => Map<String, dynamic>.from(card))
          .toList();
  JsonMap? get dailyCardDraw {
    final value = days[today]?['cardDraw'];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  String? get selectedDailyCardId =>
      dailyCardDraw?['selectedCardId']?.toString();
  List<String> get passedDailyCardIds =>
      ((dailyCardDraw?['passedCardIds'] ?? const []) as List)
          .map((id) => id.toString())
          .toList();
  int get dailyDeckStartIndex {
    if (dailyDrawCards.isEmpty) return 0;
    return ((dailyCardDraw?['deckStartIndex'] as num?)?.toInt() ?? 0) %
        dailyDrawCards.length;
  }

  JsonMap? get selectedDailyCard {
    final id = selectedDailyCardId;
    if (id == null) return null;
    return dailyDrawCards.cast<JsonMap?>().firstWhere(
      (card) => card?['id'] == id,
      orElse: () => null,
    );
  }

  JsonMap? get recommendedDailyCard => dailyDrawCards
      .where(
        (card) =>
            card['recommended'] == true &&
            !passedDailyCardIds.contains(card['id']),
      )
      .firstOrNull;

  bool chooseRecommendedDailyCard() {
    if (profile == null || uatProgramComplete) return false;
    prepareToday();
    final card = recommendedDailyCard;
    return card != null && selectDailyCard(card['id'].toString());
  }

  bool get hasCommittedDailyCard => dailyCardDraw?['committedCardId'] != null;
  bool get needsDailyCardDraw =>
      profile != null && !uatProgramComplete && !hasCommittedDailyCard;
  int get dailyCardSwitchesRemaining =>
      (1 - passedDailyCardIds.length).clamp(0, 1);
  bool get canChooseAnotherDailyCard =>
      selectedDailyCard != null &&
      dailyCardSwitchesRemaining > 0 &&
      !hasCommittedDailyCard;

  List<JsonMap> get completedCards =>
      quests.where((task) => task['status'] == 'completed').toList();

  /// Missions of today's card; Kartu Bonus quests are listed separately.
  List<JsonMap> get coreQuests =>
      quests.where((task) => task['bonus'] != true).toList();
  List<JsonMap> get bonusQuests =>
      quests.where((task) => task['bonus'] == true).toList();
  bool get coreComplete =>
      hasCommittedDailyCard &&
      coreQuests.isNotEmpty &&
      coreQuests.every((task) => task['status'] == 'completed');

  /// One optional Kartu Bonus per day, offered after a full day.
  bool get canDrawBonusCard =>
      !uatProgramComplete && coreComplete && days[today]?['bonusDrawn'] != true;

  bool drawBonusCard() {
    if (!canDrawBonusCard) return false;
    final extras = const DailyCardGenerator().bonusQuests(
      today: today,
      takenCatalogIds: quests.map((task) => task['catalogId'].toString()),
      reduction: reduction,
      cameraAvailable: !cameraUnavailable,
      hasWaterLadder: quests.any((task) => task['activityKind'] == 'water'),
      hasFoodLadder: quests.any((task) => task['ladder'] == 'Food'),
      hour: now.hour,
      wellnessUat: profile != null,
    );
    _data['days'][today]['quests'] = [
      ...quests,
      for (final task in extras) {...task, 'status': 'committed'},
    ];
    _data['days'][today]['bonusDrawn'] = true;
    _save();
    return true;
  }

  int get dailyXp =>
      mobileBonusXpToday +
      completedCards.fold<int>(
        0,
        (sum, task) => sum + ((task['xp'] as num?)?.toInt() ?? 0),
      );
  double get dailyProgress =>
      quests.isEmpty ? 0 : completedCards.length / quests.length;
  double get water => ((days[today]?['water'] ?? 0) as num).toDouble();

  /// The one hydration target of [day]: its Hidrasi ladder quest if a card
  /// holds one, else that day's Hidrasi step. 2.000 ml is the ladder's top,
  /// not a fixed daily goal.
  int waterTargetOn(String day) {
    final entry = days[day];
    final quest = entry is Map
        ? ((entry['quests'] ?? const []) as List).whereType<Map>().firstWhere(
            (task) => task['ladder'] == 'Lifestyle' && task['waterMl'] is num,
            orElse: () => const {},
          )
        : const {};
    if (quest['waterMl'] is num) return (quest['waterMl'] as num).toInt();
    final steps = entry is Map ? entry['ladderSteps'] : null;
    final step = day == today || steps is! Map
        ? ladderSteps['Lifestyle']
        : (steps['Lifestyle'] as num?)?.toInt();
    return waterRung(step ?? 1).waterMl!;
  }

  int get waterTarget => waterTargetOn(today);

  /// The highest Hidrasi step this profile can reach.
  int get waterTop => waterRung(ladderMaximum('Lifestyle')).waterMl!;

  ProgressCalculator get _progress => ProgressCalculator(days: days, now: now);
  List<String> get completedDays => _progress.completedDays;
  List<String> get activeDays => _progress.activeDays;
  int get xp => _progress.xp + mobileBonusXp;

  /// Shown level: never below the highest level ever reached (`levelFloor`).
  int get level => max(levelFloor, levelForXp(xp));
  int get levelFloor => (_data['levelFloor'] as num?)?.toInt() ?? 1;

  /// XP still needed for the next level, measured above the shown level.
  int get xpToNextLevel => max(0, xpForLevel(level + 1) - xp);

  /// 0..1 progress inside the shown level, for XP bars.
  double get levelProgress {
    final start = xpForLevel(level), end = xpForLevel(level + 1);
    return ((xp - start) / (end - start)).clamp(0, 1).toDouble();
  }

  int activeDaysIn(int period) => _progress.activeDaysIn(period);
  double compliance(int period) => _progress.completionRate(period);

  // Focus belongs to the web Pomodoro. Mobile does not expose this collection.
  List<JsonMap> get focusSessions => _rows('focusSessions');

  /// Archived timer records, retained only for old exports/research summaries.
  List<JsonMap> get habitDelays => _rows('habitDelays');
  List<JsonMap> get habitSwaps => _rows('habitSwaps');
  List<JsonMap> get workoutSessions => _rows('workoutSessions');
  List<JsonMap> get mealCheckIns => _rows('mealCheckIns');
  List<JsonMap> get communityPosts => [
    ..._seedCommunityPosts,
    ..._rows('communityPosts'),
  ];
  List<JsonMap> get approvedCommunityPosts =>
      communityPosts.where((post) => post['status'] == 'approved').toList()
        ..sort((a, b) => b['time'].toString().compareTo(a['time'].toString()));
  List<JsonMap> get moderationQueue => _rows(
    'communityPosts',
  ).where((post) => post['status'] == 'pending').toList();
  List<JsonMap> get communityReports => _rows('communityReports');
  int get focusMinutesToday => focusSessions
      .where((row) => row['day'] == today)
      .fold<int>(
        0,
        (sum, row) => sum + ((row['minutes'] as num?)?.toInt() ?? 0),
      );

  int get habitSwapsToday =>
      habitSwaps.where((row) => row['day'] == today).length;
  List<String> get openedDays =>
      ((_data['openedDays'] ?? const []) as List).cast<String>();

  /// Ladder state per category: step, offered step, and the last reason.
  Map<String, JsonMap> get capacity => {
    for (final entry in ((_data['capacity'] ?? const {}) as Map).entries)
      entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
  };
  /// Steps of the active path only: a category left behind by a path switch
  /// keeps its saved step but is reported as unused (null) in research logs.
  Map<String, int> get ladderSteps {
    final active = ladderCategories(reduction: reduction);
    return {
      for (final entry in capacity.entries)
        if (active.contains(entry.key))
          entry.key: (entry.value['step'] as num?)?.toInt() ?? 1,
    };
  }
  List<String> get ladderOffers => uatProgramComplete
      ? []
      : [
          for (final category in ladderCategories(reduction: reduction))
            if (capacity[category]?['offerStep'] != null) category,
        ];

  ResearchSummary researchSummary(int week) => ResearchSummary.forWeek(
    week: week,
    started: profile?['started']?.toString() ?? today,
    days: days,
    openedDays: openedDays,
    activityDays: activityDays,
    habitDelays: habitDelays,
    habitSwaps: habitSwaps,
  );

  Future<void> _save() {
    if (profile != null && level > levelFloor) _data['levelFloor'] = level;
    if (days[today] is Map && capacity.isNotEmpty) {
      _data['days'][today]['ladderSteps'] = ladderSteps;
    }
    if (!_disposed) notifyListeners();
    final value = jsonEncode(_data);
    _pending = _pending.then((_) async {
      try {
        await persist?.call(value);
        if (storageError != null) {
          storageError = null;
          if (!_disposed) notifyListeners();
        }
      } catch (_) {
        storageError = 'Perubahan lokal belum tersimpan.';
        if (!_disposed) notifyListeners();
      }
    });
    return _pending;
  }

  /// Await pending device writes before resolving a cloud conflict.
  Future<void> flush() => _pending;

  /// The web app always counts walk/run by session time; the APK by GPS.
  /// Open quests from the other device are converted by [_matchWorkoutMethod].
  bool get workoutUsesTimer => timedWorkouts;

  Future<void> setup(JsonMap value) async {
    final alias = value['alias'].toString().trim();
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{2,19}$').hasMatch(alias)) {
      throw ArgumentError('Alias 3–20 karakter: huruf, angka, underscore.');
    }
    _data['profile'] = {
      ...?profile,
      ...value,
      'alias': alias,
      'started': profile?['started'] ?? today,
    }..remove('waterGoal');
    final product = _data['profile'].remove('nicotineProduct');
    if (reduction && nicotineProductLabels.containsKey(product)) {
      _data['reductionSettings'] = {'product': product};
    }
    prepareToday();
    await _save();
  }

  /// Community and sync show the alias; it follows the onboarding rule.
  void setAlias(String value) {
    final alias = value.trim();
    if (profile == null) return;
    if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9_]{2,19}$').hasMatch(alias)) {
      throw ArgumentError('Alias 3–20 karakter: huruf, angka, underscore.');
    }
    _data['profile']['alias'] = alias;
    _save();
  }

  /// The companion's own name, or Welli until the user picks one.
  String get companionDisplayName {
    final name = profile?['companionName']?.toString().trim() ?? '';
    return name.isEmpty ? companionName : name;
  }

  /// 1–20 characters without control characters (the server's rule too).
  bool setCompanionName(String value) {
    final name = value.trim();
    if (profile == null ||
        name.isEmpty ||
        name.length > 20 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(name)) {
      return false;
    }
    _data['profile']['companionName'] = name;
    _save();
    return true;
  }

  void prepareToday() {
    if (profile == null) return;
    final opened = (_data['openedDays'] ??= <dynamic>[]) as List;
    final firstOpenToday = !opened.contains(today);
    if (firstOpenToday) opened.add(today);
    if (uatProgramComplete) {
      if (firstOpenToday) _save();
      return;
    }
    final existing = days[today];
    if (existing != null &&
        (existing['cardPacks'] != null ||
            hasCommittedDailyCard ||
            completedCards.isNotEmpty)) {
      final refreshed = _refreshMealDraft();
      if (firstOpenToday || _mobileRewardsEnabled || refreshed) _save();
      return;
    }
    _reviewLadders();
    final oldCards = existing == null ? <JsonMap>[] : dailyDrawCards;
    final packs = _cardPacks();
    if (existing != null) {
      // Upgrade an untouched draft without wiping water or rejected choices.
      for (
        var index = 0;
        index < packs.length && index < oldCards.length;
        index++
      ) {
        packs[index]['id'] = oldCards[index]['id'];
      }
      _data['days'][today]['quests'] = <JsonMap>[];
      _data['days'][today]['cardPacks'] = packs;
      _data['days'][today].remove('bonusCards');
      _save();
      return;
    }
    _data['days'][today] = {
      'ladderSteps': ladderSteps,
      'quests': <JsonMap>[],
      'cardPacks': packs,
      'water': 0,
      'cardDraw': {
        'selectedCardId': null,
        'passedCardIds': <String>[],
        'deckStartIndex': Random().nextInt(packs.length),
      },
    };
    _save();
  }

  List<JsonMap> _cardPacks() => const DailyCardGenerator().cardPacks(
    today: today,
    steps: ladderSteps,
    pace: dailyPace == 'relaxed' ? 1 : (profile?['pace'] as num?)?.toInt() ?? 1,
    relaxed: dailyPace == 'relaxed',
    mobileThemes: _mobileRewardsEnabled,
    cameraAvailable: !cameraUnavailable,
    hour: now.hour,
    timedWorkouts: timedWorkouts,
    wellnessUat: profile != null,
    recentAttempts: {
      for (final category in ladderCategories(reduction: reduction))
        category: _ladderQuestsBefore(
          category,
          7,
          includePractice: profile != null,
        ).map((task) => task['day']).toSet().length,
    },
    lowImpact: profile?['lowImpact'] == true,
    reduction: reduction,
  );

  /// Rebuilds today's untouched cards after a ladder or path change.
  void _refreshDraft() {
    if (days[today] == null || hasCommittedDailyCard || uatProgramComplete) {
      return;
    }
    _data['days'][today]['cardPacks'] = _cardPacks();
  }

  bool _refreshMealDraft() {
    if (profile == null || hasCommittedDailyCard || uatProgramComplete) {
      return false;
    }
    final cards = dailyDrawCards;
    final expired = cards.any(
      (card) => ((card['tasks'] ?? []) as List).whereType<Map>().any(
        (task) =>
            task['ladder'] == 'Food' &&
            (task['photoWindows'] as List?)?.any(
                  (window) => (window[1] as num) <= now.hour,
                ) ==
                true,
      ),
    );
    if (!expired) return false;
    _data['days'][today]['cardPacks'] = const DailyCardGenerator()
        .refreshExpiredMeals(cards, today: today, hour: now.hour);
    return true;
  }

  /// Existing evidence belongs to this calendar day, even if the card was
  /// chosen later. Reward the newly completed tasks once, in one batch.
  void _applyRecordedWellnessEvidence() {
    final before = quests;
    var finished = false;
    final updated = [
      for (final task in before) {...task},
    ];
    for (final task in updated) {
      if (task['status'] == 'completed') continue;
      double ratio = 0;
      switch (task['activityKind']) {
        case 'water':
          final target = ((task['waterMl'] as num?)?.toDouble() ?? 250).clamp(
            1,
            4000,
          );
          ratio = water / target;
        case 'walk' || 'run':
          ratio = ActivityEvidence.workoutProgress(
            task,
            workoutSessions,
            today,
          );
        case 'meal_snap':
          final target = ((task['photoCount'] as num?)?.toInt() ?? 1).clamp(
            1,
            10,
          );
          ratio =
              ActivityEvidence.mealPhotosMatched(task, mealCheckIns, today) /
              target;
      }
      if (ratio >= 1) {
        task['status'] = 'completed';
        task['done'] = true;
        task['validationInvalidated'] = false;
        task.remove('partial');
        finished = true;
      } else if (ratio > 0) {
        task['partial'] = (ratio * 100).floor() / 100;
      }
    }
    _data['days'][today]['quests'] = updated;
    if (finished) _markActivity();
    _rewardCompletions(before);
  }

  /// Retire old timer drafts/open quests without rewriting completed history
  /// or earned XP. The category key stays compatible with saved snapshots.
  void _replaceRetiredDelayQuests() {
    JsonMap replace(Map raw) {
      final task = Map<String, dynamic>.from(raw);
      if (task['status'] == 'completed' ||
          (task['activityKind'] != 'delay' &&
              task['delayMinutes'] == null &&
              !(task['ladder'] == 'Reduction' &&
                  task['activityKind'] != 'habit_swap'))) {
        return task;
      }
      final rung = ladders['Reduction']!.first;
      return {
        ...task
          ..remove('delayMinutes')
          ..remove('partial')
          ..remove('validationInvalidated'),
        'title': rung.title,
        'description': rung.description,
        'category': 'Reduction',
        'activityKind': 'habit_swap',
        'durationMinutes': rung.durationMinutes,
        'difficulty': 1,
        if (task['ladder'] == 'Reduction') 'step': 1,
      };
    }

    JsonMap replaceCard(Map card) {
      if (card['tasks'] is! List) return replace(card);
      final tasks = [
        for (final task in (card['tasks'] as List).whereType<Map>())
          replace(task),
      ];
      return {
        ...card,
        'tasks': tasks,
        if (card['categories'] is List)
          'title': (card['categories'] as List)
              .map((category) => ladderLabels[category] ?? category)
              .join(' · '),
        'durationMinutes': tasks.fold<int>(
          0,
          (sum, task) =>
              sum + ((task['durationMinutes'] as num?)?.toInt() ?? 0),
        ),
      };
    }

    for (final entry in (_data['days'] as Map).entries) {
      if (entry.key.toString().compareTo(today) < 0 || entry.value is! Map) {
        continue;
      }
      final day = entry.value as Map;
      day['quests'] = [
        for (final task in (day['quests'] ?? const []) as List)
          if (task is Map) replace(task),
      ];
      for (final key in ['cardPacks', 'bonusCards']) {
        if (day[key] is! List) continue;
        day[key] = [
          for (final card in (day[key] as List).whereType<Map>())
            replaceCard(card),
        ];
      }
    }
    final entry = (_data['capacity'] as Map?)?['Reduction'];
    if (entry is Map && (entry['step'] != 1 || entry['offerStep'] != null)) {
      entry
        ..remove('offerStep')
        ..remove('acceptedOn')
        ..['step'] = 1
        ..['reviewedOn'] = today
        ..['change'] = 'hold'
        ..['reason'] = 'Habit Swap mengikuti aktivitas yang kamu pilih.';
    }
  }

  /// Open walk/run quests follow this device's method, whichever device drew
  /// the card: session time on the web app, GPS distance in the APK. The
  /// ladder step stays the same, so research ladder positions still match.
  void _matchWorkoutMethod() {
    final rungs = ladders['Body']!;
    JsonMap adapt(Map raw) {
      final task = Map<String, dynamic>.from(raw);
      final step = (task['step'] as num?)?.toInt();
      if (task['ladder'] != 'Body' ||
          !ActivityEvidence.isWorkout(task) ||
          step == null ||
          step < 1 ||
          step > rungs.length ||
          (task['status'] == 'completed' &&
              task['validationInvalidated'] != true)) {
        return task;
      }
      final rung = rungs[step - 1];
      final timed = rung.usesTimer(timed: timedWorkouts);
      return {
        ...task
          ..remove('targetMeters')
          ..remove('timed'),
        'title': rung.titleFor(timed: timed),
        'description': rung.descriptionFor(timed: timed),
        'durationMinutes': rung.minutesFor(timed: timed),
        if (timed) 'timed': true else 'targetMeters': ?rung.targetMeters,
      };
    }

    JsonMap adaptCard(Map card) {
      if (card['tasks'] is! List) return adapt(card);
      final tasks = [
        for (final task in (card['tasks'] as List).whereType<Map>())
          adapt(task),
      ];
      return {
        ...card,
        'tasks': tasks,
        'durationMinutes': tasks.fold<int>(
          0,
          (sum, task) =>
              sum + ((task['durationMinutes'] as num?)?.toInt() ?? 0),
        ),
        if (card.containsKey('activeMinutes'))
          'activeMinutes': const DailyCardGenerator().activeMinutes(tasks),
      };
    }

    for (final entry in (_data['days'] as Map).entries) {
      if (entry.key.toString().compareTo(today) < 0 || entry.value is! Map) {
        continue;
      }
      final day = entry.value as Map;
      day['quests'] = [
        for (final task in (day['quests'] ?? const []) as List)
          if (task is Map) adapt(task),
      ];
      for (final key in ['cardPacks', 'bonusCards']) {
        if (day[key] is! List) continue;
        day[key] = [
          for (final card in (day[key] as List).whereType<Map>())
            adaptCard(card),
        ];
      }
    }
  }

  void _reviewLadders() {
    if (uatProgramComplete) return;
    _reconcileActivityEvidence();
    final ladderState = (_data['capacity'] ??= <String, dynamic>{}) as Map;
    final pace = (profile?['pace'] as num?)?.toInt() ?? 1;
    final lowImpact = profile?['lowImpact'] == true;
    final inactive = _inactiveDays;
    for (final category in ladderCategories(reduction: reduction)) {
      final maxStep = ladderMax(
        category,
        lowImpact: lowImpact,
        wellnessUat: profile != null,
      );
      final entry = ladderState[category];
      if (entry is! Map) {
        final step = pace.clamp(1, maxStep);
        ladderState[category] = {
          'step': step,
          'reviewedOn': today,
          'change': 'start',
          'reason': 'Mulai dari anak tangga $step sesuai tempo pilihanmu.',
        };
        continue;
      }
      if (profile != null &&
          ((entry['step'] as num?)?.toInt() ?? 1) > maxStep) {
        entry['step'] = maxStep;
        entry.remove('offerStep');
        entry['reviewedOn'] = today;
        entry['reason'] =
            'Latihan disesuaikan dengan batas perjalanan 28 hari.';
      }
      // A clock set forward and back must not freeze reviews for days.
      if (_daysBetween(entry['reviewedOn'].toString(), today) < 0) {
        entry['reviewedOn'] = today;
      }
      final since = _daysBetween(entry['reviewedOn'].toString(), today);
      // The early welcome-back happens once; further quiet weeks keep the
      // regular 7-day cadence (CHALLENGE_SPEC §8).
      final welcomeBack =
          inactive >= 5 && since >= 5 && entry['change'] != 'rest';
      if (since < 7 && !welcomeBack) continue;
      final current = ((entry['step'] as num?)?.toInt() ?? 1).clamp(1, maxStep);
      final review = reviewLadder(
        category: category,
        current: current,
        maxStep: maxStep,
        weekQuests: _ladderQuestsBefore(
          category,
          7,
          step: profile != null ? current : null,
        ),
        inactiveDays: inactive,
      );
      final offered = review.change == 'up';
      ladderState[category] = {
        if (profile != null) ...entry,
        'step': offered ? current : review.step,
        'reviewedOn': today,
        'change': review.change,
        'reason': review.reason,
      };
      // A new review always replaces the previous offer.
      ladderState[category].remove('offerStep');
      if (offered) ladderState[category]['offerStep'] = review.step;
    }
  }

  /// Ladder quests the user committed to in the [period] days before today.
  List<JsonMap> _ladderQuestsBefore(
    String category,
    int period, {
    String? before,
    int? step,
    bool includePractice = false,
  }) {
    final end = before ?? today;
    final start = shiftDayKey(end, -period);
    return [
      for (final entry in days.entries)
        if (entry.key.compareTo(start) >= 0 && entry.key.compareTo(end) < 0)
          for (final task
              in ((entry.value as Map)['quests'] ?? const []) as List)
            if (task is Map &&
                task['ladder'] == category &&
                (step == null || task['step'] == step) &&
                (includePractice || task['practiceOnly'] != true) &&
                task['validationInvalidated'] != true)
              {...Map<String, dynamic>.from(task), 'day': entry.key},
    ];
  }

  /// Full days without a finished quest before today.
  int get _inactiveDays {
    final before = activeDays.where((day) => day.compareTo(today) < 0);
    final started = profile?['started']?.toString() ?? today;
    if (before.isEmpty) return _daysBetween(started, today);
    return _daysBetween(before.last, today) - 1;
  }

  int _daysBetween(String from, String to) => daysBetweenKeys(from, to);

  void acceptLadderStep(String category) {
    if (uatProgramComplete) return;
    if (profile != null) _refreshPendingLadderOffers();
    final entry = capacity[category];
    final offer = (entry?['offerStep'] as num?)?.toInt();
    if (entry == null || offer == null) return;
    _data['capacity'][category] = {
      ...entry..remove('offerStep'),
      'step': offer,
      'change': 'up',
      'acceptedOn': today,
      // Start a fresh evidence week at acceptance, including late acceptance.
      if (profile != null) 'reviewedOn': today,
    };
    if (_mobileRewardsEnabled) {
      _moments.add(
        RewardMoment(
          serial: ++rewardSerial,
          ladder: '${ladderLabels[category] ?? category}: anak tangga $offer',
          badges: _claimAchievements(),
        ),
      );
    }
    _refreshDraft();
    _save();
  }

  void declineLadderStep(String category) {
    final entry = capacity[category];
    if (entry == null || entry['offerStep'] == null) return;
    _data['capacity'][category] = {
      ...entry..remove('offerStep'),
      'change': 'hold',
      'reason': 'Tetap di level ini sesuai pilihanmu.',
    };
    _save();
  }

  /// Kept as a semantic entry point for both existing web and mobile UI.
  void drawDailyCards() => prepareToday();

  bool selectDailyCard(String id) {
    if (uatProgramComplete) return false;
    if (profile != null) prepareToday();
    if (hasCommittedDailyCard ||
        passedDailyCardIds.contains(id) ||
        !dailyDrawCards.any((card) => card['id'] == id)) {
      return false;
    }
    _writeDraw({...?dailyCardDraw, 'selectedCardId': id});
    return true;
  }

  bool chooseAnotherDailyCard() {
    if (uatProgramComplete) return false;
    if (!canChooseAnotherDailyCard) return false;
    final passed = [...passedDailyCardIds, selectedDailyCardId!];
    final choices = dailyDrawCards
        .where((card) => !passed.contains(card['id']))
        .toList();
    final next = choices.isEmpty
        ? null
        : choices[Random().nextInt(choices.length)];
    _writeDraw({
      ...?dailyCardDraw,
      'selectedCardId': null,
      'passedCardIds': passed,
      'deckStartIndex': next == null
          ? 0
          : dailyDrawCards.indexWhere((card) => card['id'] == next['id']),
    });
    return true;
  }

  bool commitDailyCardPack() {
    if (uatProgramComplete) return false;
    final beforeRefresh = selectedDailyCard;
    final mealRefreshed = _refreshMealDraft();
    if (mealRefreshed &&
        beforeRefresh != null &&
        jsonEncode(beforeRefresh['tasks']) !=
            jsonEncode(selectedDailyCard?['tasks'])) {
      // A deadline passed after reveal: show the replacement before consent.
      _save();
      return false;
    }
    final card = selectedDailyCard;
    if (card == null || hasCommittedDailyCard) return false;
    final packTasks = card['tasks'] is List
        ? (card['tasks'] as List)
              .whereType<Map>()
              .map((task) => Map<String, dynamic>.from(task))
              .toList()
        : [card]; // A committed legacy draft may still contain one task.
    if (packTasks.isEmpty) return false;
    final tasks = [
      ...quests,
      for (final task in packTasks)
        {...task, 'status': 'committed', 'done': false},
    ];
    _data['days'][today]['quests'] = tasks;
    _data['days'][today]['cardDraw'] = {
      ...?dailyCardDraw,
      'committedCardId': card['id'],
    };
    if (profile != null) _applyRecordedWellnessEvidence();
    if (reduction) _applyHabitSwapEvidence();
    _save();
    return true;
  }

  void _writeDraw(JsonMap draw) {
    _data['days'][today]['cardDraw'] = draw;
    _save();
  }

  bool completeCard(String id) {
    if (uatProgramComplete) return false;
    final tasks = quests;
    final before = quests;
    final index = tasks.indexWhere((task) => task['id'] == id);
    if (index < 0 || tasks[index]['status'] == 'completed') return false;
    tasks[index] = {...tasks[index], 'status': 'completed', 'done': true};
    _data['days'][today]['quests'] = tasks;
    _markActivity();
    _rewardCompletions(before);
    _save();
    return true;
  }

  void addWater() {
    if (uatProgramComplete) return;
    prepareToday();
    _markActivity();
    _data['days'][today]['water'] = (water + 250).clamp(0, 4000);
    _completeWhere(
      (task) =>
          task['activityKind'] == 'water' &&
          water >= ((task['waterMl'] as num?)?.toInt() ?? 0),
    );
    if (_mobileRewardsEnabled) _claimAchievements();
    _save();
  }

  /// An unfinished walk/run (kind, banked seconds, start, meters, heartbeat)
  /// kept on this device only, so closing the app does not lose the session.
  JsonMap? get workoutDraft => _data['workoutDraft'] is Map
      ? Map<String, dynamic>.from(_data['workoutDraft'])
      : null;

  void saveWorkoutDraft(JsonMap? draft) {
    if (draft == null && _data['workoutDraft'] == null) return;
    _data['workoutDraft'] = draft;
    _save();
  }

  /// Logs only meters and seconds, then checks walk/run quests against them.
  /// [startedOn] is the day the session began: a walk that runs past
  /// midnight counts for that day's card, not the new day's.
  WorkoutResult recordWorkout({
    required String kind,
    required int seconds,
    required int meters,
    String? startedOn,
  }) {
    final day =
        startedOn != null &&
            DateTime.tryParse(startedOn) != null &&
            startedOn.compareTo(today) < 0
        ? startedOn
        : today;
    final programEnded = day == today
        ? uatProgramComplete
        : profile == null ||
              WellnessUatProgram(
                started: profile?['started']?.toString() ?? day,
                now: DateTime.parse(day),
              ).complete;
    if (programEnded) return const WorkoutResult();
    if (seconds < 1) return const WorkoutResult();
    // Just after midnight the day may not exist until the next tick.
    prepareToday();
    final kmPerHour = meters / seconds * 3.6;
    final tooFast = kmPerHour > maxWalkRunKmPerHour;
    _add('workoutSessions', {
      'kind': kind,
      'seconds': seconds,
      'meters': meters,
      if (tooFast) 'countsForQuest': false,
    }, day: day);
    if (tooFast) return const WorkoutResult(tooFast: true);
    final completed = <String>[], partial = <String>[];
    final before = _questsOn(day);
    final tasks = _questsOn(day);
    for (final (index, task) in tasks.indexed) {
      if (task['status'] == 'completed' &&
          task['validationInvalidated'] != true) {
        continue;
      }
      final activity = task['activityKind'];
      if (!(activity == 'walk' && (kind == 'walk' || kind == 'run') ||
          activity == 'run' && kind == 'run')) {
        continue;
      }
      final ratio = ActivityEvidence.workoutProgress(
        task,
        workoutSessions,
        day,
      );
      if (ratio >= 1) {
        completed.add(task['title'].toString());
        tasks[index] = {
          ...task,
          'status': 'completed',
          'done': true,
          'validationInvalidated': false,
        };
      } else if (ratio > 0) {
        partial.add(task['title'].toString());
        final best = max(ratio, (task['partial'] as num?)?.toDouble() ?? 0);
        tasks[index] = {
          ...task,
          'partial': (best * 100).floor() / 100,
          if (task['status'] != 'completed') 'validationInvalidated': false,
        };
      }
    }
    if (days[day] is Map) _data['days'][day]['quests'] = tasks;
    _rewardCompletions(before, day: day);
    _save();
    return WorkoutResult(completed: completed, partial: partial);
  }

  void recordMeal({
    String? photoPath,
    bool photoCaptured = false,
    String note = '',
  }) {
    if (uatProgramComplete) return;
    final hasPhotoEvidence = photoPath != null || photoCaptured;
    if (!hasPhotoEvidence && note.trim().isEmpty) return;
    prepareToday();
    _add('mealCheckIns', {
      if (photoPath != null) 'photoPath': photoPath,
      if (hasPhotoEvidence) 'photoCaptured': true,
      'note': note.trim(),
    });
    _reconcileActivityEvidence(day: today);
    // A note is a journal entry; only a camera photo finishes the quest (§7).
    if (!hasPhotoEvidence) return;
    _applyMealPhotos();
  }

  /// Completes meal quests whose photo count (and time windows) are met,
  /// and shows the rest as partial, e.g. 1 of 2 photos.
  void _applyMealPhotos() {
    final tasks = quests;
    final finished = <String>[];
    for (final (index, task) in tasks.indexed) {
      if (task['activityKind'] != 'meal_snap' ||
          task['status'] == 'completed') {
        continue;
      }
      final required = (task['photoCount'] as num?)?.toInt() ?? 1;
      final matched = ActivityEvidence.mealPhotosMatched(
        task,
        mealCheckIns,
        today,
      );
      if (matched >= required) {
        finished.add(task['id'].toString());
      } else if (matched > 0) {
        tasks[index] = {...task, 'partial': matched / required};
      }
    }
    _data['days'][today]['quests'] = tasks;
    for (final id in finished) {
      completeCard(id);
    }
    _save();
  }

  void recordFocusSession(JsonMap value) => _add('focusSessions', value);

  bool get cameraUnavailable => _data['cameraUnavailable'] == true;

  /// Camera denied or missing: photo quests become check-off equivalents,
  /// both in today's open quests and in cards drawn from now on (§7).
  void markCameraUnavailable() {
    if (cameraUnavailable) return;
    _data['cameraUnavailable'] = true;
    if (days[today] is Map) {
      _data['days'][today]['quests'] = [
        for (final task in quests)
          if (task['activityKind'] != 'meal_snap' ||
              task['status'] == 'completed')
            task
          else if (task['ladder'] != null)
            // Keep the ladder step; it is simply checked off now.
            ({...task}
              ..remove('activityKind')
              ..remove('photoCount')
              ..remove('photoWindows'))
          else
            ({...task, ..._photoFreeMealQuest}..remove('activityKind')),
      ];
    }
    _refreshDraft();
    _save();
  }

  void _completeWhere(bool Function(JsonMap task) test) {
    for (final task in quests) {
      if (test(task) && task['status'] != 'completed') {
        completeCard(task['id'].toString());
      }
    }
  }

  /// A local fixture for reviewing the moderator UI before the backend exists.
  void addModerationPreviewPost() {
    if (!AppEnvironment.showPreviewTools) return;
    _add('communityPosts', {
      'alias': 'contohpeserta',
      'text':
          'Hari ini aku menyelesaikan satu langkah kecil. Ini contoh post untuk pratinjau moderasi.',
      'status': 'pending',
      'moderationNote': '',
      'sample': true,
    });
  }

  void submitCommunityPost(String text) {
    final clean = text.trim();
    if (clean.length < 3 || clean.length > maxCommunityPostLength) {
      throw ArgumentError('Post harus 3–$maxCommunityPostLength karakter.');
    }
    _add('communityPosts', {
      'alias': profile?['alias'] ?? 'anonymous',
      'text': clean,
      'status': 'pending',
      'moderationNote': '',
    });
  }

  void moderateCommunityPost(String id, String status, {String note = ''}) {
    if (!const {'approved', 'rejected'}.contains(status)) return;
    for (final post in _data['communityPosts'] as List) {
      if (post['id'] == id) {
        post['status'] = status;
        post['moderationNote'] = note.trim();
        post['reviewedAt'] = now.toIso8601String();
      }
    }
    _save();
  }

  bool hasCommunityReaction(String postId, String reaction) =>
      (_data['communityReactions'] as List).any(
        (row) => row['postId'] == postId && row['reaction'] == reaction,
      );

  /// One reaction per post, matching the reactions(post_id, user_id) key.
  void reactToCommunityPost(String postId, String reaction) {
    final rows = _data['communityReactions'] as List;
    final wasActive = hasCommunityReaction(postId, reaction);
    rows.removeWhere((row) => row['postId'] == postId);
    if (!wasActive) rows.add({'postId': postId, 'reaction': reaction});
    _save();
  }

  /// Sets or clears (null) this device's single reaction on a post.
  void setCommunityReaction(String postId, String? reaction) {
    final rows = _data['communityReactions'] as List;
    rows.removeWhere((row) => row['postId'] == postId);
    if (reaction != null) rows.add({'postId': postId, 'reaction': reaction});
    _save();
  }

  bool hasReportedCommunityPost(String postId) =>
      communityReports.any((report) => report['postId'] == postId);

  /// Returns false when this post was already reported.
  bool reportCommunityPost(String postId, String reason) {
    if (hasReportedCommunityPost(postId)) return false;
    _add('communityReports', {'postId': postId, 'reason': reason});
    return true;
  }

  /// Own posts only; seed examples and other aliases stay.
  void deleteCommunityPost(String id) {
    final posts = _data['communityPosts'] as List;
    final count = posts.length;
    posts.removeWhere(
      (post) =>
          post['id'] == id &&
          post['sample'] != true &&
          post['alias'] == profile?['alias'],
    );
    if (posts.length == count) return;
    (_data['communityReactions'] as List).removeWhere(
      (row) => row['postId'] == id,
    );
    (_data['communityReports'] as List).removeWhere(
      (row) => row['postId'] == id,
    );
    _save();
  }

  void resolveCommunityReport(String id) {
    (_data['communityReports'] as List).removeWhere((row) => row['id'] == id);
    _save();
  }

  void _add(String key, JsonMap value, {String? day}) {
    (_data[key] as List).add({
      ...value,
      'id': '${now.microsecondsSinceEpoch}-${Random().nextInt(9999)}',
      'day': day ?? today,
      'time': now.toIso8601String(),
    });
    if (const {
      'focusSessions',
      'habitDelays',
      'habitSwaps',
      'workoutSessions',
      'mealCheckIns',
    }.contains(key)) {
      _markActivity(day);
      if (_mobileRewardsEnabled) {
        final badges = _claimAchievements();
        if (badges.isNotEmpty) {
          _moments.add(RewardMoment(serial: ++rewardSerial, badges: badges));
        }
      }
    }
    _save();
  }

  /// Reduction logs stay on this device for now. Ask for consent again
  /// before they are ever synced (see CLAUDE.md §2, §6).
  void switchPath(bool enabled) {
    _data['profile']['path'] = enabled ? 'reduction' : 'wellness';
    _reviewLadders();
    _refreshDraft();
    _save();
  }

  void setLowImpact(bool enabled) {
    _data['profile']['lowImpact'] = enabled;
    final body = capacity['Body'];
    if (enabled && body != null) {
      final step = (body['step'] as num?)?.toInt() ?? 1;
      _data['capacity']['Body'] = {
        ...body..remove('offerStep'),
        'step': min(step, lowImpactBodyMax),
      };
    }
    _refreshDraft();
    _save();
  }

  String export() {
    final copy = jsonDecode(jsonEncode(_data)) as JsonMap;
    for (final row in copy['mealCheckIns'] as List) {
      if (row is Map) row.remove('photoPath');
    }
    return const JsonEncoder.withIndent('  ').convert(copy);
  }

  /// Only notes can be edited: measured timer/GPS data is immutable.
  bool editActivity(String collection, String id, {String? note}) {
    if (!const {'mealCheckIns', 'workoutSessions'}.contains(collection)) {
      return false;
    }
    final rows = _data[collection] as List;
    final index = rows.indexWhere((row) => row['id'] == id);
    if (index < 0 || note == null || note.trim().length > 200) return false;
    rows[index] = {
      ...rows[index] as Map,
      'note': note.trim(),
      'noteEditedAt': now.toIso8601String(),
    };
    _save();
    return true;
  }

  bool deleteActivity(String collection, String id) {
    if (!const {'mealCheckIns', 'workoutSessions'}.contains(collection)) {
      return false;
    }
    final rows = _data[collection] as List;
    final row = rows.where((row) => row['id'] == id).firstOrNull;
    if (row == null) return false;
    final day = row['day']?.toString();
    final count = rows.length;
    rows.removeWhere((row) => row['id'] == id);
    if (rows.length == count) return false;
    _reconcileActivityEvidence(day: day);
    _refreshPendingLadderOffers();
    _save();
    return true;
  }

  /// Keep XP/status intact while separating unsupported claims from evidence.
  /// Also handles older snapshots with manually corrected metrics or deletions.
  void _reconcileActivityEvidence({String? day}) {
    final sessionsByDay = <String, List<JsonMap>>{};
    for (final session in workoutSessions) {
      final loggedDay = session['day']?.toString();
      if (loggedDay == null || day != null && loggedDay != day) continue;
      (sessionsByDay[loggedDay] ??= []).add(session);
    }
    final mealDays = mealCheckIns.map((row) => row['day']).toSet();
    for (final entry in days.entries) {
      if (day != null && entry.key != day) continue;
      final value = entry.value;
      if (value is! Map || value['quests'] is! List) continue;
      final tasks = value['quests'] as List;
      for (final raw in tasks.whereType<Map>()) {
        final task = Map<String, dynamic>.from(raw);
        final completed = task['status'] == 'completed';
        if (ActivityEvidence.isWorkout(task)) {
          final ratio = ActivityEvidence.workoutProgress(
            task,
            sessionsByDay[entry.key] ?? const [],
            entry.key,
          );
          if (completed) {
            raw['validationInvalidated'] = ratio < 1;
          } else if (task['partial'] is num ||
              task['validationInvalidated'] == true) {
            raw['validationInvalidated'] = ratio <= 0;
            raw['partial'] = ((ratio.clamp(0, .99) * 100).floor()) / 100;
          }
        } else if (completed && task['activityKind'] == 'meal_snap') {
          raw['validationInvalidated'] =
              !mealDays.contains(entry.key) ||
              ActivityEvidence.mealPhotosMatched(
                    task,
                    mealCheckIns,
                    entry.key,
                  ) <
                  ((task['photoCount'] as num?)?.toInt() ?? 1);
        }
      }
    }
  }

  /// Pending offers must not be accepted on evidence that has been removed.
  /// Accepted steps stay earned; normal future reviews decide the next step.
  void _refreshPendingLadderOffers() {
    for (final category in ladderOffers) {
      final entry = capacity[category]!;
      final current = (entry['step'] as num).toInt();
      final review = reviewLadder(
        category: category,
        current: current,
        maxStep: ladderMaximum(category),
        weekQuests: _ladderQuestsBefore(
          category,
          7,
          before: entry['reviewedOn']?.toString() ?? today,
          step: profile != null ? current : null,
        ),
        inactiveDays: 0,
      );
      final updated = {...entry};
      if (review.change == 'up') {
        updated['reason'] = review.reason;
      } else {
        updated.remove('offerStep');
        updated['change'] = 'hold';
        updated['reason'] =
            'Bukti sesi diperbarui. Anak tangga tetap sampai peninjauan berikutnya.';
      }
      _data['capacity'][category] = updated;
    }
  }

  Future<void> reset() async {
    _data = createEmptyWellnessState();
    _moments.clear();
    await _save();
  }
}

const _photoFreeMealQuest = {
  'catalogId': 'fruit-veg',
  'title': 'Tambahkan buah atau sayur',
  'description': 'Satu porsi di salah satu makanmu hari ini.',
};

/// Above this average speed a session was most likely in a vehicle.
const maxWalkRunKmPerHour = 20.0;

class WorkoutResult {
  const WorkoutResult({
    this.completed = const [],
    this.partial = const [],
    this.tooFast = false,
  });
  final List<String> completed, partial;
  final bool tooFast;
}

/// Example posts, flagged so the Wall can label them as "contoh".
final List<JsonMap> _seedCommunityPosts = [
  {
    'id': 'seed-water',
    'alias': 'daunpagi',
    'text': 'Hari ini berhasil memenuhi target minum air. Small win!',
    'status': 'approved',
    'sample': true,
    'time': '2026-09-20T08:00:00.000',
  },
  {
    'id': 'seed-walk',
    'alias': 'awanbiru',
    'text': 'Jalan santai sepuluh menit ternyata bikin energi balik lagi.',
    'status': 'approved',
    'sample': true,
    'time': '2026-09-20T07:00:00.000',
  },
];

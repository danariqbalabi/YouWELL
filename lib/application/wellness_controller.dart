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
import 'package:youwell/features/companion/domain/companion_rewards.dart';

part 'wellness_gamification.dart';

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
        if (wellnessUat &&
            DateTime.tryParse(profile?['started']?.toString() ?? '') == null) {
          _data['profile']['started'] = today;
        }
        // Snapshots from the flat 100-XP curve keep the level they showed.
        if (_data['profile'] != null && _data['levelFloor'] == null) {
          _data['levelFloor'] = legacyLevelForXp(xp);
        }
      } catch (_) {
        storageError =
            'Preview lokal lama direset untuk memakai versi terbaru.';
      }
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
  WellnessUatProgram? get wellnessProgram => wellnessUat
      ? WellnessUatProgram(
          started: profile?['started']?.toString() ?? today,
          now: now,
        )
      : null;
  bool get wellnessProgramComplete => wellnessProgram?.complete == true;
  int ladderMaximum(String category) => ladderMax(
    category,
    lowImpact: profile?['lowImpact'] == true,
    wellnessUat: wellnessUat,
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

  List<JsonMap> get quests => ((days[today]?['quests'] ?? const []) as List)
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
    if (!wellnessUat || wellnessProgramComplete) return false;
    prepareToday();
    final card = recommendedDailyCard;
    return card != null && selectDailyCard(card['id'].toString());
  }

  bool get hasCommittedDailyCard => dailyCardDraw?['committedCardId'] != null;
  bool get needsDailyCardDraw =>
      profile != null && !wellnessProgramComplete && !hasCommittedDailyCard;
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
      !wellnessProgramComplete &&
      coreComplete &&
      days[today]?['bonusDrawn'] != true;

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
      wellnessUat: wellnessUat,
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

  /// Only full timers count as a finished delay; partial ones stay in the log.
  int get delayedToday => habitDelays
      .where((row) => row['day'] == today && row['completed'] != false)
      .length;
  int get habitSwapsToday =>
      habitSwaps.where((row) => row['day'] == today).length;
  List<String> get openedDays =>
      ((_data['openedDays'] ?? const []) as List).cast<String>();

  /// Ladder state per category: step, offered step, and the last reason.
  Map<String, JsonMap> get capacity => {
    for (final entry in ((_data['capacity'] ?? const {}) as Map).entries)
      entry.key.toString(): Map<String, dynamic>.from(entry.value as Map),
  };
  Map<String, int> get ladderSteps => {
    for (final entry in capacity.entries)
      entry.key: (entry.value['step'] as num?)?.toInt() ?? 1,
  };
  List<String> get ladderOffers => wellnessProgramComplete
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
      'waterGoal': value['waterGoal'] ?? profile?['waterGoal'] ?? 2000,
    };
    prepareToday();
    await _save();
  }

  void prepareToday() {
    if (profile == null) return;
    final opened = (_data['openedDays'] ??= <dynamic>[]) as List;
    final firstOpenToday = !opened.contains(today);
    if (firstOpenToday) opened.add(today);
    if (wellnessProgramComplete) {
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
    wellnessUat: wellnessUat,
    recentAttempts: {
      for (final category in ladderCategories(reduction: reduction))
        category: _ladderQuestsBefore(
          category,
          7,
          includePractice: wellnessUat,
        ).map((task) => task['day']).toSet().length,
    },
    lowImpact: profile?['lowImpact'] == true,
    reduction: reduction,
  );

  /// Rebuilds today's untouched cards after a ladder or path change.
  void _refreshDraft() {
    if (days[today] == null ||
        hasCommittedDailyCard ||
        wellnessProgramComplete) {
      return;
    }
    _data['days'][today]['cardPacks'] = _cardPacks();
  }

  bool _refreshMealDraft() {
    if (!wellnessUat || hasCommittedDailyCard || wellnessProgramComplete) {
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

  void _reviewLadders() {
    if (wellnessProgramComplete) return;
    _reconcileActivityEvidence();
    final ladderState = (_data['capacity'] ??= <String, dynamic>{}) as Map;
    final pace = (profile?['pace'] as num?)?.toInt() ?? 1;
    final lowImpact = profile?['lowImpact'] == true;
    final inactive = _inactiveDays;
    for (final category in ladderCategories(reduction: reduction)) {
      final maxStep = ladderMax(
        category,
        lowImpact: lowImpact,
        wellnessUat: wellnessUat,
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
      if (wellnessUat && ((entry['step'] as num?)?.toInt() ?? 1) > maxStep) {
        entry['step'] = maxStep;
        entry.remove('offerStep');
        entry['reviewedOn'] = today;
        entry['reason'] =
            'Latihan disesuaikan dengan batas perjalanan 28 hari.';
      }
      final since = _daysBetween(entry['reviewedOn'].toString(), today);
      if (since < 7 && !(inactive >= 5 && since >= 5)) continue;
      final current = ((entry['step'] as num?)?.toInt() ?? 1).clamp(1, maxStep);
      final review = reviewLadder(
        category: category,
        current: current,
        maxStep: maxStep,
        weekQuests: _ladderQuestsBefore(
          category,
          7,
          step: wellnessUat ? current : null,
        ),
        inactiveDays: inactive,
      );
      final offered = review.change == 'up';
      ladderState[category] = {
        if (wellnessUat) ...entry,
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
    final start = dayKey(DateTime.parse(end).subtract(Duration(days: period)));
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

  int _daysBetween(String from, String to) =>
      DateTime.parse(to).difference(DateTime.parse(from)).inDays;

  void acceptLadderStep(String category) {
    if (wellnessProgramComplete) return;
    if (wellnessUat) _refreshPendingLadderOffers();
    final entry = capacity[category];
    final offer = (entry?['offerStep'] as num?)?.toInt();
    if (entry == null || offer == null) return;
    _data['capacity'][category] = {
      ...entry..remove('offerStep'),
      'step': offer,
      'change': 'up',
      'acceptedOn': today,
      // Start a fresh evidence week at acceptance, including late acceptance.
      if (wellnessUat) 'reviewedOn': today,
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
    if (wellnessProgramComplete) return false;
    if (wellnessUat) prepareToday();
    if (hasCommittedDailyCard ||
        passedDailyCardIds.contains(id) ||
        !dailyDrawCards.any((card) => card['id'] == id)) {
      return false;
    }
    _writeDraw({...?dailyCardDraw, 'selectedCardId': id});
    return true;
  }

  bool chooseAnotherDailyCard() {
    if (wellnessProgramComplete) return false;
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
    if (wellnessProgramComplete) return false;
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
    if (wellnessUat) _applyRecordedWellnessEvidence();
    _save();
    return true;
  }

  void _writeDraw(JsonMap draw) {
    _data['days'][today]['cardDraw'] = draw;
    _save();
  }

  bool completeCard(String id) {
    if (wellnessProgramComplete) return false;
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
    if (wellnessProgramComplete) return;
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

  /// Logs only meters and seconds, then checks walk/run quests against them.
  WorkoutResult recordWorkout({
    required String kind,
    required int seconds,
    required int meters,
  }) {
    if (wellnessProgramComplete) return const WorkoutResult();
    if (seconds < 1) return const WorkoutResult();
    final kmPerHour = meters / seconds * 3.6;
    final tooFast = kmPerHour > maxWalkRunKmPerHour;
    _add('workoutSessions', {
      'kind': kind,
      'seconds': seconds,
      'meters': meters,
      if (tooFast) 'countsForQuest': false,
    });
    if (tooFast) return const WorkoutResult(tooFast: true);
    final completed = <String>[], partial = <String>[];
    final before = quests;
    final tasks = quests;
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
        today,
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
    _data['days'][today]['quests'] = tasks;
    _rewardCompletions(before);
    _save();
    return WorkoutResult(completed: completed, partial: partial);
  }

  void recordMeal({
    String? photoPath,
    bool photoCaptured = false,
    String note = '',
  }) {
    if (wellnessProgramComplete) return;
    final hasPhotoEvidence = photoPath != null || photoCaptured;
    if (!hasPhotoEvidence && note.trim().isEmpty) return;
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

  /// A stopped timer is logged as "ditunda X menit", never as a miss.
  void recordHabitDelay({
    int minutes = 5,
    int plannedMinutes = 5,
    bool completed = true,
  }) {
    _add('habitDelays', {
      'minutes': minutes,
      'plannedMinutes': plannedMinutes,
      'completed': completed,
    });
    if (completed) {
      _completeWhere(
        (task) =>
            task['activityKind'] == 'delay' &&
            plannedMinutes >= ((task['delayMinutes'] as num?)?.toInt() ?? 5),
      );
    }
  }

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

  /// Minutes until another Habit Swap can be logged (one per craving moment).
  int get habitSwapCooldownMinutes {
    if (habitSwaps.isEmpty) return 0;
    final last = DateTime.tryParse(habitSwaps.last['time'].toString());
    if (last == null) return 0;
    final left = habitSwapCooldown - now.difference(last);
    return left.inMicroseconds <= 0
        ? 0
        : (left.inMicroseconds / Duration.microsecondsPerMinute).ceil();
  }

  /// Habit Swap stays self-reported; logging one also ticks its quest.
  bool recordHabitSwap(String swap) {
    if (habitSwapCooldownMinutes > 0) return false;
    _add('habitSwaps', {'swap': swap});
    _completeWhere((task) => task['activityKind'] == 'habit_swap');
    return true;
  }

  /// Minutes of the Delay Craving timer for today's ladder quest.
  int get delayTargetMinutes {
    for (final task in quests) {
      if (task['activityKind'] == 'delay' && task['status'] != 'completed') {
        return (task['delayMinutes'] as num?)?.toInt() ?? 5;
      }
    }
    final step = ladderSteps['Reduction'] ?? 2;
    return ladders['Reduction']![(step - 1).clamp(0, 3)].delayMinutes ?? 5;
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

  bool hasReportedCommunityPost(String postId) =>
      communityReports.any((report) => report['postId'] == postId);

  /// Returns false when this post was already reported.
  bool reportCommunityPost(String postId, String reason) {
    if (hasReportedCommunityPost(postId)) return false;
    _add('communityReports', {'postId': postId, 'reason': reason});
    return true;
  }

  void resolveCommunityReport(String id) {
    (_data['communityReports'] as List).removeWhere((row) => row['id'] == id);
    _save();
  }

  void _add(String key, JsonMap value) {
    (_data[key] as List).add({
      ...value,
      'id': '${now.microsecondsSinceEpoch}-${Random().nextInt(9999)}',
      'day': today,
      'time': now.toIso8601String(),
    });
    if (const {
      'focusSessions',
      'habitDelays',
      'habitSwaps',
      'workoutSessions',
      'mealCheckIns',
    }.contains(key)) {
      _markActivity();
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

  JsonMap? get researchParticipation => _data['researchParticipation'] is Map
      ? Map<String, dynamic>.from(_data['researchParticipation'])
      : null;

  void setResearchParticipation(String? code, {required bool consent}) {
    if (consent &&
        (code == null || !RegExp(r'^P(?:[1-9]|10)$').hasMatch(code))) {
      throw ArgumentError('Pilih kode P1–P10.');
    }
    _data['researchParticipation'] = consent
        ? {'code': code, 'consentedOn': today}
        : null;
    _save();
  }

  String exportResearchSummary() {
    if (researchParticipation == null) {
      throw StateError('Persetujuan ringkasan diperlukan.');
    }
    return const JsonEncoder.withIndent('  ').convert({
      'schema_version': 2,
      'participant_code': researchParticipation!['code'],
      'weeks': [
        for (var week = 1; week <= 4; week++) researchSummary(week).toJson(),
      ],
    });
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
          step: wellnessUat ? current : null,
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

const maxCommunityPostLength = 280;
const _photoFreeMealQuest = {
  'catalogId': 'fruit-veg',
  'title': 'Tambahkan buah atau sayur',
  'description': 'Satu porsi di salah satu makanmu hari ini.',
};
const habitSwapCooldown = Duration(minutes: 10);

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

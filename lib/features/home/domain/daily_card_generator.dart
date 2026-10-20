import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/home/domain/quest_ladder.dart';

/// Explainable, rule-based daily cards (CHALLENGE_SPEC §4).
///
/// Each of the five cards holds ladder quests from a different mix of
/// categories (3 random healthy categories, or Habit Swap + 2 for the
/// smoking/vaping path), plus 0–2 light side quests, so cards carry 3, 3, 4,
/// 4 and 5 missions. Categories done least this week appear on most cards.
class DailyCardGenerator {
  const DailyCardGenerator();

  /// Card sizes for a normal day; a relaxed day only offers 3-mission cards.
  static const sizes = [3, 3, 4, 4, 5];

  List<JsonMap> cardPacks({
    required String today,
    required Map<String, int> steps,
    required int pace,
    required bool lowImpact,
    required bool reduction,
    bool relaxed = false,
    bool mobileThemes = false,
    bool cameraAvailable = true,
    int hour = 0,
    Map<String, int> recentAttempts = const {},
    bool timedWorkouts = false,
    bool wellnessUat = false,
  }) {
    final combos = _combos(today, reduction, recentAttempts);
    final order = [...sizes]
      ..sort((a, b) => _score('$a', today).compareTo(_score('$b', today)));
    if (wellnessUat) _shuffle(order, '$today:wellness-sizes');
    final cardSizes = relaxed ? List.filled(sizes.length, 3) : order;
    // Tempo only recommends a card; any card can still be taken.
    final recommendedSize = relaxed ? 3 : (pace + 2).clamp(3, 5);
    final cards = List.generate(sizes.length, (index) {
      final categories = combos[index % combos.length];
      final ladderTasks = [
        for (final category in categories)
          _ladderTask(
            category,
            ((steps[category] ?? 1) - (relaxed ? 1 : 0)).clamp(
              1,
              ladderMax(
                category,
                lowImpact: lowImpact,
                wellnessUat: wellnessUat,
              ),
            ),
            today,
            index,
            hour: hour,
            cameraAvailable: cameraAvailable,
            practice: relaxed,
            timedWorkouts: timedWorkouts,
          ),
      ];
      final sides = _sideQuests(
        count: cardSizes[index] - ladderTasks.length,
        categories: categories,
        reduction: reduction,
        cameraAvailable: cameraAvailable,
        salt: '$today:$index',
        hour: hour,
        wellnessUat: wellnessUat,
      );
      final tasks = [
        ...ladderTasks,
        for (final (sideIndex, task) in sides.indexed)
          {
            ..._toMap(task, today, 'card-$index-side-$sideIndex'),
            if (mobileThemes) 'xp': 20,
          },
      ];
      return {
        'id': '$today-card-$index',
        'title': categories.map((c) => ladderLabels[c] ?? c).join(' · '),
        'categories': categories,
        'cardStyle': index,
        'size': tasks.length,
        // 1 Ringan · 2 Sedang · 3 Penuh, from the number of missions.
        'difficulty': (tasks.length - 2).clamp(1, 3),
        'tasks': tasks,
        'xp': tasks.fold<int>(0, (sum, task) => sum + (task['xp'] as int)),
        'durationMinutes': tasks.fold<int>(
          0,
          (sum, task) => sum + (task['durationMinutes'] as int),
        ),
        if (wellnessUat) 'activeMinutes': activeMinutes(tasks),
        if (wellnessUat)
          'categoryUsage': categories.fold<int>(
            0,
            (sum, category) => sum + (recentAttempts[category] ?? 0),
          ),
      };
    });
    // Tempo sets the recommended size. Balance practice before preferring
    // lower active effort, so the easiest category mix cannot dominate.
    final candidates = cards
        .where((card) => card['size'] == recommendedSize)
        .toList();
    if (wellnessUat) {
      candidates.sort((a, b) {
        final byPractice = (a['categoryUsage'] as int).compareTo(
          b['categoryUsage'] as int,
        );
        if (byPractice == 0 && reduction) {
          final movementA = (a['categories'] as List).contains('Body') ? 1 : 0;
          final movementB = (b['categories'] as List).contains('Body') ? 1 : 0;
          if (movementA != movementB) return movementB.compareTo(movementA);
        }
        return byPractice != 0
            ? byPractice
            : (a['activeMinutes'] as int).compareTo(b['activeMinutes'] as int);
      });
    }
    candidates.first['recommended'] = true;
    return cards;
  }

  /// Card minutes that need moving, without sleep and water quests.
  int activeMinutes(List<JsonMap> tasks) => tasks.fold(
    0,
    (sum, task) =>
        sum +
        (task['ladder'] == 'Energy' || task['activityKind'] == 'water'
            ? 0
            : (task['durationMinutes'] as num?)?.toInt() ?? 0),
  );

  /// Fisher–Yates with integer arithmetic that is identical on Dart VM/web.
  void _shuffle<T>(List<T> values, String salt) {
    var state = _score('shuffle', salt) + 1;
    for (var index = values.length - 1; index > 0; index--) {
      state = (state * 48271) % 2147483647;
      final other = state % (index + 1);
      final value = values[index];
      values[index] = values[other];
      values[other] = value;
    }
  }

  /// Refresh only expired meal tasks; preserve card IDs, sizes, categories,
  /// recommended flags and already revealed choices. Never called on commits.
  List<JsonMap> refreshExpiredMeals(
    List<JsonMap> cards, {
    required String today,
    required int hour,
  }) {
    return [
      for (final (index, card) in cards.indexed)
        _refreshMealCard(card, today, hour, index),
    ];
  }

  JsonMap _refreshMealCard(JsonMap card, String today, int hour, int index) {
    final tasks = (card['tasks'] as List).cast<JsonMap>();
    final refreshed = [
      for (final task in tasks)
        if (task['ladder'] == 'Food' &&
            (task['photoWindows'] as List?)?.any(
                  (window) => (window[1] as num) <= hour,
                ) ==
                true)
          {
            ..._ladderTask(
              'Food',
              (task['step'] as num).toInt(),
              today,
              index,
              hour: hour,
              cameraAvailable: true,
              practice: task['practiceOnly'] == true,
              timedWorkouts: false,
            ),
            'id': task['id'],
          }
        else
          task,
    ];
    return {
      ...card,
      'tasks': refreshed,
      if (card.containsKey('activeMinutes'))
        'activeMinutes': activeMinutes(refreshed),
    };
  }

  /// Light extras after a full day (§6): no ladder or strenuous quests,
  /// nothing already on today's list, 15 XP each.
  List<JsonMap> bonusQuests({
    required String today,
    required Iterable<String> takenCatalogIds,
    required bool reduction,
    required bool cameraAvailable,
    required bool hasWaterLadder,
    bool hasFoodLadder = false,
    int count = 3,
    int hour = 0,
    bool wellnessUat = false,
  }) {
    final taken = takenCatalogIds.toSet();
    final pool =
        [..._catalog, ..._mobileCatalog].where((task) {
          if (taken.contains(task.id)) return false;
          if (task.reductionOnly && !reduction) return false;
          if (reduction && task.activityKind == 'habit_swap') return false;
          if (task.difficulty > 1) return false;
          if (wellnessUat &&
              (task.durationMinutes > 5 ||
                  (task.id == 'sunlight' && hour >= 12))) {
            return false;
          }
          if (task.activityKind == 'water' && hasWaterLadder) return false;
          if (_mealSideIds.contains(task.id) && hasFoodLadder) return false;
          if (task.activityKind == 'meal_snap' && !cameraAvailable) {
            return false;
          }
          return true;
        }).toList()..sort(
          (a, b) => _score(
            a.id,
            '$today:bonus',
          ).compareTo(_score(b.id, '$today:bonus')),
        );
    return [
      for (final (index, task) in pool.take(count).indexed)
        {
          ..._toMap(task, today, 'bonus-$index'),
          'xp': bonusQuestXp,
          'bonus': true,
        },
    ];
  }

  /// Category mixes for the five cards, least-practised categories first.
  List<List<String>> _combos(
    String today,
    bool reduction,
    Map<String, int> recent,
  ) {
    final pool = healthyCategories;
    final picks = reduction ? ladderQuestsPerCard - 1 : ladderQuestsPerCard;
    final combos = <List<String>>[];
    void build(int start, List<String> chosen) {
      if (chosen.length == picks) {
        combos.add([if (reduction) 'Reduction', ...chosen]);
        return;
      }
      for (var i = start; i < pool.length; i++) {
        build(i + 1, [...chosen, pool[i]]);
      }
    }

    build(0, []);
    int weight(List<String> combo) =>
        combo.fold(0, (sum, c) => sum + (recent[c] ?? 0));
    combos.sort((a, b) {
      final byPractice = weight(a).compareTo(weight(b));
      if (byPractice != 0) return byPractice;
      return _score(a.join(), today).compareTo(_score(b.join(), today));
    });
    return combos;
  }

  List<_TaskDefinition> _sideQuests({
    required int count,
    required List<String> categories,
    required bool reduction,
    required bool cameraAvailable,
    required String salt,
    int hour = 0,
    bool wellnessUat = false,
  }) {
    if (count <= 0) return const [];
    final eligible =
        [..._catalog, ..._mobileCatalog].where((task) {
          if (task.reductionOnly && !reduction) return false;
          if (task.difficulty > count + 1) return false;
          if (wellnessUat &&
              (task.durationMinutes > 5 ||
                  (task.id == 'sunlight' && hour >= 12))) {
            return false;
          }
          // One +250 ml tap or one photo must not finish two quests.
          if (task.activityKind == 'habit_swap' &&
              categories.contains('Reduction')) {
            return false;
          }
          if (task.activityKind == 'water' &&
              categories.contains('Lifestyle')) {
            return false;
          }
          if (task.category == 'Lifestyle' &&
              _mealSideIds.contains(task.id) &&
              categories.contains('Food')) {
            return false;
          }
          if (task.activityKind == 'meal_snap' && !cameraAvailable) {
            return false;
          }
          return true;
        }).toList()..sort((a, b) {
          return _score(a.id, salt).compareTo(_score(b.id, salt));
        });
    return eligible.take(count).toList();
  }

  JsonMap _ladderTask(
    String category,
    int step,
    String today,
    int card, {
    required int hour,
    required bool cameraAvailable,
    required bool practice,
    required bool timedWorkouts,
  }) {
    final rung = ladders[category]![step - 1];
    // Without background GPS (web app), walk/run counts session time.
    final timed = rung.usesTimer(timed: timedWorkouts);
    // A meal window that has already passed gets the same-step anytime quest.
    final windowPassed =
        rung.photoWindows?.any((window) => window[1] <= hour) ?? false;
    final anytime = windowPassed && rung.anytimeTitle != null;
    final photo = rung.activityKind == 'meal_snap';
    return {
      'id': '$today-card-$card-ladder-$category',
      'catalogId': 'ladder-${category.toLowerCase()}',
      'ladder': category,
      'step': step,
      'title': anytime ? rung.anytimeTitle : rung.titleFor(timed: timed),
      'description': anytime
          ? 'Jam makannya sudah lewat, jadi hari ini cukup ini. Foto tiap porsinya.'
          : rung.descriptionFor(timed: timed),
      'category': category,
      'difficulty': step,
      'durationMinutes': rung.minutesFor(timed: timed),
      'xp': 15 + step * 5,
      'source': 'card',
      'status': 'available',
      'done': false,
      // Without a camera, photo quests are checked off instead (§7).
      if (!photo || cameraAvailable) 'activityKind': ?rung.activityKind,
      if (!timed) 'targetMeters': ?rung.targetMeters,
      if (timed) 'timed': true,
      'waterMl': ?rung.waterMl,
      if (photo && cameraAvailable) 'photoCount': rung.photoCount ?? 1,
      if (photo && cameraAvailable && !anytime && rung.photoWindows != null)
        'photoWindows': rung.photoWindows,
      if (rung.strenuous) 'strenuous': true,
      if (practice) 'practiceOnly': true,
    };
  }

  JsonMap _toMap(_TaskDefinition task, String today, String suffix) => {
    'id': '$today-$suffix-${task.id}',
    'catalogId': task.id,
    'title': task.title,
    'description': task.description,
    'category': task.category,
    'difficulty': task.difficulty,
    'durationMinutes': task.durationMinutes,
    'xp': task.xp,
    'source': 'card',
    'status': 'available',
    'done': false,
    'activityKind': ?task.activityKind,
    'waterMl': ?task.waterMl,
  };

  int _score(String value, String salt) {
    var score = 17;
    for (final code in '$salt:$value'.codeUnits) {
      score = (score * 31 + code) % 100003;
    }
    return score;
  }
}

class _TaskDefinition {
  const _TaskDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.durationMinutes,
    required this.xp,
    this.reductionOnly = false,
    this.activityKind,
    this.waterMl,
  });
  final String id, title, description, category;
  final int difficulty, durationMinutes, xp;
  final bool reductionOnly;
  final String? activityKind;
  final int? waterMl;
}

/// Side quests: short, self-reported (or photo-backed) extras.
const _catalog = [
  _TaskDefinition(
    id: 'posture',
    title: 'Rapikan postur',
    description: 'Lepaskan bahu dan rapikan posisi duduk.',
    category: 'Body',
    difficulty: 1,
    durationMinutes: 1,
    xp: 15,
  ),
  _TaskDefinition(
    id: 'stretch',
    title: 'Stretching ringan',
    description: 'Leher, bahu, dan punggung dengan nyaman.',
    category: 'Body',
    difficulty: 1,
    durationMinutes: 3,
    xp: 20,
  ),
  _TaskDefinition(
    id: 'meal-snap',
    title: 'Catat satu momen makan',
    description: 'Foto untuk jurnal makan pribadimu. Foto tetap di HP.',
    category: 'Lifestyle',
    difficulty: 1,
    durationMinutes: 1,
    xp: 15,
    activityKind: 'meal_snap',
  ),
  _TaskDefinition(
    id: 'sunlight',
    title: 'Cari cahaya pagi',
    description: 'Keluar atau duduk dekat jendela.',
    category: 'Energy',
    difficulty: 1,
    durationMinutes: 3,
    xp: 15,
  ),
  _TaskDefinition(
    id: 'screen-break',
    title: 'Jeda layar',
    description: 'Alihkan pandangan dari layar.',
    category: 'Energy',
    difficulty: 1,
    durationMinutes: 2,
    xp: 15,
  ),
  _TaskDefinition(
    id: 'habit-swap',
    title: 'Coba 1 Habit Swap',
    description: 'Saat keinginan muncul, pilih satu aktivitas pengganti.',
    category: 'Reduction',
    difficulty: 1,
    durationMinutes: 2,
    xp: 20,
    reductionOnly: true,
    activityKind: 'habit_swap',
  ),
  _TaskDefinition(
    id: 'swap-plan',
    title: 'Rencana Habit Swap',
    description: 'Siapkan dua pengganti untuk momen keinginan.',
    category: 'Reduction',
    difficulty: 3,
    durationMinutes: 8,
    xp: 40,
    reductionOnly: true,
  ),
  _TaskDefinition(
    id: 'fresh-air',
    title: 'Cari udara segar',
    description: 'Keluar sebentar dan ubah suasana.',
    category: 'Lifestyle',
    difficulty: 1,
    durationMinutes: 5,
    xp: 25,
  ),
];

/// Physical wellness extras for mobile; never change the web quest pool.
const _mobileCatalog = [
  _TaskDefinition(
    id: 'water-glass',
    title: 'Satu gelas air',
    description: 'Minum sesuai kebutuhanmu, lalu catat di Hidrasi.',
    category: 'Lifestyle',
    difficulty: 1,
    durationMinutes: 1,
    xp: 20,
    activityKind: 'water',
    waterMl: 250,
  ),
  _TaskDefinition(
    id: 'fruit-veg',
    title: 'Tambahkan buah atau sayur',
    description: 'Pilih buah atau sayur yang tersedia saat makan.',
    category: 'Lifestyle',
    difficulty: 1,
    durationMinutes: 2,
    xp: 20,
  ),
  _TaskDefinition(
    id: 'stand-break',
    title: 'Ubah posisi sebentar',
    description: 'Berdiri atau regangkan tubuh sambil duduk senyamanmu.',
    category: 'Body',
    difficulty: 1,
    durationMinutes: 1,
    xp: 20,
  ),
];

/// XP for each Kartu Bonus quest (lower than the 20 XP of a card extra).
const bonusQuestXp = 15;

/// Side quests that a Makan ladder photo would also finish.
const _mealSideIds = {'meal-snap', 'fruit-veg'};

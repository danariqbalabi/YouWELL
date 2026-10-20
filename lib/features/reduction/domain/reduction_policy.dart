import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';

const nicotineProductLabels = {
  'cigarette': 'Rokok',
  'vape': 'Vape',
  'both': 'Rokok dan vape',
};
/// How the choice reads where the user picks it (onboarding, settings).
const nicotineChoiceLabels = {
  'cigarette': 'Saya merokok',
  'vape': 'Saya memakai vape',
  'both': 'Saya memakai keduanya',
};

/// The verb after "ingin", "tidak jadi" or "tetap" for one product.
String useVerb(String product) => product == 'vape' ? 'vape' : 'merokok';

/// The path's title for the chosen product. Under 21 speaks about quitting
/// (PP 28/2024 Ps. 434); with both products the title stays neutral.
String reductionTitle(String? choice, {required bool quit}) => switch (choice) {
  'cigarette' => quit ? 'Berhenti merokok' : 'Kurangi rokok',
  'vape' => quit ? 'Berhenti vaping' : 'Kurangi vape',
  'both' => 'Kelola rokok dan vape',
  _ => quit ? 'Berhenti rokok / vape' : 'Kurangi rokok / vape',
};

/// "merokok", "vape" or "merokok atau vape" for the chosen product(s).
String choiceVerb(String? choice) => switch (choice) {
  'vape' => 'vape',
  'both' => 'merokok atau vape',
  _ => 'merokok',
};

/// The button that opens Habit Swap when a craving starts.
String cravingLabel(String product) => 'Saya ingin ${useVerb(product)}';

/// A moment's outcome in the words of its own product.
String outcomeLabel(String outcome, String product) => switch (outcome) {
  'skipped' => 'Tidak jadi ${useVerb(product)} pada momen ini',
  'used' => 'Akhirnya tetap ${useVerb(product)}',
  'later' => 'Belum tahu, saya isi nanti',
  _ => swapOutcomeLabels[outcome] ?? 'Hasil belum dicatat',
};

const reductionTriggerLabels = {
  'after_meal': 'Setelah makan',
  'coffee': 'Minum kopi',
  'screen': 'Main HP / game',
  'boredom': 'Bosan',
  'stress': 'Tertekan',
  'social': 'Bersama teman',
  'wakeup': 'Setelah bangun',
  'other': 'Lainnya',
};
const swapActivityLabels = {
  'walk': 'Jalan santai',
  'seated': 'Gerak sambil duduk',
  'hands': 'Sibukkan tangan',
  'water': 'Minum segelas air',
  'music': 'Dengarkan musik',
  'breathing': 'Tarik napas pelan',
  'contact': 'Hubungi teman',
};
const swapOutcomeLabels = {
  'skipped': 'Tidak jadi merokok / vape',
  'used': 'Sudah coba, tetap merokok / vape',
  'not_tried': 'Belum coba pengganti',
};

List<String> productsFor(String? choice) => switch (choice) {
  'cigarette' => ['cigarette'],
  'vape' => ['vape'],
  'both' => ['cigarette', 'vape'],
  _ => [],
};

List<String> triggersFor(String product) => product == 'vape'
    ? [
        'screen',
        'boredom',
        'stress',
        'social',
        'wakeup',
        'after_meal',
        'coffee',
        'other',
      ]
    : [
        'after_meal',
        'coffee',
        'social',
        'stress',
        'wakeup',
        'boredom',
        'screen',
        'other',
      ];

/// A moment whose activity was reported as tried. New moments carry
/// `tried` from "Saya sudah mencoba", before any outcome; older rows only
/// have an outcome.
bool isSwapAttempt(Map row) =>
    row['tried'] == true || const ['skipped', 'used'].contains(row['outcome']);

/// A tried moment whose outcome the user chose to fill in later.
bool awaitingOutcome(Map row) =>
    row['tried'] == true && row['outcome'] == null && row['status'] != 'done';

/// Free-text triggers/activities: trimmed, short, no duplicates.
const maxCustomSwapText = 40;
List<String> cleanCustom(Iterable<String> values) => {
  for (final value in values)
    if (value.trim().isNotEmpty && value.trim().length <= maxCustomSwapText)
      value.trim(),
}.toList();

/// Every activity of a moment or setup in reading form, custom ones too.
List<String> activityNames(Map row) => [
  for (final key in {
    ...?(row['activities'] as List?)?.whereType<String>(),
    if (row['activity'] is String) row['activity'] as String,
  })
    ?swapActivityLabels[key],
  ...?(row['customActivities'] as List?)?.whereType<String>(),
];

/// Product-specific self-report: a vape session is never a cigarette or a
/// nicotine dose. Missing/unconfirmed days are absent, never implicit zeroes.
class ConsumptionWeek {
  const ConsumptionWeek(this.week, this.rows);
  factory ConsumptionWeek.fromLogs({
    required int week,
    required String started,
    required List<JsonMap> logs,
    required String through,
  }) {
    RangeError.checkValueInInterval(week, 1, 4, 'week');
    final from = shiftDayKey(started, (week - 1) * 7),
        until = shiftDayKey(from, 7);
    final unique = <String, JsonMap>{};
    for (final row in logs) {
      final day = row['day']?.toString() ?? '';
      if (row['confirmed'] == true &&
          day.compareTo(from) >= 0 &&
          day.compareTo(until) < 0 &&
          day.compareTo(through) <= 0) {
        unique[day] = row;
      }
    }
    return ConsumptionWeek(week, unique.values.toList());
  }
  final int week;
  final List<JsonMap> rows;
  List<num> _values(String product) => [
    for (final row in rows)
      if (row[product] is num && (row[product] as num) >= 0)
        row[product] as num,
  ];
  int daysFor(String product) => _values(product).length;
  double? meanFor(String product) {
    final values = _values(product);
    return values.isEmpty
        ? null
        : values.fold<double>(0, (sum, n) => sum + n) / values.length;
  }

  /// An explicit coverage rule for this demo; not a clinical validity claim.
  bool comparableFor(String product) => daysFor(product) >= 4;
  double? changeFrom(ConsumptionWeek baseline, String product) {
    final original = baseline.meanFor(product);
    if (!comparableFor(product) ||
        !baseline.comparableFor(product) ||
        original == null ||
        original == 0) {
      return null;
    }
    return (meanFor(product)! - original) / original * 100;
  }
}

/// Every trigger of a moment; older rows keep a single `trigger`.
List<String> momentTriggers(Map row) => [
  ...?(row['triggers'] as List?)?.whereType<String>(),
  if (row['triggers'] is! List && row['trigger'] is String)
    row['trigger'] as String,
];

/// "Setelah makan, Ngopi" for a moment or plan, or null if none is known.
String? triggerText(Map row) {
  final labels = [
    for (final key in momentTriggers(row)) ?reductionTriggerLabels[key],
    ...?(row['customTriggers'] as List?)?.whereType<String>(),
  ];
  return labels.isEmpty ? null : labels.join(', ');
}

/// Explainable suggestions: movement first, seated movement for low-impact;
/// a tried strategy may lead after two matched reports that skipped the moment
/// (REDUCTION_UAT: "dua laporan cocok ... dengan hasil melewatkan").
List<String> suggestedSwaps({
  required bool lowImpact,
  required String product,
  String trigger = '',
  List<String> triggers = const [],
  required List<JsonMap> history,
}) {
  final picked = {...triggers, if (trigger.isNotEmpty) trigger};
  final order = lowImpact
      ? ['seated', 'hands', 'water', 'breathing', 'music', 'contact', 'walk']
      : ['walk', 'seated', 'hands', 'water', 'breathing', 'music', 'contact'];
  double score(String activity) {
    final matches = history.where(
      (row) =>
          row['product'] == product &&
          momentTriggers(row).any(picked.contains) &&
          (row['activity'] == activity ||
              (row['activities'] as List?)?.contains(activity) == true) &&
          isSwapAttempt(row),
    );
    final skipped = matches.where((row) => row['outcome'] == 'skipped').length;
    return skipped < 2 ? -1 : skipped / matches.length;
  }

  return [...order]..sort((a, b) {
    final byHistory = score(b).compareTo(score(a));
    return byHistory == 0
        ? order.indexOf(a).compareTo(order.indexOf(b))
        : byHistory;
  });
}

import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/core/utils/date_key.dart';

const nicotineProductLabels = {
  'cigarette': 'Rokok',
  'vape': 'Vape',
  'both': 'Rokok dan vape',
};
const reductionTriggerLabels = {
  'after_meal': 'Setelah makan',
  'coffee': 'Saat minum kopi',
  'screen': 'Saat main HP / game',
  'boredom': 'Sedang bosan',
  'stress': 'Sedang tertekan',
  'social': 'Bersama teman',
  'wakeup': 'Setelah bangun',
  'other': 'Momen lain',
};
const swapActivityLabels = {
  'walk': 'Jalan santai sebentar',
  'seated': 'Gerak ringan sambil duduk',
  'hands': 'Sibukkan tangan dengan aktivitas lain',
  'water': 'Minum segelas air',
  'breathing': 'Tarik napas perlahan',
  'contact': 'Hubungi teman',
};
const swapOutcomeLabels = {
  'skipped': 'Melewatkan rokok / vape pada momen ini',
  'used': 'Sudah mencoba, tetap merokok / vape',
  'not_tried': 'Belum mencoba aktivitas pengganti',
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

bool isSwapAttempt(Map row) =>
    const ['skipped', 'used'].contains(row['outcome']);

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

/// Explainable suggestions: movement first, seated movement for low-impact;
/// a tried strategy may lead after two matched reports that skipped the moment
/// (REDUCTION_UAT: "dua laporan cocok ... dengan hasil melewatkan").
List<String> suggestedSwaps({
  required bool lowImpact,
  required String product,
  required String trigger,
  required List<JsonMap> history,
}) {
  final order = lowImpact
      ? ['seated', 'hands', 'water', 'breathing', 'contact', 'walk']
      : ['walk', 'seated', 'hands', 'water', 'breathing', 'contact'];
  double score(String activity) {
    final matches = history.where(
      (row) =>
          row['product'] == product &&
          row['trigger'] == trigger &&
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

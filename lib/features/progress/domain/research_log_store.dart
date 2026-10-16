import 'package:youwell/core/types/json_map.dart';

/// Research channel: a P1–P10 code and the agreed numbers only.
abstract interface class ResearchLogStore {
  /// Participant side, insert-only.
  Future<void> submit({
    required String participantCode,
    required bool weekComplete,
    required JsonMap summary,
  });

  /// Admin side (MFA): the latest row per participant and week.
  Future<List<JsonMap>> exportLatest();
}

/// Column order of the export; matches `youwell_research_logs`.
const researchCsvColumns = [
  'participant_code',
  'week',
  'week_complete',
  'opened_days',
  'active_days',
  'active',
  'quests_done',
  'ladder_gerak',
  'ladder_istirahat',
  'ladder_tidur',
  'ladder_hidrasi',
  'ladder_makan',
  'ladder_jeda',
  'delay_craving_count',
  'delay_craving_completed',
  'habit_swap_count',
  'submitted_at',
];

/// Plain CSV for spreadsheets. Values are codes, numbers, booleans and
/// timestamps, but are still quoted when needed so the file never breaks.
String researchCsv(List<JsonMap> rows) {
  String cell(Object? value) {
    final text = value?.toString() ?? '';
    return RegExp(r'[",\n\r]').hasMatch(text)
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  return [
    researchCsvColumns.join(','),
    for (final row in rows)
      researchCsvColumns.map((column) => cell(row[column])).join(','),
  ].join('\n');
}

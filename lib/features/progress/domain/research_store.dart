import 'package:youwell/core/types/json_map.dart';

/// Researcher dashboard data. Every call is for allowlisted admins with MFA;
/// the server refuses anyone else.
abstract interface class ResearchStore {
  /// Every account's synced progress, with its alias and assigned code.
  Future<List<JsonMap>> progressOverview();

  /// Assigns P1–P10 to an account; null removes its code.
  Future<void> setParticipantCode(String account, String? code);
}

/// Weekly research columns (proposal §3.3), one row per code and week.
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
  'synced_at',
];

/// Plain CSV for spreadsheets; values are quoted when needed.
String toCsv(List<String> columns, List<JsonMap> rows) {
  String cell(Object? value) {
    final text = value?.toString() ?? '';
    return RegExp(r'[",\n\r]').hasMatch(text)
        ? '"${text.replaceAll('"', '""')}"'
        : text;
  }

  return [
    columns.join(','),
    for (final row in rows)
      columns.map((column) => cell(row[column])).join(','),
  ].join('\n');
}

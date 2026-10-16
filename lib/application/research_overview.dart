import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/sync/domain/cloud_progress.dart';
import 'wellness_controller.dart';

/// One participant row of the researcher dashboard, computed with the same
/// rules the app uses, from the progress snapshot the account synced.
class ParticipantOverview {
  const ParticipantOverview({
    required this.account,
    required this.alias,
    required this.path,
    required this.dayNumber,
    required this.complete,
    required this.level,
    required this.xp,
    required this.activeLast7,
    required this.questsDone,
    required this.fullDays,
    required this.habitSwaps,
    required this.ladder,
    required this.weeks,
    required this.payload,
    this.code,
    this.updatedAt,
  });

  /// Returns null for a row whose snapshot cannot be read.
  static ParticipantOverview? fromRow(Map row, {DateTime? now}) {
    final payload = row['payload'];
    if (payload is! Map) return null;
    WellnessController? controller;
    try {
      controller = WellnessController(
        saved: CloudProgress.apply(Map<String, dynamic>.from(payload), null),
        clock: () => now ?? DateTime.now(),
      );
      final c = controller;
      final program = c.uatProgram;
      if (c.profile == null || program == null) return null;
      final weeks = [
        for (var week = 1; week <= 4; week++)
          if (!program.complete && week > program.week)
            null
          else
            c.researchSummary(week).toJson(),
      ];
      return ParticipantOverview(
        account: row['account']?.toString() ?? '',
        code: row['code']?.toString(),
        alias: row['alias']?.toString() ?? c.profile!['alias'].toString(),
        path: c.reduction ? 'Rokok/vape' : 'Wellness',
        dayNumber: program.dayNumber,
        complete: program.complete,
        level: c.level,
        xp: c.xp,
        activeLast7: c.activeDaysIn(7),
        questsDone: weeks.fold(
          0,
          (sum, week) => sum + ((week?['quests_done'] as int?) ?? 0),
        ),
        fullDays: c.completedDays.length,
        habitSwaps: c.habitSwaps.length,
        ladder: c.ladderSteps,
        weeks: weeks,
        payload: Map<String, dynamic>.from(payload),
        updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      );
    } catch (_) {
      return null;
    } finally {
      controller?.dispose();
    }
  }

  /// Opaque server key used only to assign a participant code.
  final String account;
  final String? code;
  final String alias, path;
  final int dayNumber, level, xp, activeLast7, questsDone, fullDays;
  final int habitSwaps;
  final bool complete;
  final Map<String, int> ladder;

  /// Research summary per program week (proposal §3.3 columns); null for
  /// weeks not reached yet.
  final List<JsonMap?> weeks;

  /// The synced progress as the server holds it, for a per-account download.
  final JsonMap payload;
  final DateTime? updatedAt;

  List<bool?> get activeWeeks => [
    for (final week in weeks) week == null ? null : week['active'] == true,
  ];

  static const csvColumns = [
    'kode',
    'alias',
    'jalur',
    'hari',
    'level',
    'xp',
    'aktif_7_hari',
    'quest_selesai',
    'hari_penuh',
    'habit_swap',
    'aktif_m1',
    'aktif_m2',
    'aktif_m3',
    'aktif_m4',
    'tangga_gerak',
    'tangga_istirahat',
    'tangga_hidrasi',
    'tangga_makan',
    'tangga_jeda',
    'terakhir_sinkron',
  ];

  JsonMap toCsvRow() => {
    'kode': code,
    'alias': alias,
    'jalur': path,
    'hari': complete ? 'selesai' : dayNumber,
    'level': level,
    'xp': xp,
    'aktif_7_hari': activeLast7,
    'quest_selesai': questsDone,
    'hari_penuh': fullDays,
    'habit_swap': habitSwaps,
    for (var week = 1; week <= 4; week++) 'aktif_m$week': activeWeeks[week - 1],
    'tangga_gerak': ladder['Body'],
    'tangga_istirahat': ladder['Energy'],
    'tangga_hidrasi': ladder['Lifestyle'],
    'tangga_makan': ladder['Food'],
    'tangga_jeda': ladder['Reduction'],
    'terakhir_sinkron': updatedAt?.toIso8601String(),
  };

  /// Coded weekly rows for the research CSV (no alias).
  List<JsonMap> researchRows() => [
    if (code != null)
      for (final (index, week) in weeks.indexed)
        if (week != null)
          {
            ...week,
            'participant_code': code,
            'week_complete': complete || index + 1 < dayNumberWeek,
            'synced_at': updatedAt?.toIso8601String(),
          },
  ];

  int get dayNumberWeek => ((dayNumber - 1) ~/ 7) + 1;
}

/// Proposal §3.8 criterion 3: of the coded participants who reached week 4,
/// how many were active in it.
({int active, int reached}) weekFourEngagement(
  Iterable<ParticipantOverview> people,
) {
  final reached = people.where(
    (p) => p.code != null && p.activeWeeks[3] != null,
  );
  return (
    active: reached.where((p) => p.activeWeeks[3] == true).length,
    reached: reached.length,
  );
}

import 'package:youwell/core/types/json_map.dart';
import 'package:youwell/features/home/domain/wellness_uat_program.dart';

/// Graded, rule-based quest ladders (no ML). Each category keeps its own step;
/// the step decides which quest of that category appears on a daily card.
class LadderRung {
  const LadderRung({
    required this.title,
    required this.description,
    required this.durationMinutes,
    this.activityKind,
    this.targetMeters,
    this.waterMl,
    this.photoCount,
    this.photoWindows,
    this.anytimeTitle,
    this.timedTitle,
    this.timedMinutes,
    this.strenuous = false,
  });
  final String title, description;
  final int durationMinutes;
  final String? activityKind;
  final int? targetMeters, waterMl;

  /// Meal photos needed (camera only). With [photoWindows], photo i must be
  /// taken between hour `start` (inclusive) and `end` (exclusive).
  final int? photoCount;
  final List<List<int>>? photoWindows;

  /// Same-step quest without time windows, used when a window has already
  /// passed when today's cards are made (e.g. breakfast after 10.00).
  final String? anytimeTitle;

  /// Walk/run quest by session time, for builds without background GPS
  /// (the iPhone web app). Same step, so research ladder positions match.
  final String? timedTitle;
  final int? timedMinutes;

  /// Whether this device counts the rung by session time (web) or GPS (APK).
  bool usesTimer({required bool timed}) => timed && timedTitle != null;

  String titleFor({required bool timed}) =>
      usesTimer(timed: timed) ? timedTitle! : title;

  String descriptionFor({required bool timed}) =>
      usesTimer(timed: timed) ? timedWorkoutDescription : description;

  int minutesFor({required bool timed}) =>
      usesTimer(timed: timed) ? timedMinutes! : durationMinutes;

  /// Shows "berhenti jika pusing atau nyeri" on the quest.
  final bool strenuous;
}

const ladderLabels = {
  'Body': 'Gerak',
  'Food': 'Makan',
  'Lifestyle': 'Hidrasi',
  'Energy': 'Istirahat',
  'Reduction': 'Ganti kebiasaan',
};

const timedWorkoutDescription =
    'Dihitung dari lama sesi. Boleh kunci layar selama sesi.';

/// Low-impact users never enter the running part of the Body ladder.
const lowImpactBodyMax = 4;

/// Walk/run quests count GPS distance only in the APK; time alone never
/// finishes them there. The web app always uses each rung's
/// [LadderRung.timedTitle], since browsers have no background GPS.
const ladders = <String, List<LadderRung>>{
  'Body': [
    LadderRung(
      title: 'Jalan 400 m',
      description: 'Sekitar 5 menit. Jarak dihitung lewat GPS.',
      durationMinutes: 5,
      activityKind: 'walk',
      targetMeters: 400,
      timedTitle: 'Jalan 5 menit',
      timedMinutes: 5,
    ),
    LadderRung(
      title: 'Jalan 800 m',
      description: 'Sekitar 10 menit. Jarak dihitung lewat GPS.',
      durationMinutes: 10,
      activityKind: 'walk',
      targetMeters: 800,
      timedTitle: 'Jalan 10 menit',
      timedMinutes: 10,
    ),
    LadderRung(
      title: 'Jalan cepat 1,2 km',
      description: 'Sekitar 15 menit, masih bisa sambil bicara.',
      durationMinutes: 15,
      activityKind: 'walk',
      targetMeters: 1200,
      timedTitle: 'Jalan cepat 15 menit',
      timedMinutes: 15,
      strenuous: true,
    ),
    LadderRung(
      title: 'Jalan 1,5 km',
      description: 'Sekitar 20 menit dengan ritmemu sendiri.',
      durationMinutes: 20,
      activityKind: 'walk',
      targetMeters: 1500,
      timedTitle: 'Jalan 20 menit',
      timedMinutes: 20,
      strenuous: true,
    ),
    LadderRung(
      title: 'Interval jalan-lari 2 km',
      description: '1 menit lari pelan, 2 menit jalan, sampai 2 km.',
      durationMinutes: 20,
      activityKind: 'run',
      targetMeters: 2000,
      timedTitle: 'Interval jalan-lari 20 menit',
      timedMinutes: 20,
      strenuous: true,
    ),
    LadderRung(
      title: 'Interval jalan-lari 2,5 km',
      description: '1 menit lari pelan, 2 menit jalan, sampai 2,5 km.',
      durationMinutes: 25,
      activityKind: 'run',
      targetMeters: 2500,
      timedTitle: 'Interval jalan-lari 25 menit',
      timedMinutes: 25,
      strenuous: true,
    ),
    LadderRung(
      title: 'Lari santai 2 km',
      description: 'Pelan saja, boleh selingi jalan.',
      durationMinutes: 16,
      activityKind: 'run',
      targetMeters: 2000,
      timedTitle: 'Lari santai 20 menit',
      timedMinutes: 20,
      strenuous: true,
    ),
    LadderRung(
      title: 'Lari 3 km',
      description: 'Jaga napas tetap nyaman.',
      durationMinutes: 24,
      activityKind: 'run',
      targetMeters: 3000,
      timedTitle: 'Lari 25 menit',
      timedMinutes: 25,
      strenuous: true,
    ),
    LadderRung(
      title: 'Lari 4 km',
      description: 'Jaga napas tetap nyaman.',
      durationMinutes: 30,
      activityKind: 'run',
      targetMeters: 4000,
      timedTitle: 'Lari 30 menit',
      timedMinutes: 30,
      strenuous: true,
    ),
    LadderRung(
      title: 'Lari 5 km',
      description: 'Ritme stabil, tidak perlu cepat.',
      durationMinutes: 38,
      activityKind: 'run',
      targetMeters: 5000,
      timedTitle: 'Lari 40 menit',
      timedMinutes: 40,
      strenuous: true,
    ),
  ],
  // Meal quests add, never restrict: no calories, weights, or bans.
  'Food': [
    LadderRung(
      title: 'Sarapan sebelum 10.00',
      description: 'Foto sarapanmu, apa saja boleh.',
      durationMinutes: 5,
      activityKind: 'meal_snap',
      photoCount: 1,
      photoWindows: [
        [4, 10],
      ],
      anytimeTitle: 'Tambah 1 porsi buah atau sayur',
    ),
    LadderRung(
      title: 'Makan siang tepat waktu',
      description: 'Foto makan siangmu sebelum 14.00.',
      durationMinutes: 5,
      activityKind: 'meal_snap',
      photoCount: 1,
      photoWindows: [
        [10, 14],
      ],
      anytimeTitle: 'Tambah 1 porsi buah atau sayur',
    ),
    LadderRung(
      title: 'Tambah 1 porsi buah atau sayur',
      description: 'Foto porsinya di salah satu makanmu.',
      durationMinutes: 5,
      activityKind: 'meal_snap',
      photoCount: 1,
    ),
    LadderRung(
      title: 'Sarapan & makan siang tepat waktu',
      description: 'Foto sarapan sebelum 10.00 dan makan siang sebelum 14.00.',
      durationMinutes: 10,
      activityKind: 'meal_snap',
      photoCount: 2,
      photoWindows: [
        [4, 10],
        [10, 14],
      ],
      anytimeTitle: '2 porsi buah atau sayur hari ini',
    ),
    LadderRung(
      title: '2 porsi buah atau sayur hari ini',
      description: 'Foto tiap porsinya.',
      durationMinutes: 10,
      activityKind: 'meal_snap',
      photoCount: 2,
    ),
    LadderRung(
      title: 'Ganti 1 minuman manis dengan air putih',
      description: 'Foto air putih yang kamu pilih.',
      durationMinutes: 5,
      activityKind: 'meal_snap',
      photoCount: 1,
    ),
    LadderRung(
      title: 'Makan 3 kali dengan jam teratur',
      description: 'Foto pagi (sebelum 10.00), siang (10–15), malam (17–21).',
      durationMinutes: 15,
      activityKind: 'meal_snap',
      photoCount: 3,
      photoWindows: [
        [4, 10],
        [10, 15],
        [17, 21],
      ],
      anytimeTitle: '3 porsi buah atau sayur hari ini',
    ),
    LadderRung(
      title: '1 piring "Isi Piringku"',
      description: 'Setengah piring sayur dan buah. Foto piringmu.',
      durationMinutes: 10,
      activityKind: 'meal_snap',
      photoCount: 1,
    ),
    LadderRung(
      title: '3 porsi buah atau sayur hari ini',
      description: 'Foto tiap porsinya.',
      durationMinutes: 15,
      activityKind: 'meal_snap',
      photoCount: 3,
    ),
    LadderRung(
      title: '2 piring "Isi Piringku" hari ini',
      description: 'Setengah piring sayur dan buah, dua kali makan.',
      durationMinutes: 20,
      activityKind: 'meal_snap',
      photoCount: 2,
    ),
  ],
  // Asked about last night: putting the phone down needs no tap at bedtime.
  'Energy': [
    LadderRung(
      title: 'Semalam: layar off 10 menit sebelum tidur',
      description: 'Centang hari ini kalau semalam kamu menaruh HP dulu.',
      durationMinutes: 10,
    ),
    LadderRung(
      title: 'Semalam: layar off 15 menit sebelum tidur',
      description: 'Ganti scroll dengan hal yang menenangkan.',
      durationMinutes: 15,
    ),
    LadderRung(
      title: 'Semalam: layar off 20 menit sebelum tidur',
      description: 'Redupkan lampu dan beri tubuh tanda istirahat.',
      durationMinutes: 20,
    ),
    LadderRung(
      title: 'Semalam: layar off 30 menit sebelum tidur',
      description: 'Isi dengan stretching, baca, atau musik pelan.',
      durationMinutes: 30,
    ),
    LadderRung(
      title: 'Semalam: layar off 45 menit sebelum tidur',
      description: 'HP ditaruh di luar jangkauan tempat tidur.',
      durationMinutes: 45,
    ),
    LadderRung(
      title: 'Semalam: layar off 60 menit & jam tidur tetap',
      description: 'Tidur di jam yang kurang lebih sama seperti biasanya.',
      durationMinutes: 60,
    ),
  ],
  'Reduction': [
    LadderRung(
      title: 'Coba satu aktivitas pengganti',
      description:
          'Saat keinginan muncul, coba kegiatan pengganti lalu laporkan '
          'di Habit Swap.',
      durationMinutes: 5,
      activityKind: 'habit_swap',
    ),
  ],
  'Lifestyle': [
    LadderRung(
      title: 'Minum 1.000 ml hari ini',
      description: 'Catat setiap gelas di Aktivitas.',
      durationMinutes: 1,
      activityKind: 'water',
      waterMl: 1000,
    ),
    LadderRung(
      title: 'Minum 1.250 ml hari ini',
      description: 'Catat setiap gelas di Aktivitas.',
      durationMinutes: 1,
      activityKind: 'water',
      waterMl: 1250,
    ),
    LadderRung(
      title: 'Minum 1.500 ml hari ini',
      description: 'Catat setiap gelas di Aktivitas.',
      durationMinutes: 1,
      activityKind: 'water',
      waterMl: 1500,
    ),
    LadderRung(
      title: 'Minum 1.750 ml hari ini',
      description: 'Catat setiap gelas di Aktivitas.',
      durationMinutes: 1,
      activityKind: 'water',
      waterMl: 1750,
    ),
    LadderRung(
      title: 'Minum 2.000 ml hari ini',
      description: 'Catat setiap gelas di Aktivitas.',
      durationMinutes: 1,
      activityKind: 'water',
      waterMl: 2000,
    ),
  ],
};

/// The Hidrasi rung at [step], kept inside the ladder.
LadderRung waterRung(int step) {
  final rungs = ladders['Lifestyle']!;
  return rungs[step.clamp(1, rungs.length) - 1];
}

/// Healthy-living categories a card can draw from (§2).
const healthyCategories = ['Body', 'Food', 'Lifestyle', 'Energy'];

/// Every category with a ladder for this path: all healthy categories, plus
/// Habit Swap (always on a card) for the smoking/vaping path.
List<String> ladderCategories({required bool reduction}) =>
    reduction ? const ['Reduction', ...healthyCategories] : healthyCategories;

/// Ladder quests per card: 3 random healthy categories, or Habit Swap + 2 random.
const ladderQuestsPerCard = 3;

int ladderMax(
  String category, {
  required bool lowImpact,
  bool wellnessUat = false,
}) {
  final length = ladders[category]!.length;
  final limit = wellnessUat
      ? WellnessUatProgram.stepLimits[category] ?? length
      : length;
  return category == 'Body' && lowImpact
      ? lowImpactBodyMax.clamp(1, limit)
      : limit.clamp(1, length);
}

/// The rule from the proposal (§4), evaluated per category every 7 days.
/// Days a category must be done in the week before a step up is offered.
/// Categories rotate across cards, so this is 3 rather than 4 (§8).
const minCardDaysToStepUp = 3;

int nextStep(
  int current,
  int maxStep, {
  required double completion,
  required int cardDays,
  required int inactiveDays,
}) {
  if (inactiveDays >= 5) return (current - 1).clamp(1, maxStep);
  if (cardDays >= minCardDaysToStepUp && completion >= .8) {
    return (current + 1).clamp(1, maxStep);
  }
  if (completion < .5) return (current - 1).clamp(1, maxStep);
  return current;
}

class LadderReview {
  const LadderReview({
    required this.step,
    required this.change,
    required this.reason,
  });
  final int step;

  /// up (offered, not yet applied), down, hold, or rest (after inactivity).
  final String change;
  final String reason;
}

/// Turns one category's last 7 days of ladder quests into an explained step.
LadderReview reviewLadder({
  required String category,
  required int current,
  required int maxStep,
  required List<JsonMap> weekQuests,
  required int inactiveDays,
}) {
  final label = ladderLabels[category] ?? category;
  if (inactiveDays >= 5) {
    final step = nextStep(
      current,
      maxStep,
      completion: 0,
      cardDays: 0,
      inactiveDays: inactiveDays,
    );
    return LadderReview(
      step: step,
      change: 'rest',
      reason: step < current
          ? 'Selamat datang lagi. $label turun satu anak tangga supaya mulai '
                'lagi terasa ringan.'
          : 'Selamat datang lagi. Mulai lagi dari langkah yang ringan.',
    );
  }
  if (weekQuests.isEmpty) {
    return LadderReview(
      step: current,
      change: 'hold',
      reason: 'Belum ada quest $label minggu ini, jadi anak tangga tetap.',
    );
  }
  final total = weekQuests.length;
  final done = weekQuests.where((task) => task['status'] == 'completed').length;
  final score = weekQuests.fold<double>(
    0,
    (sum, task) => task['status'] == 'completed'
        ? sum + 1
        : sum + ((task['partial'] as num?)?.toDouble() ?? 0),
  );
  final completion = score / total;
  // Days on which a card (and so this ladder quest) was taken.
  final cardDays = weekQuests.map((task) => task['day']).toSet().length;
  final step = nextStep(
    current,
    maxStep,
    completion: completion,
    cardDays: cardDays,
    inactiveDays: inactiveDays,
  );
  final summary = '$done dari $total quest $label selesai';
  if (step > current) {
    return LadderReview(
      step: step,
      change: 'up',
      reason: 'Naik karena $summary.',
    );
  }
  if (step < current) {
    return LadderReview(
      step: step,
      change: 'down',
      reason: 'Turun satu anak tangga karena $summary. Biar lebih pas dulu.',
    );
  }
  final ready = completion >= .8;
  return LadderReview(
    step: current,
    change: 'hold',
    reason: ready && current == maxStep
        ? 'Kamu sudah di anak tangga teratas. $summary.'
        : ready
        ? 'Tetap dulu: $label dikerjakan $cardDays kali minggu ini. Naik butuh '
              'minimal $minCardDaysToStepUp kali.'
        : 'Tetap di anak tangga ini: $summary.',
  );
}

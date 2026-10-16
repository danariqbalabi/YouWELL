/// Personal rewards only: no rankings, penalties, or expiring progress.
class CompanionUnlock {
  const CompanionUnlock(this.id, this.label, this.level, this.background);
  final String id, label;
  final int level;
  final bool background;
}

const companionUnlocks = [
  CompanionUnlock('ribbon', 'Pita ceria', 2, false),
  CompanionUnlock('dusk', 'Langit senja', 3, true),
  CompanionUnlock('stars', 'Bintang kecil', 4, false),
  CompanionUnlock('sunrise', 'Pagi hangat', 6, true),
  CompanionUnlock('crown', 'Mahkota daun', 8, false),
];

/// Level at which each of the five growth stages starts. Sized so someone
/// who finishes every mission daily reaches stage 5 by week 4 even at the
/// slowest pace (Santai, never stepping up ≈ level 9 on day 28).
const companionStageLevels = [1, 3, 5, 7, 9];

int companionStage(int level) =>
    companionStageLevels.lastIndexWhere((start) => level >= start) + 1;

/// YouWELL's one mascot. The stored `companion` value (plant/cat/cloud, kept
/// for existing profiles and sync) now only picks Welli's colour.
const companionName = 'Welli';
const companionColors = {'plant': 'Daun', 'cat': 'Senja', 'cloud': 'Langit'};

const _stageNames = ['Benih', 'Tunas', 'Berdaun', 'Mekar', 'Bersinar'];

String companionStageName(int stage) => _stageNames[(stage - 1).clamp(0, 4)];

class RewardMoment {
  const RewardMoment({
    required this.serial,
    this.xp = 0,
    this.dayComplete = false,
    this.evolved = false,
    this.ladder,
    this.unlocks = const [],
    this.badges = const [],
  });
  final int serial, xp;
  final bool dayComplete, evolved;
  final String? ladder;
  final List<String> unlocks, badges;
}

const achievementNames = {
  'first-quest': 'Langkah pertama',
  'full-day': 'Hari penuh pertama',
  'weekly-rhythm': 'Ritme 4 hari',
  'hydration-7': '7 hari hidrasi',
  'first-ladder': 'Anak tangga baru',
};

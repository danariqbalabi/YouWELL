import 'package:youwell/core/utils/date_key.dart';

/// Calendar days, not streaks: missing a day never restarts the UAT period.
class WellnessUatProgram {
  WellnessUatProgram({required String started, required DateTime now})
    : firstDay = DateTime.tryParse(started) ?? DateTime.parse(dayKey(now)),
      currentDay = DateTime.parse(dayKey(now));

  static const durationDays = 28;
  static const stepLimits = {'Body': 4, 'Food': 5, 'Energy': 4, 'Lifestyle': 5};
  final DateTime firstDay, currentDay;
  int get elapsedDays => daysBetweenKeys(dayKey(firstDay), dayKey(currentDay));
  bool get complete => elapsedDays >= durationDays;
  int get dayNumber => (elapsedDays + 1).clamp(1, durationDays);
  int get week => ((dayNumber - 1) ~/ 7) + 1;
  String get phase => switch (week) {
    1 => 'Mulai pelan',
    2 => 'Ulangi langkah kecil',
    3 => 'Temukan ritmemu',
    _ => 'Jaga yang cocok',
  };
  String get message => switch (week) {
    1 => 'Kenali yang terasa nyaman. Satu misi kecil pun berarti.',
    2 => 'Ulangi yang cocok. Tidak perlu menambah beban setiap hari.',
    3 => 'Cari ritme yang bisa diulang. Kenaikan tetap pilihanmu.',
    _ => 'Pertahankan langkah yang cocok untukmu setelah perjalanan ini.',
  };
}

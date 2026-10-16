import 'package:youwell/core/utils/date_key.dart';

const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Agu',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// "Hari ini", "Kemarin", or "Kam, 30 Okt" for a yyyy-mm-dd day key.
String dayLabel(String key, DateTime now) {
  final date = DateTime.tryParse(key);
  if (date == null) return key;
  if (key == dayKey(now)) return 'Hari ini';
  if (key == shiftDayKey(dayKey(now), -1)) return 'Kemarin';
  return '${_days[date.weekday - 1]}, ${date.day} ${_months[date.month - 1]}';
}

/// "30 Okt" for a yyyy-mm-dd day key.
String shortDate(String key) {
  final date = DateTime.tryParse(key);
  return date == null ? key : '${date.day} ${_months[date.month - 1]}';
}

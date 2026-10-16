/// Stable local calendar key, shared by daily missions and activity logs.
String dayKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Calendar arithmetic runs on UTC dates: local midnights are 23 or 25 hours
/// apart around a daylight-saving change, which shifts `Duration(days:)` maths.
DateTime _calendarDate(String key) {
  final date = DateTime.parse(key);
  return DateTime.utc(date.year, date.month, date.day);
}

/// The key [days] calendar days after (or before, if negative) [key].
String shiftDayKey(String key, int days) =>
    dayKey(_calendarDate(key).add(Duration(days: days)));

/// Whole calendar days from [from] to [to]; negative when [to] is earlier.
int daysBetweenKeys(String from, String to) =>
    _calendarDate(to).difference(_calendarDate(from)).inDays;

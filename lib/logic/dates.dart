/// Calendar dates, without clock times.
///
/// Days are added on the calendar, so a daylight-saving change on the phone
/// cannot skip or repeat a date.
library;

DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

DateTime addDays(DateTime date, int days) {
  final day = dateOnly(date);
  return DateTime(day.year, day.month, day.day + days);
}

bool isWeekend(DateTime date) {
  final weekday = dateOnly(date).weekday;
  return weekday == DateTime.saturday || weekday == DateTime.sunday;
}

/// Moves forward across weekdays only. Saturday and Sunday are not counted.
DateTime addWeekdays(DateTime date, int weekdays) {
  var next = dateOnly(date);
  var left = weekdays < 1 ? 1 : weekdays;
  while (left > 0) {
    next = addDays(next, 1);
    if (!isWeekend(next)) left--;
  }
  return next;
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

DateTime lastWeekdayOfMonth(int year, int month) {
  var date = DateTime(year, month + 1, 0);
  while (isWeekend(date)) {
    date = addDays(date, -1);
  }
  return date;
}

DateTime clampDate(int year, int month, int day) {
  final last = daysInMonth(year, month);
  return DateTime(year, month, day > last ? last : day);
}

DateTime startOfWeek(DateTime date) {
  final day = dateOnly(date);
  return addDays(day, 1 - day.weekday);
}

String formatIsoDate(DateTime date) {
  final day = dateOnly(date);
  final month = day.month.toString().padLeft(2, '0');
  final dayText = day.day.toString().padLeft(2, '0');
  return '${day.year}-$month-$dayText';
}

DateTime parseIsoDate(String value) {
  final parts = value.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
}

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const monthShort = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];
const monthLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

String prettyDate(DateTime date) {
  final day = dateOnly(date);
  return '${weekdayShort[day.weekday - 1]}, ${day.day} ${monthShort[day.month - 1]} ${day.year}';
}

String monthTitle(DateTime date) {
  final day = dateOnly(date);
  return '${monthLong[day.month - 1]} ${day.year}';
}

String weekTitle(DateTime date) {
  final start = startOfWeek(date);
  final end = addDays(start, 6);
  if (start.year == end.year && start.month == end.month) {
    return '${start.day} – ${end.day} ${monthShort[start.month - 1]} ${start.year}';
  }
  if (start.year == end.year) {
    return '${start.day} ${monthShort[start.month - 1]} – ${end.day} ${monthShort[end.month - 1]} ${start.year}';
  }
  return '${start.day} ${monthShort[start.month - 1]} ${start.year} – ${end.day} ${monthShort[end.month - 1]} ${end.year}';
}

/// 10:30 or 15:00 in India (UTC+5:30, no daylight saving), as a UTC instant.
DateTime indiaInstant(DateTime date, int hour, int minute) {
  final day = dateOnly(date);
  return DateTime.utc(day.year, day.month, day.day, hour, minute)
      .subtract(const Duration(hours: 5, minutes: 30));
}

/// Calendar date in India for a UTC instant.
DateTime indiaDate(DateTime instantUtc) {
  final ist = instantUtc.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime(ist.year, ist.month, ist.day);
}

/// Calendar date without time (local timezone).
DateTime parseDateOnly(String yyyyMmDd) {
  final parts = yyyyMmDd.split('-');
  if (parts.length != 3) {
    return DateTime.parse(yyyyMmDd);
  }
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

DateTime dateOnly(DateTime date) =>
    DateTime(date.year, date.month, date.day);

bool sameCalendarDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

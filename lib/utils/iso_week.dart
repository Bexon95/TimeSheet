/// ISO 8601 week helpers (Monday-based weeks).
class IsoWeek {
  IsoWeek._();

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Monday 00:00 of the week containing [date].
  static DateTime mondayOf(DateTime date) {
    final d = dateOnly(date);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  /// ISO week number (1–53) for [date].
  static int weekNumber(DateTime date) {
    final thursday = dateOnly(date).add(
      Duration(days: DateTime.thursday - date.weekday),
    );
    final year = thursday.year;
    final jan4 = DateTime(year, 1, 4);
    final week1Monday = mondayOf(jan4);
    return ((thursday.difference(week1Monday).inDays) / 7).floor() + 1;
  }

  /// All week-start Mondays from [firstMonday] through weeks overlapping [lastDay].
  static List<DateTime> allWeekStarts({
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    var monday = mondayOf(rangeStart);
    final end = dateOnly(rangeEnd);
    final weeks = <DateTime>[];
    while (!monday.isAfter(end)) {
      weeks.add(monday);
      monday = monday.add(const Duration(days: 7));
    }
    return weeks;
  }
}

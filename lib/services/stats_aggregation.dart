import '../database/models.dart';
import 'formatters.dart';

class ChartDataPoint {
  ChartDataPoint({
    required this.label,
    required this.start,
    required this.end,
    required this.hours,
    required this.earned,
  });

  final String label;
  final DateTime start;
  final DateTime end;
  final double hours;
  final double earned;
}

class StatsAggregation {
  static List<ChartDataPoint> aggregate(
    List<TimeEntry> entries,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final buckets = <String, ChartDataPoint>{};

    for (final entry in entries) {
      final keyDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (keyDate.isBefore(_day(rangeStart)) || keyDate.isAfter(_day(rangeEnd))) {
        continue;
      }

      final bucketStart = keyDate;
      final bucketEnd = keyDate;
      final label = AppFormatters.shortDate(keyDate);

      final key = bucketStart.toIso8601String();
      final existing = buckets[key];
      if (existing == null) {
        buckets[key] = ChartDataPoint(
          label: label,
          start: bucketStart,
          end: bucketEnd,
          hours: entry.hours,
          earned: entry.earned,
        );
      } else {
        buckets[key] = ChartDataPoint(
          label: existing.label,
          start: existing.start,
          end: existing.end,
          hours: existing.hours + entry.hours,
          earned: existing.earned + entry.earned,
        );
      }
    }

    final sorted = buckets.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return sorted;
  }

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

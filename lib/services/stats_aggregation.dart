import '../database/models.dart';
import 'formatters.dart';

enum ChartBucket { day, week, month }

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
  static ChartBucket bucketForRange(DateTime start, DateTime end) {
    final days = end.difference(start).inDays + 1;
    if (days <= 14) return ChartBucket.day;
    if (days <= 90) return ChartBucket.week;
    return ChartBucket.month;
  }

  static List<ChartDataPoint> aggregate(
    List<TimeEntry> entries,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final bucket = bucketForRange(rangeStart, rangeEnd);
    final buckets = <String, ChartDataPoint>{};

    for (final entry in entries) {
      final keyDate = DateTime(entry.date.year, entry.date.month, entry.date.day);
      if (keyDate.isBefore(_day(rangeStart)) || keyDate.isAfter(_day(rangeEnd))) {
        continue;
      }

      late DateTime bucketStart;
      late DateTime bucketEnd;
      late String label;

      switch (bucket) {
        case ChartBucket.day:
          bucketStart = keyDate;
          bucketEnd = keyDate;
          label = AppFormatters.shortDate(keyDate);
        case ChartBucket.week:
          final weekday = keyDate.weekday;
          bucketStart = keyDate.subtract(Duration(days: weekday - 1));
          bucketEnd = bucketStart.add(const Duration(days: 6));
          label = AppFormatters.shortDate(bucketStart);
        case ChartBucket.month:
          bucketStart = DateTime(keyDate.year, keyDate.month, 1);
          bucketEnd = DateTime(keyDate.year, keyDate.month + 1, 0);
          label = '${keyDate.month.toString().padLeft(2, '0')}/${keyDate.year % 100}';
      }

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

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timesheet/database/models.dart';
import 'package:timesheet/services/stats_aggregation.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
  });
  test('bucketForRange picks day for short ranges', () {
    final start = DateTime(2026, 1, 1);
    final end = DateTime(2026, 1, 10);
    expect(StatsAggregation.bucketForRange(start, end), ChartBucket.day);
  });

  test('aggregate sums hours per day', () {
    final start = DateTime(2026, 1, 1);
    final end = DateTime(2026, 1, 2);
    final entries = [
      TimeEntry(
        id: 1,
        workplaceId: 1,
        date: DateTime(2026, 1, 1),
        startTime: DateTime(2026, 1, 1, 9),
        endTime: DateTime(2026, 1, 1, 11),
        hourlyRate: 60,
      ),
      TimeEntry(
        id: 2,
        workplaceId: 1,
        date: DateTime(2026, 1, 2),
        startTime: DateTime(2026, 1, 2, 9),
        endTime: DateTime(2026, 1, 2, 10, 30),
        hourlyRate: 60,
      ),
    ];

    final points = StatsAggregation.aggregate(entries, start, end);
    expect(points.length, 2);
    expect(points.first.hours, 2);
    expect(points.last.hours, 1.5);
  });
}

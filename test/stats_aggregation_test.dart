import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timesheet/database/models.dart';
import 'package:timesheet/services/stats_aggregation.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
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

  test('aggregate keeps one bar per calendar day for long ranges', () {
    final start = DateTime(2026, 1, 1);
    final end = DateTime(2026, 3, 31);
    final entries = [
      TimeEntry(
        id: 1,
        workplaceId: 1,
        date: DateTime(2026, 1, 5),
        startTime: DateTime(2026, 1, 5, 9),
        endTime: DateTime(2026, 1, 5, 10),
        hourlyRate: 60,
      ),
      TimeEntry(
        id: 2,
        workplaceId: 1,
        date: DateTime(2026, 2, 10),
        startTime: DateTime(2026, 2, 10, 14),
        endTime: DateTime(2026, 2, 10, 16),
        hourlyRate: 60,
      ),
    ];

    final points = StatsAggregation.aggregate(entries, start, end);
    expect(points.length, 2);
    expect(points.first.label, '05.01.');
    expect(points.last.label, '10.02.');
  });
}

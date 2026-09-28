import 'package:flutter_test/flutter_test.dart';
import 'package:timesheet/database/models.dart';
import 'package:timesheet/services/chart_timeline.dart';

void main() {
  test('cumulativeEarned sums day by day', () {
    final start = DateTime(2026, 9, 1);
    final end = DateTime(2026, 9, 3);
    final entries = [
      TimeEntry(
        id: 1,
        workplaceId: 1,
        date: DateTime(2026, 9, 1),
        startTime: DateTime(2026, 9, 1, 9),
        endTime: DateTime(2026, 9, 1, 10),
        hourlyRate: 100,
      ),
      TimeEntry(
        id: 2,
        workplaceId: 1,
        date: DateTime(2026, 9, 3),
        startTime: DateTime(2026, 9, 3, 9),
        endTime: DateTime(2026, 9, 3, 11),
        hourlyRate: 100,
      ),
    ];
    final slots = ChartTimeline.build(entries, start, end);
    expect(ChartTimeline.cumulativeEarned(slots), [100, 100, 300]);
  });

  test('build fills every day in range', () {
    final start = DateTime(2026, 9, 1);
    final end = DateTime(2026, 9, 30);
    final slots = ChartTimeline.build([], start, end);
    expect(slots.length, 30);
    expect(slots.first.day, start);
    expect(slots.last.day, end);
  });

  test('build keeps one slot per day for long ranges', () {
    final start = DateTime(2023, 1, 1);
    final end = DateTime(2023, 12, 31);
    final entries = [
      TimeEntry(
        id: 1,
        workplaceId: 1,
        date: DateTime(2023, 6, 7),
        startTime: DateTime(2023, 6, 7, 9),
        endTime: DateTime(2023, 6, 7, 11),
        hourlyRate: 100,
      ),
      TimeEntry(
        id: 2,
        workplaceId: 1,
        date: DateTime(2023, 11, 20),
        startTime: DateTime(2023, 11, 20, 9),
        endTime: DateTime(2023, 11, 20, 10),
        hourlyRate: 100,
      ),
    ];
    final slots = ChartTimeline.build(entries, start, end);
    expect(slots.length, 365);
    expect(slots.where((s) => s.hours > 0).length, 2);
  });

  test('build places entry on last day of long custom range', () {
    final start = DateTime(2023, 1, 1);
    final end = DateTime(2023, 12, 31);
    final entries = [
      TimeEntry(
        id: 1,
        workplaceId: 1,
        date: DateTime(2023, 12, 31),
        startTime: DateTime(2023, 12, 31, 9),
        endTime: DateTime(2023, 12, 31, 11),
        hourlyRate: 100,
      ),
    ];

    final slots = ChartTimeline.build(entries, start, end);
    expect(slots.length, 365);
    expect(slots.last.hours, 2);
    expect(slots.first.hours, 0);
  });

  test('build stacks amounts per project per day', () {
    final start = DateTime(2026, 9, 25);
    final end = DateTime(2026, 9, 25);
    final entries = [
      TimeEntry(
        id: 1,
        workplaceId: 1,
        projectId: 10,
        date: DateTime(2026, 9, 25),
        startTime: DateTime(2026, 9, 25, 9),
        endTime: DateTime(2026, 9, 25, 12),
        hourlyRate: 100,
      ),
      TimeEntry(
        id: 2,
        workplaceId: 1,
        projectId: 20,
        date: DateTime(2026, 9, 25),
        startTime: DateTime(2026, 9, 25, 13),
        endTime: DateTime(2026, 9, 25, 15),
        hourlyRate: 100,
      ),
    ];

    final slots = ChartTimeline.build(entries, start, end);
    expect(slots.single.earnedByProject['p_10'], 300);
    expect(slots.single.earnedByProject['p_20'], 200);
    expect(
      ChartProjectSegments.keysForSlots(slots, useMoney: true),
      ['p_10', 'p_20'],
    );
  });
}

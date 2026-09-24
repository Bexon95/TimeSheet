import 'package:flutter_test/flutter_test.dart';
import 'package:timesheet/database/models.dart';

void main() {
  test('time entry end defaults to 30 minutes after start', () {
    final start = DateTime(2026, 1, 1, 9, 0);
    final end = start.add(const Duration(minutes: 30));
    final entry = TimeEntry(
      id: 1,
      workplaceId: 1,
      date: start,
      startTime: start,
      endTime: end,
      hourlyRate: 50,
    );

    expect(entry.durationMinutes, 30);
    expect(entry.earned, 25);
  });
}

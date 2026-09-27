import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timesheet/services/formatters.dart';
import 'package:timesheet/utils/iso_week.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de_DE', null);
  });

  group('IsoWeek', () {    test('week 32 for week starting 3 Aug 2026', () {
      final monday = DateTime(2026, 8, 3);
      expect(IsoWeek.weekNumber(monday), 32);
      expect(IsoWeek.mondayOf(DateTime(2026, 8, 5)), monday);
    });

    test('year boundary week number', () {
      // 29 Dec 2025 is Monday of ISO week 1 of 2026 in some locales;
      // verify mondayOf rolls back correctly.
      final dec29 = DateTime(2025, 12, 29);
      expect(dec29.weekday, DateTime.monday);
      expect(IsoWeek.mondayOf(dec29), DateTime(2025, 12, 29));
      expect(IsoWeek.weekNumber(dec29), greaterThan(0));
    });
  });

  group('entry duration formatters', () {
    test('weekViewEntryLine zero-pads duration', () {
      final start = DateTime(2026, 8, 3, 18, 0);
      final end = DateTime(2026, 8, 3, 18, 30);
      expect(
        AppFormatters.weekViewEntryLine(start, end),
        '18:00-18:30 (00:30h)',
      );
    });

    test('listEntryDuration uses h:mm style', () {
      final start = DateTime(2026, 8, 3, 17, 0);
      final end = DateTime(2026, 8, 3, 18, 0);
      expect(
        AppFormatters.listEntryDuration(start, end),
        '(1h:00m)',
      );
    });

    test('weekdayDayMonthLabel formats Mo., 5. Okt.', () {
      final date = DateTime(2026, 10, 5); // Monday
      expect(date.weekday, DateTime.monday);
      expect(
        AppFormatters.weekdayDayMonthLabel(date),
        'Mo., 5. Okt.',
      );
    });

    test('dayMonthCompact uses full name for Juni', () {
      expect(
        AppFormatters.dayMonthCompact(DateTime(2026, 6, 15)),
        '15. Juni',
      );
    });
  });
}

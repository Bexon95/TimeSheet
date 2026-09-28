import '../providers/providers.dart';
import 'date_only.dart';

enum DateRangePreset { week, twoWeeks, month, custom }

DateRangePreset detectDateRangePreset(DateRange range) {
  final today = dateOnly(DateTime.now());
  final end = dateOnly(range.end);
  final start = dateOnly(range.start);

  if (!sameCalendarDay(end, today)) {
    return DateRangePreset.custom;
  }

  final dayCount = end.difference(start).inDays + 1;
  if (dayCount == 7) return DateRangePreset.week;
  if (dayCount == 14) return DateRangePreset.twoWeeks;

  final monthStart = DateTime(today.year, today.month, 1);
  final monthEnd = DateTime(today.year, today.month + 1, 0);
  if (sameCalendarDay(start, monthStart) && sameCalendarDay(end, monthEnd)) {
    return DateRangePreset.month;
  }

  return DateRangePreset.custom;
}

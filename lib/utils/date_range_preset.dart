import '../providers/providers.dart';
import 'date_only.dart';

enum DateRangePreset { week, twoWeeks, month, all, custom, unbilled }

DateRangePreset detectDateRangePreset(
  DateRange range, {
  DateRange? fullEntrySpan,
  DateRange? unbilledSpan,
}) {
  final today = dateOnly(DateTime.now());
  final end = dateOnly(range.end);
  final start = dateOnly(range.start);

  if (unbilledSpan != null) {
    final uStart = dateOnly(unbilledSpan.start);
    final uEnd = dateOnly(unbilledSpan.end);
    if (sameCalendarDay(start, uStart) &&
        sameCalendarDay(end, uEnd)) {
      return DateRangePreset.unbilled;
    }
  }

  if (fullEntrySpan != null) {
    final spanStart = dateOnly(fullEntrySpan.start);
    final spanEnd = dateOnly(fullEntrySpan.end);
    if (sameCalendarDay(start, spanStart) && sameCalendarDay(end, spanEnd)) {
      return DateRangePreset.all;
    }
  }

  final monthStart = DateTime(today.year, today.month, 1);
  final monthEnd = DateTime(today.year, today.month + 1, 0);
  if (sameCalendarDay(start, monthStart) && sameCalendarDay(end, monthEnd)) {
    return DateRangePreset.month;
  }

  if (!sameCalendarDay(end, today)) {
    return DateRangePreset.custom;
  }

  final dayCount = end.difference(start).inDays + 1;
  if (dayCount == 7) return DateRangePreset.week;
  if (dayCount == 14) return DateRangePreset.twoWeeks;

  return DateRangePreset.custom;
}

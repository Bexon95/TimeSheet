import 'package:intl/intl.dart';

class AppFormatters {
  static final _currency = NumberFormat.currency(
    locale: 'de_DE',
    symbol: 'EUR',
    decimalDigits: 2,
  );

  static final _hours = NumberFormat.decimalPattern('de_DE');
  static final _chartInteger = NumberFormat('#,##0', 'de_DE');

  static final _date = DateFormat('dd.MM.yyyy', 'de_DE');
  static final _dateTime = DateFormat('dd.MM.yyyy HH:mm', 'de_DE');
  static final _time = DateFormat('HH:mm', 'de_DE');
  static final _monthYear = DateFormat('MMMM yyyy', 'de_DE');
  static final _shortDate = DateFormat('dd.MM.', 'de_DE');
  static final _compactDecimal = NumberFormat('#,##0.##', 'de_DE');

  static String money(double amount) => _currency.format(amount);

  static String hours(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String hoursDecimal(double hours) =>
      '${_hours.format(hours)} Std.';

  /// Compact whole-number labels for chart axes (no currency, no decimals).
  static String chartAxisNumber(double value) {
    if (value.abs() < 0.5) return '0';
    return _chartInteger.format(value.round());
  }

  static String date(DateTime date) => _date.format(date);
  static String dateTime(DateTime date) => _dateTime.format(date);
  static String time(DateTime date) => _time.format(date);
  static String monthYear(DateTime date) => _monthYear.format(date);
  static String shortDate(DateTime date) => _shortDate.format(date);

  static String dateRange(DateTime start, DateTime end) {
    if (start.year == end.year &&
        start.month == end.month &&
        start.day == end.day) {
      return date(start);
    }
    return '${date(start)} – ${date(end)}';
  }

  /// Week list / sheet: `6. Juli - 12. Juli` or cross-month range.
  static String weekRangeLong(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    return '${_dayMonthLabel(monday)} - ${_dayMonthLabel(sunday)}';
  }

  /// Sheet title: `Mo., 5. Okt. - So., 11. Okt.`
  static String weekRangeSheetTitle(DateTime monday) {
    final sunday = monday.add(const Duration(days: 6));
    return '${weekdayDayMonthLabel(monday)} - ${weekdayDayMonthLabel(sunday)}';
  }

  /// `Mo., 5. Okt.`
  static String weekdayDayMonthLabel(DateTime date) {
    return '${_weekdayAbbrevComma(date)} ${dayMonthCompact(date)}';
  }

  /// `5. Okt.` or `5. Juni` when the month name has ≤4 letters.
  static String dayMonthCompact(DateTime date) {
    return '${date.day}. ${_monthNameForWeekList(date)}';
  }

  static String _dayMonthLabel(DateTime date) {
    return DateFormat('d. MMMM', 'de_DE').format(date);
  }

  static String _weekdayAbbrevComma(DateTime date) {
    final raw = DateFormat('EE', 'de_DE').format(date);
    final base = raw.replaceAll('.', '').trim();
    return '$base.,';
  }

  /// Full month for ≤4 letters (Mai, Juni, Juli, März); else `Okt.` style.
  static String _monthNameForWeekList(DateTime date) {
    final full = DateFormat('MMMM', 'de_DE').format(date);
    if (full.length <= 4) return full;
    final abbr = DateFormat('MMM', 'de_DE').format(date).replaceAll('.', '').trim();
    return '$abbr.';
  }

  static String weekdayShort(DateTime day) {
    return DateFormat('EE', 'de_DE').format(day).replaceAll('.', '');
  }

  /// `18:00-18:30 (00:30h)`
  static String weekViewEntryLine(DateTime start, DateTime end) {
    final mins = end.difference(start).inMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    final dur =
        '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}h';
    return '${time(start)}-${time(end)} ($dur)';
  }

  /// `(1h:00m)` for week list entry chips.
  static String listEntryDuration(DateTime start, DateTime end) {
    final mins = end.difference(start).inMinutes;
    final h = mins ~/ 60;
    final m = mins % 60;
    return '(${h}h:${m.toString().padLeft(2, '0')}m)';
  }

  /// `+40` or `+40,50` without currency symbol.
  static String compactEarnedPlus(double amount) {
    if ((amount - amount.roundToDouble()).abs() < 0.001) {
      return '+${amount.round()}';
    }
    return '+${_compactDecimal.format(amount)}';
  }

  static String compactEarned(double amount) {
    if ((amount - amount.roundToDouble()).abs() < 0.001) {
      return '${amount.round()}';
    }
    return _compactDecimal.format(amount);
  }

  /// `20,25h` for month section totals.
  static String monthHoursCompact(double hours) =>
      '${_compactDecimal.format(hours)}h';

  /// `0 Stunden 0 Minuten gearbeitet` with singular forms.
  static String workedDurationGerman(double hours) {
    final totalMinutes = (hours * 60).round();
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    final hourWord = h == 1 ? 'Stunde' : 'Stunden';
    final minWord = m == 1 ? 'Minute' : 'Minuten';
    return '$h $hourWord $m $minWord gearbeitet';
  }
}

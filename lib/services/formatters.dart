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
}

import 'dart:math' as math;

import '../database/models.dart';
import 'formatters.dart';

class ChartDaySlot {
  ChartDaySlot({
    required this.day,
    required this.index,
    required this.hours,
    required this.earned,
  });

  final DateTime day;
  final int index;
  final double hours;
  final double earned;

  String get label => AppFormatters.shortDate(day);

  bool get hasData => hours > 0 || earned > 0;
}

class ChartTimeline {
  static const minDateLabelWidth = 46.0;

  static DateTime dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static List<ChartDaySlot> build(
    List<TimeEntry> entries,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final start = dayOnly(rangeStart);
    final end = dayOnly(rangeEnd);
    final dayCount = end.difference(start).inDays + 1;

    final totals = <DateTime, ({double hours, double earned})>{};
    for (final entry in entries) {
      final key = dayOnly(entry.date);
      if (key.isBefore(start) || key.isAfter(end)) continue;
      final existing = totals[key];
      if (existing == null) {
        totals[key] = (hours: entry.hours, earned: entry.earned);
      } else {
        totals[key] = (
          hours: existing.hours + entry.hours,
          earned: existing.earned + entry.earned,
        );
      }
    }

    return List.generate(dayCount, (index) {
      final day = start.add(Duration(days: index));
      final data = totals[day];
      return ChartDaySlot(
        day: day,
        index: index,
        hours: data?.hours ?? 0,
        earned: data?.earned ?? 0,
      );
    });
  }

  static int maxBottomLabels(int rangeDayCount, double chartWidth) {
    var maxLabels = (chartWidth / minDateLabelWidth).floor();
    if (rangeDayCount > 14) {
      maxLabels = math.min(maxLabels, 10);
    }
    if (rangeDayCount > 31) {
      maxLabels = math.min(maxLabels, 8);
    }
    if (rangeDayCount > 90) {
      maxLabels = math.min(maxLabels, 6);
    }
    if (rangeDayCount > 180) {
      maxLabels = math.min(maxLabels, 5);
    }
    return maxLabels.clamp(2, 14);
  }

  /// Day indices (0-based) that should show a date label on the chart X-axis.
  static List<int> bottomLabelIndices({
    required int dayCount,
    required double chartWidth,
  }) {
    if (dayCount <= 0) return const [];
    if (dayCount == 1) return const [0];

    final maxLabels = maxBottomLabels(dayCount, chartWidth);
    if (dayCount <= maxLabels) {
      return List.generate(dayCount, (i) => i);
    }

    final indices = <int>{0, dayCount - 1};
    final step = (dayCount - 1) / (maxLabels - 1);
    for (var i = 1; i < maxLabels - 1; i++) {
      indices.add((step * i).round().clamp(0, dayCount - 1));
    }
    final sorted = indices.toList()..sort();
    return sorted;
  }
}

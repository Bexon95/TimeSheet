import '../database/models.dart';
import 'formatters.dart';

/// Segment key for entries without a project.
const chartNoProjectSegmentKey = '__none__';

class ChartProjectSegments {
  static String keyFor(int? projectId) =>
      projectId == null ? chartNoProjectSegmentKey : 'p_$projectId';

  static int? projectIdFromKey(String key) {
    if (key == chartNoProjectSegmentKey) return null;
    if (!key.startsWith('p_')) return null;
    return int.tryParse(key.substring(2));
  }

  /// Project segment keys sorted by total amount (descending).
  static List<String> keysForSlots(
    List<ChartDaySlot> slots, {
    required bool useMoney,
  }) {
    final totals = <String, double>{};
    for (final slot in slots) {
      final byProject = useMoney ? slot.earnedByProject : slot.hoursByProject;
      for (final entry in byProject.entries) {
        totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
      }
    }
    final entries = totals.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.map((e) => e.key).toList();
  }
}

class ChartDaySlot {
  ChartDaySlot({
    required this.day,
    required this.index,
    required this.hoursByProject,
    required this.earnedByProject,
  });

  final DateTime day;
  final int index;
  final Map<String, double> hoursByProject;
  final Map<String, double> earnedByProject;

  String get label => AppFormatters.shortDate(day);

  double get hours =>
      hoursByProject.values.fold<double>(0, (sum, value) => sum + value);

  double get earned =>
      earnedByProject.values.fold<double>(0, (sum, value) => sum + value);

  bool get hasData => hours > 0 || earned > 0;

  double amountForProject(String segmentKey, {required bool useMoney}) {
    if (useMoney) return earnedByProject[segmentKey] ?? 0;
    return hoursByProject[segmentKey] ?? 0;
  }
}

class ChartTimeline {
  static List<double> cumulativeEarned(List<ChartDaySlot> slots) {
    var sum = 0.0;
    return [for (final slot in slots) sum += slot.earned];
  }

  static DateTime dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  /// Calendar-day addition (avoids DST issues from [Duration] on [DateTime]).
  static DateTime addCalendarDays(DateTime date, int days) {
    final d = dayOnly(date);
    return DateTime(d.year, d.month, d.day + days);
  }

  static List<ChartDaySlot> build(
    List<TimeEntry> entries,
    DateTime rangeStart,
    DateTime rangeEnd,
  ) {
    final start = dayOnly(rangeStart);
    final end = dayOnly(rangeEnd);
    final dayCount = end.difference(start).inDays + 1;

    final totals = <DateTime, Map<String, ({double hours, double earned})>>{};
    for (final entry in entries) {
      final key = dayOnly(entry.date);
      if (key.isBefore(start) || key.isAfter(end)) continue;
      final segmentKey = ChartProjectSegments.keyFor(entry.projectId);
      final dayTotals = totals.putIfAbsent(key, () => {});
      final existing = dayTotals[segmentKey];
      if (existing == null) {
        dayTotals[segmentKey] = (hours: entry.hours, earned: entry.earned);
      } else {
        dayTotals[segmentKey] = (
          hours: existing.hours + entry.hours,
          earned: existing.earned + entry.earned,
        );
      }
    }

    return List.generate(dayCount, (index) {
      final day = addCalendarDays(start, index);
      final dayTotals = totals[day];
      final hoursByProject = <String, double>{};
      final earnedByProject = <String, double>{};
      if (dayTotals != null) {
        for (final entry in dayTotals.entries) {
          hoursByProject[entry.key] = entry.value.hours;
          earnedByProject[entry.key] = entry.value.earned;
        }
      }
      return ChartDaySlot(
        day: day,
        index: index,
        hoursByProject: hoursByProject,
        earnedByProject: earnedByProject,
      );
    });
  }
}

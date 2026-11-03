import 'dart:math' as math;

import 'formatters.dart';

/// Approximate width of a compact chart axis label in logical pixels.
const chartAxisApproxLabelWidth = 36.0;

/// How often to show x-axis labels on the statistics bar chart.
int chartAxisLabelInterval(int pointCount, double chartWidth) {
  if (pointCount <= 1) return 1;
  final capacity = math.max(
    2,
    (chartWidth / chartAxisApproxLabelWidth).floor(),
  );
  final targetLabels = chartWidth < 600
      ? math.min(capacity, 5)
      : math.min(capacity, 10);
  if (pointCount <= targetLabels) return 1;
  return (pointCount / targetLabels).ceil();
}

/// Whether the point at [index] should show an x-axis label.
bool showChartAxisLabel({
  required int index,
  required int pointCount,
  required int interval,
  double chartWidth = 300,
}) {
  if (pointCount <= 1) return index == 0;
  if (index == 0) return true;

  final slotWidth = chartWidth / pointCount;
  final minLabelGap = chartAxisApproxLabelWidth * 1.1;

  if (index == pointCount - 1) {
    if (pointCount == 2 && slotWidth < minLabelGap) return false;
    return true;
  }

  // The last tick always shows [rangeEnd]; skip neighbors that would collide.
  if (index >= pointCount - 2) return false;

  if (pointCount > 2) {
    final gapToLast = (pointCount - 1 - index) * slotWidth;
    if (gapToLast < minLabelGap) return false;
  }

  return index % interval == 0;
}

/// Bottom-axis label for a chart slot; endpoints use the selected range.
String chartBottomAxisLabel({
  required int index,
  required int pointCount,
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required DateTime slotDay,
}) {
  if (index == 0) return AppFormatters.shortDate(rangeStart);
  if (index == pointCount - 1) return AppFormatters.shortDate(rangeEnd);
  return AppFormatters.shortDate(slotDay);
}

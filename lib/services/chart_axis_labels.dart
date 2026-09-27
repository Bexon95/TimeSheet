import 'dart:math' as math;

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
}) {
  if (pointCount <= 1) return index == 0;
  if (index == 0) return true;
  if (index == pointCount - 1) return true;
  if (index == pointCount - 2) return false;
  return index % interval == 0;
}

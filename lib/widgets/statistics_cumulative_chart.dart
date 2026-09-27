import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/chart_axis.dart';
import '../services/chart_axis_labels.dart';
import '../services/chart_timeline.dart';
import '../services/formatters.dart';

/// Cumulative earnings over the selected date range.
class StatisticsCumulativeChart extends StatelessWidget {
  const StatisticsCumulativeChart({
    super.key,
    required this.slots,
  });

  final List<ChartDaySlot> slots;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();

    final cumulative = ChartTimeline.cumulativeEarned(slots);
    final peak = cumulative.isEmpty ? 0.0 : cumulative.last;
    if (peak <= 0) return const SizedBox.shrink();

    final yScale = ChartAxisScale.forPeak(peak);
    final colorScheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: colorScheme.onSurfaceVariant,
        );

    final spots = [
      for (var i = 0; i < slots.length; i++)
        FlSpot(slots[i].index.toDouble(), cumulative[i]),
    ];

    final maxX = slots.length <= 1 ? 1.0 : (slots.length - 1).toDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelInterval =
            chartAxisLabelInterval(slots.length, constraints.maxWidth);

        return LineChart(
          LineChartData(
            minX: 0,
            maxX: maxX,
            minY: 0,
            maxY: yScale.maxY,
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  interval: yScale.interval,
                  getTitlesWidget: (value, meta) {
                    if (value < 0 ||
                        value > yScale.maxY + 0.001 ||
                        !ChartAxisScale.isTickValue(value, yScale.interval)) {
                      return const SizedBox.shrink();
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      child: Text(
                        AppFormatters.chartAxisNumber(value),
                        style: labelStyle,
                        maxLines: 1,
                        softWrap: false,
                        textAlign: TextAlign.right,
                      ),
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: 1,
                  getTitlesWidget: (value, meta) {
                    final i = value.toInt();
                    if (i < 0 || i >= slots.length) {
                      return const SizedBox.shrink();
                    }
                    if (!showChartAxisLabel(
                      index: i,
                      pointCount: slots.length,
                      interval: labelInterval,
                    )) {
                      return const SizedBox.shrink();
                    }
                    final isFirst = i == 0;
                    final isLast = i == slots.length - 1;
                    final textAlign = isFirst
                        ? TextAlign.left
                        : isLast
                            ? TextAlign.right
                            : TextAlign.center;
                    final label = Text(
                      slots[i].label,
                      style: labelStyle?.copyWith(fontWeight: FontWeight.w500),
                      textAlign: textAlign,
                    );
                    if (!isFirst && !isLast) {
                      return SideTitleWidget(
                        axisSide: meta.axisSide,
                        space: 6,
                        child: label,
                      );
                    }
                    return SideTitleWidget(
                      axisSide: meta.axisSide,
                      space: 6,
                      fitInside: SideTitleFitInsideData.fromTitleMeta(
                        meta,
                        distanceFromEdge: 4,
                      ),
                      child: label,
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: colorScheme.primary,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: colorScheme.primary.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

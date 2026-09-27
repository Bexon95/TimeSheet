import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../database/models.dart';
import '../services/chart_axis.dart';
import '../services/chart_axis_labels.dart';
import '../services/chart_timeline.dart';
import '../services/formatters.dart';
import '../utils/chart_colors.dart';

enum ChartMetric { money, hours }

class StatisticsBarChart extends StatelessWidget {
  const StatisticsBarChart({
    super.key,
    required this.slots,
    required this.projects,
    required this.metric,
  });

  final List<ChartDaySlot> slots;
  final List<Project> projects;
  final ChartMetric metric;

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) return const SizedBox.shrink();

    final useMoney = metric == ChartMetric.money;
    final segmentKeys = ChartProjectSegments.keysForSlots(
      slots,
      useMoney: useMoney,
    );
    final preferred = preferredProjectChartColors(
      projects: projects,
      segmentKeys: segmentKeys,
    );
    final segmentColors = chartColorsForSegments(
      segmentKeys: segmentKeys,
      preferred: preferred,
    );
    final noProjectColor =
        Theme.of(context).colorScheme.surfaceContainerHighest;
    if (segmentKeys.contains(chartNoProjectSegmentKey)) {
      segmentColors[chartNoProjectSegmentKey] = noProjectColor;
    }

    final maxTotal = slots.fold<double>(0, (max, slot) {
      final total = useMoney ? slot.earned : slot.hours;
      return total > max ? total : max;
    });
    final yScale = ChartAxisScale.forPeak(maxTotal);

    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelInterval =
            chartAxisLabelInterval(slots.length, constraints.maxWidth);
        final slot = constraints.maxWidth / slots.length;
        final barWidth = (slot * 0.55).clamp(4.0, 10.0);

        BarChartRodData rodForSlot(ChartDaySlot daySlot) {
          var running = 0.0;
          final stackItems = <BarChartRodStackItem>[];
          for (final segmentKey in segmentKeys) {
            final amount =
                daySlot.amountForProject(segmentKey, useMoney: useMoney);
            if (amount <= 0) continue;
            stackItems.add(
              BarChartRodStackItem(
                running,
                running + amount,
                segmentColors[segmentKey]!,
              ),
            );
            running += amount;
          }
          return BarChartRodData(
            toY: running,
            width: barWidth,
            borderRadius: BorderRadius.zero,
            color: segmentKeys.isEmpty
                ? noProjectColor
                : segmentColors[segmentKeys.first]!,
            rodStackItems: stackItems,
          );
        }

        return BarChart(
          BarChartData(
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
            barGroups: [
              for (final daySlot in slots)
                BarChartGroupData(
                  x: daySlot.index,
                  barRods: [rodForSlot(daySlot)],
                ),
            ],
          ),
        );
      },
    );
  }
}

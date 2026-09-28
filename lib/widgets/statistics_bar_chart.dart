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
    required this.rangeStart,
    required this.rangeEnd,
  });

  final List<ChartDaySlot> slots;
  final List<Project> projects;
  final ChartMetric metric;
  final DateTime rangeStart;
  final DateTime rangeEnd;

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
    final barSlots = slots;

    final labelStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
          fontSize: 10,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final labelInterval = chartAxisLabelInterval(
          barSlots.length,
          constraints.maxWidth,
        );
        final slotWidth = constraints.maxWidth / barSlots.length;
        final barWidth = barSlots.length <= 45
            ? (slotWidth * 0.55).clamp(4.0, 10.0)
            : (slotWidth * 1.1).clamp(0.5, 8.0);

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
            groupsSpace: barSlots.length <= 45 ? 2 : 0,
            alignment: barSlots.length <= 45
                ? BarChartAlignment.spaceBetween
                : BarChartAlignment.spaceEvenly,
            gridData: const FlGridData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
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
                    if (i < 0 || i >= barSlots.length) {
                      return const SizedBox.shrink();
                    }
                    if (!showChartAxisLabel(
                      index: i,
                      pointCount: barSlots.length,
                      interval: labelInterval,
                      chartWidth: constraints.maxWidth,
                    )) {
                      return const SizedBox.shrink();
                    }
                    final isFirst = i == 0;
                    final isLast = i == barSlots.length - 1;
                    final textAlign = isFirst
                        ? TextAlign.left
                        : isLast
                            ? TextAlign.right
                            : TextAlign.center;
                    final label = Text(
                      chartBottomAxisLabel(
                        index: i,
                        pointCount: barSlots.length,
                        rangeStart: rangeStart,
                        rangeEnd: rangeEnd,
                        slotDay: barSlots[i].day,
                      ),
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
              for (var i = 0; i < barSlots.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [rodForSlot(barSlots[i])],
                ),
            ],
          ),
        );
      },
    );
  }
}

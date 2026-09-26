import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/formatters.dart';
import '../../services/stats_aggregation.dart';
import '../../widgets/date_range_selector.dart';

enum ChartMetric { money, hours }

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  ChartMetric _metric = ChartMetric.money;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final workplaceId = appState.selectedWorkplaceId;
    final range = appState.dateRange;

    if (workplaceId == null) {
      return const Center(child: Text('Bitte einen Arbeitgeber auswählen.'));
    }

    final entriesAsync = ref.watch(
      entriesProvider(
        EntriesQuery(
          workplaceId: workplaceId,
          start: range.start,
          end: range.end,
        ),
      ),
    );

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (entries) {
        final totalHours = entries.fold<double>(0, (s, e) => s + e.hours);
        final totalEarned = entries.fold<double>(0, (s, e) => s + e.earned);
        final points =
            StatsAggregation.aggregate(entries, range.start, range.end);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const DateRangeSelector(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Stunden'),
                          Text(
                            AppFormatters.hours(totalHours),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Verdienst'),
                          Text(
                            AppFormatters.money(totalEarned),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<ChartMetric>(
              segments: const [
                ButtonSegment(
                  value: ChartMetric.money,
                  label: Text('Geld'),
                ),
                ButtonSegment(
                  value: ChartMetric.hours,
                  label: Text('Stunden'),
                ),
              ],
              selected: {_metric},
              onSelectionChanged: (value) {
                setState(() => _metric = value.first);
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 260,
              child: points.isEmpty
                  ? const Center(child: Text('Keine Daten im Zeitraum.'))
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: BarChart(
                          BarChartData(
                            alignment: BarChartAlignment.spaceAround,
                            maxY: _maxY(points) * 1.2,
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 52,
                                  getTitlesWidget: (value, meta) {
                                    final label = _metric == ChartMetric.money
                                        ? AppFormatters.money(value)
                                        : AppFormatters.hoursDecimal(value);
                                    return SideTitleWidget(
                                      axisSide: meta.axisSide,
                                      child: Text(
                                        label,
                                        style: const TextStyle(fontSize: 10),
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
                                  getTitlesWidget: (value, meta) {
                                    final index = value.toInt();
                                    if (index < 0 || index >= points.length) {
                                      return const SizedBox.shrink();
                                    }
                                    if (points.length > 8 && index.isOdd) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        points[index].label,
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              topTitles: const AxisTitles(),
                              rightTitles: const AxisTitles(),
                            ),
                            gridData: const FlGridData(show: true),
                            borderData: FlBorderData(show: false),
                            barGroups: [
                              for (var i = 0; i < points.length; i++)
                                BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: _metric == ChartMetric.money
                                          ? points[i].earned
                                          : points[i].hours,
                                      color: Theme.of(context).colorScheme.primary,
                                      width: 14,
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  double _maxY(List<ChartDataPoint> points) {
    if (points.isEmpty) return 1;
    return points
        .map((p) => _metric == ChartMetric.money ? p.earned : p.hours)
        .reduce((a, b) => a > b ? a : b);
  }
}

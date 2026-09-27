import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/chart_timeline.dart';
import '../../services/formatters.dart';
import '../../widgets/date_range_selector.dart';

enum ChartMetric { money, hours }

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  ChartMetric _metric = ChartMetric.money;
  int? _filterWorkplaceId;
  bool _filterInitialized = false;

  static const _barWidth = 6.0;
  static const _groupsSpace = 2.0;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final range = appState.dateRange;

    if (!_filterInitialized) {
      _filterWorkplaceId = appState.selectedWorkplaceId;
      _filterInitialized = true;
    }

    if (appState.workplaces.isEmpty) {
      return const Center(child: Text('Bitte einen Arbeitgeber anlegen.'));
    }

    final entriesAsync = ref.watch(
      entriesProvider(
        EntriesQuery(
          workplaceId: _filterWorkplaceId,
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
        final slots = ChartTimeline.build(entries, range.start, range.end);
        final hasChartData = slots.any((slot) => slot.hasData);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DateRangeSelector(
              showWorkplaceFilter: true,
              filterWorkplaceId: _filterWorkplaceId,
              onFilterWorkplaceChanged: (id) {
                setState(() => _filterWorkplaceId = id);
              },
            ),
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
              child: !hasChartData
                  ? const Center(child: Text('Keine Daten im Zeitraum.'))
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final minChartWidth = constraints.maxWidth;
                            final slotWidth = _barWidth + _groupsSpace;
                            final contentWidth =
                                slots.length * slotWidth + 48;
                            final chartWidth = contentWidth > minChartWidth
                                ? contentWidth
                                : minChartWidth;
                            final labelIndices = ChartTimeline.bottomLabelIndices(
                              dayCount: slots.length,
                              chartWidth: chartWidth,
                            );
                            final labelIndexSet = labelIndices.toSet();

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: chartWidth,
                                height: constraints.maxHeight,
                                child: BarChart(
                                  BarChartData(
                                    alignment: BarChartAlignment.start,
                                    groupsSpace: _groupsSpace,
                                    maxY: _maxY(slots) * 1.2,
                                    titlesData: FlTitlesData(
                                      leftTitles: AxisTitles(
                                        sideTitles: SideTitles(
                                          showTitles: true,
                                          reservedSize: 36,
                                          getTitlesWidget: (value, meta) {
                                            return SideTitleWidget(
                                              axisSide: meta.axisSide,
                                              child: Text(
                                                AppFormatters.chartAxisNumber(
                                                  value,
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
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
                                          reservedSize: 28,
                                          interval: 1,
                                          getTitlesWidget: (value, meta) {
                                            final index = value.toInt();
                                            if (index < 0 ||
                                                index >= slots.length) {
                                              return const SizedBox.shrink();
                                            }
                                            if (!labelIndexSet.contains(index)) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                top: 8,
                                              ),
                                              child: Text(
                                                slots[index].label,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                ),
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
                                      for (final slot in slots)
                                        if (slot.hasData)
                                          BarChartGroupData(
                                            x: slot.index,
                                            barRods: [
                                              BarChartRodData(
                                                toY: _metric == ChartMetric.money
                                                    ? slot.earned
                                                    : slot.hours,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                width: _barWidth,
                                              ),
                                            ],
                                          ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  double _maxY(List<ChartDaySlot> slots) {
    final values = slots
        .where((s) => s.hasData)
        .map((s) => _metric == ChartMetric.money ? s.earned : s.hours);
    if (values.isEmpty) return 1;
    return values.reduce((a, b) => a > b ? a : b);
  }
}

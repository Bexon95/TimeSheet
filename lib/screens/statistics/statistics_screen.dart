import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/chart_timeline.dart';
import '../../services/formatters.dart';
import '../../widgets/date_range_selector.dart';
import '../../widgets/statistics_bar_chart.dart';
import '../../widgets/statistics_cumulative_chart.dart';

class StatisticsScreen extends ConsumerStatefulWidget {
  const StatisticsScreen({super.key});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  ChartMetric _metric = ChartMetric.money;
  int? _filterWorkplaceId;
  bool _filterInitialized = false;

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final range = appState.dateRange;

    if (!_filterInitialized) {
      _filterWorkplaceId = appState.selectedWorkplaceId;
      _filterInitialized = true;
    }

    ref.listen(
      appStateProvider.select((s) => s.selectedWorkplaceId),
      (previous, next) {
        if (previous != next) {
          setState(() => _filterWorkplaceId = next);
        }
      },
    );

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
    final projects = ref.watch(chartProjectsProvider).valueOrNull ?? [];

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (entries) {
        final totalHours = entries.fold<double>(0, (s, e) => s + e.hours);
        final totalEarned = entries.fold<double>(0, (s, e) => s + e.earned);
        final slots = ChartTimeline.build(entries, range.start, range.end);
        final hasChartData = slots.any((slot) => slot.hasData);
        final hasEarnedData = slots.any((slot) => slot.earned > 0);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DateRangeSelector(
              prominentRangeLabel: true,
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
                        padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                        child: StatisticsBarChart(
                          slots: slots,
                          projects: projects,
                          metric: _metric,
                          rangeStart: range.start,
                          rangeEnd: range.end,
                        ),
                      ),
                    ),
            ),
            if (hasEarnedData) ...[
              const SizedBox(height: 16),
              Text(
                'Verdienst insgesamt',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 12, 12, 12),
                    child: StatisticsCumulativeChart(
                      slots: slots,
                      rangeStart: range.start,
                      rangeEnd: range.end,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

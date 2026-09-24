import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/providers.dart';
import '../../services/formatters.dart';
import '../../widgets/date_range_selector.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(appStateProvider).dateRange;
    final summariesAsync = ref.watch(workplaceSummariesProvider(range));

    return summariesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (summaries) {
        final totalHours =
            summaries.fold<double>(0, (sum, item) => sum + item.hours);
        final totalEarned =
            summaries.fold<double>(0, (sum, item) => sum + item.earned);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const DateRangeSelector(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _SummaryCard(
                    title: 'Gesamtstunden',
                    value: AppFormatters.hours(totalHours),
                    icon: Icons.schedule,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(
                    title: 'Gesamtverdienst',
                    value: AppFormatters.money(totalEarned),
                    icon: Icons.euro,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Nach Arbeitgeber',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (summaries.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Noch keine Arbeitgeber angelegt.'),
                ),
              )
            else
              ...summaries.map(
                (summary) => Card(
                  child: ListTile(
                    title: Text(summary.workplace.name),
                    subtitle: Text(AppFormatters.hours(summary.hours)),
                    trailing: Text(
                      AppFormatters.money(summary.earned),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    onTap: () => ref
                        .read(appStateProvider.notifier)
                        .selectWorkplace(summary.workplace.id),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

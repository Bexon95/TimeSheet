import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/formatters.dart';
import 'workplace_filter_chips.dart';

class DateRangeSelector extends ConsumerWidget {
  const DateRangeSelector({
    super.key,
    this.showWorkplaceFilter = false,
    this.filterWorkplaceId,
    this.onFilterWorkplaceChanged,
    this.prominentRangeLabel = false,
  });

  final bool showWorkplaceFilter;
  final bool prominentRangeLabel;
  final int? filterWorkplaceId;
  final ValueChanged<int?>? onFilterWorkplaceChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final range = appState.dateRange;
    final workplaces = appState.workplaces;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppFormatters.dateRange(range.start, range.end),
              style: prominentRangeLabel
                  ? Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      )
                  : Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickChip(
                    label: 'Woche',
                    onTap: () => _setQuickRange(ref, 7),
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: '2 Wochen',
                    onTap: () => _setQuickRange(ref, 14),
                  ),
                  const SizedBox(width: 8),
                  _QuickChip(
                    label: 'Monat',
                    onTap: () => _setMonth(ref),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Benutzerdefiniert'),
                    onPressed: () => _pickCustom(context, ref),
                  ),
                ],
              ),
            ),
            if (showWorkplaceFilter &&
                onFilterWorkplaceChanged != null) ...[
              const SizedBox(height: 8),
              WorkplaceFilterChips(
                workplaces: workplaces,
                selectedWorkplaceId: filterWorkplaceId,
                onSelected: onFilterWorkplaceChanged!,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _setQuickRange(WidgetRef ref, int days) {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days - 1));
    ref.read(appStateProvider.notifier).setDateRange(
          DateRange(
            start: DateTime(start.year, start.month, start.day),
            end: DateTime(end.year, end.month, end.day),
          ),
        );
  }

  void _setMonth(WidgetRef ref) {
    final now = DateTime.now();
    ref.read(appStateProvider.notifier).setDateRange(
          DateRange(
            start: DateTime(now.year, now.month, 1),
            end: DateTime(now.year, now.month + 1, 0),
          ),
        );
  }

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final appState = ref.read(appStateProvider);
    final initial = appState.savedCustomDateRange ?? appState.dateRange;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: initial.start, end: initial.end),
      locale: const Locale('de', 'DE'),
    );
    if (picked != null) {
      await ref.read(appStateProvider.notifier).setCustomDateRange(
            DateRange(start: picked.start, end: picked.end),
          );
    }
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label), onPressed: onTap);
  }
}

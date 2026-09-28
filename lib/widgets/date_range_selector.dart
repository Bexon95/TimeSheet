import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/formatters.dart';
import '../utils/date_range_preset.dart';
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
    final activePreset = detectDateRangePreset(range);

    final rangeStyle = prominentRangeLabel
        ? Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            )
        : Theme.of(context).textTheme.titleMedium;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => _pickCustom(context, ref),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  AppFormatters.dateRange(range.start, range.end),
                  style: rangeStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Woche'),
                    selected: activePreset == DateRangePreset.week,
                    onSelected: (_) => _setQuickRange(ref, 7),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('2 Wochen'),
                    selected: activePreset == DateRangePreset.twoWeeks,
                    onSelected: (_) => _setQuickRange(ref, 14),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Monat'),
                    selected: activePreset == DateRangePreset.month,
                    onSelected: (_) => _setMonth(ref),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Benutzerdefiniert'),
                    selected: activePreset == DateRangePreset.custom,
                    onSelected: (_) => _pickCustom(context, ref),
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
            DateRange(
              start: DateTime(
                picked.start.year,
                picked.start.month,
                picked.start.day,
              ),
              end: DateTime(
                picked.end.year,
                picked.end.month,
                picked.end.day,
              ),
            ),
          );
    }
  }
}

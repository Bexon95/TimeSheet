import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../services/formatters.dart';
import '../utils/date_range_preset.dart';
import 'workplace_filter_chips.dart';

class DateRangeSelector extends ConsumerStatefulWidget {
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
  ConsumerState<DateRangeSelector> createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends ConsumerState<DateRangeSelector> {
  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final range = appState.dateRange;
    final workplaces = appState.workplaces;
    final entrySpan = ref.watch(entryDateSpanProvider).valueOrNull;
    final unbilledSpan = ref.watch(unbilledEntrySpanProvider).valueOrNull;
    final activePreset = detectDateRangePreset(
      range,
      fullEntrySpan: entrySpan,
      unbilledSpan: unbilledSpan,
    );

    ref.listen(unbilledEntrySpanProvider, (previous, next) {
      next.whenData((span) async {
        if (span == null) return;
        final current = ref.read(appStateProvider).dateRange;
        final entrySpan = ref.read(entryDateSpanProvider).valueOrNull;
        final preset = detectDateRangePreset(
          current,
          fullEntrySpan: entrySpan,
          unbilledSpan: span,
        );
        if (preset != DateRangePreset.unbilled) return;
        if (current == span) return;
        await ref.read(appStateProvider.notifier).setCustomDateRange(span);
      });
    });

    final rangeStyle = widget.prominentRangeLabel
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
                    showCheckmark: false,
                    selected: activePreset == DateRangePreset.week,
                    onSelected: (_) => _setQuickRange(ref, 7),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('2 Wochen'),
                    showCheckmark: false,
                    selected: activePreset == DateRangePreset.twoWeeks,
                    onSelected: (_) => _setQuickRange(ref, 14),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Monat'),
                    showCheckmark: false,
                    selected: activePreset == DateRangePreset.month,
                    onSelected: (_) => _setMonth(ref),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Unabgerechnet'),
                    showCheckmark: false,
                    selected: activePreset == DateRangePreset.unbilled,
                    onSelected: (_) =>
                        _setUnbilled(context, ref, unbilledSpan),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Benutzerdefiniert'),
                    showCheckmark: false,
                    selected: activePreset == DateRangePreset.custom,
                    onSelected: (_) => _pickCustom(context, ref),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Alle'),
                    showCheckmark: false,
                    selected: activePreset == DateRangePreset.all,
                    onSelected: (_) => _setAll(context, ref),
                  ),
                ],
              ),
            ),
            if (widget.showWorkplaceFilter &&
                widget.onFilterWorkplaceChanged != null) ...[
              const SizedBox(height: 8),
              WorkplaceFilterChips(
                workplaces: workplaces,
                selectedWorkplaceId: widget.filterWorkplaceId,
                onSelected: widget.onFilterWorkplaceChanged!,
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

  Future<void> _setUnbilled(
    BuildContext context,
    WidgetRef ref,
    DateRange? unbilledSpan,
  ) async {
    if (unbilledSpan != null) {
      await ref.read(appStateProvider.notifier).setCustomDateRange(unbilledSpan);
      return;
    }
    final workplaceId = ref.read(appStateProvider).selectedWorkplaceId;
    if (workplaceId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bitte zuerst einen Arbeitgeber auswählen.'),
          ),
        );
      }
      return;
    }
    final span =
        await ref.read(databaseProvider).getUnbilledDateSpan(workplaceId);
    if (span == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine unabgerechneten Einträge.')),
        );
      }
      return;
    }
    await ref.read(appStateProvider.notifier).setCustomDateRange(
          DateRange(
            start: DateTime(span.start.year, span.start.month, span.start.day),
            end: DateTime(span.end.year, span.end.month, span.end.day),
          ),
        );
  }

  Future<void> _setAll(BuildContext context, WidgetRef ref) async {
    var range = ref.read(entryDateSpanProvider).valueOrNull;
    if (range == null) {
      final span = await ref.read(databaseProvider).getEntryDateSpan();
      if (span == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Noch keine Einträge vorhanden.')),
          );
        }
        return;
      }
      range = DateRange(
        start: DateTime(span.start.year, span.start.month, span.start.day),
        end: DateTime(span.end.year, span.end.month, span.end.day),
      );
    }
    await ref.read(appStateProvider.notifier).setDateRange(range);
  }

  Future<void> _pickCustom(BuildContext context, WidgetRef ref) async {
    final appState = ref.read(appStateProvider);
    final initial = appState.savedCustomDateRange ?? appState.dateRange;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(start: initial.start, end: initial.end),
      initialEntryMode: DatePickerEntryMode.calendar,
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

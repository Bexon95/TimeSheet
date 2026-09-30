import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/models.dart';
import '../../providers/providers.dart';
import '../../services/formatters.dart';
import '../../utils/iso_week.dart';
import 'calendar_view_mode.dart';
import '../../widgets/time_entry_form.dart';

Future<void> showWeekDetailSheet(
  BuildContext context, {
  required Workplace workplace,
  required DateTime weekMonday,
  VoidCallback? onChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => WeekDetailSheet(
      workplace: workplace,
      weekMonday: IsoWeek.dateOnly(weekMonday),
      onChanged: onChanged,
    ),
  );
}

class WeekDetailSheet extends ConsumerStatefulWidget {
  const WeekDetailSheet({
    super.key,
    required this.workplace,
    required this.weekMonday,
    this.onChanged,
  });

  final Workplace workplace;
  final DateTime weekMonday;
  final VoidCallback? onChanged;

  @override
  ConsumerState<WeekDetailSheet> createState() => _WeekDetailSheetState();
}

class _WeekDetailSheetState extends ConsumerState<WeekDetailSheet> {
  double _hours = 0;
  double _earned = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTotals();
  }

  Future<void> _loadTotals() async {
    final end = widget.weekMonday.add(const Duration(days: 6));
    final entries = await ref.read(databaseProvider).getEntries(
          workplaceId: widget.workplace.id,
          start: widget.weekMonday,
          end: end,
        );
    var hours = 0.0;
    var earned = 0.0;
    for (final e in entries) {
      hours += e.hours;
      earned += e.earned;
    }
    if (mounted) {
      setState(() {
        _hours = hours;
        _earned = earned;
        _loading = false;
      });
    }
  }

  Future<void> _addEntry(DateTime day) async {
    setCalendarSelectedDay(ref, day);
    Navigator.pop(context);
    await showTimeEntryForm(
      context,
      workplace: widget.workplace,
      initialDate: day,
      defaultNoon: true,
    );
    bumpRefresh(ref);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final weekendColor = Colors.amber.shade400;
    final days = List.generate(
      7,
      (i) => widget.weekMonday.add(Duration(days: i)),
    );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              AppFormatters.weekRangeCompact(widget.weekMonday),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Woche ${IsoWeek.weekNumber(widget.weekMonday)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else ...[
              Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(AppFormatters.workedDurationGerman(_hours)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.payments_outlined,
                    size: 20,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${AppFormatters.compactEarned(_earned)} gesamt verdient',
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                for (final day in days)
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '${day.day}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: day.weekday >= DateTime.saturday
                                ? weekendColor
                                : null,
                          ),
                        ),
                        Text(
                          AppFormatters.weekdayShort(day),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: day.weekday >= DateTime.saturday
                                ? weekendColor
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Material(
                          color: theme.colorScheme.surfaceContainerHighest,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _addEntry(day),
                            child: const SizedBox(
                              width: 40,
                              height: 40,
                              child: Icon(Icons.add, size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

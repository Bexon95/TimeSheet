import 'package:flutter/material.dart';

import '../database/models.dart';
import '../services/formatters.dart';
import '../utils/project_colors.dart';
import '../widgets/time_entry_form.dart';

class WeekEntryRow extends StatelessWidget {
  const WeekEntryRow({
    super.key,
    required this.entry,
    required this.workplace,
    this.project,
    required this.onChanged,
  });

  final TimeEntry entry;
  final Workplace workplace;
  final Project? project;
  final VoidCallback onChanged;

  static const _weekendColor = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWeekend = entry.date.weekday >= DateTime.saturday;
    final barColor = theme.colorScheme.primaryContainer;
    final accent = project != null
        ? projectColor(project!.colorValue)
        : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 32,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${entry.date.day}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                      color: isWeekend ? _weekendColor : null,
                    ),
                  ),
                  Text(
                    AppFormatters.weekdayShort(entry.date),
                    style: theme.textTheme.labelSmall?.copyWith(
                      height: 1.1,
                      color: isWeekend
                          ? _weekendColor
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Material(
                color: barColor.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () async {
                    await showTimeEntryForm(
                      context,
                      workplace: workplace,
                      entry: entry,
                    );
                    onChanged();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 3,
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${AppFormatters.time(entry.startTime)} - '
                            '${AppFormatters.time(entry.endTime)} '
                            '${AppFormatters.listEntryDuration(entry.startTime, entry.endTime)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Text(
                          AppFormatters.compactEarnedPlus(entry.earned),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

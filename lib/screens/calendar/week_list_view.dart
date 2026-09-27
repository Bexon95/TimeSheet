import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../../database/database_helper.dart';
import '../../database/models.dart';
import '../../providers/providers.dart';
import '../../services/formatters.dart';
import '../../utils/iso_week.dart';
import '../../utils/project_colors.dart';
import '../../widgets/time_entry_form.dart';
import 'calendar_view_mode.dart';
import 'week_detail_sheet.dart';

sealed class _WeekListRow {}

class _MonthHeaderRow extends _WeekListRow {
  _MonthHeaderRow({
    required this.monthStart,
    required this.hours,
    required this.earned,
  });

  final DateTime monthStart;
  final double hours;
  final double earned;
}

class _CalendarWeekRow extends _WeekListRow {
  _CalendarWeekRow({
    required this.weekMonday,
    required this.entries,
  });

  final DateTime weekMonday;
  final List<TimeEntry> entries;
}

class WeekListView extends ConsumerStatefulWidget {
  const WeekListView({
    super.key,
    required this.workplace,
  });

  final Workplace workplace;

  @override
  ConsumerState<WeekListView> createState() => _WeekListViewState();
}

class _WeekListViewState extends ConsumerState<WeekListView> {
  final ItemScrollController _scrollController = ItemScrollController();
  final ItemPositionsListener _positionsListener =
      ItemPositionsListener.create();

  List<_WeekListRow> _rows = [];
  bool _loading = true;
  bool _didInitialScroll = false;
  Map<int, Project> _projects = {};

  static final _rangeStart = DateTime(2020, 1, 1);
  static final _rangeEnd = DateTime(2100, 12, 31);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant WeekListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workplace.id != widget.workplace.id) {
      _didInitialScroll = false;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final db = DatabaseHelper.instance;
    final entries = await db.getEntries(workplaceId: widget.workplace.id);
    final projects = await db.getProjectsForWorkplace(widget.workplace.id);
    final projectMap = {for (final p in projects) p.id: p};

    final monthTotals = <String, ({double hours, double earned})>{};
    for (final entry in entries) {
      final key = '${entry.date.year}-${entry.date.month}';
      final existing = monthTotals[key];
      monthTotals[key] = (
        hours: (existing?.hours ?? 0) + entry.hours,
        earned: (existing?.earned ?? 0) + entry.earned,
      );
    }

    final byWeek = <DateTime, List<TimeEntry>>{};
    for (final entry in entries) {
      final monday = IsoWeek.dateOnly(IsoWeek.mondayOf(entry.date));
      byWeek.putIfAbsent(monday, () => []).add(entry);
    }
    for (final list in byWeek.values) {
      list.sort((a, b) {
        final dayCmp = a.date.compareTo(b.date);
        if (dayCmp != 0) return dayCmp;
        return a.startTime.compareTo(b.startTime);
      });
    }

    final weekStarts = IsoWeek.allWeekStarts(
      rangeStart: _rangeStart,
      rangeEnd: _rangeEnd,
    );

    final rows = <_WeekListRow>[];
    int? lastHeaderMonthKey;

    for (final monday in weekStarts) {
      final monthKey = monday.year * 100 + monday.month;
      if (lastHeaderMonthKey != monthKey) {
        lastHeaderMonthKey = monthKey;
        final totalsKey = '${monday.year}-${monday.month}';
        final totals = monthTotals[totalsKey];
        rows.add(
          _MonthHeaderRow(
            monthStart: DateTime(monday.year, monday.month, 1),
            hours: totals?.hours ?? 0,
            earned: totals?.earned ?? 0,
          ),
        );
      }
      rows.add(
        _CalendarWeekRow(
          weekMonday: IsoWeek.dateOnly(monday),
          entries: byWeek[IsoWeek.dateOnly(monday)] ?? const [],
        ),
      );
    }

    if (mounted) {
      setState(() {
        _rows = rows;
        _projects = projectMap;
        _loading = false;
      });
      _scrollToCurrentWeek();
    }
  }

  void _scrollToCurrentWeek() {
    if (_didInitialScroll) return;
    final currentMonday = IsoWeek.mondayOf(DateTime.now());
    var index = -1;
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      if (row is _CalendarWeekRow &&
          row.weekMonday == IsoWeek.dateOnly(currentMonday)) {
        index = i;
        break;
      }
    }
    if (index < 0) return;
    _didInitialScroll = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.isAttached) {
        _scrollController.jumpTo(index: index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTriggerProvider, (_, __) => _load());

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ScrollablePositionedList.builder(
      itemScrollController: _scrollController,
      itemPositionsListener: _positionsListener,
      itemCount: _rows.length,
      itemBuilder: (context, index) {
        final row = _rows[index];
        return switch (row) {
          _MonthHeaderRow(:final monthStart, :final hours, :final earned) =>
            _MonthHeader(
              monthStart: monthStart,
              hours: hours,
              earned: earned,
            ),
          _CalendarWeekRow(:final weekMonday, :final entries) =>
            _WeekBlock(
              workplace: widget.workplace,
              weekMonday: weekMonday,
              entries: entries,
              projects: _projects,
              onWeekTap: () {
                setCalendarSelectedDay(ref, weekMonday);
                showWeekDetailSheet(
                  context,
                  workplace: widget.workplace,
                  weekMonday: weekMonday,
                  onChanged: _load,
                );
              },
              onEntryChanged: () {
                bumpRefresh(ref);
                _load();
              },
            ),
        };
      },
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.monthStart,
    required this.hours,
    required this.earned,
  });

  final DateTime monthStart;
  final double hours;
  final double earned;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline,
            width: 1.5,
          ),
        ),
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.65,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppFormatters.monthYear(monthStart),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppFormatters.monthHoursCompact(hours),
            style: theme.textTheme.bodyMedium,
          ),
          Text(
            AppFormatters.money(earned),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _WeekBlock extends StatelessWidget {
  const _WeekBlock({
    required this.workplace,
    required this.weekMonday,
    required this.entries,
    required this.projects,
    required this.onWeekTap,
    required this.onEntryChanged,
  });

  final Workplace workplace;
  final DateTime weekMonday;
  final List<TimeEntry> entries;
  final Map<int, Project> projects;
  final VoidCallback onWeekTap;
  final VoidCallback onEntryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekHeaderRow(weekMonday: weekMonday, onTap: onWeekTap),
        for (final entry in entries)
          _WeekEntryRow(
            entry: entry,
            workplace: workplace,
            project:
                entry.projectId != null ? projects[entry.projectId] : null,
            onChanged: onEntryChanged,
          ),
      ],
    );
  }
}

class _WeekHeaderRow extends StatelessWidget {
  const _WeekHeaderRow({
    required this.weekMonday,
    required this.onTap,
  });

  final DateTime weekMonday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppFormatters.weekRangeLong(weekMonday),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Woche ${IsoWeek.weekNumber(weekMonday)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekEntryRow extends StatelessWidget {
  const _WeekEntryRow({
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

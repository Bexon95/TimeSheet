import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../database/database_helper.dart';
import '../../database/models.dart';
import '../../providers/providers.dart';
import '../../services/formatters.dart';
import '../../utils/project_colors.dart';
import '../../widgets/time_entry_form.dart';
import 'calendar_view_mode.dart';
import 'week_list_view.dart';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, _DayMarkerInfo> _markers = {};
  double _monthHours = 0;
  double _monthEarned = 0;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadMarkers();
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadMarkers() async {
    final workplaceId = ref.read(appStateProvider).selectedWorkplaceId;
    if (workplaceId == null) return;

    final start = DateTime(_focusedDay.year, _focusedDay.month, 1);
    final end = DateTime(_focusedDay.year, _focusedDay.month + 1, 0);
    final entries = await DatabaseHelper.instance.getEntries(
      workplaceId: workplaceId,
      start: start,
      end: end,
    );
    final projects =
        await DatabaseHelper.instance.getProjectsForWorkplace(workplaceId);
    final projectColors = {
      for (final p in projects) p.id: projectColor(p.colorValue),
    };

    final markers = <DateTime, _DayMarkerInfo>{};
    var monthHours = 0.0;
    var monthEarned = 0.0;
    for (final entry in entries) {
      monthHours += entry.hours;
      monthEarned += entry.earned;

      final day = _dateOnly(entry.date);
      final info = markers.putIfAbsent(day, () => _DayMarkerInfo());
      info.earned += entry.earned;
      info.hours += entry.hours;
      info.hasEntries = true;
      final color = entry.projectId != null
          ? (projectColors[entry.projectId] ?? projectColorPalette.first)
          : projectColorPalette.first;
      info.colors.add(color);
      info.entryPreviews.add(
        _DayEntryPreview(
          startTime: entry.startTime,
          endTime: entry.endTime,
          color: color,
        ),
      );
    }
    for (final info in markers.values) {
      info.entryPreviews.sort(
        (a, b) => a.startTime.compareTo(b.startTime),
      );
    }

    if (mounted) {
      setState(() {
        _markers = markers;
        _monthHours = monthHours;
        _monthEarned = monthEarned;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final workplaceId = ref.watch(appStateProvider).selectedWorkplaceId;
    final workplace = ref.watch(appStateProvider).workplaces
        .where((w) => w.id == workplaceId)
        .firstOrNull;

    ref.listen(appStateProvider.select((s) => s.selectedWorkplaceId), (
      _,
      _,
    ) {
      _loadMarkers();
    });

    ref.listen(refreshTriggerProvider, (_, __) {
      _loadMarkers();
    });

    if (workplace == null) {
      return const Center(
        child: Text('Bitte einen Arbeitgeber in der Seitenleiste auswählen.'),
      );
    }

    final mode = ref.watch(calendarViewModeProvider);

    return switch (mode) {
      CalendarViewMode.month => _MonthView(
          focusedDay: _focusedDay,
          selectedDay: _selectedDay,
          markers: _markers,
          monthHours: _monthHours,
          monthEarned: _monthEarned,
          onDaySelected: (day) {
            setCalendarSelectedDay(ref, day);
            setState(() {
              _selectedDay = day;
              _focusedDay = day;
            });
            _showDaySheet(context, workplace, day);
          },
          onPageChanged: (day) {
            setState(() => _focusedDay = day);
            _loadMarkers();
          },
        ),
      CalendarViewMode.week => _WeekView(
          workplace: workplace,
          focusedDay: _focusedDay,
          onDaySelected: (day) {
            setCalendarSelectedDay(ref, day);
            setState(() {
              _selectedDay = day;
              _focusedDay = day;
            });
            _showDaySheet(context, workplace, day);
          },
        ),
      CalendarViewMode.day => _DayView(
          workplace: workplace,
          day: _selectedDay ?? DateTime.now(),
          onPreviousDay: () {
            final d = _selectedDay ?? DateTime.now();
            final next = d.subtract(const Duration(days: 1));
            setCalendarSelectedDay(ref, next);
            setState(() => _selectedDay = next);
          },
          onNextDay: () {
            final d = _selectedDay ?? DateTime.now();
            final next = d.add(const Duration(days: 1));
            setCalendarSelectedDay(ref, next);
            setState(() => _selectedDay = next);
          },
        ),
      CalendarViewMode.weekList => WeekListView(workplace: workplace),
    };
  }

  Future<void> _showDaySheet(
    BuildContext context,
    Workplace workplace,
    DateTime day,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _DaySheet(
        workplace: workplace,
        day: day,
        onMarkersChanged: _loadMarkers,
      ),
    );
  }
}

class _DayEntryPreview {
  const _DayEntryPreview({
    required this.startTime,
    required this.endTime,
    required this.color,
  });

  final DateTime startTime;
  final DateTime endTime;
  final Color color;
}

class _DayMarkerInfo {
  bool hasEntries = false;
  double earned = 0;
  double hours = 0;
  final Set<Color> colors = {};
  final List<_DayEntryPreview> entryPreviews = [];
}

class _DaySheet extends ConsumerStatefulWidget {
  const _DaySheet({
    required this.workplace,
    required this.day,
    required this.onMarkersChanged,
  });

  final Workplace workplace;
  final DateTime day;
  final VoidCallback onMarkersChanged;

  @override
  ConsumerState<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends ConsumerState<_DaySheet> {
  List<TimeEntry> _entries = [];
  Map<int, Project> _projects = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    final db = DatabaseHelper.instance;
    final entries = await db.getEntriesForDay(
      widget.workplace.id,
      widget.day,
    );
    final projects = await db.getProjectsForWorkplace(widget.workplace.id);
    if (mounted) {
      setState(() {
        _entries = entries;
        _projects = {for (final p in projects) p.id: p};
        _loading = false;
      });
    }
  }

  void _onEntryChanged() {
    bumpRefresh(ref);
    widget.onMarkersChanged();
    _loadEntries();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              AppFormatters.date(widget.day),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      controller: scrollController,
                      children: [
                        if (_entries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text('Keine Einträge an diesem Tag.'),
                          )
                        else
                          ..._entries.map(
                            (entry) => _EntryTile(
                              entry: entry,
                              workplace: widget.workplace,
                              project: entry.projectId != null
                                  ? _projects[entry.projectId]
                                  : null,
                              onChanged: _onEntryChanged,
                            ),
                          ),
                      ],
                    ),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.pop(context);
                await showTimeEntryForm(
                  context,
                  workplace: widget.workplace,
                  initialDate: widget.day,
                  defaultNoon: true,
                );
                bumpRefresh(ref);
                widget.onMarkersChanged();
              },
              icon: const Icon(Icons.add),
              label: const Text('Eintrag hinzufügen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.focusedDay,
    required this.selectedDay,
    required this.markers,
    required this.monthHours,
    required this.monthEarned,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Map<DateTime, _DayMarkerInfo> markers;
  final double monthHours;
  final double monthEarned;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Widget _buildDayCell(
    BuildContext context,
    DateTime day,
    DateTime focusedMonth, {
    required bool isSelected,
    required bool isToday,
    required bool isOutside,
  }) {
    final info = markers[_dateOnly(day)];
    final previews = info?.entryPreviews ?? const <_DayEntryPreview>[];
    final colorScheme = Theme.of(context).colorScheme;

    final dayNumberColor = isSelected
        ? colorScheme.onPrimary
        : isOutside
            ? colorScheme.onSurface.withValues(alpha: 0.38)
            : colorScheme.onSurface;

    Decoration? decoration;
    if (isSelected) {
      decoration = BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(4),
      );
    } else if (isToday) {
      decoration = BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4),
      );
    }

    const maxVisible = 4;
    final visible = previews.take(maxVisible).toList();
    final hiddenCount = previews.length - visible.length;

    return SizedBox.expand(
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '${day.day}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: dayNumberColor,
              ),
            ),
          ),
          if (previews.isNotEmpty)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(1, 0, 1, 1),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final preview in visible)
                      _MonthEntryChip(
                        preview: preview,
                        onPrimaryBackground: isSelected,
                      ),
                    if (hiddenCount > 0)
                      Text(
                        '+$hiddenCount',
                        style: TextStyle(
                          fontSize: 8,
                          color: dayNumberColor.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TableCalendar(
            locale: 'de_DE',
            firstDay: DateTime(2020),
            lastDay: DateTime(2100),
            focusedDay: focusedDay,
            selectedDayPredicate: (day) => isSameDay(selectedDay, day),
            onDaySelected: (selected, focused) => onDaySelected(selected),
            onPageChanged: onPageChanged,
            calendarFormat: CalendarFormat.month,
            shouldFillViewport: true,
            rowHeight: 72,
            headerStyle: const HeaderStyle(formatButtonVisible: false),
            calendarStyle: CalendarStyle(
              cellMargin: EdgeInsets.zero,
              cellPadding: EdgeInsets.zero,
              cellAlignment: Alignment.topCenter,
              outsideDaysVisible: true,
              defaultDecoration: const BoxDecoration(),
              outsideDecoration: const BoxDecoration(),
              weekendDecoration: const BoxDecoration(),
              disabledDecoration: const BoxDecoration(),
              holidayDecoration: const BoxDecoration(),
              todayDecoration: const BoxDecoration(),
              selectedDecoration: const BoxDecoration(),
              defaultTextStyle: TextStyle(color: colorScheme.onSurface),
              outsideTextStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.38),
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, day, focusedMonth) => _buildDayCell(
                context,
                day,
                focusedMonth,
                isSelected: false,
                isToday: isSameDay(day, DateTime.now()),
                isOutside: day.month != focusedMonth.month,
              ),
              todayBuilder: (context, day, focusedMonth) => _buildDayCell(
                context,
                day,
                focusedMonth,
                isSelected: isSameDay(selectedDay, day),
                isToday: true,
                isOutside: day.month != focusedMonth.month,
              ),
              selectedBuilder: (context, day, focusedMonth) => _buildDayCell(
                context,
                day,
                focusedMonth,
                isSelected: true,
                isToday: isSameDay(day, DateTime.now()),
                isOutside: day.month != focusedMonth.month,
              ),
              outsideBuilder: (context, day, focusedMonth) => _buildDayCell(
                context,
                day,
                focusedMonth,
                isSelected: isSameDay(selectedDay, day),
                isToday: isSameDay(day, DateTime.now()),
                isOutside: true,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    AppFormatters.monthYear(focusedDay),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Stunden'),
                            Text(
                              AppFormatters.hours(monthHours),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Verdienst'),
                            Text(
                              AppFormatters.money(monthEarned),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthEntryChip extends StatelessWidget {
  const _MonthEntryChip({
    required this.preview,
    required this.onPrimaryBackground,
  });

  final _DayEntryPreview preview;
  final bool onPrimaryBackground;

  @override
  Widget build(BuildContext context) {
    final label =
        '${AppFormatters.time(preview.startTime)}–${AppFormatters.time(preview.endTime)}';
    final textColor = onPrimaryBackground
        ? Theme.of(context).colorScheme.onPrimary
        : Theme.of(context).colorScheme.onSurface;

    return Container(
      margin: const EdgeInsets.only(bottom: 1),
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        color: preview.color.withValues(alpha: onPrimaryBackground ? 0.35 : 0.22),
        borderRadius: BorderRadius.circular(2),
        border: Border(
          left: BorderSide(color: preview.color, width: 2),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 8, height: 1.1, color: textColor),
      ),
    );
  }
}

class _WeekView extends ConsumerStatefulWidget {
  const _WeekView({
    required this.workplace,
    required this.focusedDay,
    required this.onDaySelected,
  });

  final Workplace workplace;
  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  ConsumerState<_WeekView> createState() => _WeekViewState();
}

class _WeekViewState extends ConsumerState<_WeekView> {
  Map<DateTime, _DayMarkerInfo> _weekData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWeek();
  }

  @override
  void didUpdateWidget(covariant _WeekView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusedDay != widget.focusedDay ||
        oldWidget.workplace.id != widget.workplace.id) {
      _loadWeek();
    }
  }

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadWeek() async {
    setState(() => _loading = true);
    final start = widget.focusedDay
        .subtract(Duration(days: widget.focusedDay.weekday - 1));
    final end = start.add(const Duration(days: 6));
    final entries = await DatabaseHelper.instance.getEntries(
      workplaceId: widget.workplace.id,
      start: start,
      end: end,
    );
    final projects = await DatabaseHelper.instance
        .getProjectsForWorkplace(widget.workplace.id);
    final projectColors = {
      for (final p in projects) p.id: projectColor(p.colorValue),
    };

    final data = <DateTime, _DayMarkerInfo>{};
    for (final entry in entries) {
      final day = _dateOnly(entry.date);
      final info = data.putIfAbsent(day, () => _DayMarkerInfo());
      info.earned += entry.earned;
      info.hasEntries = true;
      final color = entry.projectId != null
          ? (projectColors[entry.projectId] ?? projectColorPalette.first)
          : projectColorPalette.first;
      if (entry.projectId != null) {
        info.colors.add(color);
      }
      info.entryPreviews.add(
        _DayEntryPreview(
          startTime: entry.startTime,
          endTime: entry.endTime,
          color: color,
        ),
      );
    }
    for (final info in data.values) {
      info.entryPreviews.sort(
        (a, b) => a.startTime.compareTo(b.startTime),
      );
    }

    if (mounted) {
      setState(() {
        _weekData = data;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(refreshTriggerProvider, (_, __) => _loadWeek());

    final start = widget.focusedDay
        .subtract(Duration(days: widget.focusedDay.weekday - 1));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        final info = _weekData[_dateOnly(day)];
        final hasEntries = info?.hasEntries ?? false;
        final previews = info?.entryPreviews ?? const <_DayEntryPreview>[];

        return Card(
          child: ListTile(
            leading: hasEntries
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (info!.colors.isNotEmpty)
                        ...info.colors.take(3).map(
                              (c) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: CircleAvatar(
                                  radius: 5,
                                  backgroundColor: c,
                                ),
                              ),
                            )
                      else
                        CircleAvatar(
                          radius: 5,
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                        ),
                    ],
                  )
                : const SizedBox(width: 24),
            isThreeLine: previews.length > 1,
            title: Text(AppFormatters.date(day)),
            subtitle: hasEntries
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final preview in previews)
                        Text(
                          AppFormatters.weekViewEntryLine(
                            preview.startTime,
                            preview.endTime,
                          ),
                        ),
                    ],
                  )
                : const Text('Keine Einträge'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasEntries && info != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      AppFormatters.money(info.earned),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => widget.onDaySelected(day),
          ),
        );
      },
    );
  }
}

class _DayView extends ConsumerWidget {
  const _DayView({
    required this.workplace,
    required this.day,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  final Workplace workplace;
  final DateTime day;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = DayQuery(workplaceId: workplace.id, day: day);
    final entriesAsync = ref.watch(dayEntriesProvider(query));
    final projectsAsync = ref.watch(projectsProvider(workplace.id));

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (entries) {
        final projects = projectsAsync.valueOrNull ?? <Project>[];
        final projectMap = {for (final p in projects) p.id: p};

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onPreviousDay,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      AppFormatters.date(day),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: onNextDay,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('Keine Einträge.'))
                  : ListView(
                      children: entries
                          .map(
                            (entry) => _EntryTile(
                              entry: entry,
                              workplace: workplace,
                              project: entry.projectId != null
                                  ? projectMap[entry.projectId]
                                  : null,
                              onChanged: () => bumpRefresh(ref),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({
    required this.entry,
    required this.workplace,
    this.project,
    required this.onChanged,
  });

  final TimeEntry entry;
  final Workplace workplace;
  final Project? project;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = project != null
        ? projectColor(project!.colorValue)
        : Theme.of(context).colorScheme.outline;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          radius: 6,
          backgroundColor: color,
        ),
        title: Text(
          '${AppFormatters.time(entry.startTime)} – ${AppFormatters.time(entry.endTime)}',
        ),
        subtitle: Text(
          '${project != null ? '${project!.name} • ' : ''}${AppFormatters.hours(entry.hours)} • ${AppFormatters.money(entry.earned)}${entry.notes.isNotEmpty ? '\n${entry.notes}' : ''}',
        ),
        onTap: () async {
          await showTimeEntryForm(
            context,
            workplace: workplace,
            entry: entry,
          );
          onChanged();
        },
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Eintrag löschen?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Abbrechen'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Löschen'),
                  ),
                ],
              ),
            );
            if (confirmed == true) {
              await ref.read(databaseProvider).deleteEntry(entry.id);
              onChanged();
            }
          },
        ),
      ),
    );
  }
}

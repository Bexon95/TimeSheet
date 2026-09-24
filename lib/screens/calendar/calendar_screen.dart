import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../database/database_helper.dart';
import '../../database/models.dart';
import '../../providers/providers.dart';
import '../../services/formatters.dart';
import '../../widgets/time_entry_form.dart';

enum CalendarViewMode { month, week, day }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  CalendarViewMode _mode = CalendarViewMode.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Set<DateTime> _markedDays = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now();
    _loadMarkers();
  }

  Future<void> _loadMarkers() async {
    final workplaceId = ref.read(appStateProvider).selectedWorkplaceId;
    if (workplaceId == null) return;
    final dates = await DatabaseHelper.instance.getDatesWithEntries(
      workplaceId,
      _focusedDay,
    );
    setState(() => _markedDays = dates);
  }

  @override
  Widget build(BuildContext context) {
    final workplaceId = ref.watch(appStateProvider).selectedWorkplaceId;
    final workplace = ref.watch(appStateProvider).workplaces
        .where((w) => w.id == workplaceId)
        .firstOrNull;

    ref.listen(appStateProvider.select((s) => s.selectedWorkplaceId), (
      _,
      __,
    ) {
      _loadMarkers();
    });

    if (workplace == null) {
      return const Center(
        child: Text('Bitte einen Arbeitgeber in der Seitenleiste auswählen.'),
      );
    }

    return Column(
      children: [
        SegmentedButton<CalendarViewMode>(
          segments: const [
            ButtonSegment(value: CalendarViewMode.month, label: Text('Monat')),
            ButtonSegment(value: CalendarViewMode.week, label: Text('Woche')),
            ButtonSegment(value: CalendarViewMode.day, label: Text('Tag')),
          ],
          selected: {_mode},
          onSelectionChanged: (value) {
            setState(() => _mode = value.first);
          },
        ),
        Expanded(
          child: switch (_mode) {
            CalendarViewMode.month => _MonthView(
                workplace: workplace,
                focusedDay: _focusedDay,
                selectedDay: _selectedDay,
                markedDays: _markedDays,
                onDaySelected: (day) {
                  setState(() {
                    _selectedDay = day;
                    _focusedDay = day;
                  });
                  _showDaySheet(context, workplace, day);
                },
                onPageChanged: (day) {
                  _focusedDay = day;
                  _loadMarkers();
                },
              ),
            CalendarViewMode.week => _WeekView(
                workplace: workplace,
                focusedDay: _focusedDay,
                onDaySelected: (day) {
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
                onAdd: () => showTimeEntryForm(
                  context,
                  workplace: workplace,
                  initialDate: _selectedDay,
                ),
              ),
          },
        ),
      ],
    );
  }

  Future<void> _showDaySheet(
    BuildContext context,
    Workplace workplace,
    DateTime day,
  ) async {
    final entries = await DatabaseHelper.instance.getEntriesForDay(
      workplace.id,
      day,
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
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
                AppFormatters.date(day),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    if (entries.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('Keine Einträge an diesem Tag.'),
                      )
                    else
                      ...entries.map(
                        (entry) => _EntryTile(
                          entry: entry,
                          workplace: workplace,
                          onChanged: () {
                            bumpRefresh(ref);
                            _loadMarkers();
                          },
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
                    workplace: workplace,
                    initialDate: day,
                  );
                  bumpRefresh(ref);
                  _loadMarkers();
                },
                icon: const Icon(Icons.add),
                label: const Text('Eintrag hinzufügen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthView extends StatelessWidget {
  const _MonthView({
    required this.workplace,
    required this.focusedDay,
    required this.selectedDay,
    required this.markedDays,
    required this.onDaySelected,
    required this.onPageChanged,
  });

  final Workplace workplace;
  final DateTime focusedDay;
  final DateTime? selectedDay;
  final Set<DateTime> markedDays;
  final ValueChanged<DateTime> onDaySelected;
  final ValueChanged<DateTime> onPageChanged;

  @override
  Widget build(BuildContext context) {
    return TableCalendar(
      locale: 'de_DE',
      firstDay: DateTime(2020),
      lastDay: DateTime(2100),
      focusedDay: focusedDay,
      selectedDayPredicate: (day) => isSameDay(selectedDay, day),
      onDaySelected: (selected, focused) => onDaySelected(selected),
      onPageChanged: onPageChanged,
      calendarFormat: CalendarFormat.month,
      eventLoader: (day) {
        return markedDays.any((d) => isSameDay(d, day)) ? ['entry'] : [];
      },
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, events) {
          if (events.isEmpty) return null;
          return Positioned(
            bottom: 1,
            child: Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WeekView extends ConsumerWidget {
  const _WeekView({
    required this.workplace,
    required this.focusedDay,
    required this.onDaySelected,
  });

  final Workplace workplace;
  final DateTime focusedDay;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = focusedDay.subtract(Duration(days: focusedDay.weekday - 1));
    final days = List.generate(7, (i) => start.add(Duration(days: i)));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: days.length,
      itemBuilder: (context, index) {
        final day = days[index];
        return Card(
          child: ListTile(
            title: Text(AppFormatters.date(day)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => onDaySelected(day),
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
    required this.onAdd,
  });

  final Workplace workplace;
  final DateTime day;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(
      FutureProvider((ref) async {
        return DatabaseHelper.instance.getEntriesForDay(workplace.id, day);
      }),
    );

    return entriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (entries) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              AppFormatters.date(day),
              style: Theme.of(context).textTheme.titleLarge,
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
                            onChanged: () => bumpRefresh(ref),
                          ),
                        )
                        .toList(),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Eintrag hinzufügen'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({
    required this.entry,
    required this.workplace,
    required this.onChanged,
  });

  final TimeEntry entry;
  final Workplace workplace;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        title: Text(
          '${AppFormatters.time(entry.startTime)} – ${AppFormatters.time(entry.endTime)}',
        ),
        subtitle: Text(
          '${AppFormatters.hours(entry.hours)} • ${AppFormatters.money(entry.earned)}${entry.notes.isNotEmpty ? '\n${entry.notes}' : ''}',
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

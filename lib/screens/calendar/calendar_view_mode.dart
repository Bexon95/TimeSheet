import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum CalendarViewMode { month, week, day, weekList }

extension CalendarViewModeLabel on CalendarViewMode {
  String get label => switch (this) {
        CalendarViewMode.month => 'Monat',
        CalendarViewMode.week => 'Woche',
        CalendarViewMode.day => 'Tag',
        CalendarViewMode.weekList => 'Wochenliste',
      };
}

const calendarViewModePrefsKey = 'calendar_view_mode';

CalendarViewMode calendarViewModeFromStored(String? stored) {
  if (stored == null) return CalendarViewMode.month;
  for (final mode in CalendarViewMode.values) {
    if (mode.name == stored) return mode;
  }
  return CalendarViewMode.month;
}

Future<CalendarViewMode> loadStoredCalendarViewMode() async {
  final prefs = await SharedPreferences.getInstance();
  return calendarViewModeFromStored(prefs.getString(calendarViewModePrefsKey));
}

Future<void> persistCalendarViewMode(CalendarViewMode mode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(calendarViewModePrefsKey, mode.name);
}

final calendarViewModeProvider =
    StateProvider<CalendarViewMode>((ref) => CalendarViewMode.month);

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Last day selected or viewed in the calendar tab (for manual entry prefills).
final calendarSelectedDayProvider = StateProvider<DateTime>(
  (ref) => _dateOnly(DateTime.now()),
);

void setCalendarSelectedDay(WidgetRef ref, DateTime day) {
  ref.read(calendarSelectedDayProvider.notifier).state = _dateOnly(day);
}

/// Increment to open the bottom-nav plus menu from the calendar (e.g. week day row).
final calendarPlusMenuRequestProvider = StateProvider<int>((ref) => 0);

void requestCalendarPlusMenu(WidgetRef ref) {
  ref.read(calendarPlusMenuRequestProvider.notifier).update((n) => n + 1);
}

class CalendarViewModeMenu extends ConsumerWidget {
  const CalendarViewModeMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(calendarViewModeProvider);
    final theme = Theme.of(context);

    return PopupMenuButton<CalendarViewMode>(
      tooltip: 'Kalenderansicht',
      offset: const Offset(0, 24),
      onSelected: (value) {
        ref.read(calendarViewModeProvider.notifier).state = value;
        persistCalendarViewMode(value);
      },
      itemBuilder: (context) => CalendarViewMode.values
          .map(
            (m) => PopupMenuItem(
              value: m,
              child: Text(m.label),
            ),
          )
          .toList(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            mode.label,
            style: theme.textTheme.titleSmall,
          ),
          Icon(
            Icons.arrow_drop_down,
            size: 20,
            color: theme.textTheme.bodySmall?.color,
          ),
        ],
      ),
    );
  }
}

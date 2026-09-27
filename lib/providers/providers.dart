import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../database/models.dart';
import '../services/timer_service.dart';

final databaseProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

final packageInfoProvider = FutureProvider<PackageInfo>((ref) async {
  return PackageInfo.fromPlatform();
});

final timerServiceProvider = Provider<TimerService>((ref) => TimerService());

final refreshTriggerProvider = StateProvider<int>((ref) => 0);

void bumpRefresh(WidgetRef ref) {
  ref.read(refreshTriggerProvider.notifier).state++;
}

enum AppThemeMode { system, light, dark }

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('theme_mode');
    state = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(AppThemeMode mode) async {
    final themeMode = switch (mode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
    state = themeMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'theme_mode',
      switch (mode) {
        AppThemeMode.light => 'light',
        AppThemeMode.dark => 'dark',
        AppThemeMode.system => 'system',
      },
    );
  }
}

Future<int?> loadLastProjectId(int workplaceId) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt('last_project_$workplaceId');
}

Future<void> saveLastProjectId(int workplaceId, int? projectId) async {
  final prefs = await SharedPreferences.getInstance();
  final key = 'last_project_$workplaceId';
  if (projectId == null) {
    await prefs.remove(key);
  } else {
    await prefs.setInt(key, projectId);
  }
}

class DayQuery {
  DayQuery({required this.workplaceId, required this.day});

  final int workplaceId;
  final DateTime day;

  @override
  bool operator ==(Object other) =>
      other is DayQuery &&
      workplaceId == other.workplaceId &&
      other.day.year == day.year &&
      other.day.month == day.month &&
      other.day.day == day.day;

  @override
  int get hashCode => Object.hash(workplaceId, day.year, day.month, day.day);
}

final dayEntriesProvider =
    FutureProvider.family<List<TimeEntry>, DayQuery>((ref, query) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(databaseProvider).getEntriesForDay(
        query.workplaceId,
        query.day,
      );
});

class DateRange {
  DateRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  DateRange copyWith({DateTime? start, DateTime? end}) {
    return DateRange(start: start ?? this.start, end: end ?? this.end);
  }
}

class AppStateNotifier extends StateNotifier<AppState> {
  AppStateNotifier(this._db, this._timerService) : super(AppState.initial()) {
    _load();
  }

  final DatabaseHelper _db;
  final TimerService _timerService;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final workplaces = await _db.getWorkplaces();
    final selectedId = prefs.getInt('selected_workplace_id');
    final rangeStart = prefs.getString('date_range_start');
    final rangeEnd = prefs.getString('date_range_end');
    final customStart = prefs.getString('custom_date_range_start');
    final customEnd = prefs.getString('custom_date_range_end');
    final timer = await _timerService.getActiveTimer();

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    state = state.copyWith(
      workplaces: workplaces,
      selectedWorkplaceId: selectedId ??
          (workplaces.isNotEmpty ? workplaces.first.id : null),
      dateRange: DateRange(
        start: rangeStart != null
            ? DateTime.parse(rangeStart)
            : monthStart,
        end: rangeEnd != null ? DateTime.parse(rangeEnd) : monthEnd,
      ),
      savedCustomDateRange: customStart != null && customEnd != null
          ? DateRange(
              start: DateTime.parse(customStart),
              end: DateTime.parse(customEnd),
            )
          : null,
      activeTimer: timer,
      isLoading: false,
    );
  }

  Future<void> reload() async {
    final workplaces = await _db.getWorkplaces();
    state = state.copyWith(workplaces: workplaces);
  }

  Future<void> selectWorkplace(int? id) async {
    state = state.copyWith(selectedWorkplaceId: id);
    final prefs = await SharedPreferences.getInstance();
    if (id != null) {
      await prefs.setInt('selected_workplace_id', id);
    } else {
      await prefs.remove('selected_workplace_id');
    }
  }

  Future<void> setDateRange(DateRange range) async {
    state = state.copyWith(dateRange: range);
    await _persistActiveDateRange(range);
  }

  Future<void> setCustomDateRange(DateRange range) async {
    state = state.copyWith(
      dateRange: range,
      savedCustomDateRange: range,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'custom_date_range_start',
      range.start.toIso8601String().split('T').first,
    );
    await prefs.setString(
      'custom_date_range_end',
      range.end.toIso8601String().split('T').first,
    );
    await _persistActiveDateRange(range);
  }

  Future<void> _persistActiveDateRange(DateRange range) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'date_range_start',
      range.start.toIso8601String().split('T').first,
    );
    await prefs.setString(
      'date_range_end',
      range.end.toIso8601String().split('T').first,
    );
  }

  Future<void> reorderWorkplaces(List<int> orderedIds) async {
    await _db.reorderWorkplaces(orderedIds);
    await reload();
  }

  Future<void> refreshTimer() async {
    final timer = await _timerService.getActiveTimer();
    state = state.copyWith(activeTimer: timer);
  }

  Workplace? get selectedWorkplace {
    if (state.selectedWorkplaceId == null) return null;
    return state.workplaces
        .where((w) => w.id == state.selectedWorkplaceId)
        .firstOrNull;
  }
}

class AppState {
  AppState({
    required this.workplaces,
    this.selectedWorkplaceId,
    required this.dateRange,
    this.savedCustomDateRange,
    this.activeTimer,
    this.isLoading = true,
  });

  final List<Workplace> workplaces;
  final int? selectedWorkplaceId;
  final DateRange dateRange;
  final DateRange? savedCustomDateRange;
  final ActiveTimer? activeTimer;
  final bool isLoading;

  factory AppState.initial() => AppState(
        workplaces: [],
        dateRange: DateRange(
          start: DateTime.now(),
          end: DateTime.now(),
        ),
      );

  AppState copyWith({
    List<Workplace>? workplaces,
    int? selectedWorkplaceId,
    bool clearWorkplace = false,
    DateRange? dateRange,
    DateRange? savedCustomDateRange,
    bool clearSavedCustomDateRange = false,
    ActiveTimer? activeTimer,
    bool clearTimer = false,
    bool? isLoading,
  }) {
    return AppState(
      workplaces: workplaces ?? this.workplaces,
      selectedWorkplaceId:
          clearWorkplace ? null : (selectedWorkplaceId ?? this.selectedWorkplaceId),
      dateRange: dateRange ?? this.dateRange,
      savedCustomDateRange: clearSavedCustomDateRange
          ? null
          : (savedCustomDateRange ?? this.savedCustomDateRange),
      activeTimer: clearTimer ? null : (activeTimer ?? this.activeTimer),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final appStateProvider =
    StateNotifierProvider<AppStateNotifier, AppState>((ref) {
  final db = ref.watch(databaseProvider);
  final timer = ref.watch(timerServiceProvider);
  return AppStateNotifier(db, timer);
});

final workplacesProvider = FutureProvider<List<Workplace>>((ref) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(databaseProvider).getWorkplaces();
});

final projectsProvider =
    FutureProvider.family<List<Project>, int>((ref, workplaceId) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(databaseProvider).getProjectsForWorkplace(workplaceId);
});

/// All workplace projects (for statistics chart colors).
final chartProjectsProvider = FutureProvider<List<Project>>((ref) async {
  ref.watch(refreshTriggerProvider);
  final db = ref.watch(databaseProvider);
  final workplaces = await db.getWorkplaces();
  final projects = <Project>[];
  for (final workplace in workplaces) {
    projects.addAll(await db.getProjectsForWorkplace(workplace.id));
  }
  return projects;
});

final workplaceSummariesProvider =
    FutureProvider.family<List<WorkplaceSummary>, DateRange>((ref, range) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(databaseProvider).getWorkplaceSummaries(
        start: range.start,
        end: range.end,
      );
});

final entriesProvider = FutureProvider.family<List<TimeEntry>, EntriesQuery>((
  ref,
  query,
) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(databaseProvider).getEntries(
        workplaceId: query.workplaceId,
        start: query.start,
        end: query.end,
      );
});

class EntriesQuery {
  EntriesQuery({this.workplaceId, this.start, this.end});

  final int? workplaceId;
  final DateTime? start;
  final DateTime? end;

  @override
  bool operator ==(Object other) =>
      other is EntriesQuery &&
      workplaceId == other.workplaceId &&
      start == other.start &&
      end == other.end;

  @override
  int get hashCode => Object.hash(workplaceId, start, end);
}

final savedInvoicesProvider =
    FutureProvider.family<List<SavedInvoice>, int>((ref, workplaceId) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(databaseProvider).getSavedInvoices(workplaceId);
});

final invoiceSettingsProvider = FutureProvider<InvoiceSettings>((ref) async {
  ref.watch(refreshTriggerProvider);
  return ref.watch(databaseProvider).getInvoiceSettings();
});

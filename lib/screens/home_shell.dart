import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models.dart';
import '../providers/providers.dart';
import '../services/quick_entry_service.dart';
import '../widgets/quick_entry_settings.dart';
import '../widgets/time_entry_form.dart';
import '../widgets/timer_banner.dart';
import '../widgets/workplace_app_bar.dart';
import '../widgets/workplace_drawer.dart';
import 'calendar/calendar_view_mode.dart';
import 'calendar/calendar_screen.dart';
import 'dashboard/dashboard_screen.dart';
import 'invoice/invoice_screen.dart';
import 'statistics/statistics_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;
  final _quickEntryService = QuickEntryService();

  static const _titles = [
    'Dashboard',
    'Kalender',
    'Statistik',
    'Rechnungen',
  ];

  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);

    if (appState.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final bodyIndex = _index > 2 ? _index - 1 : _index;

    return Scaffold(
      appBar: WorkplaceAppBar(
        title: _titles[bodyIndex],
        subtitleWidget:
            bodyIndex == 1 ? const CalendarViewModeMenu() : null,
      ),
      drawer: const WorkplaceDrawer(),
      body: Column(
        children: [
          const TimerBanner(),
          Expanded(
            child: IndexedStack(
              index: bodyIndex,
              children: const [
                DashboardScreen(),
                CalendarScreen(),
                StatisticsScreen(),
                InvoiceScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Material(
        elevation: 2,
        color: Theme.of(context).colorScheme.surface,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  selectedIcon: Icons.dashboard,
                  label: 'Dashboard',
                  selected: _index == 0,
                  onTap: () => setState(() => _index = 0),
                ),
                _NavItem(
                  icon: Icons.calendar_month_outlined,
                  selectedIcon: Icons.calendar_month,
                  label: 'Kalender',
                  selected: _index == 1,
                  onTap: () => setState(() => _index = 1),
                ),
                _AddNavButton(onPressed: _showPlusMenu),
                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  selectedIcon: Icons.bar_chart,
                  label: 'Statistik',
                  selected: _index == 3,
                  onTap: () => setState(() => _index = 3),
                ),
                _NavItem(
                  icon: Icons.receipt_long_outlined,
                  selectedIcon: Icons.receipt_long,
                  label: 'Rechnung',
                  selected: _index == 4,
                  onTap: () => setState(() => _index = 4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createQuickEntry(Workplace workplace, QuickEntryPreset preset) async {
    final times = QuickEntryService.computeTimes(preset);
    final db = ref.read(databaseProvider);
    final entry = TimeEntry(
      id: 0,
      workplaceId: workplace.id,
      date: DateTime(
        times.start.year,
        times.start.month,
        times.start.day,
      ),
      startTime: times.start,
      endTime: times.end,
      hourlyRate: workplace.defaultHourlyRate,
      notes: '',
      source: EntrySource.manual,
    );
    await db.insertEntry(entry);
    bumpRefresh(ref);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Eintrag ${QuickEntryService.formatTimeRange(times.start, times.end)} gespeichert',
          ),
        ),
      );
    }
  }

  Future<void> _showPlusMenu() async {
    final workplace = ref.read(appStateProvider).workplaces
        .where((w) => w.id == ref.read(appStateProvider).selectedWorkplaceId)
        .firstOrNull;

    if (workplace == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst einen Arbeitgeber hinzufügen.'),
        ),
      );
      return;
    }

    final presets = await _quickEntryService.getPresets();

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_calendar),
              title: const Text('Manueller Eintrag'),
              onTap: () => Navigator.pop(context, 'manual'),
            ),
            ...presets.map(
              (preset) => ListTile(
                leading: const Icon(Icons.bolt),
                title: Text(_quickEntryService.displayLabel(preset)),
                onTap: () => Navigator.pop(context, 'quick:${preset.id}'),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Timer starten'),
              onTap: () => Navigator.pop(context, 'timer'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Schnelleinträge verwalten'),
              onTap: () => Navigator.pop(context, 'manage_quick'),
            ),
          ],
        ),
      ),
    );

    if (action == 'manual') {
      await showTimeEntryForm(
        context,
        workplace: workplace,
        defaultNoon: true,
      );
      bumpRefresh(ref);
    } else if (action == 'manage_quick') {
      await showQuickEntrySettings(context);
    } else if (action != null && action.startsWith('quick:')) {
      final presetId = action.substring('quick:'.length);
      final preset = presets.firstWhere(
        (p) => p.id == presetId,
        orElse: () => QuickEntryService.defaultPreset,
      );
      await _createQuickEntry(workplace, preset);
    } else if (action == 'timer') {
      final active = ref.read(appStateProvider).activeTimer;
      if (active != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ein Timer läuft bereits.')),
        );
        return;
      }
      await ref.read(timerServiceProvider).startTimer(
            workplaceId: workplace.id,
          );
      await ref.read(appStateProvider.notifier).refreshTimer();
    }
  }
}

class _AddNavButton extends StatelessWidget {
  const _AddNavButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Transform.translate(
      offset: const Offset(0, -4),
      child: Material(
        color: colorScheme.primary,
        elevation: 1,
        shadowColor: colorScheme.shadow.withValues(alpha: 0.25),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.add, color: colorScheme.onPrimary, size: 26),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';
import '../widgets/time_entry_form.dart';
import '../widgets/timer_banner.dart';
import '../widgets/workplace_app_bar.dart';
import '../widgets/workplace_drawer.dart';
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
      appBar: WorkplaceAppBar(title: _titles[bodyIndex]),
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton.large(
        onPressed: _showPlusMenu,
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
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
            const SizedBox(width: 48),
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
    );
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
            ListTile(
              leading: const Icon(Icons.timer),
              title: const Text('Timer starten'),
              onTap: () => Navigator.pop(context, 'timer'),
            ),
          ],
        ),
      ),
    );

    if (action == 'manual') {
      await showTimeEntryForm(context, workplace: workplace);
      bumpRefresh(ref);
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

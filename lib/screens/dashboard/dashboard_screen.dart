import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/models.dart';
import '../../providers/providers.dart';
import '../../services/formatters.dart';
import '../../widgets/date_range_selector.dart';
import '../../widgets/week_entry_row.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  var _diskCacheLoaded = false;

  @override
  void initState() {
    super.initState();
    _hydrateDiskCache();
  }

  Future<void> _hydrateDiskCache() async {
    final cached = await loadDashboardSummariesCacheFromPrefs();
    if (!mounted) return;
    if (cached != null &&
        ref.read(workplaceSummariesCacheProvider) == null) {
      ref.read(workplaceSummariesCacheProvider.notifier).state = cached;
    }
    if (mounted) setState(() => _diskCacheLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(appStateProvider).dateRange;
    final summariesAsync = ref.watch(workplaceSummariesProvider(range));

    ref.listen(
      workplaceSummariesProvider(range),
      (_, next) {
        next.whenData((summaries) async {
          final cache = CachedWorkplaceSummaries(
            range: range,
            summaries: summaries,
          );
          ref.read(workplaceSummariesCacheProvider.notifier).state = cache;
          await persistDashboardSummariesCache(cache);
        });
      },
    );

    final cache = ref.watch(workplaceSummariesCacheProvider);
    final cachedSummaries =
        cache != null && cache.range == range ? cache.summaries : null;

    if (!_diskCacheLoaded && cachedSummaries == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return summariesAsync.when(
      loading: () {
        if (cachedSummaries != null) {
          return _DashboardBody(summaries: cachedSummaries);
        }
        return const Center(child: CircularProgressIndicator());
      },
      error: (e, _) => Center(child: Text('Fehler: $e')),
      data: (summaries) => _DashboardBody(summaries: summaries),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.summaries});

  final List<WorkplaceSummary> summaries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalHours =
        summaries.fold<double>(0, (sum, item) => sum + item.hours);
    final totalEarned =
        summaries.fold<double>(0, (sum, item) => sum + item.earned);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const DateRangeSelector(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'Gesamtstunden',
                value: AppFormatters.hours(totalHours),
                icon: Icons.schedule,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                title: 'Gesamtverdienst',
                value: AppFormatters.money(totalEarned),
                icon: Icons.euro,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Nach Arbeitgeber',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        if (summaries.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Noch keine Arbeitgeber angelegt.'),
            ),
          )
        else
          ...summaries.map(
            (summary) => _EmployerSummaryCard(summary: summary),
          ),
      ],
    );
  }
}

class _EmployerSummaryCard extends ConsumerStatefulWidget {
  const _EmployerSummaryCard({required this.summary});

  final WorkplaceSummary summary;

  @override
  ConsumerState<_EmployerSummaryCard> createState() =>
      _EmployerSummaryCardState();
}

class _EmployerSummaryCardState extends ConsumerState<_EmployerSummaryCard> {
  List<TimeEntry>? _entries;
  Map<int, Project>? _projects;
  bool _loadingEntries = false;

  Future<void> _loadEntries() async {
    if (_loadingEntries) return;
    setState(() => _loadingEntries = true);
    final range = ref.read(appStateProvider).dateRange;
    final db = ref.read(databaseProvider);
    final entries = await db.getEntries(
      workplaceId: widget.summary.workplace.id,
      start: range.start,
      end: range.end,
    );
    final projects =
        await db.getProjectsForWorkplace(widget.summary.workplace.id);
    if (mounted) {
      setState(() {
        _entries = entries;
        _projects = {for (final p in projects) p.id: p};
        _loadingEntries = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(summary.workplace.name),
                  const SizedBox(height: 2),
                  Text(
                    AppFormatters.hours(summary.hours),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              AppFormatters.money(summary.earned),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        onExpansionChanged: (expanded) {
          if (expanded && _entries == null) {
            _loadEntries();
          }
        },
        children: [
          const Divider(height: 1),
          if (_loadingEntries)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_entries == null || _entries!.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Keine Einträge in diesem Zeitraum.'),
            )
          else
            ..._entries!.map(
              (entry) {
                final projectId = entry.projectId;
                final projects = _projects;
                return WeekEntryRow(
                  entry: entry,
                  workplace: summary.workplace,
                  project: projectId != null && projects != null
                      ? projects[projectId]
                      : null,
                  onChanged: () {
                    bumpRefresh(ref);
                    _loadEntries();
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models.dart';
import '../providers/providers.dart';

class WorkplaceDrawer extends ConsumerStatefulWidget {
  const WorkplaceDrawer({super.key});

  @override
  ConsumerState<WorkplaceDrawer> createState() => _WorkplaceDrawerState();
}

class _WorkplaceDrawerState extends ConsumerState<WorkplaceDrawer> {
  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final workplaces = appState.workplaces;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Arbeitgeber',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Expanded(
              child: workplaces.isEmpty
                  ? const Center(child: Text('Noch keine Arbeitgeber'))
                  : ReorderableListView.builder(
                      itemCount: workplaces.length,
                      onReorder: (oldIndex, newIndex) async {
                        if (newIndex > oldIndex) newIndex--;
                        final ids = workplaces.map((w) => w.id).toList();
                        final id = ids.removeAt(oldIndex);
                        ids.insert(newIndex, id);
                        await ref
                            .read(appStateProvider.notifier)
                            .reorderWorkplaces(ids);
                        bumpRefresh(ref);
                      },
                      itemBuilder: (context, index) {
                        final workplace = workplaces[index];
                        final selected =
                            workplace.id == appState.selectedWorkplaceId;
                        return ListTile(
                          key: ValueKey(workplace.id),
                          leading: const Icon(Icons.drag_handle),
                          title: Text(workplace.name),
                          subtitle: Text(
                            '€ ${workplace.defaultHourlyRate.toStringAsFixed(2)}/h',
                          ),
                          selected: selected,
                          onTap: () {
                            ref
                                .read(appStateProvider.notifier)
                                .selectWorkplace(workplace.id);
                            Navigator.pop(context);
                          },
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _showWorkplaceDialog(
                                  context,
                                  workplace: workplace,
                                );
                              } else if (value == 'delete') {
                                await _confirmDelete(context, workplace);
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Bearbeiten'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Löschen'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _showWorkplaceDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Arbeitgeber hinzufügen'),
              ),
            ),
            const _AppVersionFooter(),
          ],
        ),
      ),
    );
  }

  Future<void> _showWorkplaceDialog(
    BuildContext context, {
    Workplace? workplace,
  }) async {
    final nameController = TextEditingController(text: workplace?.name ?? '');
    final rateController = TextEditingController(
      text: workplace?.defaultHourlyRate.toString() ?? '0',
    );
    final recipientController =
        TextEditingController(text: workplace?.recipientName ?? '');
    final addressController =
        TextEditingController(text: workplace?.recipientAddress ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          workplace == null ? 'Arbeitgeber hinzufügen' : 'Arbeitgeber bearbeiten',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: rateController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Stundensatz (EUR)',
                ),
              ),
              TextField(
                controller: recipientController,
                decoration: const InputDecoration(
                  labelText: 'Rechnungsempfänger',
                ),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Empfängeradresse',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final db = ref.read(databaseProvider);
    final rate = double.tryParse(rateController.text.replaceAll(',', '.')) ?? 0;

    if (workplace == null) {
      final id = await db.insertWorkplace(
        Workplace(
          id: 0,
          name: nameController.text.trim(),
          defaultHourlyRate: rate,
          recipientName: recipientController.text.trim(),
          recipientAddress: addressController.text.trim(),
        ),
      );
      await ref.read(appStateProvider.notifier).reload();
      await ref.read(appStateProvider.notifier).selectWorkplace(id);
    } else {
      await db.updateWorkplace(
        workplace.copyWith(
          name: nameController.text.trim(),
          defaultHourlyRate: rate,
          recipientName: recipientController.text.trim(),
          recipientAddress: addressController.text.trim(),
        ),
      );
      await ref.read(appStateProvider.notifier).reload();
    }
    bumpRefresh(ref);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Workplace workplace,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Arbeitgeber löschen?'),
        content: Text(
          'Alle Einträge und Rechnungen für "${workplace.name}" werden gelöscht.',
        ),
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
    if (confirmed != true) return;

    await ref.read(databaseProvider).deleteWorkplace(workplace.id);
    await ref.read(appStateProvider.notifier).reload();
    final workplaces = ref.read(appStateProvider).workplaces;
    if (workplaces.isNotEmpty) {
      await ref
          .read(appStateProvider.notifier)
          .selectWorkplace(workplaces.first.id);
    } else {
      await ref.read(appStateProvider.notifier).selectWorkplace(null);
    }
    bumpRefresh(ref);
  }
}

class _AppVersionFooter extends ConsumerWidget {
  const _AppVersionFooter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packageInfo = ref.watch(packageInfoProvider);

    return packageInfo.when(
      data: (info) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Text(
          'Version ${info.version} (${info.buildNumber})',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

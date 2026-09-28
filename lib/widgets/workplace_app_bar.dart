import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

class WorkplaceAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const WorkplaceAppBar({
    super.key,
    this.actions,
    this.subtitleWidget,
  });

  final List<Widget>? actions;
  final Widget? subtitleWidget;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final selected = appState.workplaces
        .where((w) => w.id == appState.selectedWorkplaceId)
        .firstOrNull;

    final employerTitle = Text(
      selected?.name ?? 'Kein Arbeitgeber',
      style: Theme.of(context).textTheme.titleMedium,
      overflow: TextOverflow.ellipsis,
    );

    return AppBar(
      title: subtitleWidget != null
          ? Row(
              children: [
                Expanded(child: employerTitle),
                subtitleWidget!,
              ],
            )
          : employerTitle,
      actions: [
        if (appState.workplaces.length > 1)
          PopupMenuButton<int>(
            tooltip: 'Arbeitgeber wechseln',
            icon: const Icon(Icons.swap_horiz),
            onSelected: (id) {
              ref.read(appStateProvider.notifier).selectWorkplace(id);
            },
            itemBuilder: (context) => appState.workplaces
                .map(
                  (w) => PopupMenuItem(
                    value: w.id,
                    child: Text(w.name),
                  ),
                )
                .toList(),
          ),
        ...?actions,
      ],
    );
  }
}

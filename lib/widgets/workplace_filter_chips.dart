import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models.dart';

/// Horizontal workplace chips for filtering stats (null = all workplaces).
class WorkplaceFilterChips extends StatelessWidget {
  const WorkplaceFilterChips({
    super.key,
    required this.workplaces,
    required this.selectedWorkplaceId,
    required this.onSelected,
  });

  final List<Workplace> workplaces;
  final int? selectedWorkplaceId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (workplaces.isEmpty) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: const Text('Alle'),
              selected: selectedWorkplaceId == null,
              onSelected: (_) => onSelected(null),
            ),
          ),
          for (final workplace in workplaces)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(workplace.name),
                selected: selectedWorkplaceId == workplace.id,
                onSelected: (_) => onSelected(workplace.id),
              ),
            ),
        ],
      ),
    );
  }
}

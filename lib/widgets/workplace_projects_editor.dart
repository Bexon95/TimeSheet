import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models.dart';
import '../providers/providers.dart';
import '../utils/project_colors.dart';
import 'project_color_picker.dart';

class WorkplaceProjectsEditor extends ConsumerStatefulWidget {
  const WorkplaceProjectsEditor({super.key, required this.workplaceId});

  final int workplaceId;

  @override
  ConsumerState<WorkplaceProjectsEditor> createState() =>
      _WorkplaceProjectsEditorState();
}

class _WorkplaceProjectsEditorState
    extends ConsumerState<WorkplaceProjectsEditor> {
  Future<void> _addProject() async {
    final existing = await ref
        .read(databaseProvider)
        .getProjectsForWorkplace(widget.workplaceId);
    final defaultColor =
        projectColorPalette[existing.length % projectColorPalette.length];
    final input = await showAddProjectDialog(
      context,
      initialColor: defaultColor,
    );
    if (input == null) return;

    await ref.read(databaseProvider).insertProject(
          Project(
            id: 0,
            workplaceId: widget.workplaceId,
            name: input.name,
            colorValue: colorToValue(input.color),
          ),
        );
    bumpRefresh(ref);
  }

  Future<void> _renameProject(Project project) async {
    final controller = TextEditingController(text: project.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projekt umbenennen'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Projektname'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    await ref.read(databaseProvider).updateProject(
          project.copyWith(name: name),
        );
    bumpRefresh(ref);
  }

  Future<void> _pickColor(Project project) async {
    final picked = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projektfarbe'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: projectColorPalette.map((color) {
            return InkWell(
              onTap: () => Navigator.pop(context, color),
              child: CircleAvatar(
                radius: 16,
                backgroundColor: color,
                child: project.colorValue == color.value
                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                    : null,
              ),
            );
          }).toList(),
        ),
      ),
    );
    if (picked == null) return;

    await ref.read(databaseProvider).updateProject(
          project.copyWith(colorValue: colorToValue(picked)),
        );
    bumpRefresh(ref);
  }

  Future<void> _deleteProject(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projekt löschen?'),
        content: Text(
          'Einträge behalten ihre Zeiten, verlieren aber die Projektzuordnung.',
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

    await ref.read(databaseProvider).deleteProject(project.id);
    bumpRefresh(ref);
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectsProvider(widget.workplaceId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Projekte', style: Theme.of(context).textTheme.titleSmall),
            const Spacer(),
            TextButton.icon(
              onPressed: _addProject,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Hinzufügen'),
            ),
          ],
        ),
        projectsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Fehler: $e'),
          data: (projects) {
            if (projects.isEmpty) {
              return const Text('Noch keine Projekte für diesen Arbeitgeber.');
            }
            return Column(
              children: projects.map((project) {
                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 8,
                    backgroundColor: projectColor(project.colorValue),
                  ),
                  title: Text(project.name),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'color':
                          await _pickColor(project);
                        case 'rename':
                          await _renameProject(project);
                        case 'delete':
                          await _deleteProject(project);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'color', child: Text('Farbe')),
                      PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
                      PopupMenuItem(value: 'delete', child: Text('Löschen')),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

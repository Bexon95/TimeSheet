import 'package:flutter/material.dart';

import '../utils/project_colors.dart';

/// Grid of palette colors for choosing a project color.
class ProjectColorPicker extends StatelessWidget {
  const ProjectColorPicker({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
  });

  final Color selectedColor;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: projectColorPalette.map((color) {
        return InkWell(
          onTap: () => onColorSelected(color),
          borderRadius: BorderRadius.circular(20),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: selectedColor.value == color.value
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}

/// Result of the add-project dialog.
class NewProjectInput {
  const NewProjectInput({required this.name, required this.color});

  final String name;
  final Color color;
}

/// Dialog: project name + color below the name field.
Future<NewProjectInput?> showAddProjectDialog(
  BuildContext context, {
  Color? initialColor,
}) async {
  final controller = TextEditingController();
  var selected = initialColor ?? projectColorPalette.first;

  return showDialog<NewProjectInput>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Projekt hinzufügen'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(labelText: 'Projektname'),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Farbe',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  ProjectColorPicker(
                    selectedColor: selected,
                    onColorSelected: (c) => setState(() => selected = c),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(
                    context,
                    NewProjectInput(name: name, color: selected),
                  );
                },
                child: const Text('Hinzufügen'),
              ),
            ],
          );
        },
      );
    },
  );
}

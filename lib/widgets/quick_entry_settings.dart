import 'package:flutter/material.dart';

import '../services/quick_entry_service.dart';

Future<void> showQuickEntrySettings(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _QuickEntrySettingsSheet(),
  );
}

class _QuickEntrySettingsSheet extends StatefulWidget {
  const _QuickEntrySettingsSheet();

  @override
  State<_QuickEntrySettingsSheet> createState() =>
      _QuickEntrySettingsSheetState();
}

class _QuickEntrySettingsSheetState extends State<_QuickEntrySettingsSheet> {
  final _service = QuickEntryService();
  List<QuickEntryPreset> _presets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final presets = await _service.getPresets();
    setState(() {
      _presets = presets;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await _service.savePresets(_presets);
  }

  Future<void> _editPreset(QuickEntryPreset preset, {bool isNew = false}) async {
    final result = await showDialog<QuickEntryPreset>(
      context: context,
      builder: (context) => _PresetEditDialog(preset: preset, isNew: isNew),
    );
    if (result == null) return;

    setState(() {
      if (isNew) {
        _presets = [..._presets, result];
      } else {
        _presets = _presets
            .map((p) => p.id == result.id ? result : p)
            .toList();
      }
    });
    await _save();
  }

  Future<void> _deletePreset(QuickEntryPreset preset) async {
    if (preset.id == QuickEntryService.defaultPresetId) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schnelleintrag löschen?'),
        content: Text('"${preset.name}" wird entfernt.'),
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

    setState(() {
      _presets = _presets.where((p) => p.id != preset.id).toList();
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Schnelleinträge verwalten',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text(
            'Dynamische Einträge berechnen die Zeiten aus der aktuellen Uhrzeit. '
            'Feste Einträge verwenden feste Start- und Endzeiten.',
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ..._presets.map((preset) {
                    final label = _service.displayLabel(preset);
                    final isDefault =
                        preset.id == QuickEntryService.defaultPresetId;
                    return ListTile(
                      leading: Icon(
                        preset.type == QuickEntryPresetType.dynamicHalfHour
                            ? Icons.bolt
                            : Icons.schedule,
                      ),
                      title: Text(label),
                      subtitle: Text(
                        isDefault
                            ? 'Standard (bearbeitbar)'
                            : preset.type == QuickEntryPresetType.dynamicHalfHour
                                ? 'Dynamisch, ${preset.durationMinutes} Min.'
                                : 'Feste Zeiten',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Bearbeiten',
                            onPressed: () => _editPreset(preset),
                          ),
                          if (!isDefault)
                            IconButton(
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Löschen',
                              onPressed: () => _deletePreset(preset),
                            ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _editPreset(
              QuickEntryPreset(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: 'Neuer Schnelleintrag',
                type: QuickEntryPresetType.fixed,
                startHour: 9,
                startMinute: 0,
                endHour: 9,
                endMinute: 30,
              ),
              isNew: true,
            ),
            icon: const Icon(Icons.add),
            label: const Text('Schnelleintrag hinzufügen'),
          ),
        ],
      ),
    );
  }
}

class _PresetEditDialog extends StatefulWidget {
  const _PresetEditDialog({required this.preset, required this.isNew});

  final QuickEntryPreset preset;
  final bool isNew;

  @override
  State<_PresetEditDialog> createState() => _PresetEditDialogState();
}

class _PresetEditDialogState extends State<_PresetEditDialog> {
  late final TextEditingController _nameController;
  late QuickEntryPresetType _type;
  late int _durationMinutes;
  late TimeOfDay _start;
  late TimeOfDay _end;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.preset.name);
    _type = widget.preset.type;
    _durationMinutes = widget.preset.durationMinutes;
    _start = TimeOfDay(
      hour: widget.preset.startHour ?? 9,
      minute: widget.preset.startMinute ?? 0,
    );
    _end = TimeOfDay(
      hour: widget.preset.endHour ?? 9,
      minute: widget.preset.endMinute ?? 30,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        _end = picked;
      }
    });
  }

  void _save() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    Navigator.pop(
      context,
      QuickEntryPreset(
        id: widget.preset.id,
        name: name,
        type: _type,
        startHour: _type == QuickEntryPresetType.fixed ? _start.hour : null,
        startMinute: _type == QuickEntryPresetType.fixed ? _start.minute : null,
        endHour: _type == QuickEntryPresetType.fixed ? _end.hour : null,
        endMinute: _type == QuickEntryPresetType.fixed ? _end.minute : null,
        durationMinutes: _durationMinutes,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Schnelleintrag hinzufügen' : 'Schnelleintrag bearbeiten'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<QuickEntryPresetType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Typ'),
              items: const [
                DropdownMenuItem(
                  value: QuickEntryPresetType.dynamicHalfHour,
                  child: Text('Dynamisch (letzte X Minuten)'),
                ),
                DropdownMenuItem(
                  value: QuickEntryPresetType.fixed,
                  child: Text('Feste Zeiten'),
                ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _type = value);
              },
            ),
            if (_type == QuickEntryPresetType.dynamicHalfHour) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _durationMinutes,
                decoration: const InputDecoration(labelText: 'Dauer'),
                items: const [
                  DropdownMenuItem(value: 15, child: Text('15 Minuten')),
                  DropdownMenuItem(value: 30, child: Text('30 Minuten')),
                  DropdownMenuItem(value: 45, child: Text('45 Minuten')),
                  DropdownMenuItem(value: 60, child: Text('60 Minuten')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _durationMinutes = value);
                },
              ),
            ],
            if (_type == QuickEntryPresetType.fixed) ...[
              const SizedBox(height: 8),
              ListTile(
                title: const Text('Start'),
                subtitle: Text(_start.format(context)),
                onTap: () => _pickTime(true),
              ),
              ListTile(
                title: const Text('Ende'),
                subtitle: Text(_end.format(context)),
                onTap: () => _pickTime(false),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(widget.isNew ? 'Hinzufügen' : 'Speichern'),
        ),
      ],
    );
  }
}

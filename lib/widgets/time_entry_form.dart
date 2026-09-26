import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/models.dart';
import '../providers/providers.dart';
import '../services/formatters.dart';
import '../utils/project_colors.dart';

class TimeEntryFormSheet extends ConsumerStatefulWidget {
  const TimeEntryFormSheet({
    super.key,
    required this.workplace,
    this.entry,
    this.initialDate,
    this.initialStart,
    this.initialEnd,
    this.defaultMidnight = false,
    this.source = EntrySource.manual,
  });

  final Workplace workplace;
  final TimeEntry? entry;
  final DateTime? initialDate;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  final bool defaultMidnight;
  final EntrySource source;

  @override
  ConsumerState<TimeEntryFormSheet> createState() =>
      _TimeEntryFormSheetState();
}

class _TimeEntryFormSheetState extends ConsumerState<TimeEntryFormSheet> {
  late DateTime _startDate;
  late DateTime _endDate;
  late TimeOfDay _start;
  late TimeOfDay _end;
  late double _rate;
  int? _projectId;
  final _notesController = TextEditingController();
  late final TextEditingController _rateController;
  bool _endManuallyEdited = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (entry != null) {
      _startDate = DateTime(
        entry.startTime.year,
        entry.startTime.month,
        entry.startTime.day,
      );
      _endDate = DateTime(
        entry.endTime.year,
        entry.endTime.month,
        entry.endTime.day,
      );
      _start = TimeOfDay.fromDateTime(entry.startTime);
      _end = TimeOfDay.fromDateTime(entry.endTime);
      _endManuallyEdited = true;
    } else if (widget.initialStart != null && widget.initialEnd != null) {
      _startDate = DateTime(
        widget.initialStart!.year,
        widget.initialStart!.month,
        widget.initialStart!.day,
      );
      _endDate = DateTime(
        widget.initialEnd!.year,
        widget.initialEnd!.month,
        widget.initialEnd!.day,
      );
      _start = TimeOfDay.fromDateTime(widget.initialStart!);
      _end = TimeOfDay.fromDateTime(widget.initialEnd!);
      _endManuallyEdited = true;
    } else {
      _startDate = widget.initialDate ?? today;
      _endDate = widget.initialDate ?? today;
      if (widget.defaultMidnight) {
        _start = const TimeOfDay(hour: 0, minute: 0);
        _end = const TimeOfDay(hour: 0, minute: 30);
      } else {
        _start = TimeOfDay(hour: now.hour, minute: now.minute);
        _end = _addMinutes(_start, 30);
      }
    }

    _rate = entry?.hourlyRate ?? widget.workplace.defaultHourlyRate;
    _rateController = TextEditingController(text: _rate.toStringAsFixed(2));
    _projectId = entry?.projectId;
    _notesController.text = entry?.notes ?? '';

    if (entry == null) {
      loadLastProjectId(widget.workplace.id).then((id) {
        if (!mounted || id == null) return;
        setState(() => _projectId = id);
      });
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  TimeOfDay _addMinutes(TimeOfDay time, int minutes) {
    final total = time.hour * 60 + time.minute + minutes;
    return TimeOfDay(hour: (total ~/ 60) % 24, minute: total % 60);
  }

  DateTime _combine(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      locale: const Locale('de', 'DE'),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
        _endManuallyEdited = true;
      }
    });
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
        if (!_endManuallyEdited) {
          _end = _addMinutes(_start, 30);
          _endDate = _startDate;
        }
      } else {
        _end = picked;
        _endManuallyEdited = true;
      }
    });
  }

  Future<void> _save() async {
    final start = _combine(_startDate, _start);
    var end = _combine(_endDate, _end);
    if (!end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    final db = ref.read(databaseProvider);
    final entry = TimeEntry(
      id: widget.entry?.id ?? 0,
      workplaceId: widget.workplace.id,
      projectId: _projectId,
      date: DateTime(_startDate.year, _startDate.month, _startDate.day),
      startTime: start,
      endTime: end,
      hourlyRate: _rate,
      notes: _notesController.text.trim(),
      source: widget.entry?.source ?? widget.source,
    );

    if (widget.entry == null) {
      await db.insertEntry(entry);
    } else {
      await db.updateEntry(entry);
    }
    await saveLastProjectId(widget.workplace.id, _projectId);
    bumpRefresh(ref);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _addProject() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Projekt hinzufügen'),
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
            child: const Text('Hinzufügen'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;

    final colorIndex =
        (await ref.read(databaseProvider).getProjectsForWorkplace(
              widget.workplace.id,
            ))
            .length;
    final color = projectColorPalette[
        colorIndex % projectColorPalette.length];
    final id = await ref.read(databaseProvider).insertProject(
          Project(
            id: 0,
            workplaceId: widget.workplace.id,
            name: name,
            colorValue: colorToValue(color),
          ),
        );
    bumpRefresh(ref);
    setState(() => _projectId = id);
  }

  Widget _buildDateTimeTile({
    required String label,
    required DateTime date,
    required TimeOfDay time,
    required VoidCallback onDateTap,
    required VoidCallback onTimeTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today, size: 20),
                    title: Text(AppFormatters.date(date)),
                    onTap: onDateTap,
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.access_time, size: 20),
                    title: Text(time.format(context)),
                    onTap: onTimeTap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync =
        ref.watch(projectsProvider(widget.workplace.id));

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.entry == null ? 'Eintrag hinzufügen' : 'Eintrag bearbeiten',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildDateTimeTile(
              label: 'Start',
              date: _startDate,
              time: _start,
              onDateTap: () => _pickDate(true),
              onTimeTap: () => _pickTime(true),
            ),
            _buildDateTimeTile(
              label: 'Ende',
              date: _endDate,
              time: _end,
              onDateTap: () => _pickDate(false),
              onTimeTap: () => _pickTime(false),
            ),
            TextField(
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Stundensatz (EUR)',
                helperText:
                    'Standard: ${widget.workplace.defaultHourlyRate.toStringAsFixed(2)}',
              ),
              controller: _rateController,
              onChanged: (value) {
                _rate = double.tryParse(value.replaceAll(',', '.')) ?? _rate;
              },
            ),
            const SizedBox(height: 8),
            projectsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Fehler: $e'),
              data: (projects) => Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _projectId,
                      decoration: const InputDecoration(labelText: 'Projekt'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Kein Projekt'),
                        ),
                        ...projects.map(
                          (p) => DropdownMenuItem(
                            value: p.id,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 6,
                                  backgroundColor: projectColor(p.colorValue),
                                ),
                                const SizedBox(width: 8),
                                Text(p.name),
                              ],
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) => setState(() => _projectId = value),
                    ),
                  ),
                  IconButton(
                    onPressed: _addProject,
                    icon: const Icon(Icons.add),
                    tooltip: 'Projekt hinzufügen',
                  ),
                ],
              ),
            ),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notizen'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<bool?> showTimeEntryForm(
  BuildContext context, {
  required Workplace workplace,
  TimeEntry? entry,
  DateTime? initialDate,
  DateTime? initialStart,
  DateTime? initialEnd,
  bool defaultMidnight = false,
  EntrySource source = EntrySource.manual,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (context) => TimeEntryFormSheet(
      workplace: workplace,
      entry: entry,
      initialDate: initialDate,
      initialStart: initialStart,
      initialEnd: initialEnd,
      defaultMidnight: defaultMidnight,
      source: source,
    ),
  );
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum QuickEntryPresetType { dynamicHalfHour, fixed }

class QuickEntryPreset {
  const QuickEntryPreset({
    required this.id,
    required this.name,
    required this.type,
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
    this.durationMinutes = 30,
  });

  final String id;
  final String name;
  final QuickEntryPresetType type;
  final int? startHour;
  final int? startMinute;
  final int? endHour;
  final int? endMinute;
  final int durationMinutes;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.name,
        'startHour': startHour,
        'startMinute': startMinute,
        'endHour': endHour,
        'endMinute': endMinute,
        'durationMinutes': durationMinutes,
      };

  factory QuickEntryPreset.fromJson(Map<String, dynamic> json) {
    return QuickEntryPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      type: QuickEntryPresetType.values.byName(json['type'] as String),
      startHour: json['startHour'] as int?,
      startMinute: json['startMinute'] as int?,
      endHour: json['endHour'] as int?,
      endMinute: json['endMinute'] as int?,
      durationMinutes: json['durationMinutes'] as int? ?? 30,
    );
  }

  QuickEntryPreset copyWith({
    String? name,
    QuickEntryPresetType? type,
    int? startHour,
    int? startMinute,
    int? endHour,
    int? endMinute,
    int? durationMinutes,
  }) {
    return QuickEntryPreset(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      startHour: startHour ?? this.startHour,
      startMinute: startMinute ?? this.startMinute,
      endHour: endHour ?? this.endHour,
      endMinute: endMinute ?? this.endMinute,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

class QuickEntryService {
  static const _prefsKey = 'quick_entry_presets';

  static const defaultPresetId = 'default_dynamic';

  static QuickEntryPreset get defaultPreset => const QuickEntryPreset(
        id: defaultPresetId,
        name: 'Schneller Eintrag',
        type: QuickEntryPresetType.dynamicHalfHour,
        durationMinutes: 30,
      );

  Future<List<QuickEntryPreset>> getPresets() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [defaultPreset];

    final list = (jsonDecode(raw) as List)
        .map((e) => QuickEntryPreset.fromJson(e as Map<String, dynamic>))
        .toList();
    if (list.isEmpty) return [defaultPreset];
    return list;
  }

  Future<void> savePresets(List<QuickEntryPreset> presets) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(presets.map((p) => p.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }

  /// Rounds [dt] to the nearest 15-minute boundary.
  static DateTime roundToNearestQuarterHour(DateTime dt) {
    final totalMinutes = dt.hour * 60 + dt.minute;
    final rounded = (totalMinutes / 15).round() * 15;
    final dayOffset = rounded ~/ (24 * 60);
    final minutesInDay = rounded % (24 * 60);
    return DateTime(
      dt.year,
      dt.month,
      dt.day + dayOffset,
      minutesInDay ~/ 60,
      minutesInDay % 60,
    );
  }

  static ({DateTime start, DateTime end}) computeTimes(
    QuickEntryPreset preset, {
    DateTime? reference,
  }) {
    final now = reference ?? DateTime.now();

    switch (preset.type) {
      case QuickEntryPresetType.dynamicHalfHour:
        final end = roundToNearestQuarterHour(now);
        final start = end.subtract(Duration(minutes: preset.durationMinutes));
        return (start: start, end: end);
      case QuickEntryPresetType.fixed:
        var start = DateTime(
          now.year,
          now.month,
          now.day,
          preset.startHour ?? 0,
          preset.startMinute ?? 0,
        );
        var end = DateTime(
          now.year,
          now.month,
          now.day,
          preset.endHour ?? 0,
          preset.endMinute ?? 0,
        );
        if (!end.isAfter(start)) {
          end = end.add(const Duration(days: 1));
        }
        return (start: start, end: end);
    }
  }

  static String formatTimeRange(DateTime start, DateTime end) {
    final sh = start.hour.toString().padLeft(2, '0');
    final sm = start.minute.toString().padLeft(2, '0');
    final eh = end.hour.toString().padLeft(2, '0');
    final em = end.minute.toString().padLeft(2, '0');
    return '$sh:$sm–$eh:$em';
  }

  String displayLabel(QuickEntryPreset preset, {DateTime? reference}) {
    final times = computeTimes(preset, reference: reference);
    return '${preset.name} (${formatTimeRange(times.start, times.end)})';
  }
}

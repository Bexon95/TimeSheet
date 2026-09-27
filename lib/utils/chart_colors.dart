import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../database/models.dart';
import '../services/chart_timeline.dart';
import 'project_colors.dart';

/// Assigns chart colors for [segmentKeys], honoring [preferred] overrides first
/// and picking maximally distinct colors for the rest.
Map<String, Color> chartColorsForSegments({
  required List<String> segmentKeys,
  required Map<String, Color?> preferred,
}) {
  final result = <String, Color>{};
  final used = <Color>[];

  for (final key in segmentKeys) {
    final locked = preferred[key];
    if (locked != null) {
      result[key] = locked;
      used.add(locked);
    }
  }

  final palette = _chartPalette(segmentKeys.length);
  for (final key in segmentKeys) {
    if (result.containsKey(key)) continue;
    final color = _pickDistinctColor(palette, used);
    result[key] = color;
    used.add(color);
  }

  return result;
}

Map<String, Color?> preferredProjectChartColors({
  required List<Project> projects,
  required Iterable<String> segmentKeys,
}) {
  final byId = {for (final p in projects) p.id: p};
  final result = <String, Color?>{};
  for (final key in segmentKeys) {
    final id = ChartProjectSegments.projectIdFromKey(key);
    if (id == null) continue;
    final project = byId[id];
    if (project == null) continue;
    result[key] = projectColor(project.colorValue);
  }
  return result;
}

List<Color> _chartPalette(int needed) {
  final colors = List<Color>.from(projectColorPalette);
  if (needed <= colors.length) return colors;
  for (var i = colors.length; i < needed; i++) {
    final hue = (i * 137.5) % 360;
    colors.add(HSVColor.fromAHSV(1, hue, 0.65, 0.85).toColor());
  }
  return colors;
}

Color _pickDistinctColor(List<Color> palette, List<Color> used) {
  if (used.isEmpty) {
    return palette.first;
  }

  Color? best;
  var bestScore = -1.0;
  for (final candidate in palette) {
    if (used.contains(candidate)) continue;
    final score = used
        .map((color) => _colorDistance(candidate, color))
        .reduce(math.min);
    if (score > bestScore) {
      bestScore = score;
      best = candidate;
    }
  }

  if (best != null) return best;

  final hue = (used.length * 137.5) % 360;
  return HSVColor.fromAHSV(1, hue, 0.65, 0.85).toColor();
}

double _colorDistance(Color a, Color b) {
  final dr = a.r - b.r;
  final dg = a.g - b.g;
  final db = a.b - b.b;
  return dr * dr + dg * dg + db * db;
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timesheet/database/models.dart';
import 'package:timesheet/services/chart_timeline.dart';
import 'package:timesheet/utils/chart_colors.dart';
import 'package:timesheet/utils/project_colors.dart';

void main() {
  test('preferredProjectChartColors uses project color values', () {
    final projects = [
      Project(
        id: 10,
        workplaceId: 1,
        name: 'Alpha',
        colorValue: projectColorPalette.first.value,
      ),
    ];
    final preferred = preferredProjectChartColors(
      projects: projects,
      segmentKeys: [ChartProjectSegments.keyFor(10)],
    );
    expect(preferred['p_10'], projectColorPalette.first);
  });

  test('chartColorsForSegments assigns distinct colors', () {
    final colors = chartColorsForSegments(
      segmentKeys: ['p_1', 'p_2', 'p_3'],
      preferred: const {},
    );
    expect(colors.length, 3);
    expect(colors.values.toSet().length, 3);
  });
}

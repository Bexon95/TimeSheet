import 'package:flutter_test/flutter_test.dart';
import 'package:timesheet/services/chart_timeline.dart';

void main() {
  test('bottomLabelIndices includes start and end', () {
    final indices = ChartTimeline.bottomLabelIndices(
      dayCount: 90,
      chartWidth: 400,
    );
    expect(indices.first, 0);
    expect(indices.last, 89);
    expect(indices.length, greaterThan(2));
  });

  test('bottomLabelIndices shows every day for a week', () {
    final indices = ChartTimeline.bottomLabelIndices(
      dayCount: 7,
      chartWidth: 400,
    );
    expect(indices, [0, 1, 2, 3, 4, 5, 6]);
  });
}

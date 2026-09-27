import 'package:flutter_test/flutter_test.dart';
import 'package:timesheet/services/chart_axis_labels.dart';

void main() {
  test('chartAxisLabelInterval spaces labels for narrow charts', () {
    expect(chartAxisLabelInterval(30, 320), greaterThan(1));
    expect(chartAxisLabelInterval(7, 400), greaterThanOrEqualTo(1));
  });

  test('showChartAxisLabel always shows first and last', () {
    const count = 30;
    final interval = chartAxisLabelInterval(count, 320);
    expect(showChartAxisLabel(index: 0, pointCount: count, interval: interval),
        isTrue);
    expect(
      showChartAxisLabel(index: count - 1, pointCount: count, interval: interval),
      isTrue,
    );
    expect(
      showChartAxisLabel(index: count - 2, pointCount: count, interval: interval),
      isFalse,
    );
  });
}

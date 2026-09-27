import 'package:flutter_test/flutter_test.dart';
import 'package:timesheet/services/chart_axis.dart';

void main() {
  test('forPeak uses modest cap and 4–5 divisions for 25h peak', () {
    final scale = ChartAxisScale.forPeak(25);
    expect(scale.maxY, 30);
    expect(scale.interval, 10);
    expect((scale.maxY / scale.interval).round(), 3);
  });

  test('forPeak scales daily earnings around 100', () {
    final scale = ChartAxisScale.forPeak(100);
    expect(scale.maxY, 100);
    expect(scale.interval, 25);
  });

  test('forPeak scales monthly earnings around 900–980', () {
    expect(ChartAxisScale.forPeak(900).maxY, 1000);
    final scale = ChartAxisScale.forPeak(980);
    expect(scale.maxY, 1000);
    expect(scale.interval, 250);
  });

  test('forPeak handles empty-scale edge case', () {
    final scale = ChartAxisScale.forPeak(0);
    expect(scale.maxY, 1);
  });
}

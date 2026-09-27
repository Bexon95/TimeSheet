import 'dart:math' as math;

/// Rounded Y-axis bounds for bar charts (avoids odd max tick labels like 1176).
class ChartAxisScale {
  ChartAxisScale({required this.maxY, required this.interval});

  final double maxY;
  final double interval;

  /// Scale from the tallest value on the chart (bar height or cumulative total).
  static ChartAxisScale forPeak(double peak) {
    if (peak <= 0) {
      return ChartAxisScale(maxY: 1, interval: 0.25);
    }
    final maxY = _sensibleMax(peak);
    final interval = _stepForMax(maxY);
    return ChartAxisScale(
      maxY: maxY,
      interval: interval > 0 ? interval : maxY,
    );
  }

  /// Whether [value] is an intentional tick for [interval] (guards float noise).
  static bool isTickValue(double value, double interval) {
    if (interval <= 0) return true;
    final steps = value / interval;
    return (steps - steps.round()).abs() < 0.001;
  }

  static double _sensibleMax(double peak) {
    final caps = _niceCaps();
    var capIndex = 0;
    while (capIndex < caps.length && caps[capIndex] < peak) {
      capIndex++;
    }
    if (capIndex >= caps.length) return caps.last;

    var cap = caps[capIndex];
    if (cap == peak && capIndex + 1 < caps.length && peak < 100) {
      final next = caps[capIndex + 1];
      if (next / peak <= 1.25) {
        cap = next;
      }
    }
    return cap;
  }

  static List<double> _niceCaps() {
    final caps = <double>{};
    for (var exp = -2; exp < 8; exp++) {
      final magnitude = math.pow(10.0, exp).toDouble();
      for (final factor in [
        1.0,
        1.2,
        1.5,
        2.0,
        2.5,
        3.0,
        4.0,
        5.0,
        6.0,
        8.0,
        10.0,
      ]) {
        final raw = factor * magnitude;
        if (raw <= 0 || raw > 1e9) continue;
        caps.add(_quantizeCap(raw));
      }
    }
    final sorted = caps.toList()..sort();
    return sorted;
  }

  static double _quantizeCap(double value) {
    if (value >= 100) return value.roundToDouble();
    if (value >= 10) return (value * 10).round() / 10;
    if (value >= 1) return (value * 100).round() / 100;
    return (value * 1000).round() / 1000;
  }

  static double _stepForMax(double maxY) {
    for (final divisions in [4, 5, 3, 6]) {
      final step = maxY / divisions;
      if (_isCleanStep(step)) return step;
    }

    final stepCandidates = <double>[];
    for (var exp = -2; exp < 8; exp++) {
      final magnitude = math.pow(10.0, exp).toDouble();
      for (final factor in [1.0, 2.0, 2.5, 5.0, 10.0]) {
        stepCandidates.add(factor * magnitude);
      }
    }
    stepCandidates.sort((a, b) => b.compareTo(a));

    for (final divisions in [4, 5, 3, 6]) {
      for (final step in stepCandidates) {
        if (step <= 0) continue;
        final remainder = maxY % step;
        if (remainder > 0.01 && (maxY - remainder) > 0.01) continue;
        final divCount = maxY / step;
        if ((divCount - divisions).abs() < 0.01) return step;
      }
    }

    for (final step in stepCandidates.reversed) {
      if (step <= 0) continue;
      final divCount = maxY / step;
      if (divCount >= 3 && divCount <= 6 && _isCleanStep(step)) {
        return step;
      }
    }

    return maxY / 4;
  }

  static bool _isCleanStep(double step) {
    if (step <= 0) return false;
    for (var exp = -2; exp < 8; exp++) {
      final magnitude = math.pow(10.0, exp).toDouble();
      for (final factor in [1.0, 2.0, 2.5, 5.0, 10.0]) {
        if ((step - factor * magnitude).abs() < 0.01) return true;
      }
    }
    return false;
  }
}

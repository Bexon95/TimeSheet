import 'package:flutter/material.dart';

/// Default palette when creating or picking project colors.
const List<Color> projectColorPalette = [
  Color(0xFF5C6BC0),
  Color(0xFF26A69A),
  Color(0xFFEF5350),
  Color(0xFFFFA726),
  Color(0xFFAB47BC),
  Color(0xFF42A5F5),
  Color(0xFF8D6E63),
  Color(0xFF78909C),
];

Color projectColor(int? colorValue, {Color fallback = Colors.indigo}) {
  if (colorValue == null) return fallback;
  return Color(colorValue);
}

int colorToValue(Color color) => color.value;

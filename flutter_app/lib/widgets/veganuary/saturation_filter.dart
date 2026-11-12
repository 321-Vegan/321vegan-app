import 'dart:ui';

/// From grey ([saturation] 0) to the original colors (1), for what isn't
/// open yet on the Veganuary (the recipe's pot, a locked week's cover).
ColorFilter saturationFilter(double saturation) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final s = saturation;
  return ColorFilter.matrix(<double>[
    r + (1 - r) * s, g - g * s, b - b * s, 0, 0, //
    r - r * s, g + (1 - g) * s, b - b * s, 0, 0, //
    r - r * s, g - g * s, b + (1 - b) * s, 0, 0, //
    0, 0, 0, 1, 0, //
  ]);
}

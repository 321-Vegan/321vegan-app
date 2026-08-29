import 'package:flutter/material.dart';
import '../models/seasonal_theme.dart';

SeasonalTheme winterTheme = const SeasonalTheme(
  name: 'Hiver',
  season: Season.winter,
  primaryColor: Color(0xFF0284C7),
  confettiColors: [
    Color(0xFFE0F2FE),
    Color(0xFFFFFFFF),
    Color(0xFF38BDF8),
    Color(0xFFBAE6FD),
  ],
  particleType: ParticleType.snowflakes,
  particleCount: 200,
  particleOpacity: 1.0,
  // 192.05deg linear-gradient from Figma.
  backgroundGradient: LinearGradient(
    begin: Alignment(0.2087, -0.978),
    end: Alignment(-0.2087, 0.978),
    stops: [0.0, 0.3],
    colors: [
      Color(0xFFD8E8F5),
      Color(0xFFEDF4FA),
    ],
  ),
);

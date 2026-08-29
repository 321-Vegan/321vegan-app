import 'package:flutter/material.dart';
import '../models/seasonal_theme.dart';

const SeasonalTheme defaultTheme = SeasonalTheme(
  name: 'Défaut',
  season: Season.defaultTheme,
  primaryColor: Color(0xFF15866E),
  confettiColors: [
    Colors.red,
    Colors.blue,
    Colors.green,
    Colors.yellow,
  ],
  particleType: ParticleType.sunRays,
  backgroundGradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF0FDF4),
      Colors.white,
    ],
  ),
);

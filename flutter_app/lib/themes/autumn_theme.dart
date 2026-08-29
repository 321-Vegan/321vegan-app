import 'package:flutter/material.dart';
import '../models/seasonal_theme.dart';

SeasonalTheme autumnTheme = const SeasonalTheme(
  name: 'Automne',
  season: Season.autumn,
  primaryColor: Color(0xFFEA580C),
  confettiColors: [
    Color(0xFFF97316),
    Color(0xFFDC2626),
    Color(0xFFA16207),
    Color(0xFFFCD34D),
  ],
  particleType: ParticleType.leaves,
  particleCount: 100,
  particleOpacity: 0.7,
  snowGlobeParticleAssets: [
    'lib/assets/themes/particles/autumn-leaf.webp',
  ],
  // 192.05deg linear-gradient from Figma.
  backgroundGradient: LinearGradient(
    begin: Alignment(0.2087, -0.978),
    end: Alignment(-0.2087, 0.978),
    stops: [0.0, 0.3],
    colors: [
      Color(0xFFFBCA7B),
      Color(0xFFFAF3E8),
    ],
  ),
);

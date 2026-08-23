import 'package:flutter/material.dart';
import '../models/seasonal_theme.dart';

SeasonalTheme autumnTheme = SeasonalTheme(
  name: 'Automne',
  season: Season.autumn,
  primaryColor: const Color(0xFFEA580C),
  confettiColors: [
    const Color(0xFFF97316),
    const Color(0xFFDC2626),
    const Color(0xFFA16207),
    const Color(0xFFFCD34D),
  ],
  particleType: ParticleType.leaves,
  particleCount: 100,
  particleOpacity: 0.7,
  snowGlobeParticleAssets: [
    'lib/assets/themes/particles/autumn-leaf.webp',
  ],
  // 192.05deg linear-gradient from Figma.
  backgroundGradient: const LinearGradient(
    begin: Alignment(0.2087, -0.978),
    end: Alignment(-0.2087, 0.978),
    stops: [0.0, 0.3],
    colors: [
      Color(0xFFFBCA7B),
      Color(0xFFFAF3E8),
    ],
  ),
);

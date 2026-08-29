import 'package:flutter/material.dart';
import '../models/seasonal_theme.dart';

SeasonalTheme summerTheme = const SeasonalTheme(
  name: 'Été',
  season: Season.summer,
  primaryColor: Color.fromARGB(255, 228, 176, 8),
  confettiColors: [
    Color(0xFFFCD34D),
    Color(0xFF60A5FA),
    Color(0xFF22C55E),
    Color(0xFFFCA311),
  ],
  particleType: ParticleType.sunRays,
  particleCount: 40,
  particleOpacity: 0.7,
  snowGlobeParticleAssets: [
    'lib/assets/themes/particles/summer-fraise.webp',
    'lib/assets/themes/particles/summer-orange.webp',
    'lib/assets/themes/particles/summer-tomate.webp',
  ],
  particleMinRadius: 2,
  particleMaxRadius: 6,
  // 192.05deg linear-gradient from Figma.
  backgroundGradient: LinearGradient(
    begin: Alignment(0.2087, -0.978),
    end: Alignment(-0.2087, 0.978),
    stops: [0.0, 0.3],
    colors: [
      Color(0xFFFFE57C),
      Color(0xFFFFFBF2),
    ],
  ),
);

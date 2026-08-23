import 'package:flutter/material.dart';
import '../models/seasonal_theme.dart';

SeasonalTheme springTheme = SeasonalTheme(
  name: 'Printemps',
  season: Season.spring,
  primaryColor: const Color(0xFFBA5A86),
  confettiColors: [
    const Color(0xFFFDA4AF),
    const Color(0xFFFDE047),
    const Color(0xFF86EFAC),
    const Color(0xFFDDD6FE),
  ],
  particleType: ParticleType.petals,
  particleCount: 50,
  particleOpacity: 0.7,
  snowGlobeParticleAssets: [
    'lib/assets/themes/particles/spring-flower1.webp',
    'lib/assets/themes/particles/spring-flower2.webp',
  ],
  particleMinRadius: 2,
  particleMaxRadius: 4,
  // 192.05deg linear-gradient from Figma.
  backgroundGradient: const LinearGradient(
    begin: Alignment(0.2087, -0.978),
    end: Alignment(-0.2087, 0.978),
    stops: [0.0, 0.3],
    colors: [
      Color(0xFFF5CFC0),
      Color(0xFFFCF3EE),
    ],
  ),
);

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/seasonal_theme.dart';

SeasonalTheme summerTheme = SeasonalTheme(
  name: 'Été',
  season: Season.summer,
  primaryColor: const Color.fromARGB(255, 228, 176, 8),
  secondaryColor: const Color(0xFF166534),
  accentColor: const Color(0xFF60A5FA),
  waveColor: const Color.fromARGB(255, 228, 176, 8),
  seasonalIcon: Icons.sunny,
  iconBackgroundColor: const Color(0xFFFEF9C3),
  confettiColors: [
    const Color(0xFFFCD34D),
    const Color(0xFF60A5FA),
    const Color(0xFF22C55E),
    const Color(0xFFFCA311),
  ],
  particleType: ParticleType.sunRays,
  seasonalAsset: 'lib/assets/images/ruche.webp',
  snowGlobeParticleAsset: 'lib/assets/images/papillon.webp',
  // 192.05deg linear-gradient from Figma.
  backgroundGradient: const LinearGradient(
    begin: Alignment(0.2087, -0.978),
    end: Alignment(-0.2087, 0.978),
    stops: [0.0, 0.3],
    colors: [
      Color(0xFFFFE57C),
      Color(0xFFFFFBF2),
    ],
  ),
  iconTopPosition: -700.h,
  iconLeftPosition: 100.w,
);

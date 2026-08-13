import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/seasonal_theme.dart';

SeasonalTheme winterTheme = SeasonalTheme(
  name: 'Hiver',
  season: Season.winter,
  primaryColor: const Color(0xFF0284C7),
  secondaryColor: const Color(0xFF64748B),
  accentColor: const Color(0xFF06B6D4),
  waveColor: const Color(0xFF38BDF8),
  seasonalIcon: Icons.ac_unit,
  iconBackgroundColor: const Color(0xFFF0F9FF),
  confettiColors: [
    const Color(0xFFE0F2FE),
    const Color(0xFFFFFFFF),
    const Color(0xFF38BDF8),
    const Color(0xFFBAE6FD),
  ],
  particleType: ParticleType.snowflakes,
  particleCount: 200,
  particleOpacity: 1.0,
  // 192.05deg linear-gradient from Figma.
  backgroundGradient: const LinearGradient(
    begin: Alignment(0.2087, -0.978),
    end: Alignment(-0.2087, 0.978),
    stops: [0.0, 0.3],
    colors: [
      Color(0xFFD8E8F5),
      Color(0xFFEDF4FA),
    ],
  ),
  iconTopPosition: -200.h,
  iconLeftPosition: -100.w,
);

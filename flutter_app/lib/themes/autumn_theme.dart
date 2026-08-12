import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/seasonal_theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

SeasonalTheme autumnTheme = SeasonalTheme(
  name: 'Automne',
  season: Season.autumn,
  primaryColor: const Color(0xFFEA580C),
  secondaryColor: const Color(0xFFA16207),
  accentColor: const Color(0xFFDC2626),
  waveColor: const Color(0xFFFB923C),
  seasonalIcon: FontAwesomeIcons.canadianMapleLeaf,
  iconBackgroundColor: const Color(0xFFFEF3C7),
  confettiColors: [
    const Color(0xFFF97316),
    const Color(0xFFDC2626),
    const Color(0xFFA16207),
    const Color(0xFFFCD34D),
  ],
  particleType: ParticleType.leaves,
  seasonalAsset: 'lib/assets/images/pumpkin.webp',
  snowGlobeParticleIcon: FontAwesomeIcons.canadianMapleLeaf,
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
  iconTopPosition: -500.h,
  iconLeftPosition: -50.w,
);

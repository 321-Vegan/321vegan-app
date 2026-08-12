import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/seasonal_theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

SeasonalTheme springTheme = SeasonalTheme(
  name: 'Printemps',
  season: Season.spring,
  primaryColor: const Color(0xFFBA5A86),
  secondaryColor: const Color(0xFFFDA4AF),
  accentColor: const Color(0xFFFDE047),
  waveColor: const Color.fromARGB(255, 234, 115, 168),
  seasonalIcon: FontAwesomeIcons.dove,
  iconBackgroundColor: const Color(0xFFFEF3C7),
  confettiColors: [
    const Color(0xFFFDA4AF),
    const Color(0xFFFDE047),
    const Color(0xFF86EFAC),
    const Color(0xFFDDD6FE),
  ],
  particleType: ParticleType.petals,
  seasonalAsset: 'lib/assets/images/tulipe.webp',
  snowGlobeParticleAsset: 'lib/assets/images/marguerite.webp',
  iconTopPosition: -400.h,
  iconLeftPosition: -200.w,
  // 192.05deg linear-gradient from Figma.
  backgroundGradient: const LinearGradient(
    begin: Alignment(0.2087, -0.978),
    end: Alignment(-0.2087, 0.978),
    stops: [0.0, 0.3],
    colors: [
      Color(0xFFC3E6A0),
      Color(0xFFF0F8E4),
    ],
  ),
);

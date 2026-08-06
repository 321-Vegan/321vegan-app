import 'package:flutter/material.dart';

enum Season {
  defaultTheme,
  spring,
  summer,
  autumn,
  winter,
}

enum ParticleType {
  petals,
  sunRays,
  leaves,
  snowflakes,
}

class SeasonalTheme extends ThemeExtension<SeasonalTheme> {
  final String name;
  final Season season;
  final Color primaryColor;
  final Color secondaryColor;
  final Color accentColor;
  final Color waveColor;
  final IconData seasonalIcon;
  final List<Color> confettiColors;
  final ParticleType particleType;
  final Color iconBackgroundColor;
  final LinearGradient? backgroundGradient;
  final double iconTopPosition;
  final double iconLeftPosition;

  /// Asset path for the main seasonal image (e.g. pumpkin, tulip, ruche).
  /// Null means the season uses [seasonalIcon] instead.
  final String? seasonalAsset;

  /// Asset path for the snow-globe particle image (e.g. marguerite, papillon).
  /// Null means particles use [snowGlobeParticleIcon] or default snowflakes.
  final String? snowGlobeParticleAsset;

  /// Icon for snow-globe particles (e.g. maple leaf for autumn).
  /// Only used when [snowGlobeParticleAsset] is null.
  final IconData? snowGlobeParticleIcon;

  bool get isPremium => season != Season.defaultTheme;

  const SeasonalTheme({
    required this.name,
    required this.season,
    required this.primaryColor,
    required this.secondaryColor,
    required this.accentColor,
    required this.waveColor,
    required this.seasonalIcon,
    required this.confettiColors,
    required this.particleType,
    required this.iconBackgroundColor,
    this.backgroundGradient,
    this.iconTopPosition = 0,
    this.iconLeftPosition = 0,
    this.seasonalAsset,
    this.snowGlobeParticleAsset,
    this.snowGlobeParticleIcon,
  });

  @override
  SeasonalTheme copyWith({
    String? name,
    Season? season,
    Color? primaryColor,
    Color? secondaryColor,
    Color? accentColor,
    Color? waveColor,
    IconData? seasonalIcon,
    List<Color>? confettiColors,
    ParticleType? particleType,
    Color? iconBackgroundColor,
    LinearGradient? backgroundGradient,
    double? iconTopPosition,
    double? iconLeftPosition,
    String? seasonalAsset,
    String? snowGlobeParticleAsset,
    IconData? snowGlobeParticleIcon,
  }) {
    return SeasonalTheme(
      name: name ?? this.name,
      season: season ?? this.season,
      primaryColor: primaryColor ?? this.primaryColor,
      secondaryColor: secondaryColor ?? this.secondaryColor,
      accentColor: accentColor ?? this.accentColor,
      waveColor: waveColor ?? this.waveColor,
      seasonalIcon: seasonalIcon ?? this.seasonalIcon,
      confettiColors: confettiColors ?? this.confettiColors,
      particleType: particleType ?? this.particleType,
      iconBackgroundColor: iconBackgroundColor ?? this.iconBackgroundColor,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      iconTopPosition: iconTopPosition ?? this.iconTopPosition,
      iconLeftPosition: iconLeftPosition ?? this.iconLeftPosition,
      seasonalAsset: seasonalAsset ?? this.seasonalAsset,
      snowGlobeParticleAsset:
          snowGlobeParticleAsset ?? this.snowGlobeParticleAsset,
      snowGlobeParticleIcon:
          snowGlobeParticleIcon ?? this.snowGlobeParticleIcon,
    );
  }

  @override
  SeasonalTheme lerp(SeasonalTheme? other, double t) {
    if (other == null) return this;
    return SeasonalTheme(
      name: t < 0.5 ? name : other.name,
      season: t < 0.5 ? season : other.season,
      primaryColor: Color.lerp(primaryColor, other.primaryColor, t)!,
      secondaryColor: Color.lerp(secondaryColor, other.secondaryColor, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      waveColor: Color.lerp(waveColor, other.waveColor, t)!,
      seasonalIcon: t < 0.5 ? seasonalIcon : other.seasonalIcon,
      confettiColors: t < 0.5 ? confettiColors : other.confettiColors,
      particleType: t < 0.5 ? particleType : other.particleType,
      iconBackgroundColor:
          Color.lerp(iconBackgroundColor, other.iconBackgroundColor, t)!,
      backgroundGradient:
          t < 0.5 ? backgroundGradient : other.backgroundGradient,
      iconTopPosition:
          iconTopPosition + (other.iconTopPosition - iconTopPosition) * t,
      iconLeftPosition:
          iconLeftPosition + (other.iconLeftPosition - iconLeftPosition) * t,
      seasonalAsset: t < 0.5 ? seasonalAsset : other.seasonalAsset,
      snowGlobeParticleAsset:
          t < 0.5 ? snowGlobeParticleAsset : other.snowGlobeParticleAsset,
      snowGlobeParticleIcon:
          t < 0.5 ? snowGlobeParticleIcon : other.snowGlobeParticleIcon,
    );
  }

  // Create a ColorScheme from this theme
  ColorScheme toColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      secondary: secondaryColor,
      surface: Colors.white,
      brightness: Brightness.light,
    );
  }

  // Create a ThemeData from this theme
  ThemeData toThemeData() {
    return ThemeData(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: toColorScheme(),
      useMaterial3: true,
      primaryColor: primaryColor,
      // App-wide default body font. Explicit fontFamily: 'Baloo' on a
      // TextStyle (used for prominent numbers/counters) overrides this.
      fontFamily: 'Karla',
      extensions: [this],
    );
  }
}

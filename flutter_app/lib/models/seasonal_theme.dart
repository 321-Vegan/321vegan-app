import 'package:flutter/material.dart';
import '../themes/default_theme.dart';

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
  final List<Color> confettiColors;
  final ParticleType particleType;

  /// Number of drifting snow-globe particles (see [AppBackground]); each
  /// season tunes its own density.
  final int particleCount;

  /// Opacity multiplier on top of each particle's own random base opacity
  /// (see [AppBackground]/[SnowGlobeOverlay]) — 1.0 keeps the default range.
  final double particleOpacity;

  /// Random particle radius range (see [SnowGlobeOverlay]); each particle
  /// picks one at creation and keeps it for its lifetime.
  final double particleMinRadius;
  final double particleMaxRadius;

  final LinearGradient? backgroundGradient;

  /// Asset paths the snow-globe particles are randomly drawn from (e.g. one
  /// per particle for summer's strawberry/orange/tomato mix). Null/empty
  /// means particles use [snowGlobeParticleIcon] or default snowflakes.
  final List<String>? snowGlobeParticleAssets;

  /// Icon for snow-globe particles (e.g. maple leaf for autumn).
  /// Only used when [snowGlobeParticleAssets] is null/empty.
  final IconData? snowGlobeParticleIcon;

  bool get isPremium => season != Season.defaultTheme;

  const SeasonalTheme({
    required this.name,
    required this.season,
    required this.primaryColor,
    required this.confettiColors,
    required this.particleType,
    this.particleCount = 16,
    this.particleOpacity = 1.0,
    this.particleMinRadius = 1.5,
    this.particleMaxRadius = 4.0,
    this.backgroundGradient,
    this.snowGlobeParticleAssets,
    this.snowGlobeParticleIcon,
  });

  @override
  SeasonalTheme copyWith({
    String? name,
    Season? season,
    Color? primaryColor,
    List<Color>? confettiColors,
    ParticleType? particleType,
    int? particleCount,
    double? particleOpacity,
    double? particleMinRadius,
    double? particleMaxRadius,
    LinearGradient? backgroundGradient,
    List<String>? snowGlobeParticleAssets,
    IconData? snowGlobeParticleIcon,
  }) {
    return SeasonalTheme(
      name: name ?? this.name,
      season: season ?? this.season,
      primaryColor: primaryColor ?? this.primaryColor,
      confettiColors: confettiColors ?? this.confettiColors,
      particleType: particleType ?? this.particleType,
      particleCount: particleCount ?? this.particleCount,
      particleOpacity: particleOpacity ?? this.particleOpacity,
      particleMinRadius: particleMinRadius ?? this.particleMinRadius,
      particleMaxRadius: particleMaxRadius ?? this.particleMaxRadius,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      snowGlobeParticleAssets:
          snowGlobeParticleAssets ?? this.snowGlobeParticleAssets,
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
      confettiColors: t < 0.5 ? confettiColors : other.confettiColors,
      particleType: t < 0.5 ? particleType : other.particleType,
      particleCount: t < 0.5 ? particleCount : other.particleCount,
      particleOpacity:
          particleOpacity + (other.particleOpacity - particleOpacity) * t,
      particleMinRadius:
          particleMinRadius + (other.particleMinRadius - particleMinRadius) * t,
      particleMaxRadius:
          particleMaxRadius + (other.particleMaxRadius - particleMaxRadius) * t,
      backgroundGradient:
          t < 0.5 ? backgroundGradient : other.backgroundGradient,
      snowGlobeParticleAssets:
          t < 0.5 ? snowGlobeParticleAssets : other.snowGlobeParticleAssets,
      snowGlobeParticleIcon:
          t < 0.5 ? snowGlobeParticleIcon : other.snowGlobeParticleIcon,
    );
  }

  ColorScheme toColorScheme() {
    return ColorScheme.fromSeed(
      seedColor: primaryColor,
      primary: primaryColor,
      surface: Colors.white,
      brightness: Brightness.light,
    );
  }

  // Buttons/icons/colorScheme stay the app's one base palette regardless of
  // season; only the [SeasonalTheme] extension below varies, driving the
  // background gradient/particles ([AppBackground]).
  ThemeData toThemeData() {
    return ThemeData(
      scaffoldBackgroundColor: Colors.white,
      colorScheme: defaultTheme.toColorScheme(),
      useMaterial3: true,
      primaryColor: defaultTheme.primaryColor,
      // App-wide default body font. Explicit fontFamily: 'Baloo' on a
      // TextStyle (used for prominent numbers/counters) overrides this.
      fontFamily: 'Karla',
      extensions: [this],
    );
  }
}

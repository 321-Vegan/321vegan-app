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
  final Color secondaryColor;
  final Color accentColor;
  final Color waveColor;
  final IconData seasonalIcon;
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

  final Color iconBackgroundColor;
  final LinearGradient? backgroundGradient;
  final double iconTopPosition;
  final double iconLeftPosition;

  /// Asset path for the main seasonal image (e.g. pumpkin, tulip, ruche).
  /// Null means the season uses [seasonalIcon] instead.
  final String? seasonalAsset;

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
    required this.secondaryColor,
    required this.accentColor,
    required this.waveColor,
    required this.seasonalIcon,
    required this.confettiColors,
    required this.particleType,
    this.particleCount = 16,
    this.particleOpacity = 1.0,
    this.particleMinRadius = 1.5,
    this.particleMaxRadius = 4.0,
    required this.iconBackgroundColor,
    this.backgroundGradient,
    this.iconTopPosition = 0,
    this.iconLeftPosition = 0,
    this.seasonalAsset,
    this.snowGlobeParticleAssets,
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
    int? particleCount,
    double? particleOpacity,
    double? particleMinRadius,
    double? particleMaxRadius,
    Color? iconBackgroundColor,
    LinearGradient? backgroundGradient,
    double? iconTopPosition,
    double? iconLeftPosition,
    String? seasonalAsset,
    List<String>? snowGlobeParticleAssets,
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
      particleCount: particleCount ?? this.particleCount,
      particleOpacity: particleOpacity ?? this.particleOpacity,
      particleMinRadius: particleMinRadius ?? this.particleMinRadius,
      particleMaxRadius: particleMaxRadius ?? this.particleMaxRadius,
      iconBackgroundColor: iconBackgroundColor ?? this.iconBackgroundColor,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
      iconTopPosition: iconTopPosition ?? this.iconTopPosition,
      iconLeftPosition: iconLeftPosition ?? this.iconLeftPosition,
      seasonalAsset: seasonalAsset ?? this.seasonalAsset,
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
      secondaryColor: Color.lerp(secondaryColor, other.secondaryColor, t)!,
      accentColor: Color.lerp(accentColor, other.accentColor, t)!,
      waveColor: Color.lerp(waveColor, other.waveColor, t)!,
      seasonalIcon: t < 0.5 ? seasonalIcon : other.seasonalIcon,
      confettiColors: t < 0.5 ? confettiColors : other.confettiColors,
      particleType: t < 0.5 ? particleType : other.particleType,
      particleCount: t < 0.5 ? particleCount : other.particleCount,
      particleOpacity:
          particleOpacity + (other.particleOpacity - particleOpacity) * t,
      particleMinRadius:
          particleMinRadius + (other.particleMinRadius - particleMinRadius) * t,
      particleMaxRadius:
          particleMaxRadius + (other.particleMaxRadius - particleMaxRadius) * t,
      iconBackgroundColor:
          Color.lerp(iconBackgroundColor, other.iconBackgroundColor, t)!,
      backgroundGradient:
          t < 0.5 ? backgroundGradient : other.backgroundGradient,
      iconTopPosition:
          iconTopPosition + (other.iconTopPosition - iconTopPosition) * t,
      iconLeftPosition:
          iconLeftPosition + (other.iconLeftPosition - iconLeftPosition) * t,
      seasonalAsset: t < 0.5 ? seasonalAsset : other.seasonalAsset,
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
      secondary: secondaryColor,
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

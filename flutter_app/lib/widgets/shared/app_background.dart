import 'package:flutter/material.dart';
import '../../models/seasonal_theme.dart';
import '../../themes/app_colors.dart';
import '../theme/snow_globe_overlay.dart';

/// Paints the app's one basic background gradient behind [child] — the same
/// gradient for every theme, seasonal or not — and, once a seasonal theme
/// (spring/summer/autumn/winter) is active, its drifting snow-globe
/// particles — the same tilt-reactive effect already used on the homepage
/// stat cards, now covering the whole screen instead of just a card.
/// Wrap a page's whole subtree (including its Scaffold, made transparent)
/// so the gradient also shows through the status-bar and app-bar areas.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final seasonal = Theme.of(context).extension<SeasonalTheme>();
    // Only the particles change with the season — the background gradient
    // itself stays the app's original cream for every theme.
    final isSeasonal =
        seasonal != null && seasonal.season != Season.defaultTheme;

    const gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [kBackgroundGradientTop, kBackgroundGradientBottom],
    );

    // SizedBox.expand forces this to fill the available space — a childless
    // DecoratedBox collapses to zero size under the loosened constraints a
    // non-positioned Stack child gets (SnowGlobeOverlay wraps this in its
    // own Stack below), which painted nothing at all.
    Widget backdrop = const SizedBox.expand(
      child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
    );

    final hasParticles = isSeasonal &&
        (seasonal.snowGlobeParticleAsset != null ||
            seasonal.snowGlobeParticleIcon != null ||
            seasonal.particleType == ParticleType.snowflakes);
    if (hasParticles) {
      backdrop = SnowGlobeOverlay(
        particleAsset: seasonal.snowGlobeParticleAsset,
        particleIcon: seasonal.snowGlobeParticleIcon,
        particleCount:
            seasonal.particleType == ParticleType.snowflakes ? 24 : 16,
        particleColor: seasonal.primaryColor,
        borderRadius: BorderRadius.zero,
        child: backdrop,
      );
    }

    // Backdrop (gradient + particles) painted first, page content stacked on
    // top — otherwise the particles would float above cards/buttons instead
    // of drifting behind them.
    return Stack(
      children: [
        Positioned.fill(child: backdrop),
        child,
      ],
    );
  }
}

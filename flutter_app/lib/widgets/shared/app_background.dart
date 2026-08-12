import 'package:flutter/material.dart';
import '../../models/seasonal_theme.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../theme/snow_globe_overlay.dart';

/// Paints the app's background gradient behind [child] — the app's default
/// cream gradient normally, or the active season's own gradient once a
/// seasonal theme (spring/summer/autumn/winter) is active — and, for
/// seasonal themes, drifting snow-globe particles — the same tilt-reactive
/// effect already used on the homepage stat cards, now covering the whole
/// screen instead of just a card.
/// Wrap a page's whole subtree (including its Scaffold, made transparent)
/// so the gradient also shows through the status-bar and app-bar areas.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final seasonal = Theme.of(context).extension<SeasonalTheme>();
    final isSeasonal =
        seasonal != null && seasonal.season != Season.defaultTheme;

    const defaultGradient = LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      stops: [0.0, 0.3],
      colors: [kBackgroundGradientTop, kBackgroundGradientBottom],
    );

    final gradient = isSeasonal
        ? (seasonal.backgroundGradient ?? defaultGradient)
        : defaultGradient;

    // SizedBox.expand forces this to fill the available space — a childless
    // DecoratedBox collapses to zero size under the loosened constraints a
    // non-positioned Stack child gets (SnowGlobeOverlay wraps this in its
    // own Stack below), which painted nothing at all.
    Widget backdrop = SizedBox.expand(
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
            seasonal.particleType == ParticleType.snowflakes ? 200 : 16,
        // Snowflakes read better as white/icy against winter's pale blue
        // gradient than the theme's saturated primary blue.
        particleColor: seasonal.particleType == ParticleType.snowflakes
            ? Colors.white
            : seasonal.primaryColor,
        borderRadius: squircleRadius(0),
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

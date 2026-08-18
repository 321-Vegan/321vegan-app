import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
        ((seasonal.snowGlobeParticleAssets?.isNotEmpty ?? false) ||
            seasonal.snowGlobeParticleIcon != null ||
            seasonal.particleType == ParticleType.snowflakes);
    if (hasParticles) {
      backdrop = SnowGlobeOverlay(
        particleAssets: seasonal.snowGlobeParticleAssets,
        particleIcon: seasonal.snowGlobeParticleIcon,
        particleCount: seasonal.particleCount,
        particleOpacity: seasonal.particleOpacity,
        particleMinRadius: seasonal.particleMinRadius,
        particleMaxRadius: seasonal.particleMaxRadius,
        // Snowflakes read better as white/icy against winter's pale blue
        // gradient than the theme's saturated primary blue.
        particleColor: seasonal.particleType == ParticleType.snowflakes
            ? Colors.white
            : seasonal.primaryColor,
        borderRadius: squircleRadius(0),
        child: backdrop,
      );
    }

    // Soft white sunburst glow, top-right corner, summer only — bleeds off
    // both edges since the asset is a soft radial fade, not a hard shape.
    final summerBurst = isSeasonal && seasonal.season == Season.summer
        ? Positioned(
            top: -80.h,
            right: -80.w,
            child: IgnorePointer(
              child: Image.asset(
                'lib/assets/themes/burst.webp',
                width: 900.w,
                fit: BoxFit.fitWidth,
                alignment: Alignment.topRight,
              ),
            ),
          )
        : null;

    // Backdrop (gradient + particles) painted first, corner glow next, page
    // content stacked on top — otherwise the particles/glow would float
    // above cards/buttons instead of sitting behind them.
    return Stack(
      children: [
        Positioned.fill(child: backdrop),
        if (summerBurst != null) summerBurst,
        child,
      ],
    );
  }
}

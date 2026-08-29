import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../models/seasonal_theme.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../theme/snow_globe_overlay.dart';

/// Paints the app's background gradient behind [child] — the default cream
/// gradient, or the active season's gradient plus drifting snow-globe
/// particles. Wrap a page's whole subtree (Scaffold included, made
/// transparent) so it shows through the status-bar and app-bar areas.
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

    // SizedBox.expand is needed: a childless DecoratedBox collapses to zero
    // size under the loose constraints a Stack child gets, painting nothing.
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

    // Backdrop, then corner glow, then page content — stack order matters,
    // otherwise particles/glow would float above cards/buttons.
    return Stack(
      children: [
        Positioned.fill(child: backdrop),
        if (summerBurst != null) summerBurst,
        child,
      ],
    );
  }
}

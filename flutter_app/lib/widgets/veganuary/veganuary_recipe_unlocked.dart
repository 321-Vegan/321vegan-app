import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../themes/app_colors.dart';
import '../../themes/app_spacing.dart';
import '../../themes/app_text_styles.dart';

/// "Recette débloquée !" over the recipe page as it opens: a padlock
/// wobbles, turns into a bowl ([onUnlocked], for the vibration), then the
/// whole thing fades out on the recipe ([onDone]). A tap skips it.
class VeganuaryRecipeUnlocked extends StatefulWidget {
  final VoidCallback onUnlocked;
  final VoidCallback onDone;

  const VeganuaryRecipeUnlocked({
    super.key,
    required this.onUnlocked,
    required this.onDone,
  });

  @override
  State<VeganuaryRecipeUnlocked> createState() =>
      _VeganuaryRecipeUnlockedState();
}

class _VeganuaryRecipeUnlockedState extends State<VeganuaryRecipeUnlocked>
    with SingleTickerProviderStateMixin {
  /// When the padlock turns into the bowl, along the animation.
  static const double _unlockAt = 0.3;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _unlocked = false;

  late final Animation<double> _scrim = _interval(0, 0.1);
  late final Animation<double> _pastille =
      _interval(0.02, 0.25, Curves.easeOutBack);
  late final Animation<double> _wobble = _interval(0.1, _unlockAt);
  late final Animation<double> _pop =
      _interval(_unlockAt, 0.55, Curves.elasticOut);
  late final Animation<double> _title =
      _interval(_unlockAt + 0.02, 0.5, Curves.easeOutCubic);
  late final Animation<double> _fadeOut = _interval(0.82, 1, Curves.easeIn);

  Animation<double> _interval(double begin, double end,
          [Curve curve = Curves.linear]) =>
      CurvedAnimation(
          parent: _controller, curve: Interval(begin, end, curve: curve));

  @override
  void initState() {
    super.initState();
    _controller
      ..addListener(() {
        if (!_unlocked && _controller.value >= _unlockAt) {
          setState(() => _unlocked = true);
          widget.onUnlocked();
        }
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  /// Straight to the fade out (unlocking first if it wasn't yet).
  void _skip() {
    if (_controller.value < 0.82) _controller.value = 0.82;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final visible = 1 - _fadeOut.value;
          // Shakes harder and harder, as if about to give
          final shake =
              math.sin(_wobble.value * math.pi * 8) * 0.18 * _wobble.value;

          return Opacity(
            opacity: visible,
            child: ColoredBox(
              color: kBackgroundGradientBottom.withValues(
                  alpha: 0.92 * _scrim.value),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: _pastille.value,
                      child: Container(
                        width: 320.w,
                        height: 320.w,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _unlocked ? primary : kLockedFill,
                        ),
                        child: _unlocked
                            ? Transform.scale(
                                scale: 0.4 + 0.6 * _pop.value,
                                child: FaIcon(FontAwesomeIcons.bowlFood,
                                    color: Colors.white, size: 140.sp),
                              )
                            : Transform.rotate(
                                angle: shake,
                                child: FaIcon(FontAwesomeIcons.lock,
                                    color: kLockedContent, size: 130.sp),
                              ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.section),
                    Opacity(
                      opacity: _title.value,
                      child: Transform.translate(
                        offset: Offset(0, 40.h * (1 - _title.value)),
                        child: Text(
                          'Recette débloquée !',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.baloo36,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';

/// Below the last day of the path: the trophy of the course, grey with the
/// days left, then yellow once it's done.
class VeganuaryFinishLine extends StatelessWidget {
  /// Days still to do (0 once the course is over).
  final int daysLeft;

  const VeganuaryFinishLine({super.key, required this.daysLeft});

  bool get _done => daysLeft <= 0;

  @override
  Widget build(BuildContext context) {
    final days = '$daysLeft jour${daysLeft > 1 ? 's' : ''}';
    return Semantics(
      label: _done ? 'Parcours terminé' : 'Fin du parcours dans $days',
      excludeSemantics: true,
      child: Column(
        children: [
          VeganuaryTrophy(done: _done),
          SizedBox(height: 30.h),
          // Changes along with the trophy
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: Column(
              key: ValueKey(_done),
              children: [
                Text(
                  _done ? 'Parcours terminé !' : 'La ligne d\'arrivée',
                  style: AppTextStyles.baloo26
                      .copyWith(color: _done ? kAccentYellow : kTextPrimary),
                ),
                Text(
                  _done ? 'Bravo pour ces 31 jours 💛' : 'Encore $days !',
                  style: AppTextStyles.bodyRegular15
                      .copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The trophy of the course: grey and padlocked like a locked day, yellow
/// once it's done. Becoming done on screen, it shakes, its padlock opens
/// and flies off, then it turns yellow while growing and settles with a
/// bounce; with [appear], it just bounces in already yellow (the last day's
/// done page).
class VeganuaryTrophy extends StatefulWidget {
  final bool done;

  /// In design pixels, before `.w`.
  final double size;

  /// Bounces in when first shown.
  final bool appear;

  const VeganuaryTrophy({
    super.key,
    required this.done,
    this.size = 240,
    this.appear = false,
  });

  @override
  State<VeganuaryTrophy> createState() => _VeganuaryTrophyState();
}

/// Where the unlocking ends and the yellow bounce starts, in the
/// animation (0 to 1).
const double _unlocked = 0.38;

class _VeganuaryTrophyState extends State<VeganuaryTrophy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
    value: widget.done && !widget.appear ? 1 : 0,
  );

  @override
  void initState() {
    super.initState();
    // Already yellow: just the bounce
    if (widget.done && widget.appear) _controller.forward(from: _unlocked);
  }

  @override
  void didUpdateWidget(VeganuaryTrophy oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.done && !oldWidget.done) _unlock();
    if (!widget.done && oldWidget.done) _controller.value = 0;
  }

  /// Once the last coin of the path has turned yellow; straight there if
  /// the phone asks for fewer animations.
  Future<void> _unlock() async {
    if (MediaQuery.of(context).disableAnimations) {
      _controller.value = 1;
      return;
    }
    _controller.value = 0;
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// How far the animation is between [from] and [to], from 0 to 1.
  double _phase(double from, double to) =>
      ((_controller.value - from) / (to - from)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final size = widget.size.w;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final done = widget.done;
        // Shakes harder and harder, then stops as the padlock opens
        final shake = done ? _phase(0, 0.3) : 0.0;
        final angle =
            shake > 0 && shake < 1 ? sin(shake * pi * 10) * 0.14 * shake : 0.0;
        // The padlock opens, then flies up and fades out
        final open = done ? _phase(0.28, _unlocked) : 0.0;
        // Grey to yellow, growing past its size then bouncing back
        final yellow = done
            ? (widget.appear
                ? 1.0
                : Curves.easeOut.transform(_phase(_unlocked, 0.6)))
            : 0.0;
        final bounce = done ? _phase(_unlocked, 1) : 0.0;
        final scale = bounce < 0.35
            ? 1 + 0.3 * Curves.easeOut.transform(bounce / 0.35)
            : 1.3 - 0.3 * Curves.elasticOut.transform((bounce - 0.35) / 0.65);

        return Transform.rotate(
          angle: angle,
          child: Transform.scale(
            scale: scale,
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(kLockedFill, kAccentYellow, yellow),
                      border: Border.all(
                        color: Color.lerp(kLockedEdge, kSecondaryTag, yellow)!,
                        width: 6,
                      ),
                    ),
                    child: FaIcon(
                      FontAwesomeIcons.trophy,
                      size: size * 0.46,
                      color: Color.lerp(kLockedContent, Colors.white, yellow),
                    ),
                  ),
                  if (open < 1 && !(done && widget.appear))
                    Positioned(
                      right: -size * 0.04,
                      bottom: -size * 0.04 + open * size * 0.3,
                      child: Opacity(
                        opacity: 1 - open,
                        child: Transform.scale(
                          scale: 1 + open * 0.4,
                          child: _Padlock(size: size * 0.38, open: open > 0),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// On the trophy until the course is done.
class _Padlock extends StatelessWidget {
  final double size;
  final bool open;

  const _Padlock({required this.size, required this.open});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: kLockedEdge, width: 3),
      ),
      child: Icon(
        open ? Icons.lock_open_rounded : Icons.lock_rounded,
        size: size * 0.55,
        color: kLockedContent,
      ),
    );
  }
}

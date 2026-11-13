import 'dart:math';

import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../models/veganuary/veganuary_content.dart';
import '../../models/veganuary/veganuary_progress.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';
import '../shared/attention_pulse.dart';
import 'saturation_filter.dart';

/// Darker shade of [color], for the side of a coin.
Color _side(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor();
}

const String _recipeIllustration =
    'lib/assets/images/veganuary/recipe-pot.webp';

IconData _iconData(VeganuaryDayIcon icon) => switch (icon) {
      VeganuaryDayIcon.info => FontAwesomeIcons.scroll,
      VeganuaryDayIcon.myth => FontAwesomeIcons.comments,
      VeganuaryDayIcon.recipe => FontAwesomeIcons.bowlFood,
      VeganuaryDayIcon.book => FontAwesomeIcons.book,
      VeganuaryDayIcon.cart => FontAwesomeIcons.basketShopping,
      VeganuaryDayIcon.cow => FontAwesomeIcons.cow,
      VeganuaryDayIcon.egg => FontAwesomeIcons.egg,
      // Font Awesome has no bee nor honeycomb
      VeganuaryDayIcon.honey => Icons.hive,
      VeganuaryDayIcon.plate => FontAwesomeIcons.utensils,
    };

/// A day on the Veganuary path: a coin, yellow once done, green when it's
/// the one to do, grey otherwise. The next day to do also gets a ring
/// (how far into the day the user is) and a bubble above ("COMMENCER" /
/// "DEMAIN").
class VeganuaryDayNode extends StatefulWidget {
  final int day;
  final VeganuaryDayIcon icon;
  final VeganuaryDayState state;

  /// The next day to do (available or tomorrow).
  final bool isNext;

  /// Share of the day read so far (0 to 1), for the ring of the next day.
  final double dayProgress;
  final VoidCallback onTap;

  const VeganuaryDayNode({
    super.key,
    required this.day,
    required this.icon,
    required this.state,
    required this.isNext,
    required this.dayProgress,
    required this.onTap,
  });

  @override
  State<VeganuaryDayNode> createState() => _VeganuaryDayNodeState();
}

const Duration _colorDuration = Duration(milliseconds: 400);

class _VeganuaryDayNodeState extends State<VeganuaryDayNode>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  Offset _pressPosition = Offset.zero;
  DateTime _pressedAt = DateTime.now();

  /// Pushed in for at least this long, for a quick tap to show.
  static const Duration _minPress = Duration(milliseconds: 120);

  void _press(Offset position) {
    _pressPosition = position;
    _pressedAt = DateTime.now();
    setState(() => _pressed = true);
  }

  Future<void> _release() async {
    if (!_pressed) return;
    final held = DateTime.now().difference(_pressedAt);
    if (held < _minPress) await Future.delayed(_minPress - held);
    if (mounted) setState(() => _pressed = false);
  }

  /// Bounce of the coin when the day gets done.
  late final AnimationController _bounce = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  late final Animation<double> _scale = TweenSequence([
    TweenSequenceItem(
      tween:
          Tween(begin: 1.0, end: 1.18).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: 1.18, end: 1.0)
          .chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_bounce);

  @override
  void didUpdateWidget(VeganuaryDayNode oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != VeganuaryDayState.completed &&
        widget.state == VeganuaryDayState.completed) {
      _bounce.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _bounce.dispose();
    super.dispose();
  }

  /// A day shown as an illustration instead of a coin (the recipe's pot):
  /// in color once open, in grey before, pushed in a little when pressed.
  Widget _illustration(String asset, {required bool open}) {
    return AnimatedScale(
      scale: _pressed ? 0.94 : 1,
      duration: const Duration(milliseconds: 80),
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: open ? 1 : 0),
        duration: _colorDuration,
        builder: (context, color, child) => ColorFiltered(
          colorFilter: saturationFilter(color),
          child: child,
        ),
        // A bit bigger than a coin, like on the mockups
        child: Transform.scale(
          scale: 1.15,
          child: Image.asset(asset, fit: BoxFit.contain),
        ),
      ),
    );
  }

  String get _semanticsLabel => 'Jour ${widget.day}, ${switch (widget.state) {
        VeganuaryDayState.completed => 'terminé',
        VeganuaryDayState.available => 'à faire',
        VeganuaryDayState.tomorrow => 'disponible demain',
        VeganuaryDayState.locked => 'verrouillé',
      }}';

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final face = switch (widget.state) {
      VeganuaryDayState.completed => kAccentYellow,
      VeganuaryDayState.available => primary,
      _ => kLockedFill,
    };
    final side = switch (widget.state) {
      VeganuaryDayState.completed || VeganuaryDayState.available => _side(face),
      _ => kLockedEdge,
    };
    final iconColor = widget.state == VeganuaryDayState.completed ||
            widget.state == VeganuaryDayState.available
        ? Colors.white
        : kLockedContent;

    final width = 216.w;
    final faceHeight = width * 0.72;
    final depth = width * 0.15;
    // Pressed, the face goes down onto the side, like a button
    final pressOffset = _pressed ? depth : 0.0;

    final open = widget.state == VeganuaryDayState.completed ||
        widget.state == VeganuaryDayState.available;

    // Colors fade when the state changes (green → yellow once done, grey
    // → green once open)
    final coin = ScaleTransition(
      scale: _scale,
      child: SizedBox(
        width: width,
        height: faceHeight + depth,
        child: widget.icon == VeganuaryDayIcon.recipe
            ? _illustration(_recipeIllustration, open: open)
            : Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: faceHeight,
                    child: AnimatedContainer(
                      duration: _colorDuration,
                      decoration: ShapeDecoration(
                          color: side, shape: const OvalBorder()),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 80),
                    left: 0,
                    right: 0,
                    top: pressOffset,
                    height: faceHeight,
                    child: AnimatedContainer(
                      duration: _colorDuration,
                      decoration: ShapeDecoration(
                          color: face, shape: const OvalBorder()),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Shine of a done (gold) coin
                          ClipOval(
                            child: AnimatedOpacity(
                              duration: _colorDuration,
                              opacity:
                                  widget.state == VeganuaryDayState.completed
                                      ? 1
                                      : 0,
                              child: CustomPaint(painter: _ShinePainter()),
                            ),
                          ),
                          Center(
                            child: TweenAnimationBuilder<Color?>(
                              tween: ColorTween(end: iconColor),
                              duration: _colorDuration,
                              builder: (context, color, _) => FaIcon(
                                  _iconData(widget.icon),
                                  color: color,
                                  size: 78.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );

    final hasRing =
        widget.isNext && widget.state == VeganuaryDayState.available;
    Widget node = coin;
    if (hasRing) {
      // Ring hugging the coin: 18 stroke + 14 gap on each side
      final ringSize = width + 64.w;
      node = SizedBox(
        width: ringSize,
        height: ringSize,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Fades in when it appears, and fills up to the day's progress
            // (from 0, then from where it was when it moves on)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 300),
              builder: (context, opacity, child) =>
                  Opacity(opacity: opacity, child: child),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: widget.dayProgress),
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeOutCubic,
                builder: (context, progress, _) => CustomPaint(
                  size: Size.square(ringSize),
                  painter: _RingPainter(
                    progress: progress,
                    color: primary,
                    strokeWidth: 18.w,
                  ),
                ),
              ),
            ),
            coin,
          ],
        ),
      );
      // Breathes, round like the ring, to show it's the one to do
      node = AttentionPulse(
        radius: ringSize / 2,
        color: primary,
        child: node,
      );
    }

    return Semantics(
      button: true,
      label: _semanticsLabel,
      // Raw pointer events for the press: a tap's onTapDown only comes
      // with its onTapUp in a scrolling list, too late to show
      child: Listener(
        onPointerDown: (event) => _press(event.position),
        onPointerMove: (event) {
          // Becoming a scroll
          if ((event.position - _pressPosition).distance > kTouchSlop) {
            _release();
          }
        },
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          // The path below slides instead of jumping when the bubble and the
          // ring come or go
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            // Lets the bounce and the bubble's pop go past the bounds
            clipBehavior: Clip.none,
            child: !widget.isNext
                ? node
                // The bubble sits on the top of the ring, its pointer dipping
                // in; without a ring, just above the coin
                : Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: hasRing
                              // Box over the ring's top edge, pointer tip just
                              // above the coin
                              ? _Bubble.boxHeight - 20.w
                              : _Bubble.boxHeight + _Bubble.pointerHeight + 6.w,
                        ),
                        child: node,
                      ),
                      // Pops in from its pointer when it appears
                      TweenAnimationBuilder<double>(
                        key: ValueKey(hasRing),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutBack,
                        builder: (context, t, child) => Transform.scale(
                          scale: t,
                          alignment: Alignment.bottomCenter,
                          child:
                              Opacity(opacity: t.clamp(0.0, 1.0), child: child),
                        ),
                        child: _Bubble(
                          label: !hasRing
                              ? 'DEMAIN'
                              // Left halfway: the ring shows it too
                              : widget.dayProgress > 0
                                  ? 'CONTINUER'
                                  : 'COMMENCER',
                          color: hasRing ? primary : kLockedContent,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final String label;
  final Color color;

  const _Bubble({required this.label, required this.color});

  static double get boxHeight => 123.w;
  static double get pointerHeight => 24.w;
  static const double _borderWidth = 2.5;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: boxHeight,
          padding: EdgeInsets.symmetric(horizontal: 39.w),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: squircleBorder(
              radius: 27.r,
              side: const BorderSide(color: kLockedFill, width: _borderWidth),
            ),
          ),
          // Not Container.alignment: it would stretch the bubble to the
          // whole width
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: AppTextStyles.baloo13Bold.copyWith(color: color)),
            ],
          ),
        ),
        // Up over the box's bottom border, so the outline runs on along
        // the pointer
        Transform.translate(
          offset: const Offset(0, -_borderWidth),
          child: CustomPaint(
            size: Size(42.w, pointerHeight),
            painter: _PointerPainter(borderWidth: _borderWidth),
          ),
        ),
      ],
    );
  }
}

/// Two light diagonal bands across a coin's face, rising to the right: a
/// wide one left of the center, a thin one right of it.
class _ShinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.2);
    // Horizontal shift between the bottom and the top of a band
    final slant = size.height * 0.75;
    void band(double center, double halfWidth) {
      final x = size.width * center;
      final w = size.width * halfWidth;
      canvas.drawPath(
        Path()
          ..moveTo(x - w - slant / 2, size.height)
          ..lineTo(x + w - slant / 2, size.height)
          ..lineTo(x + w + slant / 2, 0)
          ..lineTo(x - w + slant / 2, 0)
          ..close(),
        paint,
      );
    }

    band(0.38, 0.12);
    band(0.72, 0.07);
  }

  @override
  bool shouldRepaint(_ShinePainter oldDelegate) => false;
}

class _PointerPainter extends CustomPainter {
  final double borderWidth;

  _PointerPainter({required this.borderWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final sides = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0);
    canvas.drawPath(
      Path.from(sides)..close(),
      Paint()..color = Colors.white,
    );
    canvas.drawPath(
      sides,
      Paint()
        ..color = kLockedFill
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_PointerPainter oldDelegate) =>
      oldDelegate.borderWidth != borderWidth;
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * pi, false, paint..color = kLockedFill);
    if (progress > 0) {
      canvas.drawArc(
          rect, -pi / 2, 2 * pi * progress, false, paint..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth;
}

import 'package:flutter/material.dart';
import '../../themes/app_shapes.dart';

/// Draws attention to [child] (e.g. a button the user hasn't found yet):
/// a squircle halo of [color] grows and fades out around it in a loop,
/// while it swells slightly. Without [enabled], just the child.
class AttentionPulse extends StatefulWidget {
  final Widget child;

  /// Corner radius of the halo, the child's own.
  final double radius;
  final Color color;
  final bool enabled;

  const AttentionPulse({
    super.key,
    required this.child,
    required this.radius,
    required this.color,
    this.enabled = true,
  });

  @override
  State<AttentionPulse> createState() => _AttentionPulseState();
}

class _AttentionPulseState extends State<AttentionPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 2800),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _controller.repeat();
  }

  @override
  void didUpdateWidget(AttentionPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.enabled && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        // The halo takes the first two thirds of the loop, then a pause
        final t = Curves.easeOut
            .transform((_controller.value / 0.66).clamp(0.0, 1.0));
        // Swells then comes back, while the halo leaves
        final swell = 1 + 0.06 * (1 - (2 * t - 1).abs());
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Transform.scale(
                  scale: 1 + 0.45 * t,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                      shape: squircleBorder(radius: widget.radius),
                    ),
                  ),
                ),
              ),
            ),
            Transform.scale(scale: swell, child: child),
          ],
        );
      },
      child: widget.child,
    );
  }
}

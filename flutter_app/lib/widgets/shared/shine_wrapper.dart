import 'package:figma_squircle/figma_squircle.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_shapes.dart';

class ShineWrapper extends StatefulWidget {
  const ShineWrapper({
    super.key,
    required this.borderRadius,
    required this.child,
  });

  final double borderRadius;
  final Widget child;

  @override
  State<ShineWrapper> createState() => _ShineWrapperState();
}

class _ShineWrapperState extends State<ShineWrapper>
    with SingleTickerProviderStateMixin {
  late AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      duration: const Duration(milliseconds: 3500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _shineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipSmoothRect(
      radius: squircleRadius(widget.borderRadius.r),
      child: AnimatedBuilder(
        animation: _shineController,
        builder: (context, child) {
          final t = CurvedAnimation(
            parent: _shineController,
            curve: const Interval(0.0, 0.35, curve: Curves.easeInOut),
          ).value;
          final shinePos = -1.5 + t * 3.0;
          return Stack(
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment(shinePos - 0.4, -1),
                        end: Alignment(shinePos + 0.4, 1),
                        colors: [
                          Colors.transparent,
                          Colors.white.withValues(alpha: 0.28),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}

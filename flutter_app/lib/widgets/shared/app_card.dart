import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';

/// "Surface card" from the Figma design system: white background,
/// 1px [kBorderDefault] border, 20pt radius (override [radius] for
/// components specced differently, e.g. the stat cards at 12pt).
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Corner radius in ScreenUtil units; defaults to the design's 20pt.
  final double? radius;

  const AppCard({super.key, required this.child, this.padding, this.radius});

  @override
  Widget build(BuildContext context) {
    final r = radius ?? 60.r;
    return Container(
      width: double.infinity,
      padding: padding ?? EdgeInsets.all(28.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: kBorderDefault, width: 1),
      ),
      child: child,
    );
  }
}

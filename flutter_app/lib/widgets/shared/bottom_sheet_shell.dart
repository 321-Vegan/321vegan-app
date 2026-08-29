import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_shapes.dart';

/// Common shell for `showModalBottomSheet` content: white squircle card with
/// rounded top corners, a grey drag handle, and safe-area-aware padding.
/// Pass `isScrollControlled: true` and `backgroundColor: Colors.transparent`
/// to `showModalBottomSheet` when using this as the builder's root.
class BottomSheetShell extends StatelessWidget {
  final Widget child;
  final double radius;
  final Color backgroundColor;
  final EdgeInsetsGeometry? padding;

  const BottomSheetShell({
    super.key,
    required this.child,
    this.radius = 24,
    this.backgroundColor = Colors.white,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: squircleBorderOnly(topLeft: radius, topRight: radius),
      ),
      padding: padding ??
          EdgeInsets.only(
            left: 24.w,
            right: 24.w,
            top: 12.h,
            bottom: MediaQuery.of(context).padding.bottom + 24.h,
          ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 70.w,
              height: 8.h,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(3.r),
              ),
            ),
          ),
          SizedBox(height: 64.h),
          child,
        ],
      ),
    );
  }
}

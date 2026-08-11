import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:vegan_app/themes/app_shapes.dart';

Widget buildReviewCard({required Widget child, Color? backgroundColor}) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(24.w),
    decoration: ShapeDecoration(
      color: backgroundColor ?? Colors.white,
      shape: squircleBorder(
        radius: 20.r,
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      shadows: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: child,
  );
}

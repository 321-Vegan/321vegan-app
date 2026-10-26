import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_shapes.dart';
import '../../themes/app_text_styles.dart';

/// One choice of an actions bottom sheet (e.g. the "…" of a restaurant
/// page): tinted icon, title and detail, chevron.
class SheetOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback onTap;

  /// Defaults to the theme's primary color (e.g. red for a deletion).
  final Color? color;

  const SheetOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.detail,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tint = color ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      customBorder: squircleBorder(radius: 30.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
        child: Row(
          children: [
            Container(
              width: 110.w,
              height: 110.w,
              decoration: ShapeDecoration(
                color: tint.withValues(alpha: 0.1),
                shape: squircleBorder(radius: 30.r),
              ),
              child: Icon(icon, color: tint, size: 56.sp),
            ),
            SizedBox(width: 30.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.bodyBold15),
                  Text(detail,
                      style: AppTextStyles.bodyRegular13
                          .copyWith(color: Colors.grey[600])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

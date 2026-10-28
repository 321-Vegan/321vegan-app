import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_text_styles.dart';

/// Shows [text] in a green snack bar, or a red one with [error], in place
/// of the one shown.
void showResultSnackBar(BuildContext context, String text,
    {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? kSemanticError : kSemanticSuccess,
    ));
}

/// Snack bar with a white [icon] before the [message], and an optional
/// white pill button ([actionLabel]) at the end, in the snack bar's [color].
/// The floating squircle look comes from the app's snackBarTheme. Tapping
/// the button doesn't hide the snack bar: [onAction] does it if needed.
SnackBar iconSnackBar({
  required IconData icon,
  required String message,
  required Color color,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 4),
}) {
  return SnackBar(
    // Tighter right padding for the button
    padding: EdgeInsets.fromLTRB(42.w, 18.h, 18.w, 18.h),
    backgroundColor: color,
    duration: duration,
    content: Row(
      children: [
        Icon(icon, color: Colors.white, size: 54.sp),
        SizedBox(width: 24.w),
        Expanded(
          child: Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyBold15.copyWith(color: Colors.white),
          ),
        ),
        if (actionLabel != null) ...[
          SizedBox(width: 18.w),
          Material(
            color: Colors.white,
            shape: const StadiumBorder(),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onAction,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 33.w, vertical: 21.h),
                child: Text(
                  actionLabel,
                  style: AppTextStyles.bodyBold13.copyWith(color: color),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../themes/app_colors.dart';
import '../../themes/app_shapes.dart';

/// Inline error message for forms inside a modal bottom sheet.
///
/// A page-level `ScaffoldMessenger` SnackBar renders behind an open modal
/// bottom sheet (the sheet sits above the page's Scaffold in the Overlay
/// stack), so it's invisible for errors that intentionally keep the sheet
/// open for the user to correct (e.g. "wrong password, try again"). Use
/// this instead for that case; SnackBars remain fine for errors/success
/// shown after the sheet has been popped.
class FormErrorBanner extends StatelessWidget {
  final String message;

  const FormErrorBanner({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 24.h),
      decoration: ShapeDecoration(
        color: kSemanticError.withValues(alpha: 0.08),
        shape: squircleBorder(
          radius: 24.r,
          side: BorderSide(color: kSemanticError.withValues(alpha: 0.4)),
        ),
      ),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 39.sp,
          fontWeight: FontWeight.w600,
          color: kSemanticError,
        ),
      ),
    );
  }
}

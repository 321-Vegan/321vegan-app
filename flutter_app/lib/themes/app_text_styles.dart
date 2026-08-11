import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// Shared text styles from the Figma redesign. Getters (not consts)
/// because ScreenUtil units resolve at runtime.
class AppTextStyles {
  AppTextStyles._();

  /// Section titles ("Végan depuis…", "Boutiques solidaires", "Badges").
  /// Figma: Baloo 2 SemiBold 22px, line-height 100%, letter-spacing -1.
  static TextStyle get sectionTitle => TextStyle(
        fontFamily: 'Baloo2',
        fontWeight: FontWeight.w600,
        fontSize: 66.sp,
        height: 1.0,
        letterSpacing: -1,
        color: kTextPrimary,
      );

  /// Page-level title (header username / "Bienvenue").
  /// Figma: Baloo 2 SemiBold 26px, line-height 100%, letter-spacing -1.
  static TextStyle get pageTitle => TextStyle(
        fontFamily: 'Baloo2',
        fontWeight: FontWeight.w600,
        fontSize: 78.sp,
        height: 1.0,
        letterSpacing: -1,
        color: kTextPrimary,
      );

  /// "Résultats (N)" search-results counter — [sectionTitle] a size down.
  static TextStyle get resultsCount => TextStyle(
        fontFamily: 'Baloo2',
        fontWeight: FontWeight.w600,
        fontSize: 66.sp,
        height: 1.0,
        letterSpacing: -1,
        color: kTextPrimary,
      );
}

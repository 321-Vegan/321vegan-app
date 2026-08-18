import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

/// Shared text styles from the Figma redesign ("Styles" → "Styles de
/// texte" panel: Baloo 2 SemiBold at 17/22/26/36 for headings, Karla at
/// 10/11/13/15 in various weights for body text). Getters (not consts)
/// because ScreenUtil units resolve at runtime.
///
/// Figma point sizes are ×3 here to match `designSize: Size(1170, 2532)`
/// in main.dart (3× an iPhone's 390pt logical width) before going through
/// ScreenUtil's `.sp` — e.g. Figma's 22px heading is `66.sp` below.
///
/// New text should reuse one of these instead of a hand-rolled `TextStyle`;
/// add a new getter here first if the Figma frame calls for a size/weight
/// that isn't covered yet, rather than inlining one-off `TextStyle`s.
/// Every Baloo 2 style carries `letterSpacing: -1` — Figma spec, applies at
/// every size.
class AppTextStyles {
  AppTextStyles._();

  // ---- Baloo 2 (headings) ----
  // Named with their Figma point size (baloo17/22/26/36) so a size in a
  // Figma frame maps straight to a getter name — no guessing which one a
  // semantic name like "sectionTitle" refers to.

  /// Baloo 2 SemiBold 17/Auto — smallest heading (compact titles, tags).
  static TextStyle get baloo17 => TextStyle(
        fontFamily: 'Baloo2',
        fontWeight: FontWeight.w600,
        fontSize: 51.sp,
        height: 1.0,
        letterSpacing: -1,
        color: kTextPrimary,
      );

  /// Baloo 2 SemiBold 22/Auto — section titles ("Végan depuis…", "Boutiques
  /// solidaires", "Badges") and the "Résultats (N)" search counter.
  static TextStyle get baloo22 => TextStyle(
        fontFamily: 'Baloo2',
        fontWeight: FontWeight.w600,
        fontSize: 66.sp,
        height: 1.0,
        letterSpacing: -1,
        color: kTextPrimary,
      );

  /// Baloo 2 SemiBold 26/Auto — page-level title (header username /
  /// "Bienvenue").
  static TextStyle get baloo26 => TextStyle(
        fontFamily: 'Baloo2',
        fontWeight: FontWeight.w600,
        fontSize: 78.sp,
        height: 1.0,
        letterSpacing: -1,
        color: kTextPrimary,
      );

  /// Baloo 2 SemiBold 36/43.2 — hero/display size (subscription price,
  /// onboarding headline).
  static TextStyle get baloo36 => TextStyle(
        fontFamily: 'Baloo2',
        fontWeight: FontWeight.w600,
        fontSize: 108.sp,
        height: 1.2,
        letterSpacing: -1,
        color: kTextPrimary,
      );

  // ---- Karla (body) ----
  // Karla is the app's default fontFamily (see ThemeData in main.dart), so
  // these only need to be reached for when a specific Figma body-text
  // token calls for a weight/size combination — not for every piece of body
  // copy. No letterSpacing override: Figma's Karla styles are all Auto.

  static TextStyle get bodyItalic10 => TextStyle(
        fontFamily: 'Karla',
        fontStyle: FontStyle.italic,
        fontSize: 30.sp,
        color: kTextPrimary,
      );

  static TextStyle get bodyRegular10 => TextStyle(
        fontFamily: 'Karla',
        fontWeight: FontWeight.w400,
        fontSize: 30.sp,
        color: kTextPrimary,
      );

  static TextStyle get bodyMedium11 => TextStyle(
        fontFamily: 'Karla',
        fontWeight: FontWeight.w500,
        fontSize: 33.sp,
        color: kTextPrimary,
      );

  static TextStyle get bodyBold11 => TextStyle(
        fontFamily: 'Karla',
        fontWeight: FontWeight.bold,
        fontSize: 33.sp,
        color: kTextPrimary,
      );

  static TextStyle get bodyRegular13 => TextStyle(
        fontFamily: 'Karla',
        fontWeight: FontWeight.w400,
        fontSize: 39.sp,
        color: kTextPrimary,
      );

  static TextStyle get bodyMedium13 => TextStyle(
        fontFamily: 'Karla',
        fontWeight: FontWeight.w500,
        fontSize: 39.sp,
        color: kTextPrimary,
      );

  static TextStyle get bodyBold13 => TextStyle(
        fontFamily: 'Karla',
        fontWeight: FontWeight.bold,
        fontSize: 39.sp,
        color: kTextPrimary,
      );

  static TextStyle get bodyLight15 => TextStyle(
        fontFamily: 'Karla',
        fontWeight: FontWeight.w300,
        fontSize: 45.sp,
        color: kTextPrimary,
      );

  static TextStyle get bodyRegular15 => TextStyle(
        fontFamily: 'Karla',
        fontWeight: FontWeight.w400,
        fontSize: 45.sp,
        color: kTextPrimary,
      );

  static TextStyle get bodyMedium15 => TextStyle(
        fontFamily: 'Karla',
        fontWeight: FontWeight.w500,
        fontSize: 45.sp,
        color: kTextPrimary,
      );

  static TextStyle get bodyBold15 => TextStyle(
        fontFamily: 'Karla',
        fontWeight: FontWeight.bold,
        fontSize: 45.sp,
        color: kTextPrimary,
      );
  static TextStyle get bodyBold22 => TextStyle(
      fontFamily: 'Karla',
      fontWeight: FontWeight.bold,
      fontSize: 66.sp,
      color: kTextPrimary,
    );
}
